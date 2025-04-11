defmodule WandererAppWeb.MapCoreEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCharactersEventHandler, MapSystemsEventHandler}

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
            :ok =
              WandererApp.Character.TrackingUtils.untrack_characters(
                map_characters,
                map_id,
                self()
              )

            :ok = WandererApp.Character.TrackingUtils.remove_characters(map_characters, map_id)

          _ ->
            :ok =
              WandererApp.Character.TrackingUtils.track_characters(
                map_characters,
                map_id,
                true,
                self()
              )

            :ok =
              WandererApp.Character.TrackingUtils.add_characters(
                map_characters,
                map_id,
                track_character
              )
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
      {:ok, %{deleted: false} = map} ->
        socket |> init_map(map)

      _ ->
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

  def handle_server_event(event, socket) do
    Logger.warning(fn -> "unhandled map core event: #{inspect(event)}" end)
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

  def handle_ui_event(
        "get_user_settings",
        _,
        %{
          assigns: %{
            map_user_settings: map_user_settings
          }
        } = socket
      ) do
    {:ok, user_settings} =
      map_user_settings
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

    {:noreply, socket |> assign(map_user_settings: user_settings)}
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

  def handle_ui_event(event, body, socket) do
    Logger.debug(fn -> "unhandled map ui event: #{inspect(event)} #{inspect(body)}" end)
    {:noreply, socket}
  end

  def handle_ui_event(
        _event,
        _body,
        %{assigns: %{has_tracked_characters?: false}} =
          socket
      ) do
    Process.send_after(self(), %{event: :show_tracking}, 10)

    {:noreply,
     socket
     |> put_flash(
       :error,
       "You should enable tracking for at least one character!"
     )}
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
           only_tracked_characters: only_tracked_characters,
           user_permissions: user_permissions,
           name: map_name,
           owner_id: owner_id
         } = map
       ) do
    with {:ok, init_data} <- setup_map_data(map, current_user, user_permissions, owner_id),
         :ok <- check_map_access(init_data, only_tracked_characters) do
      Phoenix.PubSub.subscribe(WandererApp.PubSub, map_id)
      {:ok, ui_loaded} = WandererApp.Cache.get_and_remove("map_#{map_slug}:ui_loaded", false)

      if ui_loaded do
        maybe_start_map(map_id)
      end

      socket
      |> assign(
        map_id: map_id,
        map_user_settings: init_data.map_user_settings,
        page_title: map_name,
        user_permissions: init_data.user_permissions,
        main_character_id: init_data.main_character_id,
        main_character_eve_id: init_data.main_character_eve_id,
        following_character_eve_id: init_data.following_character_eve_id,
        tracked_characters: init_data.tracked_characters,
        has_tracked_characters?: init_data.has_tracked_characters?,
        needs_tracking_setup: init_data.needs_tracking_setup,
        only_tracked_characters: only_tracked_characters
      )
    else
      {:error, :not_all_tracked} ->
        Process.send_after(self(), :not_all_characters_tracked, 10)
        socket

      _ ->
        Process.send_after(self(), :no_permissions, 10)
        socket
    end
  end

  defp setup_map_data(
         %{
           id: map_id,
           only_tracked_characters: only_tracked_characters
         } = map,
         %{
           id: current_user_id,
           characters: current_user_characters
         } = current_user,
         user_permissions,
         owner_id
       ) do
    with user_permissions <-
           WandererApp.Permissions.get_map_permissions(
             user_permissions,
             owner_id,
             current_user_characters |> Enum.map(& &1.id)
           ),
         {:ok, map_user_settings} <- WandererApp.MapUserSettingsRepo.get(map_id, current_user_id),
         {:ok, character_settings} <-
           WandererApp.Character.Activity.get_map_character_settings(map_id),
         {:ok, %{characters: available_map_characters}} =
           WandererApp.Maps.load_characters(map, character_settings, current_user_id) do
      tracked_data =
        get_tracked_data(
          available_map_characters,
          character_settings,
          user_permissions,
          only_tracked_characters
        )

      {:ok, main_character} =
        WandererApp.Character.TrackingUtils.get_main_character(
          map_user_settings,
          current_user_characters,
          available_map_characters
        )

      following_character_eve_id = case map_user_settings do
        nil -> nil
        %{following_character_eve_id: following_character_eve_id} -> following_character_eve_id
      end

      {:ok,
       %{
         user_permissions: user_permissions,
         map_user_settings: map_user_settings,
         main_character_id: main_character.id,
         main_character_eve_id: main_character.eve_id,
         following_character_eve_id: following_character_eve_id,
         tracked_characters: tracked_data.tracked_characters,
         all_character_tracked?: tracked_data.all_tracked?,
         has_tracked_characters?: tracked_data.has_tracked_characters?,
         needs_tracking_setup: tracked_data.needs_tracking_setup,
         can_view?: user_permissions.view_system,
         can_track?: user_permissions.track_character
       }}
    end
  end

  defp get_tracked_data(
         available_map_characters,
         character_settings,
         user_permissions,
         only_tracked_characters
       ) do
    tracked_characters =
      available_map_characters
      |> Enum.filter(fn char ->
        setting = Enum.find(character_settings, &(&1.character_id == char.id))
        setting != nil && setting.tracked == true
      end)

    all_tracked? =
      not Enum.empty?(available_map_characters) and
        Enum.count(available_map_characters) == Enum.count(tracked_characters)

    needs_tracking_setup =
      MapCharactersEventHandler.needs_tracking_setup?(
        only_tracked_characters,
        available_map_characters,
        character_settings,
        user_permissions
      )

    %{
      tracked_characters: tracked_characters,
      all_tracked?: all_tracked?,
      needs_tracking_setup: needs_tracking_setup,
      has_tracked_characters?: tracked_characters |> Enum.empty?() |> Kernel.not()
    }
  end

  defp check_map_access(
         %{can_view?: true, can_track?: can_track?, all_character_tracked?: all_tracked?},
         only_tracked_characters
       ) do
    cond do
      only_tracked_characters and can_track? and all_tracked? -> :ok
      not only_tracked_characters -> :ok
      only_tracked_characters and can_track? -> {:error, :not_all_tracked}
      true -> {:error, :no_permissions}
    end
  end

  defp check_map_access(_, _), do: {:error, :no_permissions}

  defp setup_map_socket(socket, map_id, map_slug, map_name, init_data, only_tracked_characters) do
  end

  defp handle_map_server_started(
         %{
           assigns: %{
             current_user: current_user,
             map_id: map_id,
             tracked_characters: tracked_characters,
             has_tracked_characters?: has_tracked_characters?,
             user_permissions:
               %{view_system: true, track_character: track_character} = user_permissions
           }
         } = socket
       ) do
    with {:ok, _} <- current_user |> WandererApp.Api.User.update_last_map(%{last_map_id: map_id}),
         {:ok, characters_limit} <- map_id |> WandererApp.Map.get_characters_limit(),
         {:ok, present_character_ids} <-
           WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", []) do
      events =
        case tracked_characters |> Enum.any?(&(&1.access_token == nil)) do
          true ->
            [:invalid_token_message]

          _ ->
            []
        end

      events =
        case not has_tracked_characters? do
          true ->
            events ++ [:empty_tracked_characters]

          _ ->
            events
        end

      events =
        case present_character_ids |> Enum.count() < characters_limit do
          true ->
            events ++ [{:track_characters, tracked_characters, track_character}]

          _ ->
            events ++ [:map_character_limit]
        end

      initial_data =
        %{
          kills: nil,
          present_characters:
            present_character_ids
            |> WandererApp.Character.get_character_eve_ids!(),
          user_characters: tracked_characters |> Enum.map(& &1.eve_id),
          system_static_infos: nil,
          wormhole_types: nil,
          effects: nil,
          reset: false
        }

      socket
      |> map_start(
        %{
          map_id: map_id,
          initial_data: initial_data,
          events: events
        },
        user_permissions
      )
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
         %{
           assigns: %{
             needs_tracking_setup: needs_tracking_setup,
             main_character_eve_id: main_character_eve_id,
             following_character_eve_id: following_character_eve_id
           }
         } = socket,
         %{
           map_id: map_id,
           initial_data: initial_data,
           events: events
         } = _started_data,
         user_permissions
       ) do
    socket =
      socket
      |> MapCharactersEventHandler.handle_tracking_events(map_id, events)

    {:ok, options} =
      map_id
      |> WandererApp.Map.get_options()

    map_characters =
      map_id
      |> WandererApp.Map.list_characters()
      |> filter_map_characters(initial_data.user_characters, user_permissions, options)
      |> Enum.map(&MapCharactersEventHandler.map_ui_character/1)

    {:ok, is_subscription_active} = map_id |> WandererApp.Map.is_subscription_active?()

    map_data =
      map_id
      |> get_map_data()

    socket =
      socket
      |> assign(
        map_loaded?: true,
        is_subscription_active?: is_subscription_active
      )
      |> MapEventHandler.push_map_event(
        "init",
        initial_data
        |> Map.merge(map_data)
        |> Map.merge(%{
          main_character_eve_id: main_character_eve_id,
          following_character_eve_id: following_character_eve_id,
          is_subscription_active: is_subscription_active,
          user_permissions: user_permissions,
          characters: map_characters,
          options: options,
          wormholes: WandererApp.CachedInfo.get_wormhole_types!(),
          effects: WandererApp.CachedInfo.get_effects!(),
          reset: true
        })
      )
      |> push_event("js-exec", %{
        to: "#map-loader",
        attr: "data-loaded"
      })

    Process.send_after(self(), %{event: :init_kills}, 100)

    if needs_tracking_setup do
      Process.send_after(self(), %{event: :show_tracking}, 10)

      socket
    else
      socket
    end
  end

  defp get_map_data(map_id) do
    {:ok, hubs} = map_id |> WandererApp.Map.list_hubs()
    {:ok, connections} = map_id |> WandererApp.Map.list_connections()
    {:ok, systems} = map_id |> WandererApp.Map.list_systems()

    system_static_infos =
      systems
      |> Enum.map(&WandererApp.CachedInfo.get_system_static_info!(&1.solar_system_id))

    %{
      systems:
        systems
        |> Enum.map(fn system -> MapEventHandler.map_ui_system(system, false) end),
      system_static_infos:
        system_static_infos |> Enum.map(&MapEventHandler.map_ui_system_static_info/1),
      hubs: hubs,
      connections: connections |> Enum.map(&MapEventHandler.map_ui_connection/1)
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
