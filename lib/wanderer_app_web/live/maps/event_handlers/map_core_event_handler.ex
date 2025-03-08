defmodule WandererAppWeb.MapCoreEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCharactersEventHandler, MapSystemsEventHandler}
  alias WandererApp.Utils.EVEUtil

  def handle_server_event(:update_permissions, socket) do
    DebounceAndThrottle.Debounce.apply(
      Process,
      :send_after,
      [self(), :refresh_permissions, 100],
      "update_permissions_#{inspect(self())}",
      1000
    )

    socket
  end

  def handle_server_event(
        :refresh_permissions,
        %{assigns: %{current_user: current_user, map_slug: map_slug}} = socket
      ) do
    {:ok, %{id: map_id, user_permissions: user_permissions, owner_id: owner_id}} =
      map_slug
      |> WandererApp.Api.Map.get_map_by_slug!()
      |> Ash.load(:user_permissions, actor: current_user)

    user_permissions =
      WandererApp.Permissions.get_map_permissions(
        user_permissions,
        owner_id,
        current_user.characters |> Enum.map(& &1.id)
      )

    case user_permissions do
      %{view_system: false} ->
        socket
        |> Phoenix.LiveView.put_flash(:error, "Your access to the map have been revoked.")
        |> Phoenix.LiveView.push_navigate(to: ~p"/maps")

      %{track_character: track_character} ->
        {:ok, map_characters} =
          case WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_filtered(
                 map_id,
                 current_user.characters |> Enum.map(& &1.id)
               ) do
            {:ok, settings} ->
              {:ok,
               settings
               |> Enum.map(fn s -> s |> Ash.load!(:character) |> Map.get(:character) end)}

            _ ->
              {:ok, []}
          end

        case track_character do
          false ->
            :ok = MapCharactersEventHandler.untrack_characters(map_characters, map_id)
            :ok = MapCharactersEventHandler.remove_characters(map_characters, map_id)

          _ ->
            :ok = MapCharactersEventHandler.track_characters(map_characters, map_id, true)

            :ok =
              MapCharactersEventHandler.add_characters(map_characters, map_id, track_character)
        end

        socket
        |> assign(user_permissions: user_permissions)
        |> MapEventHandler.push_map_event(
          "user_permissions",
          user_permissions
        )
    end
  end

  def handle_server_event(
        %{
          event: :load_map
        },
        %{assigns: %{current_user: current_user, map_slug: map_slug}} = socket
      ) do
    ErrorTracker.set_context(%{user_id: current_user.id})

    map_slug
    |> WandererApp.MapRepo.get_by_slug_with_permissions(current_user)
    |> case do
      {:ok, map} ->
        socket |> init_map(map)

      {:error, _} ->
        socket
        |> put_flash(
          :error,
          "Something went wrong. Please try one more time or submit an issue."
        )
        |> push_navigate(to: ~p"/maps")
    end
  end

  def handle_server_event(
        %{event: :map_server_started},
        socket
      ),
      do: socket |> handle_map_server_started()

  def handle_server_event(%{event: :update_map, payload: map_diff}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event(
        "map_updated",
        map_diff
      )

  def handle_server_event(
        %{event: "presence_diff"},
        socket
      ),
      do: socket

  def handle_server_event(%{event: :structures_updated, payload: _solar_system_id}, socket) do
    socket
  end

  def handle_server_event(%{event: :detailed_kills_updated, payload: payload}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "detailed_kills_updated",
      payload
    )
  end

  def handle_server_event(event, socket) do
    Logger.debug(fn -> "unhandled map core event: #{inspect(event)}" end)
    socket
  end

  def handle_ui_event(
        "ui_loaded",
        %{"version" => version},
        %{assigns: %{map_slug: map_slug, app_version: app_version} = assigns} = socket
      ) do
    is_version_valid? = to_string(version) == to_string(app_version)

    if is_version_valid? do
      assigns
      |> Map.get(:map_id)
      |> case do
        map_id when not is_nil(map_id) ->
          maybe_start_map(map_id)

        _ ->
          WandererApp.Cache.insert("map_#{map_slug}:ui_loaded", true)
      end
    end

    {:noreply, socket |> assign(:is_version_valid?, is_version_valid?)}
  end

  def handle_ui_event(
        "live_select_change",
        %{"id" => id, "text" => text},
        socket
      )
      when id == "_system_id_live_select_component" do
    options =
      WandererApp.Api.MapSolarSystem.find_by_name!(%{name: text})
      |> Enum.take(100)
      |> Enum.map(&MapSystemsEventHandler.map_system/1)

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  def handle_ui_event("toggle_track_" <> character_id, _, socket),
    do:
      MapCharactersEventHandler.handle_ui_event(
        "toggle_track",
        %{"character-id" => character_id},
        socket
      )

  def handle_ui_event("toggle_follow_" <> character_id, _, socket),
    do:
      MapCharactersEventHandler.handle_ui_event(
        "toggle_follow",
        %{"character-id" => character_id},
        socket
      )

  def handle_ui_event(
        "get_user_settings",
        _,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    {:ok, user_settings} =
      WandererApp.MapUserSettingsRepo.get!(map_id, current_user.id)
      |> WandererApp.MapUserSettingsRepo.to_form_data()

    {:reply, %{user_settings: user_settings}, socket}
  end

  def handle_ui_event(
        "update_user_settings",
        user_settings_form,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    settings =
      user_settings_form
      |> Map.take(["select_on_spash", "link_signature_on_splash", "delete_connection_with_sigs"])
      |> Jason.encode!()

    {:ok, user_settings} =
      WandererApp.MapUserSettingsRepo.create_or_update(map_id, current_user.id, settings)

    {:noreply,
     socket |> assign(user_settings_form: user_settings_form, map_user_settings: user_settings)}
  end

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
           "You should enable tracking for at least one character!"
         )
         |> MapCharactersEventHandler.add_character()}

  def handle_ui_event(
        "show_activity",
        _,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    # Show loading state immediately
    socket = socket
      |> WandererAppWeb.MapEventHandler.push_map_event(
        "character_activity_data",
        %{activity: [], loading: true}
      )

    # Start async task to fetch and process activity data
    # Use Task.async so we can properly handle the result
    task = Task.async(fn ->
      try do
        WandererApp.Utils.CharacterUtil.process_character_activity(map_id, current_user)
      rescue
        e ->
          Logger.error("Error processing character activity: #{inspect(e)}")
          Logger.error("#{Exception.format_stacktrace()}")
          []
      end
    end)

    {:noreply, socket |> assign(:character_activity_task, task)}
  end

  def handle_ui_event("hide_activity", _, socket),
    do: {:noreply, socket |> assign(show_activity?: false)}

  def handle_ui_event("show_tracking", _, socket),
    do: MapCharactersEventHandler.handle_ui_event("show_tracking", %{}, socket)

  def handle_ui_event(event, body, socket) do
    Logger.debug(fn -> "unhandled map ui event: #{inspect(event)} #{inspect(body)}" end)
    {:noreply, socket}
  end

  def handle_info(
        {ref, activity_data},
        %{assigns: %{character_activity_task: %Task{ref: ref}}} = socket
      ) do
    # Demonitor the task to avoid receiving DOWN messages
    Process.demonitor(ref, [:flush])

    # Send the result to the client with loading: false
    socket = socket
      |> WandererAppWeb.MapEventHandler.push_map_event(
        "character_activity_data",
        %{activity: activity_data, loading: false}
      )
      |> assign(:character_activity_task, nil)

    {:noreply, socket}
  end

  # Fallback handler for task results when the character_activity_task assign is missing
  def handle_info(
        {ref, activity_data},
        socket
      ) when is_reference(ref) do
    # Demonitor the task to avoid receiving DOWN messages
    Process.demonitor(ref, [:flush])

    # Send the result to the client with loading: false
    socket = socket
      |> WandererAppWeb.MapEventHandler.push_map_event(
        "character_activity_data",
        %{activity: activity_data, loading: false}
      )

    {:noreply, socket}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{assigns: %{character_activity_task: %Task{ref: ref}}} = socket
      ) do
    # Task failed, log the error and update the client
    Logger.error("Character activity task failed: #{inspect(reason)}")

    socket = socket
      |> WandererAppWeb.MapEventHandler.push_map_event(
        "character_activity_data",
        %{activity: [], loading: false}
      )
      |> assign(:character_activity_task, nil)

    {:noreply, socket}
  end

  # Fallback handler for DOWN messages when the character_activity_task assign is missing
  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        socket
      ) when is_reference(ref) do
    # Log that we're handling a DOWN message without a matching task reference
    Logger.error("Character activity task failed: #{inspect(reason)}")

    # Send the result to the client with loading: false
    socket = socket
      |> WandererAppWeb.MapEventHandler.push_map_event(
        "character_activity_data",
        %{activity: [], loading: false}
      )

    {:noreply, socket}
  end

  def handle_info(
        :refresh_character_activity,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    # Show loading state immediately
    socket = socket
      |> WandererAppWeb.MapEventHandler.push_map_event(
        "character_activity_data",
        %{activity: [], loading: true}
      )

    # Start async task to fetch and process activity data
    task = Task.async(fn ->
      try do
        WandererApp.Utils.CharacterUtil.process_character_activity(map_id, current_user)
      rescue
        e ->
          Logger.error("Error processing character activity: #{inspect(e)}")
          Logger.error("#{Exception.format_stacktrace()}")
          []
      end
    end)

    {:noreply, socket |> assign(:character_activity_task, task)}
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
         } = _map
       ) do
    user_permissions =
      WandererApp.Permissions.get_map_permissions(
        user_permissions,
        owner_id,
        current_user.characters |> Enum.map(& &1.id)
      )

    {:ok, map_user_settings} = WandererApp.MapUserSettingsRepo.get(map_id, current_user.id)

    {:ok, character_settings} =
      case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
        {:ok, settings} -> {:ok, settings}
        _ -> {:ok, []}
      end

    # Get characters that have access to the map
    {:ok, available_map_characters} =
      WandererApp.Maps.get_tracked_map_characters(map_id, current_user)

    can_view? = user_permissions.view_system
    can_track? = user_permissions.track_character

    tracked_character_ids =
      available_map_characters |> Enum.filter(fn char ->
        setting = Enum.find(character_settings, &(&1.character_id == char.id))
        setting != nil && setting.tracked == true
      end) |> Enum.map(& &1.id)

    all_character_tracked? =
      not (available_map_characters |> Enum.empty?()) and
        available_map_characters |> Enum.all?(fn char ->
          setting = Enum.find(character_settings, &(&1.character_id == char.id))
          setting != nil && setting.tracked == true
        end)

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
          map_user_settings: map_user_settings,
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

  defp handle_map_server_started(
         %{
           assigns: %{
             current_user: current_user,
             map_id: map_id,
             user_permissions:
               %{view_system: true, track_character: track_character} = user_permissions
           }
         } = socket
       ) do
    with {:ok, _} <- current_user |> WandererApp.Api.User.update_last_map(%{last_map_id: map_id}),
         {:ok, tracked_map_characters} <-
           WandererApp.Maps.get_tracked_map_characters(map_id, current_user),
         {:ok, characters_limit} <- map_id |> WandererApp.Map.get_characters_limit(),
         {:ok, present_character_ids} <-
           WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", []),
         {:ok, kills} <- WandererApp.Cache.lookup("map_#{map_id}:zkb_kills", Map.new()) do
      user_character_eve_ids = tracked_map_characters |> Enum.map(& &1.eve_id)

      events =
        case tracked_map_characters |> Enum.any?(&(&1.access_token == nil)) do
          true ->
            [:invalid_token_message]

          _ ->
            []
        end

      events =
        case tracked_map_characters |> Enum.empty?() do
          true ->
            events ++ [:empty_tracked_characters]

          _ ->
            events
        end

      events =
        case present_character_ids |> Enum.count() < characters_limit do
          true ->
            events ++ [{:track_characters, tracked_map_characters, track_character}]

          _ ->
            events ++ [:map_character_limit]
        end

      initial_data =
        map_id
        |> get_map_data()
        |> Map.merge(%{
          kills:
            kills
            |> Enum.filter(fn {_, kills} -> kills > 0 end)
            |> Enum.map(&MapEventHandler.map_ui_kill/1),
          present_characters:
            present_character_ids
            |> WandererApp.Character.get_character_eve_ids!(),
          user_characters: user_character_eve_ids,
          user_permissions: user_permissions,
          system_static_infos: nil,
          wormhole_types: nil,
          effects: nil,
          reset: false
        })

      system_static_infos =
        map_id
        |> WandererApp.Map.list_systems!()
        |> Enum.map(&WandererApp.CachedInfo.get_system_static_info!(&1.solar_system_id))
        |> Enum.map(&MapEventHandler.map_ui_system_static_info/1)

      initial_data =
        initial_data
        |> Map.put(
          :wormholes,
          WandererApp.CachedInfo.get_wormhole_types!()
        )
        |> Map.put(
          :effects,
          WandererApp.CachedInfo.get_effects!()
        )
        |> Map.put(
          :system_static_infos,
          system_static_infos
        )
        |> Map.put(:reset, true)

      socket
      |> map_start(%{
        map_id: map_id,
        user_characters: user_character_eve_ids,
        initial_data: initial_data,
        events: events
      })
    else
      error ->
        Logger.error(fn -> "map_start_error: #{error}" end)
        Process.send_after(self(), :no_access, 10)

        socket
    end
  end

  defp handle_map_server_started(socket) do
    Process.send_after(self(), :no_access, 10)
    socket
  end

  defp map_start(
         socket,
         %{
           map_id: map_id,
           user_characters: user_character_eve_ids,
           initial_data: initial_data,
           events: events
         } = _started_data
       ) do
    socket =
      socket
      |> handle_map_start_events(map_id, events)

    {:ok, options} =
      map_id
      |> WandererApp.Map.get_options()

    user_permissions =
      initial_data
      |> Map.get(:user_permissions)

    # Use the current user directly without reloading
    current_user = socket.assigns.current_user

    # Get character settings for this map
    {:ok, character_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

    # Get the map with ACLs
    {:ok, map} = WandererApp.Api.Map.by_id(map_id)
    map = Ash.load!(map, :acls)

    # Get characters that have access to the map using load_characters
    # This will include all characters with access, even if they're not tracked
    {:ok, %{characters: characters_with_access}} =
      WandererApp.Maps.load_characters(map, character_settings, current_user.id)

    map_characters =
      map_id
      |> WandererApp.Map.list_characters()
      |> filter_map_characters(user_character_eve_ids, user_permissions, options)
      |> Enum.map(&MapCharactersEventHandler.map_ui_character/1)

    has_tracked_characters? =
      MapCharactersEventHandler.has_tracked_characters?(user_character_eve_ids)

    socket =
      socket
      |> assign(
        map_loaded?: true,
        is_subscription_active?: Map.get(initial_data, :is_subscription_active, false),
        user_characters: user_character_eve_ids,
        has_tracked_characters?: has_tracked_characters?
      )
      |> MapEventHandler.push_map_event(
        "init",
        initial_data
        |> Map.put(:characters, map_characters)
      )
      |> push_event("js-exec", %{
        to: "#map-loader",
        attr: "data-loaded"
      })

    case not has_tracked_characters? && user_permissions.track_character do
      true ->
        socket
        |> MapCharactersEventHandler.add_character()

      _ ->
        # Check if there are any characters that are not tracked
        untracked_characters = Enum.filter(characters_with_access, fn char ->
          # Find settings for this character if they exist
          setting = Enum.find(character_settings, &(&1.character_id == char.id))
          # A character is untracked if it has no settings or tracked is false
          is_tracked = setting && setting.tracked
          is_untracked = !is_tracked

          is_untracked
        end)

        if length(untracked_characters) > 0 && user_permissions.track_character do
          # Show the Track and Follow dialog

          # Create tracking data for all user characters with access to the map
          tracking_data = Enum.map(characters_with_access, fn char ->
            # Find settings for this character if they exist
            setting = Enum.find(character_settings, &(&1.character_id == char.id))
            tracked = if setting, do: setting.tracked, else: false
            followed = if setting, do: setting.followed, else: false

            %{
              id: char.id,
              name: char.name,
              portrait_url: EVEUtil.get_portrait_url(char.eve_id, 64),
              corporation_ticker: char.corporation_ticker,
              alliance_ticker: Map.get(char, :alliance_ticker, ""),
              tracked: tracked,
              followed: followed
            }
          end)

          # Push both events directly
          socket
          |> push_event("map_event", %{
            type: "show_tracking",
            body: %{}
          })
          |> push_event("map_event", %{
            type: "tracking_characters_data",
            body: %{characters: tracking_data}
          })
          |> assign(:show_tracking, true)
        else
          socket
        end
    end
  end

  defp handle_map_start_events(socket, map_id, events) do
    events
    |> Enum.reduce(socket, fn event, socket ->
      case event do
        {:track_characters, map_characters, track_character} ->
          :ok =
            MapCharactersEventHandler.track_characters(map_characters, map_id, track_character)

          :ok = MapCharactersEventHandler.add_characters(map_characters, map_id, track_character)
          socket

        :invalid_token_message ->
          socket
          |> put_flash(
            :error,
            "One of your characters has expired token. Please refresh it on characters page."
          )

        :empty_tracked_characters ->
          socket

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
    {:ok, options} = map_id |> WandererApp.Map.get_options()
    {:ok, is_subscription_active} = map_id |> WandererApp.Map.is_subscription_active?()

    %{
      systems:
        systems
        |> Enum.map(fn system -> MapEventHandler.map_ui_system(system, include_static_data?) end),
      hubs: hubs,
      connections: connections |> Enum.map(&MapEventHandler.map_ui_connection/1),
      options: options,
      is_subscription_active: is_subscription_active
    }
  end

  defp filter_map_characters(
         characters,
         user_character_eve_ids,
         %{
           manage_map: manage_map_permission
         } = _user_permissions,
         options
       ) do
    restrict_offline_showing =
      options |> Map.get("restrict_offline_showing", "false") |> String.to_existing_atom()

    show_offline? = not restrict_offline_showing or manage_map_permission

    characters
    |> Enum.filter(fn character ->
      show_offline? || character.online ||
        user_character_eve_ids |> Enum.member?(character.eve_id)
    end)
  end
end
