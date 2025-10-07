defmodule WandererAppWeb.MapRoutesEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler, MapSystemsEventHandler}

  def handle_server_event(
        %{
          event: :routes,
          payload: {solar_system_id, %{routes: routes, systems_static_data: systems_static_data}}
        },
        socket
      ),
      do:
        socket
        |> MapEventHandler.push_map_event(
          "routes",
          %{
            solar_system_id: solar_system_id,
            loading: false,
            routes: routes,
            systems_static_data: systems_static_data
          }
        )

  def handle_server_event(
        %{
          event: :user_routes,
          payload: {solar_system_id, %{routes: routes, systems_static_data: systems_static_data}}
        },
        socket
      ),
      do:
        socket
        |> MapEventHandler.push_map_event(
          "user_routes",
          %{
            solar_system_id: solar_system_id,
            loading: false,
            routes: routes,
            systems_static_data: systems_static_data
          }
        )

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "get_routes",
        %{"system_id" => solar_system_id, "routes_settings" => routes_settings} = _event,
        %{assigns: %{map_id: map_id, map_loaded?: true}} = socket
      ) do
    {:ok, map} = map_id |> WandererApp.Map.get_map()
    hubs_limit = map |> Map.get(:hubs_limit, 20)

    {:ok, hubs} = map_id |> WandererApp.Map.list_hubs()

    {:ok, pings} = WandererApp.MapPingsRepo.get_by_map(map_id)

    ping_system_ids =
      pings
      |> Enum.map(fn %{system: %{solar_system_id: solar_system_id}} -> "#{solar_system_id}" end)

    route_hubs = (ping_system_ids ++ hubs) |> Enum.uniq()

    is_hubs_limit_reached = hubs |> Enum.count() > hubs_limit

    Task.async(fn ->
      {:ok, routes} =
        WandererApp.Maps.find_routes(
          map_id,
          route_hubs,
          solar_system_id,
          get_routes_settings(routes_settings),
          is_hubs_limit_reached
        )

      {:routes, {solar_system_id, routes}}
    end)

    if is_hubs_limit_reached do
      {:noreply,
       socket
       |> put_flash(
         :warning,
         "The Map hubs limit has been reached, please try to remove some hubs first, or contact the map administrators."
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_ui_event(
        "get_user_routes",
        %{"system_id" => solar_system_id, "routes_settings" => routes_settings} = _event,
        %{
          assigns: %{
            map_id: map_id,
            map_loaded?: true,
            current_user: current_user,
            is_subscription_active?: is_subscription_active?
          }
        } = socket
      ) do
    {:ok, map} = map_id |> WandererApp.Map.get_map()
    hubs_limit = map |> Map.get(:hubs_limit, 20)

    {:ok, hubs} = WandererApp.MapUserSettingsRepo.get_hubs(map_id, current_user.id)

    is_hubs_limit_reached = hubs |> Enum.count() > hubs_limit

    Task.async(fn ->
      if is_subscription_active? do
        {:ok, routes} =
          WandererApp.Maps.find_routes(
            map_id,
            hubs,
            solar_system_id,
            get_routes_settings(routes_settings),
            is_hubs_limit_reached
          )

        {:user_routes, {solar_system_id, routes}}
      else
        {:user_routes, {solar_system_id, %{routes: [], systems_static_data: []}}}
      end
    end)

    if is_hubs_limit_reached do
      {:noreply,
       socket
       |> put_flash(
         :warning,
         "The user hubs limit has been reached, please try to remove some hubs first, or contact the map administrators."
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_ui_event(
        "add_hub",
        %{"system_id" => solar_system_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    {:ok, map} = map_id |> WandererApp.Map.get_map()
    hubs_limit = map |> Map.get(:hubs_limit, 20)

    {:ok, hubs} = map_id |> WandererApp.Map.list_hubs()

    if hubs |> Enum.count() < hubs_limit do
      map_id
      |> WandererApp.Map.Server.add_hub(%{
        solar_system_id: solar_system_id
      })

      {:ok, _} =
        WandererApp.User.ActivityTracker.track_map_event(:hub_added, %{
          character_id: main_character_id,
          user_id: current_user.id,
          map_id: map_id,
          solar_system_id: solar_system_id
        })

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_flash(
         :warning,
         "The Map hubs limit has been reached, please try to remove some hubs first, or contact the map administrators."
       )}
    end
  end

  def handle_ui_event(
        "delete_hub",
        %{"system_id" => solar_system_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    map_id
    |> WandererApp.Map.Server.remove_hub(%{
      solar_system_id: solar_system_id
    })

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:hub_removed, %{
        character_id: main_character_id,
        user_id: current_user.id,
        map_id: map_id,
        solar_system_id: solar_system_id
      })

    {:noreply, socket}
  end

  def handle_ui_event(
        "get_user_hubs",
        _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user
          }
        } =
          socket
      ) do
    {:ok, hubs} = WandererApp.MapUserSettingsRepo.get_hubs(map_id, current_user.id)

    {:reply, %{hubs: hubs}, socket}
  end

  def handle_ui_event(
        "add_user_hub",
        %{"system_id" => solar_system_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user
          }
        } =
          socket
      ) do
    {:ok, map} = map_id |> WandererApp.Map.get_map()
    hubs_limit = map |> Map.get(:hubs_limit, 20)

    {:ok, hubs} = WandererApp.MapUserSettingsRepo.get_hubs(map_id, current_user.id)

    if hubs |> Enum.count() < hubs_limit do
      hubs = hubs ++ ["#{solar_system_id}"]

      {:ok, _} =
        WandererApp.MapUserSettingsRepo.update_hubs(
          map_id,
          current_user.id,
          hubs
        )

      {:noreply,
       socket
       |> MapEventHandler.push_map_event(
         "map_updated",
         %{user_hubs: hubs}
       )}
    else
      {:noreply,
       socket
       |> MapEventHandler.push_map_event(
         "map_updated",
         %{user_hubs: hubs}
       )
       |> put_flash(
         :warning,
         "The user hubs limit has been reached, please try to remove some user hubs first, or contact the map administrators."
       )}
    end
  end

  def handle_ui_event(
        "delete_user_hub",
        %{"system_id" => solar_system_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user
          }
        } =
          socket
      ) do
    {:ok, hubs} = WandererApp.MapUserSettingsRepo.get_hubs(map_id, current_user.id)

    case hubs |> Enum.member?("#{solar_system_id}") do
      true ->
        hubs = hubs |> Enum.reject(fn hub -> hub == "#{solar_system_id}" end)

        {:ok, _} =
          WandererApp.MapUserSettingsRepo.update_hubs(
            map_id,
            current_user.id,
            hubs
          )

        {:noreply,
         socket
         |> MapEventHandler.push_map_event(
           "map_updated",
           %{user_hubs: hubs}
         )}

      _ ->
        {:noreply,
         socket
         |> MapEventHandler.push_map_event(
           "map_updated",
           %{user_hubs: hubs}
         )}
    end
  end

  def handle_ui_event(
        "set_autopilot_waypoint",
        %{
          "character_eve_ids" => character_eve_ids,
          "add_to_beginning" => add_to_beginning,
          "clear_other_waypoints" => clear_other_waypoints,
          "destination_id" => destination_id
        } = _event,
        %{assigns: %{current_user: current_user, has_tracked_characters?: true}} = socket
      ) do
    character_eve_ids
    |> Task.async_stream(
      fn character_eve_id ->
        set_autopilot_waypoint(
          current_user,
          character_eve_id,
          add_to_beginning,
          clear_other_waypoints,
          destination_id
        )
      end,
      max_concurrency: System.schedulers_online() * 4,
      on_timeout: :kill_task,
      timeout: :timer.minutes(1)
    )
    |> Enum.each(fn _result -> :skip end)

    {:noreply, socket}
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  defp get_routes_settings(%{
         "path_type" => path_type,
         "include_mass_crit" => include_mass_crit,
         "include_eol" => include_eol,
         "include_frig" => include_frig,
         "include_cruise" => include_cruise,
         "avoid_wormholes" => avoid_wormholes,
         "avoid_pochven" => avoid_pochven,
         "avoid_edencom" => avoid_edencom,
         "avoid_triglavian" => avoid_triglavian,
         "include_thera" => include_thera,
         "avoid" => avoid
       }),
       do: %{
         path_type: path_type,
         include_mass_crit: include_mass_crit,
         include_eol: include_eol,
         include_frig: include_frig,
         include_cruise: include_cruise,
         avoid_wormholes: avoid_wormholes,
         avoid_pochven: avoid_pochven,
         avoid_edencom: avoid_edencom,
         avoid_triglavian: avoid_triglavian,
         include_thera: include_thera,
         avoid: avoid
       }

  defp get_routes_settings(_), do: %{}

  defp set_autopilot_waypoint(
         current_user,
         character_eve_id,
         add_to_beginning,
         clear_other_waypoints,
         destination_id
       ) do
    case current_user.characters
         |> Enum.find(fn c -> c.eve_id == character_eve_id end) do
      nil ->
        :skip

      %{id: character_id} = _character ->
        character_id
        |> WandererApp.Character.set_autopilot_waypoint(destination_id,
          add_to_beginning: add_to_beginning,
          clear_other_waypoints: clear_other_waypoints
        )

        :skip
    end
  end
end
