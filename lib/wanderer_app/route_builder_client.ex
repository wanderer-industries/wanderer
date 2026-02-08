defmodule WandererApp.RouteBuilderClient do
  @moduledoc """
  HTTP client for the local route builder service.
  """

  require Logger

  @timeout_opts [pool_timeout: 5_000, receive_timeout: :timer.seconds(30)]
  @loot_dir Path.join(["repo", "data", "route_by_systems"])
  @available_routes_by ["blueLoot", "redLoot", "thera", "turnur", "so_cleaning", "trade_hubs"]

  def available_routes_by(), do: @available_routes_by

  def find_closest(
        %{
          origin: origin,
          flag: flag,
          connections: connections,
          avoid: avoid,
          count: count,
          type: type,
          security_type: security_type
        } = payload
      ) do
    url = "#{WandererApp.Env.custom_route_base_url()}/route/findClosest"

    routes_settings = Map.get(payload, :routes_settings, %{})
    destinations = destinations_for(type, security_type, routes_settings)

    payload = %{
      origin: origin,
      flag: flag,
      connections: connections || [],
      avoid: avoid || [],
      destinations: destinations,
      count: count || 1
    }

    case Req.post(url, Keyword.merge([json: payload], @timeout_opts)) do
      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[RouteBuilderClient] Unexpected status: #{status}")
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        Logger.error("[RouteBuilderClient] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp destinations_for(type, security_type, routes_settings) do
    case normalize_type(type) do
      :thera ->
        thera_destinations(routes_settings, security_type)

      :turnur ->
        turnur_destinations(routes_settings, security_type)

      _ ->
        case load_loot_data(type) do
          {:ok, %{"system_ids_by_band" => by_band}} ->
            high = Map.get(by_band, "high", [])
            low = Map.get(by_band, "low", [])
            pick_by_band(high, low, security_type)

          {:ok, %{"system_ids" => system_ids}} when is_list(system_ids) ->
            filter_by_security(system_ids, security_type)

          {:error, reason} ->
            Logger.error("[RouteBuilderClient] Failed to load loot data: #{inspect(reason)}")
            []

          _ ->
            []
        end
    end
  end

  defp thera_destinations(routes_settings, security_type) do
    {:ok, thera_chains} = WandererApp.Server.TheraDataFetcher.get_chain_pairs(routes_settings)

    system_ids =
      thera_chains
      |> Enum.map(fn %{first: first, second: second} ->
        pick_thera_destination(first, second)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    filter_by_security(system_ids, security_type)
  end

  defp turnur_destinations(routes_settings, security_type) do
    {:ok, turnur_chains} = WandererApp.Server.TurnurDataFetcher.get_chain_pairs(routes_settings)

    system_ids =
      turnur_chains
      |> Enum.map(fn %{first: first, second: second} ->
        pick_turnur_destination(first, second)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    filter_by_security(system_ids, security_type)
  end

  defp filter_by_security(system_ids, security_type) do
    case normalize_security_type(security_type) do
      "high" ->
        Enum.filter(system_ids, fn system_id ->
          case system_security(system_id) do
            {:ok, security} -> security >= 0.5
            _ -> false
          end
        end)

      "low" ->
        Enum.filter(system_ids, fn system_id ->
          case system_security(system_id) do
            {:ok, security} -> security > 0.0 and security < 0.5
            _ -> false
          end
        end)

      _ ->
        system_ids
    end
  end

  defp system_security(system_id) do
    case WandererApp.CachedInfo.get_system_static_info(system_id) do
      {:ok, %{security: security}} -> parse_security(security)
      _ -> {:error, :missing_security}
    end
  end

  defp pick_thera_destination(first, second) do
    first_is_thera = is_thera_system?(first)
    second_is_thera = is_thera_system?(second)

    cond do
      first_is_thera and not second_is_thera -> second
      second_is_thera and not first_is_thera -> first
      true -> second
    end
  end

  defp is_thera_system?(system_id) do
    case WandererApp.CachedInfo.get_system_static_info(system_id) do
      {:ok, %{system_class: 12}} -> true
      _ -> false
    end
  end

  defp pick_turnur_destination(first, second) do
    first_is_turnur = is_turnur_system?(first)
    second_is_turnur = is_turnur_system?(second)

    cond do
      first_is_turnur and not second_is_turnur -> second
      second_is_turnur and not first_is_turnur -> first
      true -> second
    end
  end

  defp is_turnur_system?(system_id) do
    case WandererApp.CachedInfo.get_system_static_info(system_id) do
      {:ok, %{solar_system_name: name}} when is_binary(name) ->
        String.downcase(name) == "turnur"

      _ ->
        false
    end
  end

  defp parse_security(security) when is_float(security), do: {:ok, security}
  defp parse_security(security) when is_integer(security), do: {:ok, security * 1.0}

  defp parse_security(security) when is_binary(security) do
    case Float.parse(security) do
      {value, _} -> {:ok, value}
      _ -> {:error, :invalid_security}
    end
  end

  defp parse_security(_), do: {:error, :invalid_security}

  defp normalize_security_type("high"), do: "high"
  defp normalize_security_type(:high), do: "high"
  defp normalize_security_type("hight"), do: "high"
  defp normalize_security_type(:hight), do: "high"
  defp normalize_security_type("low"), do: "low"
  defp normalize_security_type(:low), do: "low"
  defp normalize_security_type(_), do: "both"

  def stations_for(type) do
    case normalize_type(type) do
      :thera ->
        %{}

      :turnur ->
        %{}

      _ ->
        case load_loot_data(type) do
          {:ok, %{"system_stations" => system_stations}} when is_map(system_stations) ->
            system_stations

          {:ok, _} ->
            %{}

          {:error, reason} ->
            Logger.error("[RouteBuilderClient] Failed to load loot stations: #{inspect(reason)}")
            %{}
        end
    end
  end

  defp pick_by_band(high, _low, "high"), do: high
  defp pick_by_band(high, _low, :high), do: high
  defp pick_by_band(high, _low, "hight"), do: high
  defp pick_by_band(high, _low, :hight), do: high
  defp pick_by_band(_high, low, "low"), do: low
  defp pick_by_band(_high, low, :low), do: low
  defp pick_by_band(high, low, _), do: high ++ low

  defp load_loot_data("blueLoot"), do: load_loot_file("blueloot.json")
  defp load_loot_data(:blueLoot), do: load_loot_file("blueloot.json")
  defp load_loot_data("redLoot"), do: load_loot_file("redloot.json")
  defp load_loot_data(:redLoot), do: load_loot_file("redloot.json")
  defp load_loot_data("so_cleaning"), do: load_loot_file("ss_cleaning.json")
  defp load_loot_data(:so_cleaning), do: load_loot_file("ss_cleaning.json")
  defp load_loot_data("trade_hubs"), do: load_loot_file("trade_hubs.json")
  defp load_loot_data(:trade_hubs), do: load_loot_file("trade_hubs.json")
  defp load_loot_data(_), do: load_loot_file("blueloot.json")

  defp normalize_type("thera"), do: :thera
  defp normalize_type(:thera), do: :thera
  defp normalize_type("turnur"), do: :turnur
  defp normalize_type(:turnur), do: :turnur
  defp normalize_type("so_cleaning"), do: :so_cleaning
  defp normalize_type(:so_cleaning), do: :so_cleaning
  defp normalize_type("trade_hubs"), do: :trade_hubs
  defp normalize_type(:trade_hubs), do: :trade_hubs
  defp normalize_type(type), do: type

  defp load_loot_file(filename) do
    key = {__MODULE__, :loot_data, filename}

    case :persistent_term.get(key, :missing) do
      :missing ->
        path = Path.join([:code.priv_dir(:wanderer_app), @loot_dir, filename])

        with {:ok, body} <- File.read(path),
             {:ok, json} <- Jason.decode(body) do
          :persistent_term.put(key, json)
          {:ok, json}
        else
          error -> error
        end

      cached ->
        {:ok, cached}
    end
  end
end
