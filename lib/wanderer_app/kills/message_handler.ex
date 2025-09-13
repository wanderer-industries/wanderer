defmodule WandererApp.Kills.MessageHandler do
  @moduledoc """
  Handles killmail message processing and broadcasting.
  """

  require Logger

  alias WandererApp.Kills.{Config, Storage}
  alias WandererApp.Kills.Subscription.MapIntegration

  @spec process_killmail_update(map()) :: :ok
  def process_killmail_update(payload) do
    case validate_killmail_payload(payload) do
      {:ok, %{"system_id" => system_id, "killmails" => killmails}} ->
        # Log each kill received
        log_received_killmails(killmails, system_id)

        process_valid_killmail_update(system_id, killmails, payload)

      {:error, reason} ->
        Logger.error("[MessageHandler] Invalid killmail payload: #{inspect(reason)}")
        :ok
    end
  end

  defp process_valid_killmail_update(system_id, killmails, payload) do
    {valid_killmails, failed_adaptations} =
      killmails
      |> Enum.filter(&is_map/1)
      |> Enum.with_index()
      |> Enum.reduce({[], []}, &process_killmail_for_adaptation/2)

    # Reverse to maintain original order
    valid_killmails = Enum.reverse(valid_killmails)
    failed_adaptations = Enum.reverse(failed_adaptations)

    # Store failed adaptations for potential retry
    if failed_adaptations != [] do
      store_failed_adaptations(system_id, failed_adaptations)
    end

    Logger.debug(fn ->
      "[MessageHandler] Valid killmails after adaptation: #{length(valid_killmails)}"
    end)

    if valid_killmails != [] do
      store_and_broadcast_killmails(system_id, valid_killmails, payload)
    else
      :ok
    end
  end

  defp store_and_broadcast_killmails(system_id, valid_killmails, payload) do
    killmail_ttl = Config.killmail_ttl()
    kill_count_ttl = Config.kill_count_ttl()

    case Storage.store_killmails(system_id, valid_killmails, killmail_ttl) do
      :ok ->
        handle_stored_killmails(system_id, valid_killmails, kill_count_ttl, payload)

      error ->
        Logger.error(
          "[MessageHandler] Failed to store killmails for system #{system_id}: #{inspect(error)}"
        )

        error
    end
  end

  defp handle_stored_killmails(system_id, valid_killmails, kill_count_ttl, payload) do
    case Storage.update_kill_count(system_id, length(valid_killmails), kill_count_ttl) do
      :ok ->
        broadcast_killmails(system_id, valid_killmails, payload)
        :ok

      error ->
        Logger.error(
          "[MessageHandler] Failed to update kill count for system #{system_id}: #{inspect(error)}"
        )

        error
    end
  end

  @spec process_kill_count_update(map()) :: :ok | {:error, atom()} | {:error, term()}
  def process_kill_count_update(payload) do
    case validate_kill_count_payload(payload) do
      {:ok, %{"system_id" => system_id, "count" => count}} ->
        case Storage.store_kill_count(system_id, count) do
          :ok ->
            broadcast_kill_count(system_id, payload)
            :ok

          error ->
            Logger.error(
              "[MessageHandler] Failed to store kill count for system #{system_id}: #{inspect(error)}"
            )

            error
        end

      {:error, reason} ->
        Logger.warning(
          "[MessageHandler] Invalid kill count payload: #{inspect(reason)}, payload: #{inspect(payload)}"
        )

        {:error, :invalid_payload}
    end
  end

  defp broadcast_kill_count(system_id, payload) do
    case MapIntegration.broadcast_kill_to_maps(%{
           "solar_system_id" => system_id,
           "count" => payload["count"],
           "type" => :kill_count
         }) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("[MessageHandler] Failed to broadcast kill count: #{inspect(reason)}")
        :ok
    end
  end

  defp broadcast_killmails(system_id, killmails, payload) do
    case MapIntegration.broadcast_kill_to_maps(%{
           "solar_system_id" => system_id,
           "killmails" => killmails,
           "timestamp" => payload["timestamp"],
           "type" => :killmail_update
         }) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("[MessageHandler] Failed to broadcast killmails: #{inspect(reason)}")
        :ok
    end
  end

  defp store_failed_adaptations(system_id, failed_kills) do
    # Store with a special key for retry processing
    key = "kills:failed_adaptations:#{system_id}"
    # Keep for 1 hour for potential retry
    ttl = :timer.hours(1)

    case WandererApp.Cache.insert_or_update(
           key,
           failed_kills,
           fn existing ->
             # Merge with existing failed kills, keeping newest
             (failed_kills ++ existing)
             |> Enum.uniq_by(& &1["killmail_id"])
             # Limit to prevent unbounded growth
             |> Enum.take(100)
           end,
           ttl: ttl
         ) do
      :ok ->
        Logger.debug(
          "[MessageHandler] Stored #{length(failed_kills)} failed adaptations for system #{system_id}"
        )

      {:ok, _} ->
        Logger.debug(
          "[MessageHandler] Stored #{length(failed_kills)} failed adaptations for system #{system_id}"
        )

      error ->
        Logger.error("[MessageHandler] Failed to store failed adaptations: #{inspect(error)}")
    end
  end

  # Data adaptation functions (moved from DataAdapter module)

  @type killmail :: map()
  @type adapter_result :: {:ok, killmail()} | {:error, term()}

  @spec adapt_kill_data(any()) :: adapter_result()
  # Pattern match on zkillboard format - not supported
  defp adapt_kill_data(%{"killID" => kill_id}) do
    Logger.warning("[MessageHandler] Zkillboard format not supported: killID=#{kill_id}")
    {:error, :zkillboard_format_not_supported}
  end

  # Pattern match on flat format - already adapted
  defp adapt_kill_data(%{"victim_char_id" => _} = kill) do
    validated_kill = validate_flat_format_kill(kill)

    if map_size(validated_kill) > 0 do
      {:ok, validated_kill}
    else
      Logger.warning("[MessageHandler] Invalid flat format kill: #{inspect(kill["killmail_id"])}")
      {:error, :invalid_data}
    end
  end

  # Pattern match on nested format with valid structure
  defp adapt_kill_data(
         %{
           "killmail_id" => killmail_id,
           "kill_time" => _kill_time,
           "victim" => victim
         } = kill
       )
       when is_map(victim) do
    # Validate and normalize IDs first
    with {:ok, valid_killmail_id} <- validate_killmail_id(killmail_id),
         {:ok, valid_system_id} <- get_and_validate_system_id(kill) do
      # Update kill with normalized IDs
      normalized_kill =
        kill
        |> Map.put("killmail_id", valid_killmail_id)
        |> Map.put("solar_system_id", valid_system_id)
        # Remove alternate key
        |> Map.delete("system_id")

      adapted_kill = adapt_nested_format_kill(normalized_kill)

      if map_size(adapted_kill) > 0 do
        {:ok, adapted_kill}
      else
        Logger.warning("[MessageHandler] Invalid nested format kill: #{valid_killmail_id}")
        {:error, :invalid_data}
      end
    else
      {:error, reason} ->
        Logger.warning("[MessageHandler] ID validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Invalid data type
  defp adapt_kill_data(invalid_data) do
    data_type = if(is_nil(invalid_data), do: "nil", else: "#{inspect(invalid_data)}")
    Logger.warning("[MessageHandler] Invalid data type: #{data_type}")
    {:error, :invalid_format}
  end

  # Validation and adaptation helper functions

  @spec validate_flat_format_kill(map()) :: map()
  defp validate_flat_format_kill(kill) do
    required_fields = ["killmail_id", "kill_time", "solar_system_id"]

    case validate_required_fields(kill, required_fields) do
      :ok ->
        kill

      {:error, missing} ->
        Logger.warning(
          "[MessageHandler] Flat format kill missing required fields: #{inspect(missing)}"
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
        Logger.warning(
          "[MessageHandler] Kill adaptation failed - missing required fields: #{inspect(missing_fields)}, killmail_id: #{inspect(kill["killmail_id"])}"
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
      Logger.debug(fn ->
        "[MessageHandler] No final blow attacker found in #{length(attackers)} attackers"
      end)
    end

    final_blow
  end

  defp find_final_blow_attacker(_), do: %{}

  # Generic field extraction with multiple possible field names
  @spec extract_field(map(), list(String.t())) :: String.t() | nil
  defp extract_field(data, field_names) when is_map(data) and is_list(field_names) do
    Enum.find_value(field_names, fn field_name ->
      case Map.get(data, field_name) do
        value when is_binary(value) and value != "" -> value
        _ -> nil
      end
    end)
  end

  defp extract_field(_data, _field_names), do: nil

  # Specific field extractors using the generic function
  @spec get_character_name(map() | any()) :: String.t() | nil
  defp get_character_name(data) when is_map(data) do
    # Try multiple possible field names
    field_names = ["attacker_name", "victim_name", "character_name", "name"]

    extract_field(data, field_names) ||
      case Map.get(data, "character") do
        %{"name" => name} when is_binary(name) -> name
        _ -> nil
      end
  end

  defp get_character_name(_), do: nil

  @spec get_corp_ticker(map() | any()) :: String.t() | nil
  defp get_corp_ticker(data) when is_map(data) do
    extract_field(data, ["corporation_ticker", "corp_ticker"])
  end

  defp get_corp_ticker(_), do: nil

  @spec get_corp_name(map() | any()) :: String.t() | nil
  defp get_corp_name(data) when is_map(data) do
    extract_field(data, ["corporation_name", "corp_name"])
  end

  defp get_corp_name(_), do: nil

  @spec get_alliance_ticker(map() | any()) :: String.t() | nil
  defp get_alliance_ticker(data) when is_map(data) do
    extract_field(data, ["alliance_ticker"])
  end

  defp get_alliance_ticker(_), do: nil

  @spec get_alliance_name(map() | any()) :: String.t() | nil
  defp get_alliance_name(data) when is_map(data) do
    extract_field(data, ["alliance_name"])
  end

  defp get_alliance_name(_), do: nil

  @spec get_ship_name(map() | any()) :: String.t() | nil
  defp get_ship_name(data) when is_map(data) do
    extract_field(data, ["ship_name", "ship_type_name"])
  end

  defp get_ship_name(_), do: nil

  defp get_and_validate_system_id(kill) do
    system_id = kill["solar_system_id"] || kill["system_id"]
    validate_system_id(system_id)
  end

  # Validation functions (inlined from Validation module)

  @spec validate_system_id(any()) :: {:ok, integer()} | {:error, :invalid_system_id}
  defp validate_system_id(system_id)
       when is_integer(system_id) and system_id > 30_000_000 and system_id < 33_000_000 do
    {:ok, system_id}
  end

  defp validate_system_id(system_id) when is_binary(system_id) do
    case Integer.parse(system_id) do
      {id, ""} when id > 30_000_000 and id < 33_000_000 ->
        {:ok, id}

      _ ->
        {:error, :invalid_system_id}
    end
  end

  defp validate_system_id(_), do: {:error, :invalid_system_id}

  @spec validate_killmail_id(any()) :: {:ok, integer()} | {:error, :invalid_killmail_id}
  defp validate_killmail_id(killmail_id) when is_integer(killmail_id) and killmail_id > 0 do
    {:ok, killmail_id}
  end

  defp validate_killmail_id(killmail_id) when is_binary(killmail_id) do
    case Integer.parse(killmail_id) do
      {id, ""} when id > 0 ->
        {:ok, id}

      _ ->
        {:error, :invalid_killmail_id}
    end
  end

  defp validate_killmail_id(_), do: {:error, :invalid_killmail_id}

  @spec validate_killmail_payload(map()) :: {:ok, map()} | {:error, atom()}
  defp validate_killmail_payload(%{"system_id" => system_id, "killmails" => killmails} = payload)
       when is_list(killmails) do
    with {:ok, valid_system_id} <- validate_system_id(system_id) do
      {:ok, %{payload | "system_id" => valid_system_id}}
    end
  end

  defp validate_killmail_payload(_), do: {:error, :invalid_payload}

  @spec validate_kill_count_payload(map()) :: {:ok, map()} | {:error, atom()}
  defp validate_kill_count_payload(%{"system_id" => system_id, "count" => count} = payload)
       when is_integer(count) and count >= 0 do
    with {:ok, valid_system_id} <- validate_system_id(system_id) do
      {:ok, %{payload | "system_id" => valid_system_id}}
    end
  end

  defp validate_kill_count_payload(_), do: {:error, :invalid_kill_count_payload}

  # Helper functions to reduce nesting

  defp log_received_killmails(killmails, system_id) do
    Enum.each(killmails, fn kill ->
      killmail_id = kill["killmail_id"] || "unknown"
      kill_system_id = kill["solar_system_id"] || kill["system_id"] || system_id

      Logger.debug(fn ->
        "[MessageHandler] Received kill: killmail_id=#{killmail_id}, system_id=#{kill_system_id}"
      end)
    end)
  end

  defp process_killmail_for_adaptation({kill, index}, {valid, failed}) do
    # Log raw kill data
    Logger.debug(fn ->
      "[MessageHandler] Raw kill ##{index}: #{inspect(kill, pretty: true, limit: :infinity)}"
    end)

    # Adapt and log result
    case adapt_kill_data(kill) do
      {:ok, adapted} ->
        Logger.debug(fn ->
          "[MessageHandler] Adapted kill ##{index}: #{inspect(adapted, pretty: true, limit: :infinity)}"
        end)

        {[adapted | valid], failed}

      {:error, reason} ->
        Logger.warning("[MessageHandler] Failed to adapt kill ##{index}: #{inspect(reason)}")
        # Store raw kill for potential retry
        failed_kill = Map.put(kill, "_adaptation_error", to_string(reason))
        {valid, [failed_kill | failed]}
    end
  end
end
