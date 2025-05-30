defmodule WandererApp.Zkb.Provider.Parser.Core do
  @moduledoc """
  Core killmail parsing logic: merging partial/full data and building
  a normalized killmail map for downstream enrichment and caching.
  """
  require Logger

  @type raw_km       :: %{String.t() => any()}
  @type merged_km    :: raw_km()
  @type built_km     :: %{String.t() => any()}
  @type result_ok    :: {:ok, built_km()}
  @type result_error :: {:error, :invalid_payload | :missing_kill_time}
  @type result_t     :: result_ok() | :older | result_error()

  @doc """
  Merge full ESI killmail data with its zKB partial payload.
  Validates that kill_time is present in the data.
  """
  @spec merge_killmail_data(raw_km(), raw_km()) :: {:ok, merged_km()} | result_error()
  def merge_killmail_data(%{"killmail_id" => id} = full, %{"zkb" => zkb})
      when is_integer(id) and is_map(zkb) do
    kill_time = Map.get(full, "kill_time") || Map.get(full, "killmail_time")

    if kill_time do
      merged =
        full
        |> Map.put("zkb", zkb)
        |> Map.put("kill_time", kill_time)

      {:ok, merged}
    else
      {:error, :missing_kill_time}
    end
  end
  def merge_killmail_data(_, _), do: {:error, :invalid_payload}

  @doc """
  Given merged data and a cutoff, either build the final map, or return `:older` if it's too old.
  """
  @spec build_kill_data(merged_km(), DateTime.t()) :: result_t()
  def build_kill_data(%{"kill_time" => ts} = merged, %DateTime{} = cutoff) do
    case parse_time(ts) do
      {:ok, dt} ->
        case DateTime.compare(dt, cutoff) do
          :lt -> :older
          _ -> do_build(Map.put(merged, "kill_time", dt))
        end
      :error -> {:error, :invalid_payload}
    end
  end
  def build_kill_data(_, _), do: {:error, :invalid_payload}

  # -- Private helpers -----------------------------------------------------

  @spec parse_time(DateTime.t() | String.t()) :: {:ok, DateTime.t()} | :error
  defp parse_time(%DateTime{} = dt), do: {:ok, dt}
  defp parse_time(time) when is_binary(time) do
    case DateTime.from_iso8601(time) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> :error
    end
  end
  defp parse_time(_), do: :error

  # The real builder, matching on all required fields:
  @spec do_build(merged_km()) :: result_t()
  defp do_build(%{
         "killmail_id"      => id,
         "kill_time"        => %DateTime{} = ts,
         "solar_system_id"  => sys,
         "victim"           => victim_map,
         "attackers"        => attackers,
         "zkb"              => zkb
       })
       when is_map(victim_map) and is_list(attackers) do
    final_blow = Enum.find(attackers, & &1["final_blow"])

    try do
      # Extract required fields
      with {:ok, victim} <- get_victim(victim_map),
           {:ok, attackers} <- get_attackers(attackers),
           {:ok, system_id} <- get_system_id(sys),
           {:ok, time} <- get_time(ts) do
        # Build the killmail
        built =
          %{
            "killmail_id"       => id,
            "kill_time"         => time,
            "solar_system_id"   => system_id,
            "attacker_count"    => length(attackers),
            "total_value"       => Map.get(zkb, "totalValue", 0),
            "npc"               => Map.get(zkb, "npc", false),
            "victim"            => victim,
            "attackers"         => attackers,
            "zkb"               => zkb
          }
          |> Map.merge(flatten_fields(victim, "victim"))
          |> maybe_flatten_final_blow(final_blow)

        {:ok, built}
      else
        {:error, reason} ->
          Logger.error("[Core] Failed to build killmail #{id}: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("[Core] Error building killmail #{id}: #{inspect(e)}")
        {:error, :build_error}
    end
  end
  defp do_build(%{"killmail_id" => id}) do
    Logger.error("[Core] Invalid killmail data for build: #{id}")
    {:error, :invalid_payload}
  end
  defp do_build(_) do
    Logger.error("[Core] Invalid killmail data: missing killmail_id")
    {:error, :invalid_payload}
  end

  # Define once the mapping from source keys to suffixes
  @flatten_mappings [
    {"character_id",   "char_id"},
    {"corporation_id", "corp_id"},
    {"alliance_id",    "alliance_id"},
    {"ship_type_id",   "ship_type_id"}
  ]

  @spec flatten_fields(map(), String.t()) :: map()
  defp flatten_fields(map, prefix) do
    Enum.reduce(@flatten_mappings, %{}, fn {src_key, suffix}, acc ->
      case Map.fetch(map, src_key) do
        {:ok, val} -> Map.put(acc, "#{prefix}_#{suffix}", val)
        :error     -> acc
      end
    end)
  end

  @spec maybe_flatten_final_blow(map(), map() | nil) :: map()
  defp maybe_flatten_final_blow(built_map, nil), do: built_map

  defp maybe_flatten_final_blow(built_map, %{} = fb_map) do
    built_map
    |> Map.put("final_blow", fb_map)
    |> Map.merge(flatten_fields(fb_map, "final_blow"))
  end

  # Helper functions for extracting fields
  @spec get_victim(map()) :: {:ok, map()} | {:error, term()}
  defp get_victim(%{"ship_type_id" => _} = victim), do: {:ok, victim}
  defp get_victim(_), do: {:error, :invalid_victim}

  @spec get_attackers(list()) :: {:ok, list()} | {:error, term()}
  defp get_attackers(attackers) when is_list(attackers) and length(attackers) > 0 do
    {:ok, attackers}
  end
  defp get_attackers(_), do: {:error, :invalid_attackers}

  @spec get_system_id(integer()) :: {:ok, integer()} | {:error, term()}
  defp get_system_id(id) when is_integer(id), do: {:ok, id}
  defp get_system_id(_), do: {:error, :invalid_system_id}

  @spec get_time(DateTime.t()) :: {:ok, DateTime.t()} | {:error, term()}
  defp get_time(%DateTime{} = dt), do: {:ok, dt}
  defp get_time(_), do: {:error, :invalid_time}
end
