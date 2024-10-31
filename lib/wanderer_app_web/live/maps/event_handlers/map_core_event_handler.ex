defmodule WandererAppWeb.MapCoreEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.MapEventHandler

  def handle_server_event(
        %{
          event: :character_activity,
          payload: character_activity
        },
        socket
      ),
      do: socket |> assign(:character_activity, character_activity)

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

        case track_character do
          false ->
            :ok = untrack_characters(map_characters, map_id)
            :ok = remove_characters(map_characters, map_id)

          _ ->
            :ok = track_characters(map_characters, map_id, true)
            :ok = add_characters(map_characters, map_id, track_character)
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

  def handle_server_event(%{event: :add_system, payload: system}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("add_systems", [map_ui_system(system)])

  def handle_server_event(%{event: :update_system, payload: system}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("update_systems", [map_ui_system(system)])

  def handle_server_event(%{event: :update_connection, payload: connection}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("update_connection", map_ui_connection(connection))

  def handle_server_event(%{event: :systems_removed, payload: solar_system_ids}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("remove_systems", solar_system_ids)

  def handle_server_event(%{event: :remove_connections, payload: connections}, socket) do
    connection_ids = connections |> Enum.map(&map_ui_connection/1) |> Enum.map(& &1.id)

    socket
    |> MapEventHandler.push_map_event(
      "remove_connections",
      connection_ids
    )
  end

  def handle_server_event(%{event: :add_connection, payload: connection}, socket) do
    connections = [map_ui_connection(connection)]

    socket
    |> MapEventHandler.push_map_event(
      "add_connections",
      connections
    )
  end

  def handle_server_event(
        %{
          event: :maybe_select_system,
          payload: %{
            character_id: character_id,
            solar_system_id: solar_system_id
          }
        },
        %{assigns: %{current_user: current_user, map_user_settings: map_user_settings}} = socket
      ) do
    is_user_character =
      current_user.characters |> Enum.map(& &1.id) |> Enum.member?(character_id)

    is_select_on_spash =
      map_user_settings
      |> WandererApp.MapUserSettingsRepo.to_form_data!()
      |> WandererApp.MapUserSettingsRepo.get_boolean_setting("select_on_spash")

    (is_user_character && is_select_on_spash)
    |> case do
      true ->
        socket
        |> MapEventHandler.push_map_event("select_system", solar_system_id)

      false ->
        socket
    end
  end

  def handle_server_event(%{event: :update_map, payload: map_diff}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event(
        "map_updated",
        map_diff
      )

  def handle_server_event(%{event: :kills_updated, payload: kills}, socket) do
    kills =
      kills
      |> Enum.map(&map_ui_kill/1)

    socket
    |> MapEventHandler.push_map_event(
      "kills_updated",
      kills
    )
  end

  def handle_server_event(
        %{event: :characters_updated},
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    characters =
      map_id
      |> WandererApp.Map.list_characters()
      |> Enum.map(&map_ui_character/1)

    socket
    |> MapEventHandler.push_map_event(
      "characters_updated",
      characters
    )
  end

  def handle_server_event(%{event: :character_added, payload: character}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "character_added",
      character |> map_ui_character()
    )
  end

  def handle_server_event(%{event: :character_removed, payload: character}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "character_removed",
      character |> map_ui_character()
    )
  end

  def handle_server_event(%{event: :character_updated, payload: character}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "character_updated",
      character |> map_ui_character()
    )
  end

  def handle_server_event(
        %{event: :present_characters_updated, payload: present_character_eve_ids},
        socket
      ),
      do:
        socket
        |> MapEventHandler.push_map_event(
          "present_characters",
          present_character_eve_ids
        )

  def handle_server_event(event, socket) do
    Logger.warning(fn -> "unhandled map core event: #{inspect(event)}" end)
    socket
  end

  def handle_ui_event("ui_loaded", _body, %{assigns: %{map_slug: map_slug} = assigns} = socket) do
    assigns
    |> Map.get(:map_id)
    |> case do
      map_id when not is_nil(map_id) ->
        maybe_start_map(map_id)

      _ ->
        WandererApp.Cache.insert("map_#{map_slug}:ui_loaded", true)
    end

    {:noreply, socket}
  end

  def handle_ui_event(
        "manual_add_system",
        %{"coordinates" => coordinates} = _event,
        %{
          assigns: %{
            has_tracked_characters?: true,
            map_slug: map_slug,
            user_permissions: %{add_system: true}
          }
        } =
          socket
      ),
      do:
        {:noreply,
         socket
         |> assign(coordinates: coordinates)
         |> push_patch(to: ~p"/#{map_slug}/add-system")}

  def handle_ui_event(
        "manual_add_connection",
        %{"source" => solar_system_source_id, "target" => solar_system_target_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{add_connection: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.add_connection(%{
      solar_system_source_id: solar_system_source_id |> String.to_integer(),
      solar_system_target_id: solar_system_target_id |> String.to_integer()
    })

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:map_connection_added, %{
        character_id: tracked_character_ids |> List.first(),
        user_id: current_user.id,
        map_id: map_id,
        solar_system_source_id: "#{solar_system_source_id}" |> String.to_integer(),
        solar_system_target_id: "#{solar_system_target_id}" |> String.to_integer()
      })

    {:noreply, socket}
  end

  def handle_ui_event(
        "add_hub",
        %{"system_id" => solar_system_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.add_hub(%{
      solar_system_id: solar_system_id
    })

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:hub_added, %{
        character_id: tracked_character_ids |> List.first(),
        user_id: current_user.id,
        map_id: map_id,
        solar_system_id: solar_system_id
      })

    {:noreply, socket}
  end

  def handle_ui_event(
        "delete_hub",
        %{"system_id" => solar_system_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.remove_hub(%{
      solar_system_id: solar_system_id
    })

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:hub_removed, %{
        character_id: tracked_character_ids |> List.first(),
        user_id: current_user.id,
        map_id: map_id,
        solar_system_id: solar_system_id
      })

    {:noreply, socket}
  end

  def handle_ui_event(
        "update_system_" <> param,
        %{"system_id" => solar_system_id, "value" => value} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      ) do
    method_atom =
      case param do
        "name" -> :update_system_name
        "description" -> :update_system_description
        "labels" -> :update_system_labels
        "locked" -> :update_system_locked
        "tag" -> :update_system_tag
        "status" -> :update_system_status
        _ -> nil
      end

    key_atom =
      case param do
        "name" -> :name
        "description" -> :description
        "labels" -> :labels
        "locked" -> :locked
        "tag" -> :tag
        "status" -> :status
        _ -> :none
      end

    apply(WandererApp.Map.Server, method_atom, [
      map_id,
      %{
        solar_system_id: "#{solar_system_id}" |> String.to_integer()
      }
      |> Map.put_new(key_atom, value)
    ])

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:system_updated, %{
        character_id: tracked_character_ids |> List.first(),
        user_id: current_user.id,
        map_id: map_id,
        solar_system_id: "#{solar_system_id}" |> String.to_integer(),
        key: key_atom,
        value: value
      })

    {:noreply, socket}
  end

  def handle_ui_event(
        "update_connection_" <> param,
        %{
          "source" => solar_system_source_id,
          "target" => solar_system_target_id,
          "value" => value
        } = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      ) do
    method_atom =
      case param do
        "time_status" -> :update_connection_time_status
        "mass_status" -> :update_connection_mass_status
        "ship_size_type" -> :update_connection_ship_size_type
        "locked" -> :update_connection_locked
        "custom_info" -> :update_connection_custom_info
        _ -> nil
      end

    key_atom =
      case param do
        "time_status" -> :time_status
        "mass_status" -> :mass_status
        "ship_size_type" -> :ship_size_type
        "locked" -> :locked
        "custom_info" -> :custom_info
        _ -> nil
      end

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:map_connection_updated, %{
        character_id: tracked_character_ids |> List.first(),
        user_id: current_user.id,
        map_id: map_id,
        solar_system_source_id: "#{solar_system_source_id}" |> String.to_integer(),
        solar_system_target_id: "#{solar_system_target_id}" |> String.to_integer(),
        key: key_atom,
        value: value
      })

    apply(WandererApp.Map.Server, method_atom, [
      map_id,
      %{
        solar_system_source_id: "#{solar_system_source_id}" |> String.to_integer(),
        solar_system_target_id: "#{solar_system_target_id}" |> String.to_integer()
      }
      |> Map.put_new(key_atom, value)
    ])

    {:noreply, socket}
  end

  def handle_ui_event(
        "get_system_static_infos",
        %{"solar_system_ids" => solar_system_ids} = _event,
        socket
      ) do
    system_static_infos =
      solar_system_ids
      |> Enum.map(&WandererApp.CachedInfo.get_system_static_info!/1)
      |> Enum.map(&map_ui_system_static_info/1)

    {:reply, %{system_static_infos: system_static_infos}, socket}
  end

  def handle_ui_event(
        "add_system",
        %{"system_id" => solar_system_id} = _event,
        %{
          assigns:
            %{
              map_id: map_id,
              map_slug: map_slug,
              current_user: current_user,
              tracked_character_ids: tracked_character_ids,
              user_permissions: %{add_system: true}
            } = assigns
        } = socket
      )
      when is_binary(solar_system_id) and solar_system_id != "" do
    coordinates = Map.get(assigns, :coordinates)

    WandererApp.Map.Server.add_system(
      map_id,
      %{
        solar_system_id: solar_system_id |> String.to_integer(),
        coordinates: coordinates
      },
      current_user.id,
      tracked_character_ids |> List.first()
    )

    {:noreply,
     socket
     |> push_patch(to: ~p"/#{map_slug}")}
  end

  def handle_ui_event("get_passages", %{"from" => from, "to" => to} = _event, socket) do
    {:ok, passages} = socket |> map_id() |> get_connection_passages(from, to)

    {:reply, passages, socket}
  end

  def handle_ui_event(
        "update_system_position",
        position,
        %{
          assigns: %{
            map_id: map_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } = socket
      ) do
    map_id
    |> update_system_position(position)

    {:noreply, socket}
  end

  def handle_ui_event(
        "update_system_positions",
        positions,
        %{
          assigns: %{
            map_id: map_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } = socket
      ) do
    map_id
    |> update_system_positions(positions)

    {:noreply, socket}
  end

  def handle_ui_event(
        "delete_systems",
        solar_system_ids,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{delete_system: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.delete_systems(
      solar_system_ids |> Enum.map(&String.to_integer/1),
      current_user.id,
      tracked_character_ids |> List.first()
    )

    {:noreply, socket}
  end

  def handle_ui_event(
        "manual_delete_connection",
        %{"source" => solar_system_source_id, "target" => solar_system_target_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{delete_connection: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.delete_connection(%{
      solar_system_source_id: solar_system_source_id |> String.to_integer(),
      solar_system_target_id: solar_system_target_id |> String.to_integer()
    })

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:map_connection_removed, %{
        character_id: tracked_character_ids |> List.first(),
        user_id: current_user.id,
        map_id: map_id,
        solar_system_source_id: "#{solar_system_source_id}" |> String.to_integer(),
        solar_system_target_id: "#{solar_system_target_id}" |> String.to_integer()
      })

    {:noreply, socket}
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
      |> Enum.map(&map_system/1)

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  def handle_ui_event(
        "add_character",
        _,
        %{
          assigns: %{
            current_user: current_user,
            map_id: map_id,
            user_permissions: %{track_character: true}
          }
        } = socket
      ) do
    {:ok, character_settings} =
      case WandererApp.Api.MapCharacterSettings.read_by_map(%{map_id: map_id}) do
        {:ok, settings} -> {:ok, settings}
        _ -> {:ok, []}
      end

    {:noreply,
     socket
     |> assign(
       show_tracking?: true,
       character_settings: character_settings
     )
     |> assign_async(:characters, fn ->
       {:ok, map} =
         map_id
         |> WandererApp.MapRepo.get([:acls])

       map
       |> WandererApp.Maps.load_characters(
         character_settings,
         current_user.id
       )
     end)}
  end

  def handle_ui_event(
        "add_character",
        _,
        %{
          assigns: %{
            user_permissions: %{track_character: false}
          }
        } = socket
      ),
      do:
        {:noreply,
         socket
         |> put_flash(
           :error,
           "You don't have permissions to track characters. Please contact administrator."
         )}

  def handle_ui_event("toggle_track_" <> character_id, _, socket) do
    handle_ui_event("toggle_track", %{"character-id" => character_id}, socket)
  end

  def handle_ui_event(
        "toggle_track",
        %{"character-id" => character_id},
        %{
          assigns: %{
            map_id: map_id,
            map_slug: map_slug,
            character_settings: character_settings,
            current_user: current_user,
            only_tracked_characters: only_tracked_characters
          }
        } = socket
      ) do
    socket =
      case character_settings |> Enum.find(&(&1.character_id == character_id)) do
        nil ->
          {:ok, map_character_settings} =
            WandererApp.Api.MapCharacterSettings.create(%{
              character_id: character_id,
              map_id: map_id,
              tracked: true
            })

          character = map_character_settings |> Ash.load!(:character) |> Map.get(:character)

          :ok = track_characters([character], map_id, true)
          :ok = add_characters([character], map_id, true)

          socket

        character_setting ->
          case character_setting.tracked do
            true ->
              {:ok, map_character_settings} =
                character_setting
                |> WandererApp.Api.MapCharacterSettings.untrack()

              character = map_character_settings |> Ash.load!(:character) |> Map.get(:character)

              :ok = untrack_characters([character], map_id)
              :ok = remove_characters([character], map_id)

              if only_tracked_characters do
                Process.send_after(self(), :not_all_characters_tracked, 10)
              end

              socket

            _ ->
              {:ok, map_character_settings} =
                character_setting
                |> WandererApp.Api.MapCharacterSettings.track()

              character = map_character_settings |> Ash.load!(:character) |> Map.get(:character)

              :ok = track_characters([character], map_id, true)
              :ok = add_characters([character], map_id, true)

              socket
          end
      end

    %{result: characters} = socket.assigns.characters

    {:ok, map_characters} = get_tracked_map_characters(map_id, current_user)

    user_character_eve_ids = map_characters |> Enum.map(& &1.eve_id)

    {:ok, character_settings} =
      case WandererApp.Api.MapCharacterSettings.read_by_map(%{map_id: map_id}) do
        {:ok, settings} -> {:ok, settings}
        _ -> {:ok, []}
      end

    characters =
      characters
      |> Enum.map(fn c ->
        WandererApp.Maps.map_character(
          c,
          character_settings |> Enum.find(&(&1.character_id == c.id))
        )
      end)

    {:noreply,
     socket
     |> assign(user_characters: user_character_eve_ids)
     |> assign(has_tracked_characters?: has_tracked_characters?(user_character_eve_ids))
     |> assign(character_settings: character_settings)
     |> assign_async(:characters, fn ->
       {:ok, %{characters: characters}}
     end)
     |> push_map_event(
       "init",
       %{
         user_characters: user_character_eve_ids,
         reset: false
       }
     )}
  end

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
         {:ok, map_user_settings} <- WandererApp.MapUserSettingsRepo.get(map_id, current_user.id),
         {:ok, tracked_map_characters} <- get_tracked_map_characters(map_id, current_user),
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
            |> Enum.map(&map_ui_kill/1),
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
        |> Enum.map(&map_ui_system_static_info/1)

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
        map_user_settings: map_user_settings,
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
