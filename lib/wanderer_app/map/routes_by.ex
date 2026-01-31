defmodule WandererApp.Map.RoutesBy do
  @moduledoc """
  Routes-by helper that uses the local route builder service.
  """

  require Logger

  @minimum_route_attrs [
    :system_class,
    :class_title,
    :security,
    :triglavian_invasion_status,
    :solar_system_id,
    :solar_system_name,
    :region_name,
    :is_shattered
  ]

  @default_routes_settings %{
    path_type: "shortest",
    include_mass_crit: true,
    include_eol: false,
    include_frig: true,
    include_cruise: true,
    avoid_wormholes: false,
    avoid_pochven: false,
    avoid_edencom: false,
    avoid_triglavian: false,
    include_thera: true,
    avoid: []
  }

  @zarzakh_system 30_100_000
  @default_avoid_systems [@zarzakh_system]
  @get_link_pairs_advanced_params [
    :include_mass_crit,
    :include_eol,
    :include_frig
  ]

  def find(map_id, origin, routes_settings, type) do
    origin = parse_origin(origin)
    routes_settings = @default_routes_settings |> Map.merge(routes_settings || %{})

    connections = build_connections(map_id, routes_settings)

    avoidance_list = build_avoidance_list(routes_settings)

    security_type =
      routes_settings
      |> Map.get(:security_type, "both")
      |> normalize_security_type()

    payload = %{
      origin: origin,
      flag: routes_settings.path_type,
      connections: connections,
      avoid: avoidance_list,
      count: 40,
      type: type,
      security_type: security_type
    }

    stations_by_system = WandererApp.RouteBuilderClient.stations_for(type)

    case WandererApp.RouteBuilderClient.find_closest(payload) do
      {:ok, body} ->
        routes = normalize_routes(body, origin)
        routes = attach_stations(routes, stations_by_system)
        systems_static_data = fetch_systems_static_data(routes)
        {:ok, %{routes: routes, systems_static_data: systems_static_data}}

      {:error, reason} ->
        Logger.error("[RoutesBy] Failed to fetch routes by: #{inspect(reason)}")
        {:ok, %{routes: [], systems_static_data: []}}
    end
  end

  defp parse_origin(origin) when is_integer(origin), do: origin

  defp parse_origin(origin) when is_binary(origin) do
    case Integer.parse(origin) do
      {id, _} -> id
      :error -> 0
    end
  end

  defp parse_origin(_), do: 0

  defp normalize_routes(%{"routes" => routes}, origin) when is_list(routes),
    do: normalize_routes(routes, origin)

  defp normalize_routes(routes, _origin) when is_list(routes) do
    routes
    |> Enum.map(&map_route_info/1)
    |> Enum.filter(fn route_info -> not is_nil(route_info) end)
  end

  defp normalize_routes(_body, _origin), do: []

  defp attach_stations(routes, stations_by_system) do
    Enum.map(routes, fn route ->
      system_key = to_string(route.destination)
      stations = Map.get(stations_by_system, system_key, [])

      normalized_stations =
        stations
        |> Enum.filter(&is_map/1)
        |> Enum.map(fn station ->
          %{
            station_id: Map.get(station, "station_id") || Map.get(station, :station_id),
            station_name: Map.get(station, "name") || Map.get(station, :name)
          }
        end)
        |> Enum.filter(fn station ->
          is_integer(station.station_id) and is_binary(station.station_name)
        end)

      Map.put(route, :stations, normalized_stations)
    end)
  end

  defp map_route_info(%{
         "origin" => origin,
         "destination" => destination,
         "systems" => result_systems,
         "success" => success
       }) do
    map_route_info(%{
      origin: origin,
      destination: destination,
      systems: result_systems,
      success: success
    })
  end

  defp map_route_info(
         %{origin: origin, destination: destination, systems: result_systems, success: success} =
           _route_info
       ) do
    systems =
      case result_systems do
        [] -> []
        _ -> result_systems |> Enum.reject(fn system_id -> system_id == origin end)
      end

    %{
      has_connection: result_systems != [],
      systems: systems,
      origin: origin,
      destination: destination,
      success: success
    }
  end

  defp map_route_info(_), do: nil

  defp fetch_systems_static_data(routes) do
    routes
    |> Enum.map(fn route_info -> route_info.systems end)
    |> List.flatten()
    |> Enum.uniq()
    |> Task.async_stream(
      fn system_id ->
        case WandererApp.CachedInfo.get_system_static_info(system_id) do
          {:ok, nil} -> nil
          {:ok, system} -> system |> Map.take(@minimum_route_attrs)
        end
      end,
      max_concurrency: System.schedulers_online() * 4
    )
    |> Enum.map(fn {:ok, val} -> val end)
  end

  defp build_avoidance_list(routes_settings) do
    {:ok, trig_systems} = WandererApp.CachedInfo.get_trig_systems()

    pochven_solar_systems =
      trig_systems
      |> Enum.filter(fn s -> s.triglavian_invasion_status == "Final" end)
      |> Enum.map(& &1.solar_system_id)

    triglavian_solar_systems =
      trig_systems
      |> Enum.filter(fn s -> s.triglavian_invasion_status == "Triglavian" end)
      |> Enum.map(& &1.solar_system_id)

    edencom_solar_systems =
      trig_systems
      |> Enum.filter(fn s -> s.triglavian_invasion_status == "Edencom" end)
      |> Enum.map(& &1.solar_system_id)

    avoidance_list =
      case routes_settings.avoid_edencom do
        true -> edencom_solar_systems
        false -> []
      end

    avoidance_list =
      case routes_settings.avoid_triglavian do
        true -> [avoidance_list | triglavian_solar_systems]
        false -> avoidance_list
      end

    avoidance_list =
      case routes_settings.avoid_pochven do
        true -> [avoidance_list | pochven_solar_systems]
        false -> avoidance_list
      end

    (@default_avoid_systems ++ [routes_settings.avoid | avoidance_list])
    |> List.flatten()
    |> Enum.uniq()
  end

  defp normalize_security_type("high"), do: "high"
  defp normalize_security_type(:high), do: "high"
  defp normalize_security_type("low"), do: "low"
  defp normalize_security_type(:low), do: "low"
  defp normalize_security_type(_), do: "both"

  defp build_connections(map_id, routes_settings) do
    if routes_settings.avoid_wormholes do
      []
    else
      map_chains =
        routes_settings
        |> Map.take(@get_link_pairs_advanced_params)
        |> Map.put_new(:map_id, map_id)
        |> WandererApp.Api.MapConnection.get_link_pairs_advanced!()
        |> Enum.map(fn %{
                         solar_system_source: solar_system_source,
                         solar_system_target: solar_system_target
                       } ->
          %{
            first: solar_system_source,
            second: solar_system_target
          }
        end)
        |> Enum.uniq()

      {:ok, thera_chains} =
        case routes_settings.include_thera do
          true ->
            WandererApp.Server.TheraDataFetcher.get_chain_pairs(routes_settings)

          false ->
            {:ok, []}
        end

      chains = remove_intersection([map_chains | thera_chains] |> List.flatten())

      chains =
        case routes_settings.include_cruise do
          false ->
            {:ok, wh_class_a_systems} = WandererApp.CachedInfo.get_wh_class_a_systems()

            chains
            |> Enum.filter(fn x ->
              not Enum.member?(wh_class_a_systems, x.first) and
                not Enum.member?(wh_class_a_systems, x.second)
            end)

          _ ->
            chains
        end

      chains
      |> Enum.map(fn chain ->
        ["#{chain.first}|#{chain.second}", "#{chain.second}|#{chain.first}"]
      end)
      |> List.flatten()
    end
  end

  defp remove_intersection(pairs_arr) do
    tuples = pairs_arr |> Enum.map(fn x -> {x.first, x.second} end)

    tuples
    |> Enum.reduce([], fn {first, second} = x, acc ->
      if Enum.member?(tuples, {second, first}) do
        acc
      else
        [x | acc]
      end
    end)
    |> Enum.uniq()
    |> Enum.map(fn {first, second} ->
      %{
        first: first,
        second: second
      }
    end)
  end
end
