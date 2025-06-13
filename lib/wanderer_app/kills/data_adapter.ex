defmodule WandererApp.Kills.DataAdapter do
  @moduledoc """
  Adapts WandererKills service data format to match existing frontend expectations.

  The WandererKills service returns structured JSON with nested objects,
  but the frontend expects a flat structure with prefixed field names.

  ## Data Flow

  1. Receives killmail data from WandererKills WebSocket service
  2. Validates the format (nested, flat, or zkillboard)
  3. Transforms nested format to flat format for frontend compatibility
  4. Returns empty map for invalid or unsupported formats

  ## Supported Formats

  - **Nested format** - Standard WandererKills service format with victim/attacker objects
  - **Flat format** - Already adapted format (passthrough)
  - **zkillboard format** - Not supported (returns empty map)
  """

  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)

  @type killmail :: map()
  @type adapter_result :: {:ok, killmail()} | {:error, term()}
  @type system_id :: String.t() | integer()

  @doc """
  Converts a kill from WandererKills service format to the flat format expected by the frontend.

  ## Service Format (input):
  ```json
  {
    "killmail_id": 123456789,
    "kill_time": "2024-01-15T14:30:00Z",
    "solar_system_id": 30000142,
    "victim": {
      "character_id": 987654321,
      "corporation_id": 123456789,
      "alliance_id": 456789123,
      "ship_type_id": 671,
      "damage_taken": 2847
    },
    "attackers": [...],
    "zkb": {...}
  }
  ```

  ## Frontend Format (output):
  ```json
  {
    "killmail_id": 123456789,
    "victim_char_id": 987654321,
    "victim_corp_id": 123456789,
    ...
  }
  ```
  """
  @spec adapt_kill_data(any()) :: adapter_result()
  def adapt_kill_data(kill)

  # Pattern match on zkillboard format - not supported
  def adapt_kill_data(%{"killID" => kill_id}) do
    @logger.warning("[DataAdapter] Zkillboard format not supported: killID=#{kill_id}")
    {:error, :zkillboard_format_not_supported}
  end

  # Pattern match on flat format - already adapted
  def adapt_kill_data(%{"victim_char_id" => _} = kill) do
    case validate_flat_format_kill(kill) do
      %{} = validated_kill when map_size(validated_kill) > 0 ->
        {:ok, validated_kill}

      %{} ->
        @logger.warning("[DataAdapter] Invalid flat format kill: #{inspect(kill["killmail_id"])}")
        {:error, :invalid_data}

      error ->
        @logger.warning("[DataAdapter] Validation failed: #{inspect(error)}")
        {:error, :validation_failed}
    end
  end

  # Pattern match on nested format with valid structure
  def adapt_kill_data(
        %{
          "killmail_id" => killmail_id,
          "kill_time" => kill_time,
          "victim" => victim
        } = kill
      )
      when is_map(victim) do
    # Handle both "solar_system_id" and "system_id"
    solar_system_id = kill["solar_system_id"] || kill["system_id"]

    case adapt_nested_format_kill(kill) do
      %{} = adapted_kill when map_size(adapted_kill) > 0 ->
        {:ok, adapted_kill}

      %{} ->
        @logger.warning("[DataAdapter] Invalid nested format kill: #{killmail_id}")
        {:error, :invalid_data}

      error ->
        @logger.warning("[DataAdapter] Nested format adaptation failed: #{inspect(error)}")
        {:error, :validation_failed}
    end
  end

  # Pattern match on any other map structure
  def adapt_kill_data(kill) when is_map(kill) do
    cond do
      Map.has_key?(kill, "zkb") and not Map.has_key?(kill, "killmail_id") ->
        @logger.warning("[DataAdapter] Zkillboard format detected but not supported")
        {:error, :zkillboard_format_detected}

      true ->
        # Check for required fields, allowing either "solar_system_id" or "system_id"
        has_system_id = Map.has_key?(kill, "solar_system_id") or Map.has_key?(kill, "system_id")

        required_present =
          Map.has_key?(kill, "killmail_id") and
            Map.has_key?(kill, "kill_time") and
            Map.has_key?(kill, "victim") and
            has_system_id

        if required_present do
          # Try to adapt it as nested format
          adapt_nested_format_kill(kill)
          |> case do
            %{} = adapted_kill when map_size(adapted_kill) > 0 ->
              {:ok, adapted_kill}

            _ ->
              @logger.warning(
                "[DataAdapter] Failed to adapt kill: #{inspect(kill["killmail_id"])}"
              )

              {:error, :adaptation_failed}
          end
        else
          missing = []

          missing =
            if not Map.has_key?(kill, "killmail_id"), do: ["killmail_id" | missing], else: missing

          missing =
            if not Map.has_key?(kill, "kill_time"), do: ["kill_time" | missing], else: missing

          missing = if not Map.has_key?(kill, "victim"), do: ["victim" | missing], else: missing

          missing =
            if not has_system_id, do: ["solar_system_id or system_id" | missing], else: missing

          @logger.warning("[DataAdapter] Missing required fields: #{inspect(missing)}")
          {:error, :missing_required_fields}
        end
    end
  end

  # Invalid data type
  def adapt_kill_data(invalid_data) do
    data_type = if(is_nil(invalid_data), do: "nil", else: "#{inspect(invalid_data)}")
    @logger.warning("[DataAdapter] Invalid data type: #{data_type}")
    {:error, :invalid_format}
  end

  @doc """
  Adapts a list of kills from service format to frontend format.
  """
  @spec adapt_kills_list(any()) :: list(killmail())
  def adapt_kills_list(kills) when is_list(kills) do
    adapted =
      kills
      |> Stream.with_index()
      |> Stream.map(fn {kill, index} ->
        case adapt_kill_data(kill) do
          {:ok, adapted_kill} ->
            adapted_kill

          {:error, reason} ->
            @logger.warning(
              "[DataAdapter] Failed to adapt kill at index #{index}: #{inspect(reason)}"
            )

            nil
        end
      end)
      |> Stream.filter(&(&1 != nil))
      |> Enum.to_list()

    adapted
  end

  def adapt_kills_list(invalid_data) do
    @logger.warning("[DataAdapter] Expected list of kills, got: #{inspect(invalid_data)}")
    []
  end

  @doc """
  Adapts a systems kills map from service format to frontend format.
  Returns a map of %{system_id => [adapted_kills]}
  """
  @spec adapt_systems_kills(any()) :: %{String.t() => list(killmail())}
  def adapt_systems_kills(systems_kills) when is_map(systems_kills) do
    Enum.into(systems_kills, %{}, fn {system_id, kills} ->
      adapted_kills = adapt_kills_list(kills)
      {to_string(system_id), adapted_kills}
    end)
  end

  def adapt_systems_kills(invalid_data) do
    @logger.warning("[DataAdapter] Expected map of systems kills, got: #{inspect(invalid_data)}")
    %{}
  end

  # Private helper functions

  @spec validate_flat_format_kill(map()) :: map()
  defp validate_flat_format_kill(kill) do
    required_fields = ["killmail_id", "kill_time", "solar_system_id"]

    case validate_required_fields(kill, required_fields) do
      :ok ->
        kill

      {:error, missing} ->
        @logger.warning(
          "[DataAdapter] Flat format kill missing required fields: #{inspect(missing)}"
        )

        %{}
    end
  end

  @spec adapt_nested_format_kill(map()) :: map()
  defp adapt_nested_format_kill(kill) do
    victim = kill["victim"]
    attackers = Map.get(kill, "attackers", [])
    zkb = Map.get(kill, "zkb", %{})

    # Validate attackers is a list
    attackers_list = if is_list(attackers), do: attackers, else: []
    final_blow_attacker = find_final_blow_attacker(attackers_list)

    adapted_kill =
      %{}
      |> add_core_kill_data(kill, zkb)
      |> add_victim_data(victim)
      |> add_final_blow_attacker_data(final_blow_attacker)
      |> add_kill_statistics(attackers_list, zkb)

    # Validate that critical output fields are present
    case validate_required_output_fields(adapted_kill) do
      :ok ->
        adapted_kill

      {:error, missing_fields} ->
        @logger.warning(
          "[DataAdapter] Kill adaptation failed - missing required fields: #{inspect(missing_fields)}, killmail_id: #{inspect(kill["killmail_id"])}"
        )

        %{}
    end
  end

  @spec add_core_kill_data(map(), map(), map()) :: map()
  defp add_core_kill_data(acc, kill, zkb) do
    # Handle both "solar_system_id" and "system_id"
    solar_system_id = kill["solar_system_id"] || kill["system_id"]

    Map.merge(acc, %{
      "killmail_id" => kill["killmail_id"],
      "kill_time" => kill["kill_time"],
      "solar_system_id" => solar_system_id,
      "zkb" => zkb
    })
  end

  @spec add_victim_data(map(), map()) :: map()
  defp add_victim_data(acc, victim) do
    victim_data = %{
      "victim_char_id" => victim["character_id"],
      "victim_char_name" => get_character_name(victim),
      "victim_corp_id" => victim["corporation_id"],
      "victim_corp_ticker" => get_corp_ticker(victim),
      "victim_corp_name" => get_corp_name(victim),
      "victim_alliance_id" => victim["alliance_id"],
      "victim_alliance_ticker" => get_alliance_ticker(victim),
      "victim_alliance_name" => get_alliance_name(victim),
      "victim_ship_type_id" => victim["ship_type_id"],
      "victim_ship_name" => get_ship_name(victim)
    }

    # Log any nil values in victim data
    nil_fields =
      victim_data
      |> Enum.filter(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(&elem(&1, 0))

    if nil_fields != [] do
      @logger.debug(fn ->
        "[DataAdapter] Nil victim fields: #{inspect(nil_fields)}, raw victim: #{inspect(victim, pretty: true)}"
      end)
    end

    Map.merge(acc, victim_data)
  end

  @spec add_final_blow_attacker_data(map(), map()) :: map()
  defp add_final_blow_attacker_data(acc, attacker) do
    attacker_data = %{
      "final_blow_char_id" => attacker["character_id"],
      "final_blow_char_name" => get_character_name(attacker),
      "final_blow_corp_id" => attacker["corporation_id"],
      "final_blow_corp_ticker" => get_corp_ticker(attacker),
      "final_blow_corp_name" => get_corp_name(attacker),
      "final_blow_alliance_id" => attacker["alliance_id"],
      "final_blow_alliance_ticker" => get_alliance_ticker(attacker),
      "final_blow_alliance_name" => get_alliance_name(attacker),
      "final_blow_ship_type_id" => attacker["ship_type_id"],
      "final_blow_ship_name" => get_ship_name(attacker)
    }

    # Log any nil values in attacker data
    nil_fields =
      attacker_data
      |> Enum.filter(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(&elem(&1, 0))

    if nil_fields != [] do
      @logger.debug(fn ->
        "[DataAdapter] Nil attacker fields: #{inspect(nil_fields)}, raw attacker: #{inspect(attacker, pretty: true)}"
      end)
    end

    Map.merge(acc, attacker_data)
  end

  @spec add_kill_statistics(map(), list(), map()) :: map()
  defp add_kill_statistics(acc, attackers_list, zkb) do
    Map.merge(acc, %{
      "attacker_count" => length(attackers_list),
      "total_value" => zkb["total_value"] || zkb["totalValue"] || 0,
      "npc" => zkb["npc"] || false
    })
  end

  # Critical fields that the frontend expects to be present in killmail data
  @required_output_fields [
    "killmail_id",
    "kill_time",
    "solar_system_id",
    "victim_ship_type_id",
    "attacker_count",
    "total_value"
  ]

  @spec validate_required_output_fields(map()) :: :ok | {:error, list(String.t())}
  defp validate_required_output_fields(adapted_kill) do
    validate_required_fields(adapted_kill, @required_output_fields)
  end

  @spec validate_required_fields(map(), list(String.t())) :: :ok | {:error, list(String.t())}
  defp validate_required_fields(data, fields) do
    missing = Enum.filter(fields, &(not Map.has_key?(data, &1)))

    case missing do
      [] -> :ok
      _ -> {:error, missing}
    end
  end

  @spec find_final_blow_attacker(list(map()) | any()) :: map()
  defp find_final_blow_attacker(attackers) when is_list(attackers) do
    final_blow =
      Enum.find(attackers, %{}, fn
        %{"final_blow" => true} = attacker -> attacker
        _ -> false
      end)

    if final_blow == %{} and length(attackers) > 0 do
      @logger.debug(fn ->
        "[DataAdapter] No final blow attacker found in #{length(attackers)} attackers. First attacker: #{inspect(List.first(attackers), pretty: true)}"
      end)
    end

    final_blow
  end

  defp find_final_blow_attacker(_), do: %{}

  # Generic field extraction with multiple possible field names
  @spec extract_field(map() | any(), list(String.t()) | String.t()) :: String.t() | nil
  defp extract_field(data, field_names) when is_list(field_names) do
    Enum.find_value(field_names, fn field_name ->
      case Map.get(data, field_name) do
        value when is_binary(value) and value != "" -> value
        _ -> nil
      end
    end)
  end

  defp extract_field(data, field_name) when is_binary(field_name) do
    extract_field(data, [field_name])
  end

  defp extract_field(_, _), do: nil

  # Specific field extractors using the generic function
  @spec get_character_name(map() | any()) :: String.t() | nil
  defp get_character_name(data) when is_map(data) do
    # Try multiple possible field names
    # For nested character object
    name =
      extract_field(data, ["attacker_name", "victim_name", "character_name", "name"]) ||
        case Map.get(data, "character") do
          %{"name" => name} when is_binary(name) -> name
          _ -> nil
        end

    # Log if we couldn't find a name but have a character_id
    if is_nil(name) and Map.has_key?(data, "character_id") and not is_nil(data["character_id"]) do
      @logger.debug(fn ->
        "[DataAdapter] No name found for character_id: #{data["character_id"]}, available keys: #{inspect(Map.keys(data))}"
      end)
    end

    name
  end

  defp get_character_name(_), do: nil

  @spec get_corp_ticker(map() | any()) :: String.t() | nil
  defp get_corp_ticker(data), do: extract_field(data, ["corporation_ticker", "corp_ticker"])

  @spec get_corp_name(map() | any()) :: String.t() | nil
  defp get_corp_name(data), do: extract_field(data, ["corporation_name", "corp_name"])

  @spec get_alliance_ticker(map() | any()) :: String.t() | nil
  defp get_alliance_ticker(data), do: extract_field(data, ["alliance_ticker"])

  @spec get_alliance_name(map() | any()) :: String.t() | nil
  defp get_alliance_name(data), do: extract_field(data, ["alliance_name"])

  @spec get_ship_name(map() | any()) :: String.t() | nil
  defp get_ship_name(data), do: extract_field(data, ["ship_name", "ship_type_name"])
end
