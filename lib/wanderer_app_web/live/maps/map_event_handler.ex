defmodule WandererAppWeb.MapEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{
    MapActivityEventHandler,
    MapCharactersEventHandler,
    MapConnectionsEventHandler,
    MapCoreEventHandler,
    MapRoutesEventHandler,
    MapSignaturesEventHandler,
    MapSystemsEventHandler
  }

  @map_characters_events [
    :character_added,
    :character_removed,
    :character_updated,
    :characters_updated,
    :present_characters_updated
  ]

  @map_characters_ui_events [
    "add_character",
    "toggle_track",
    "hide_tracking"
  ]

  @map_system_events [
    :add_system,
    :update_system,
    :systems_removed,
    :maybe_select_system,
    :kills_updated
  ]

  @map_system_ui_events [
    "add_hub",
    "delete_hub",
    "add_system",
    "delete_systems",
    "manual_add_system",
    "get_system_static_infos",
    "update_system_position",
    "update_system_positions",
    "update_system_name",
    "update_system_description",
    "update_system_labels",
    "update_system_locked",
    "update_system_tag",
    "update_system_status"
  ]

  @map_connection_events [
    :add_connection,
    :remove_connections,
    :update_connection
  ]

  @map_connection_ui_events [
    "manual_add_connection",
    "manual_delete_connection",
    "get_connection_info",
    "get_passages",
    "update_connection_time_status",
    "update_connection_type",
    "update_connection_mass_status",
    "update_connection_ship_size_type",
    "update_connection_locked",
    "update_connection_custom_info"
  ]

  @map_activity_events [
    :character_activity
  ]

  @map_activity_ui_events [
    "show_activity",
    "hide_activity"
  ]

  @map_routes_events [
    :routes
  ]

  @map_routes_ui_events [
    "get_routes",
    "set_autopilot_waypoint"
  ]

  @map_signatures_events [
    :maybe_link_signature,
    :signatures_updated
  ]

  @map_signatures_ui_events [
    "update_signatures",
    "get_signatures",
    "link_signature_to_system",
    "unlink_signature"
  ]

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_characters_events,
      do: MapCharactersEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_system_events,
      do: MapSystemsEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_connection_events,
      do: MapConnectionsEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_activity_events,
      do: MapActivityEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_routes_events,
      do: MapRoutesEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_signatures_events,
      do: MapSignaturesEventHandler.handle_server_event(event, socket)

  def handle_event(socket, {ref, result}) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case result do
      {:map_error, map_error} ->
        Process.send_after(self(), map_error, 100)
        socket

      {event, payload} ->
        Process.send_after(
          self(),
          %{
            event: event,
            payload: payload
          },
          10
        )

        socket

      _ ->
        socket
    end
  end

  def handle_event(socket, event),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_characters_ui_events,
      do: MapCharactersEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_system_ui_events,
      do: MapSystemsEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_connection_ui_events,
      do: MapConnectionsEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_routes_ui_events,
      do: MapRoutesEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_signatures_ui_events,
      do: MapSignaturesEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_activity_ui_events,
      do: MapActivityEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  def get_system_static_info(nil), do: nil

  def get_system_static_info(solar_system_id) do
    case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
      {:ok, system_static_info} ->
        map_ui_system_static_info(system_static_info)

      _ ->
        %{}
    end
  end

  def push_map_event(socket, type, body),
    do:
      socket
      |> Phoenix.LiveView.Utils.push_event("map_event", %{
        type: type,
        body: body
      })

  def map_ui_character_stat(character),
    do:
      character
      |> Map.take([
        :eve_id,
        :name,
        :corporation_ticker,
        :alliance_ticker
      ])

  def map_ui_connection(
        %{
          solar_system_source: solar_system_source,
          solar_system_target: solar_system_target,
          mass_status: mass_status,
          time_status: time_status,
          type: type,
          ship_size_type: ship_size_type,
          locked: locked
        } = _connection
      ),
      do: %{
        id: "#{solar_system_source}_#{solar_system_target}",
        mass_status: mass_status,
        time_status: time_status,
        type: type,
        ship_size_type: ship_size_type,
        locked: locked,
        source: "#{solar_system_source}",
        target: "#{solar_system_target}"
      }

  def map_ui_system(
        %{
          id: system_id,
          solar_system_id: solar_system_id,
          name: name,
          description: description,
          position_x: position_x,
          position_y: position_y,
          locked: locked,
          tag: tag,
          labels: labels,
          status: status,
          visible: visible
        } = _system,
        _include_static_data? \\ true
      ) do
    system_static_info = get_system_static_info(solar_system_id)

    system_signatures =
      system_id
      |> WandererAppWeb.MapSignaturesEventHandler.get_system_signatures()
      |> Enum.filter(fn signature ->
        is_nil(signature.linked_system) && signature.group == "Wormhole"
      end)

    %{
      id: "#{solar_system_id}",
      position: %{x: position_x, y: position_y},
      description: description,
      name: name,
      system_static_info: system_static_info,
      system_signatures: system_signatures,
      labels: labels,
      locked: locked,
      status: status,
      tag: tag,
      visible: visible
    }
  end

  def map_ui_system_static_info(nil), do: %{}

  def map_ui_system_static_info(system_static_info),
    do:
      system_static_info
      |> Map.take([
        :region_id,
        :constellation_id,
        :solar_system_id,
        :solar_system_name,
        :solar_system_name_lc,
        :constellation_name,
        :region_name,
        :system_class,
        :security,
        :type_description,
        :class_title,
        :is_shattered,
        :effect_name,
        :effect_power,
        :statics,
        :wandering,
        :triglavian_invasion_status,
        :sun_type_id
      ])

  def map_ui_kill({solar_system_id, kills}),
    do: %{solar_system_id: solar_system_id, kills: kills}

  def map_ui_kill(_kill), do: %{}
end
