defmodule WandererApp.Zkb.KillsProvider.Parser do
  @moduledoc """
  Helper for parsing & storing a killmail from the ESI data (plus zKB partial).
  """

  require Logger

  alias WandererApp.Zkb.KillsProvider.KillsCache
  alias WandererApp.Esi
  alias WandererApp.CachedInfo

  @doc """
  Parse a raw killmail (`full_km`) and store it if valid. Returns:

    - `{:ok, kill_time}` if the killmail was successfully parsed and stored
    - `:skip` if missing/invalid data or kill_time
  """
  def parse_and_store_killmail(%{"killmail_id" => _kill_id} = full_km) do
    parsed_map = do_parse(full_km)

    if is_nil(parsed_map) or is_nil(parsed_map["kill_time"]) do
      :skip
    else
      store_killmail(parsed_map)
      {:ok, parsed_map["kill_time"]}
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

  def store_killmail(%{"killmail_id" => nil}), do: :ok

  def store_killmail(%{"killmail_id" => kill_id} = parsed) do
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

  def store_killmail(_),
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

  defp extract_victim_fields(nil),
    do: %{char_id: nil, corp_id: nil, alliance_id: nil, ship_type_id: nil}

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
    |> maybe_put_corp_ticker("victim_corp_id", "victim_corp_ticker")
    |> maybe_put_alliance_ticker("victim_alliance_id", "victim_alliance_ticker")
    |> maybe_put_ship_name("victim_ship_type_id", "victim_ship_name")
  end

  defp enrich_final_blow(km) do
    km
    |> maybe_put_character_name("final_blow_char_id", "final_blow_char_name")
    |> maybe_put_corp_ticker("final_blow_corp_id", "final_blow_corp_ticker")
    |> maybe_put_alliance_ticker("final_blow_alliance_id", "final_blow_alliance_ticker")
    |> maybe_put_ship_name("final_blow_ship_type_id", "final_blow_ship_name")
  end

  defp maybe_put_character_name(km, id_key, name_key) do
    case Map.get(km, id_key) do
      nil -> km
      0   -> km
      eve_id ->
        case Esi.get_character_info(eve_id) do
          {:ok, %{"name" => char_name} = _info} ->
            Map.put(km, name_key, char_name)

          {:ok, _other} ->
            km

          {:error, _reason} ->
            km
        end
    end
  end

  defp maybe_put_corp_ticker(km, id_key, ticker_key) do
    case Map.get(km, id_key) do
      nil -> km
      0   -> km
      corp_id ->
        case Esi.get_corporation_info(corp_id) do
          {:ok, %{"ticker" => ticker} = _corp_info} ->
            Map.put(km, ticker_key, ticker)

          {:ok, _other} ->
            km

          {:error, reason} ->
            Logger.warning("[Parser] Failed to fetch corp info: ID=#{corp_id}, reason=#{inspect(reason)}")
            km
        end
    end
  end

  defp maybe_put_alliance_ticker(km, id_key, ticker_key) do
    case Map.get(km, id_key) do
      nil -> km
      0   -> km
      alliance_id ->
        case Esi.get_alliance_info(alliance_id) do
          {:ok, %{"ticker" => alliance_ticker} = _alliance_info} ->
            Map.put(km, ticker_key, alliance_ticker)

          {:ok, _other} ->
            km

          {:error, _reason} ->
            km
        end
    end
  end

  defp maybe_put_ship_name(km, id_key, name_key) do
    case Map.get(km, id_key) do
      nil -> km
      0   -> km
      type_id ->
        case CachedInfo.get_ship_type(type_id) do
          {:ok, nil} ->
            km

          {:ok, %{name: ship_name} = _ship_type} ->
            Map.put(km, name_key, ship_name)

          {:ok, _other} ->
            km

          {:error, reason} ->
            Logger.warning("[Parser] Failed to fetch ship type: ID=#{type_id}, reason=#{inspect(reason)}")
            km
        end
    end
  end

  defp within_last_hour?(nil), do: false

  defp within_last_hour?(%DateTime{} = dt),
    do: DateTime.diff(DateTime.utc_now(), dt, :minute) < 60
end
