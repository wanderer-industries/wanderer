defmodule WandererApp.Zkb.KillsProvider.Parser do
  @moduledoc """
  Helper for parsing & storing a killmail from the ESI data (plus zKB partial).
  Responsible for:
    - Parsing the raw JSON structures,
    - Combining partial & full kill data,
    - Checking whether kills are 'too old',
    - Storing in KillsCache, etc.
  """

  require Logger
  alias WandererApp.Zkb.KillsProvider.KillsCache
  alias WandererApp.Utils.HttpUtil
  use Retry

  # Maximum retries for enrichment calls

  @doc """
  Merges the 'partial' from zKB and the 'full' killmail from ESI, checks its time
  vs. `cutoff_dt`.

  Returns:
    - `:ok` if we parsed & stored successfully,
    - `:older` if killmail time is older than `cutoff_dt`,
    - `:skip` if we cannot parse or store for some reason.
  """
  def parse_full_and_store(full_km, partial_zkb, cutoff_dt) when is_map(full_km) do
    # Attempt to parse the killmail_time
    case parse_killmail_time(full_km) do
      {:ok, km_dt} ->
        if older_than_cutoff?(km_dt, cutoff_dt) do
          :older
        else
          # Merge the "zkb" portion from the partial into the full killmail
          enriched = Map.merge(full_km, %{"zkb" => partial_zkb["zkb"]})
          parse_and_store_killmail(enriched)
        end

      _ ->
        :skip
    end
  end

  def parse_full_and_store(_full_km, _partial_zkb, _cutoff_dt),
    do: :skip

  @doc """
  Parse a raw killmail (`full_km`) and store it if valid.
  Returns:
    - `:ok` if successfully parsed & stored,
    - `:skip` otherwise
  """
  def parse_and_store_killmail(%{"killmail_id" => _kill_id} = full_km) do
    parsed_map = do_parse(full_km)

    if is_nil(parsed_map) or is_nil(parsed_map["kill_time"]) do
      :skip
    else
      store_killmail(parsed_map)
      :ok
    end
  end

  def parse_and_store_killmail(_),
    do: :skip

  defp do_parse(%{"killmail_id" => kill_id} = km) do
    victim = Map.get(km, "victim", %{})
    attackers = Map.get(km, "attackers", [])

    kill_time_dt =
      case DateTime.from_iso8601("#{Map.get(km, "killmail_time", "")}") do
        {:ok, dt, _off} -> dt
        _ -> nil
      end

    npc_flag = get_in(km, ["zkb", "npc"]) || false

    %{
      "killmail_id" => kill_id,
      "kill_time" => kill_time_dt,
      "solar_system_id" => km["solar_system_id"],
      "zkb" => Map.get(km, "zkb", %{}),
      "attacker_count" => length(attackers),
      "total_value" => get_in(km, ["zkb", "totalValue"]) || 0,
      "victim" => victim,
      "attackers" => attackers,
      "npc" => npc_flag
    }
  end

  defp do_parse(_),
    do: nil

  @doc """
  Extracts & returns {:ok, DateTime} from the "killmail_time" field, or :skip on failure.
  """
  def parse_killmail_time(full_km) do
    killmail_time_str = Map.get(full_km, "killmail_time", "")

    case DateTime.from_iso8601(killmail_time_str) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      _ ->
        :skip
    end
  end

  defp older_than_cutoff?(%DateTime{} = dt, %DateTime{} = cutoff_dt),
    do: DateTime.compare(dt, cutoff_dt) == :lt

  defp store_killmail(%{"killmail_id" => nil}), do: :ok

  defp store_killmail(%{"killmail_id" => kill_id} = parsed) do
    final = build_kill_data(parsed)

    if final do
      enriched = maybe_enrich_killmail(final)
      KillsCache.put_killmail(kill_id, enriched)

      system_id = enriched["solar_system_id"]
      KillsCache.add_killmail_id_to_system_list(system_id, kill_id)

      if within_last_hour?(enriched["kill_time"]) do
        KillsCache.incr_system_kill_count(system_id)
      end
    else
      Logger.warning("[Parser] store_killmail => build_kill_data returned nil for kill_id=#{kill_id}")
    end
  end

  defp store_killmail(_),
    do: :ok

  defp build_kill_data(%{
         "killmail_id" => kill_id,
         "kill_time" => kill_time_dt,
         "solar_system_id" => sys_id,
         "zkb" => zkb,
         "victim" => victim,
         "attackers" => attackers,
         "attacker_count" => attacker_count,
         "total_value" => total_value,
         "npc" => npc
       }) do

    victim_map = extract_victim_fields(victim)
    final_blow_map = extract_final_blow_fields(attackers)

    %{
      "killmail_id" => kill_id,
      "kill_time" => kill_time_dt,
      "solar_system_id" => sys_id,
      "zkb" => zkb,

      "victim_char_id" => victim_map.char_id,
      "victim_corp_id" => victim_map.corp_id,
      "victim_alliance_id" => victim_map.alliance_id,
      "victim_ship_type_id" => victim_map.ship_type_id,

      "final_blow_char_id" => final_blow_map.char_id,
      "final_blow_corp_id" => final_blow_map.corp_id,
      "final_blow_alliance_id" => final_blow_map.alliance_id,
      "final_blow_ship_type_id" => final_blow_map.ship_type_id,

      "attacker_count" => attacker_count,
      "total_value" => total_value,
      "npc" => npc
    }
  end

  defp build_kill_data(_),
    do: nil

  defp extract_victim_fields(%{
         "character_id" => cid,
         "corporation_id" => corp,
         "alliance_id" => alli,
         "ship_type_id" => st_id
       }),
    do: %{char_id: cid, corp_id: corp, alliance_id: alli, ship_type_id: st_id}

  defp extract_victim_fields(%{
         "character_id" => cid,
         "corporation_id" => corp,
         "ship_type_id" => st_id
       }),
    do: %{char_id: cid, corp_id: corp, alliance_id: nil, ship_type_id: st_id}

  defp extract_victim_fields(_),
    do: %{char_id: nil, corp_id: nil, alliance_id: nil, ship_type_id: nil}

  defp extract_final_blow_fields(attackers) when is_list(attackers) do
    final = Enum.find(attackers, fn a -> a["final_blow"] == true end)
    extract_attacker_fields(final)
  end

  defp extract_final_blow_fields(_),
    do: %{char_id: nil, corp_id: nil, alliance_id: nil, ship_type_id: nil}

  defp extract_attacker_fields(nil),
    do: %{char_id: nil, corp_id: nil, alliance_id: nil, ship_type_id: nil}

  defp extract_attacker_fields(%{
         "character_id" => cid,
         "corporation_id" => corp,
         "alliance_id" => alli,
         "ship_type_id" => st_id
       }),
    do: %{char_id: cid, corp_id: corp, alliance_id: alli, ship_type_id: st_id}

  defp extract_attacker_fields(%{
         "character_id" => cid,
         "corporation_id" => corp,
         "ship_type_id" => st_id
       }),
    do: %{char_id: cid, corp_id: corp, alliance_id: nil, ship_type_id: st_id}

  defp extract_attacker_fields(%{"ship_type_id" => st_id} = attacker) do
    %{
      char_id: Map.get(attacker, "character_id"),
      corp_id: Map.get(attacker, "corporation_id"),
      alliance_id: Map.get(attacker, "alliance_id"),
      ship_type_id: st_id
    }
  end

  defp extract_attacker_fields(_),
    do: %{char_id: nil, corp_id: nil, alliance_id: nil, ship_type_id: nil}

  defp maybe_enrich_killmail(km) do
    km
    |> enrich_victim()
    |> enrich_final_blow()
  end


  defp enrich_victim(km) do
    km
    |> maybe_put_character_name("victim_char_id", "victim_char_name")
    |> maybe_put_corp_info("victim_corp_id", "victim_corp_ticker", "victim_corp_name")
    |> maybe_put_alliance_info("victim_alliance_id", "victim_alliance_ticker", "victim_alliance_name")
    |> maybe_put_ship_name("victim_ship_type_id", "victim_ship_name")
  end


  defp enrich_final_blow(km) do
    km
    |> maybe_put_character_name("final_blow_char_id", "final_blow_char_name")
    |> maybe_put_corp_info("final_blow_corp_id", "final_blow_corp_ticker", "final_blow_corp_name")
    |> maybe_put_alliance_info("final_blow_alliance_id", "final_blow_alliance_ticker", "final_blow_alliance_name")
    |> maybe_put_ship_name("final_blow_ship_type_id", "final_blow_ship_name")
  end

  defp maybe_put_character_name(km, id_key, name_key) do
    case Map.get(km, id_key) do
      nil -> km
      0 -> km
      eve_id ->
        result = retry with: exponential_backoff(200) |> randomize() |> cap(2_000) |> expiry(10_000), rescue_only: [RuntimeError] do
          case WandererApp.Esi.get_character_info(eve_id) do
            {:ok, %{"name" => char_name}} ->
              {:ok, char_name}

            {:error, :timeout} ->
              Logger.debug(fn -> "[Parser] Character info timeout, retrying => id=#{eve_id}" end)
              raise "Character info timeout, will retry"

            {:error, :not_found} ->
              Logger.debug(fn -> "[Parser] Character not found => id=#{eve_id}" end)
              :skip

            {:error, reason} ->
              if HttpUtil.retriable_error?(reason) do
                Logger.debug(fn -> "[Parser] Character info retriable error => id=#{eve_id}, reason=#{inspect(reason)}" end)
                raise "Character info error: #{inspect(reason)}, will retry"
              else
                Logger.debug(fn -> "[Parser] Character info failed => id=#{eve_id}, reason=#{inspect(reason)}" end)
                :skip
              end
          end
        end

        case result do
          {:ok, char_name} -> Map.put(km, name_key, char_name)
          _ -> km
        end
    end
  end

  defp maybe_put_corp_info(km, id_key, ticker_key, name_key) do
    case Map.get(km, id_key) do
      nil -> km
      0 -> km
      corp_id ->
        result = retry with: exponential_backoff(200) |> randomize() |> cap(2_000) |> expiry(10_000), rescue_only: [RuntimeError] do
          case WandererApp.Esi.get_corporation_info(corp_id) do
            {:ok, %{"ticker" => ticker, "name" => corp_name}} ->
              {:ok, {ticker, corp_name}}

            {:error, :timeout} ->
              Logger.debug(fn -> "[Parser] Corporation info timeout, retrying => id=#{corp_id}" end)
              raise "Corporation info timeout, will retry"

            {:error, :not_found} ->
              Logger.debug(fn -> "[Parser] Corporation not found => id=#{corp_id}" end)
              :skip

            {:error, reason} ->
              if HttpUtil.retriable_error?(reason) do
                Logger.debug(fn -> "[Parser] Corporation info retriable error => id=#{corp_id}, reason=#{inspect(reason)}" end)
                raise "Corporation info error: #{inspect(reason)}, will retry"
              else
                Logger.warning("[Parser] Failed to fetch corp info: ID=#{corp_id}, reason=#{inspect(reason)}")
                :skip
              end
          end
        end

        case result do
          {:ok, {ticker, corp_name}} ->
            km
            |> Map.put(ticker_key, ticker)
            |> Map.put(name_key, corp_name)
          _ -> km
        end
    end
  end

  defp maybe_put_alliance_info(km, id_key, ticker_key, name_key) do
    case Map.get(km, id_key) do
      nil -> km
      0 -> km
      alliance_id ->
        result = retry with: exponential_backoff(200) |> randomize() |> cap(2_000) |> expiry(10_000), rescue_only: [RuntimeError] do
          case WandererApp.Esi.get_alliance_info(alliance_id) do
            {:ok, %{"ticker" => alliance_ticker, "name" => alliance_name}} ->
              {:ok, {alliance_ticker, alliance_name}}

            {:error, :timeout} ->
              Logger.debug(fn -> "[Parser] Alliance info timeout, retrying => id=#{alliance_id}" end)
              raise "Alliance info timeout, will retry"

            {:error, :not_found} ->
              Logger.debug(fn -> "[Parser] Alliance not found => id=#{alliance_id}" end)
              :skip

            {:error, reason} ->
              if HttpUtil.retriable_error?(reason) do
                Logger.debug(fn -> "[Parser] Alliance info retriable error => id=#{alliance_id}, reason=#{inspect(reason)}" end)
                raise "Alliance info error: #{inspect(reason)}, will retry"
              else
                Logger.debug(fn -> "[Parser] Alliance info failed => id=#{alliance_id}, reason=#{inspect(reason)}" end)
                :skip
              end
          end
        end

        case result do
          {:ok, {alliance_ticker, alliance_name}} ->
            km
            |> Map.put(ticker_key, alliance_ticker)
            |> Map.put(name_key, alliance_name)
          _ -> km
        end
    end
  end

  defp maybe_put_ship_name(km, id_key, name_key) do
    case Map.get(km, id_key) do
      nil -> km
      0 -> km
      type_id ->
        result = retry with: exponential_backoff(200) |> randomize() |> cap(2_000) |> expiry(10_000), rescue_only: [RuntimeError] do
          case WandererApp.CachedInfo.get_ship_type(type_id) do
            {:ok, nil} -> :skip
            {:ok, %{name: ship_name}} -> {:ok, ship_name}
            {:error, :timeout} ->
              Logger.debug(fn -> "[Parser] Ship type timeout, retrying => id=#{type_id}" end)
              raise "Ship type timeout, will retry"

            {:error, :not_found} ->
              Logger.debug(fn -> "[Parser] Ship type not found => id=#{type_id}" end)
              :skip

            {:error, reason} ->
              if HttpUtil.retriable_error?(reason) do
                Logger.debug(fn -> "[Parser] Ship type retriable error => id=#{type_id}, reason=#{inspect(reason)}" end)
                raise "Ship type error: #{inspect(reason)}, will retry"
              else
                Logger.warning("[Parser] Failed to fetch ship type: ID=#{type_id}, reason=#{inspect(reason)}")
                :skip
              end
          end
        end

        case result do
          {:ok, ship_name} -> Map.put(km, name_key, ship_name)
          _ -> km
        end
    end
  end

  # Utility
  defp within_last_hour?(nil), do: false

  defp within_last_hour?(%DateTime{} = dt),
    do: DateTime.diff(DateTime.utc_now(), dt, :minute) < 60
end
