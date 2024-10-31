defmodule WandererAppWeb.MapEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapCoreEventHandler, MapRoutesEventHandler, MapSignaturesEventHandler}

  def handle_event(socket, %{event: event_name} = event)
      when event_name in [
             :routes
           ],
      do: MapRoutesEventHandler.handle_server_event(event, socket)

  def handle_event(socket, %{event: event_name} = event)
      when event_name in [
             :maybe_link_signature,
             :signatures_updated
           ],
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

      _ ->
        socket
    end
  end

  def handle_event(socket, event),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(event, body, socket)
      when event in [
             "get_routes",
             "set_autopilot_waypoint"
           ],
      do: MapRoutesEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event(event, body, socket)
      when event in [
             "update_signatures",
             "get_signatures"
             "link_signature_to_system",
             "unlink_signature"
           ],
      do: MapSignaturesEventHandler.handle_ui_event(event, body, socket)

  def handle_ui_event("show_activity", _, socket) do
    Task.async(fn ->
      {:ok, character_activity} = socket |> map_id() |> get_character_activity()

      {:character_activity, character_activity}
    end)

    {:noreply,
     socket
     |> assign(:show_activity?, true)}
  end

  def handle_ui_event("hide_activity", _, socket),
    do: {:noreply, socket |> assign(show_activity?: false)}

  def handle_ui_event(event, body, socket),
      do: MapCoreEventHandler.handle_ui_event(event, body, socket)





  def handle_ui_event("hide_tracking", _, socket),
    do: {:noreply, socket |> assign(show_tracking?: false)}

  def handle_ui_event(
        "log_map_error",
        %{"componentStack" => component_stack, "error" => error},
        socket
      ) do
    Logger.error(fn -> "map_ui_error: #{error}  \n#{component_stack} " end)

    {:noreply,
     socket
     |> put_flash(:error, "Something went wrong. Please try refresh page or submit an issue.")
     |> push_event("js-exec", %{
       to: "#map-loader",
       attr: "data-loading",
       timeout: 100
     })}
  end

  def handle_ui_event("noop", _, socket), do: {:noreply, socket}

  def handle_ui_event(
        _event,
        _body,
        %{assigns: %{has_tracked_characters?: false}} =
          socket
      ),
      do:
        {:noreply,
         socket
         |> put_flash(
           :error,
           "You should enable tracking for at least one character."
         )}

  def handle_ui_event(event, body, socket) do
    Logger.warning(fn -> "unhandled map ui event: #{event} #{inspect(body)}" end)
    {:noreply, socket}
  end

  defp maybe_start_map(map_id) do
    {:ok, map_server_started} = WandererApp.Cache.lookup("map_#{map_id}:started", false)

    if map_server_started do
      Process.send_after(self(), %{event: :map_server_started}, 10)
    else
      WandererApp.Map.Manager.start_map(map_id)
    end
  end

  defp init_map(
         %{assigns: %{current_user: current_user, map_slug: map_slug}} = socket,
         %{
           id: map_id,
           deleted: false,
           only_tracked_characters: only_tracked_characters,
           user_permissions: user_permissions,
           name: map_name,
           owner_id: owner_id
         } = map
       ) do
    user_permissions =
      WandererApp.Permissions.get_map_permissions(
        user_permissions,
        owner_id,
        current_user.characters |> Enum.map(& &1.id)
      )

    {:ok, character_settings} =
      case WandererApp.Api.MapCharacterSettings.read_by_map(%{map_id: map_id}) do
        {:ok, settings} -> {:ok, settings}
        _ -> {:ok, []}
      end

    {:ok, %{characters: availaible_map_characters}} =
      WandererApp.Maps.load_characters(map, character_settings, current_user.id)

    can_view? = user_permissions.view_system
    can_track? = user_permissions.track_character

    tracked_character_ids =
      availaible_map_characters |> Enum.filter(& &1.tracked) |> Enum.map(& &1.id)

    all_character_tracked? =
      not (availaible_map_characters |> Enum.empty?()) and
        availaible_map_characters |> Enum.all?(& &1.tracked)

    cond do
      (only_tracked_characters and can_track? and all_character_tracked?) or
          (not only_tracked_characters and can_view?) ->
        Phoenix.PubSub.subscribe(WandererApp.PubSub, map_id)
        {:ok, ui_loaded} = WandererApp.Cache.get_and_remove("map_#{map_slug}:ui_loaded", false)

        if ui_loaded do
          maybe_start_map(map_id)
        end

        socket
        |> assign(
          map_id: map_id,
          page_title: map_name,
          user_permissions: user_permissions,
          tracked_character_ids: tracked_character_ids,
          only_tracked_characters: only_tracked_characters
        )

      only_tracked_characters and can_track? and not all_character_tracked? ->
        Process.send_after(self(), :not_all_characters_tracked, 10)
        socket

      true ->
        Process.send_after(self(), :no_permissions, 10)
        socket
    end
  end

  defp init_map(socket, _map) do
    Process.send_after(self(), :no_access, 10)
    socket
  end

  defp map_start(
         socket,
         %{
           map_id: map_id,
           map_user_settings: map_user_settings,
           user_characters: user_character_eve_ids,
           initial_data: initial_data,
           events: events
         } = _started_data
       ) do
    socket =
      socket
      |> handle_map_start_events(map_id, events)

    map_characters = map_id |> WandererApp.Map.list_characters()

    socket
    |> assign(
      map_loaded?: true,
      map_user_settings: map_user_settings,
      user_characters: user_character_eve_ids,
      has_tracked_characters?: has_tracked_characters?(user_character_eve_ids)
    )
    |> push_map_event(
      "init",
      initial_data |> Map.put(:characters, map_characters |> Enum.map(&map_ui_character/1))
    )
    |> push_event("js-exec", %{
      to: "#map-loader",
      attr: "data-loaded"
    })
  end

  defp handle_map_start_events(socket, map_id, events) do
    events
    |> Enum.reduce(socket, fn event, socket ->
      case event do
        {:track_characters, map_characters, track_character} ->
          :ok = track_characters(map_characters, map_id, track_character)
          :ok = add_characters(map_characters, map_id, track_character)
          socket

        :invalid_token_message ->
          socket
          |> put_flash(
            :error,
            "One of your characters has expired token. Please refresh it on characters page."
          )

        :empty_tracked_characters ->
          socket
          |> put_flash(
            :info,
            "You should enable tracking for at least one character to work with map."
          )

        :map_character_limit ->
          socket
          |> put_flash(
            :error,
            "Map reached its character limit, your characters won't be tracked. Please contact administrator."
          )

        _ ->
          socket
      end
    end)
  end

  defp get_map_data(map_id, include_static_data? \\ true) do
    {:ok, hubs} = map_id |> WandererApp.Map.list_hubs()
    {:ok, connections} = map_id |> WandererApp.Map.list_connections()
    {:ok, systems} = map_id |> WandererApp.Map.list_systems()

    %{
      systems: systems |> Enum.map(fn system -> map_ui_system(system, include_static_data?) end),
      hubs: hubs,
      connections: connections |> Enum.map(&map_ui_connection/1)
    }
  end

  defp has_tracked_characters?([]), do: false
  defp has_tracked_characters?(_user_characters), do: true

  defp get_tracked_map_characters(map_id, current_user) do
    case WandererApp.Api.MapCharacterSettings.tracked_by_map(%{
           map_id: map_id,
           character_ids: current_user.characters |> Enum.map(& &1.id)
         }) do
      {:ok, settings} ->
        {:ok,
         settings
         |> Enum.map(fn s -> s |> Ash.load!(:character) |> Map.get(:character) end)}

      _ ->
        {:ok, []}
    end
  end

  defp get_connection_passages(map_id, from, to) do
    {:ok, passages} = WandererApp.MapChainPassagesRepo.by_connection(map_id, from, to)

    passages =
      passages
      |> Enum.map(fn p ->
        %{
          p
          | character: p.character |> map_ui_character_stat()
        }
        |> Map.put_new(
          :ship,
          WandererApp.Character.get_ship(%{ship: p.ship_type_id, ship_name: p.ship_name})
        )
        |> Map.drop([:ship_type_id, :ship_name])
      end)

    {:ok, %{passages: passages}}
  end

  defp update_system_positions(_map_id, []), do: :ok

  defp update_system_positions(map_id, [position | rest]) do
    update_system_position(map_id, position)
    update_system_positions(map_id, rest)
  end

  defp update_system_position(map_id, %{
         "position" => %{"x" => x, "y" => y},
         "solar_system_id" => solar_system_id
       }),
       do:
         map_id
         |> WandererApp.Map.Server.update_system_position(%{
           solar_system_id: solar_system_id |> String.to_integer(),
           position_x: x,
           position_y: y
         })

  def get_character_location(%{location: location} = _character),
    do: %{location: location}

  defp map_ui_system(
         %{
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

    %{
      id: "#{solar_system_id}",
      position: %{x: position_x, y: position_y},
      description: description,
      name: name,
      system_static_info: system_static_info,
      labels: labels,
      locked: locked,
      status: status,
      tag: tag,
      visible: visible
    }
  end

  defp has_tracked_characters?([]), do: false
  defp has_tracked_characters?(_user_characters), do: true

  defp get_character_activity(map_id) do
    {:ok, jumps} = WandererApp.Api.MapChainPassages.by_map_id(%{map_id: map_id})

    jumps =
      jumps
      |> Enum.map(fn p -> %{p | character: p.character |> map_ui_character_stat()} end)

    {:ok, %{jumps: jumps}}
  end

  defp get_system_static_info(nil), do: nil

  defp get_system_static_info(solar_system_id) do
    case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
      {:ok, system_static_info} ->
        map_ui_system_static_info(system_static_info)

      _ ->
        %{}
    end
  end

  defp map_ui_system_static_info(nil), do: %{}

  defp map_ui_system_static_info(system_static_info),
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

  defp map_ui_kill({solar_system_id, kills}),
    do: %{solar_system_id: solar_system_id, kills: kills}

  defp map_ui_kill(_kill), do: %{}

  defp map_ui_connection(
         %{
           solar_system_source: solar_system_source,
           solar_system_target: solar_system_target,
           mass_status: mass_status,
           time_status: time_status,
           ship_size_type: ship_size_type,
           locked: locked
         } = _connection
       ),
       do: %{
         id: "#{solar_system_source}_#{solar_system_target}",
         mass_status: mass_status,
         time_status: time_status,
         ship_size_type: ship_size_type,
         locked: locked,
         source: "#{solar_system_source}",
         target: "#{solar_system_target}"
       }

  defp map_ui_character(character),
    do:
      character
      |> Map.take([
        :eve_id,
        :name,
        :online,
        :corporation_id,
        :corporation_name,
        :corporation_ticker,
        :alliance_id,
        :alliance_name,
        :alliance_ticker
      ])
      |> Map.put_new(:ship, WandererApp.Character.get_ship(character))
      |> Map.put_new(:location, get_location(character))

  defp map_ui_character_stat(character),
    do:
      character
      |> Map.take([
        :eve_id,
        :name,
        :corporation_ticker,
        :alliance_ticker
      ])

  defp get_location(character),
    do: %{solar_system_id: character.solar_system_id, structure_id: character.structure_id}

  defp map_system(
         %{
           solar_system_name: solar_system_name,
           constellation_name: constellation_name,
           region_name: region_name,
           solar_system_id: solar_system_id,
           class_title: class_title
         } = _system
       ),
       do: %{
         label: solar_system_name,
         value: solar_system_id,
         constellation_name: constellation_name,
         region_name: region_name,
         class_title: class_title
       }

  defp add_characters([], _map_id, _track_character), do: :ok

  defp add_characters([character | characters], map_id, track_character) do
    map_id
    |> WandererApp.Map.Server.add_character(character, track_character)

    add_characters(characters, map_id, track_character)
  end

  defp remove_characters([], _map_id), do: :ok

  defp remove_characters([character | characters], map_id) do
    map_id
    |> WandererApp.Map.Server.remove_character(character.id)

    remove_characters(characters, map_id)
  end

  defp untrack_characters(characters, map_id) do
    characters
    |> Enum.each(fn character ->
      WandererAppWeb.Presence.untrack(self(), map_id, character.id)

      WandererApp.Cache.put(
        "#{inspect(self())}_map_#{map_id}:character_#{character.id}:tracked",
        false
      )

      :ok =
        Phoenix.PubSub.unsubscribe(
          WandererApp.PubSub,
          "character:#{character.eve_id}"
        )
    end)
  end

  defp track_characters(_, _, false), do: :ok

  defp track_characters([], _map_id, _is_track_character?), do: :ok

  defp track_characters(
         [character | characters],
         map_id,
         true
       ) do
    track_character(character, map_id)

    track_characters(characters, map_id, true)
  end

  defp track_character(
         %{
           id: character_id,
           eve_id: eve_id,
           corporation_id: corporation_id,
           alliance_id: alliance_id
         },
         map_id
       ) do
    WandererAppWeb.Presence.track(self(), map_id, character_id, %{})

    case WandererApp.Cache.lookup!(
           "#{inspect(self())}_map_#{map_id}:character_#{character_id}:tracked",
           false
         ) do
      true ->
        :ok

      _ ->
        :ok =
          Phoenix.PubSub.subscribe(
            WandererApp.PubSub,
            "character:#{eve_id}"
          )

        :ok =
          WandererApp.Cache.put(
            "#{inspect(self())}_map_#{map_id}:character_#{character_id}:tracked",
            true
          )
    end

    case WandererApp.Cache.lookup(
           "#{inspect(self())}_map_#{map_id}:corporation_#{corporation_id}:tracked",
           false
         ) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        :ok =
          Phoenix.PubSub.subscribe(
            WandererApp.PubSub,
            "corporation:#{corporation_id}"
          )

        :ok =
          WandererApp.Cache.put(
            "#{inspect(self())}_map_#{map_id}:corporation_#{corporation_id}:tracked",
            true
          )
    end

    case WandererApp.Cache.lookup(
           "#{inspect(self())}_map_#{map_id}:alliance_#{alliance_id}:tracked",
           false
         ) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        :ok =
          Phoenix.PubSub.subscribe(
            WandererApp.PubSub,
            "alliance:#{alliance_id}"
          )

        :ok =
          WandererApp.Cache.put(
            "#{inspect(self())}_map_#{map_id}:alliance_#{alliance_id}:tracked",
            true
          )
    end

    :ok = WandererApp.Character.TrackerManager.start_tracking(character_id)
  end

  defp push_map_event(socket, type, body),
    do:
      socket
      |> Phoenix.LiveView.Utils.push_event("map_event", %{
        type: type,
        body: body
      })

  defp map_id(%{assigns: %{map_id: map_id}} = _socket), do: map_id
end
