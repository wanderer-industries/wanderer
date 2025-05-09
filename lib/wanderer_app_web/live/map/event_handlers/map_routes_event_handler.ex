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
    Task.async(fn ->
      {:ok, hubs} = map_id |> WandererApp.Map.list_hubs()

      {:ok, routes} =
        WandererApp.Maps.find_routes(
          map_id,
          hubs,
          solar_system_id,
          get_routes_settings(routes_settings)
        )

      {:routes, {solar_system_id, routes}}
    end)

    {:noreply, socket}
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
    Task.async(fn ->
      if is_subscription_active? do
        {:ok, hubs} = WandererApp.MapUserSettingsRepo.get_hubs(map_id, current_user.id)

        {:ok, routes} =
          WandererApp.Maps.find_routes(
            map_id,
            hubs,
            solar_system_id,
            get_routes_settings(routes_settings)
          )

        {:user_routes, {solar_system_id, routes}}
      else
        {:user_routes, {solar_system_id, %{routes: [], systems_static_data: []}}}
      end
    end)

    {:noreply, socket}
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
    |> Task.async_stream(fn character_eve_id ->
      set_autopilot_waypoint(
        current_user,
        character_eve_id,
        add_to_beginning,
        clear_other_waypoints,
        destination_id
      )
    end)
    |> Enum.map(fn _result -> :skip end)

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
