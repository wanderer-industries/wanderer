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
    MapSystemsEventHandler,
    MapSystemCommentsEventHandler,
    MapStructuresEventHandler,
    MapKillsEventHandler,
    MapPingsEventHandler
  }

  @map_characters_events [
    :character_added,
    :character_removed,
    :character_updated,
    :characters_updated,
    :present_characters_updated,
    :refresh_user_characters,
    :show_tracking,
    :untrack_character
  ]

  @map_characters_ui_events [
    "getCharacterInfo",
    "getCharactersTrackingInfo",
    "updateCharacterTracking",
    "updateFollowingCharacter",
    "updateMainCharacter",
    "startTracking"
  ]

  @map_system_events [
    :add_system,
    :update_system,
    :systems_removed,
    :maybe_select_system
  ]

  @map_system_ui_events [
    "delete_systems",
    "get_system_static_infos",
    "manual_add_system",
    "search_systems",
    "update_system_position",
    "update_system_positions",
    "update_system_name",
    "update_system_description",
    "update_system_labels",
    "update_system_locked",
    "update_system_tag",
    "update_system_temporary_name",
    "update_system_status",
    "manual_paste_systems_and_connections"
  ]

  @map_system_comments_events [
    :system_comment_added,
    :system_comment_removed
  ]

  @map_system_comments_ui_events [
    "addSystemComment",
    "getSystemComments",
    "deleteSystemComment"
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
    :character_activity_data
  ]

  @map_activity_ui_events [
    "show_activity"
  ]

  @map_routes_events [
    :routes,
    :user_routes
  ]

  @map_routes_ui_events [
    "get_routes",
    "get_user_routes",
    "set_autopilot_waypoint",
    "add_hub",
    "delete_hub",
    "get_user_hubs",
    "add_user_hub",
    "delete_user_hub"
  ]

  @map_signatures_events [
    :maybe_link_signature,
    :signatures_updated,
    :remove_signatures
  ]

  @map_signatures_ui_events [
    "load_signatures",
    "update_signatures",
    "get_signatures",
    "link_signature_to_system",
    "unlink_signature",
    "undo_delete_signatures"
  ]

  @map_structures_events [
    :structures_updated
  ]

  @map_structures_ui_events [
    "update_structures",
    "get_structures",
    "get_corporation_names",
    "get_corporation_ticker"
  ]

  @map_kills_events [
    :init_kills,
    :kills_updated,
    :detailed_kills_updated,
    :update_system_kills
  ]

  @map_kills_ui_events [
    "get_system_kills",
    "get_systems_kills"
  ]

  @map_pings_events [
    :load_map_pings,
    :ping_added,
    :ping_cancelled
  ]

  @map_pings_ui_events [
    "add_ping",
    "cancel_ping"
  ]

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_characters_events,
      do: MapCharactersEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_system_events,
      do: MapSystemsEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_system_comments_events,
      do: MapSystemCommentsEventHandler.handle_server_event(event, socket)

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
      when event_name in @map_structures_events,
      do: MapStructuresEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_signatures_events,
      do: MapSignaturesEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_kills_events,
      do: MapKillsEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in @map_pings_events,
      do: MapPingsEventHandler.handle_server_event(event, socket)

  def handle_event(socket, {ref, result}) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case result do
      {:map_error, map_error} ->
        Process.send_after(self(), map_error, 100)
        socket

      {event, payload} ->
        Process.send_after(
          self(),
          %{event: event, payload: payload},
          10
        )

        socket

      _ ->
        Logger.warning("Unhandled task result: #{inspect(result)}")
        socket
    end
  end

  def handle_event(socket, {:DOWN, ref, :process, _pid, reason}) when is_reference(ref) do
    # Task failed, log the error and update the client
    Logger.error("Task failed: #{inspect(reason)}")
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
      when event in @map_system_comments_ui_events,
      do: MapSystemCommentsEventHandler.handle_ui_event(event, body, socket)

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
      when event in @map_structures_ui_events,
      do: MapStructuresEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_activity_ui_events,
      do: MapActivityEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in @map_pings_ui_events,
      do: MapPingsEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(
        event,
        body,
        %{
          assigns: %{
            is_subscription_active?: true
          }
        } = socket
      )
      when event in @map_kills_ui_events,
      do: MapKillsEventHandler.handle_ui_event(event, body, socket)

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

  def push_map_event(
        %{
          assigns: %{
            is_version_valid?: true
          }
        } = socket,
        type,
        body
      ) do
    socket
    |> Phoenix.LiveView.Utils.push_event("map_event", %{
      type: type,
      body: body
    })
  end

  def push_map_event(socket, _type, _body), do: socket

  def map_ui_character_stat(nil), do: nil

  def map_ui_character_stat(character),
    do:
      character
      |> Map.take([
        :eve_id,
        :name,
        :corporation_id,
        :corporation_ticker,
        :alliance_id,
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
          linked_sig_eve_id: linked_sig_eve_id,
          temporary_name: temporary_name,
          status: status,
          visible: visible
        } = _system,
        include_static_data? \\ true
      ) do
    comments_count =
      system_id
      |> WandererApp.Maps.get_system_comments_activity()
      |> case do
        [{count}] when not is_nil(count) ->
          count

        _ ->
          0
      end

    system_info =
      %{
        id: "#{solar_system_id}",
        position: %{x: position_x, y: position_y},
        description: description,
        name: name,
        labels: labels,
        locked: locked,
        linked_sig_eve_id: linked_sig_eve_id,
        status: status,
        tag: tag,
        temporary_name: temporary_name,
        comments_count: comments_count,
        visible: visible
      }

    system_info =
      if include_static_data? do
        system_info |> Map.merge(%{system_static_info: get_system_static_info(solar_system_id)})
      else
        system_info
      end

    system_info
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
end
