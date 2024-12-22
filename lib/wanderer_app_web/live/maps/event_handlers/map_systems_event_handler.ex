defmodule WandererAppWeb.MapSystemsEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(%{event: :add_system, payload: system}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("add_systems", [MapEventHandler.map_ui_system(system)])

  def handle_server_event(%{event: :update_system, payload: system}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("update_systems", [MapEventHandler.map_ui_system(system)])

  def handle_server_event(%{event: :systems_removed, payload: solar_system_ids}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("remove_systems", solar_system_ids)

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

  def handle_server_event(%{event: :kills_updated, payload: kills}, socket) do
    kills =
      kills
      |> Enum.map(&MapEventHandler.map_ui_kill/1)

    socket
    |> MapEventHandler.push_map_event(
      "kills_updated",
      kills
    )
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "add_system",
        %{"system_id" => [solar_system_id]} = _event,
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

  def handle_ui_event(
        "manual_add_system",
        %{"solar_system_id" => solar_system_id, "coordinates" => coordinates} = _event,
        %{
          assigns: %{
            current_user: current_user,
            has_tracked_characters?: true,
            map_id: map_id,
            tracked_character_ids: tracked_character_ids,
            user_permissions: %{add_system: true}
          }
        } =
          socket
      )
      when is_binary(solar_system_id) do
    WandererApp.Map.Server.add_system(
      map_id,
      %{
        solar_system_id: solar_system_id,
        coordinates: coordinates
      },
      current_user.id,
      tracked_character_ids |> List.first()
    )

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
        "update_system_" <> param,
        %{"system_id" => solar_system_id, "value" => value} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            tracked_character_ids: tracked_character_ids,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true} = user_permissions
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

    if can_update_system?(key_atom, user_permissions) do
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
    end

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
      |> Enum.map(&MapEventHandler.map_ui_system_static_info/1)

    {:reply, %{system_static_infos: system_static_infos}, socket}
  end

  def handle_ui_event(
        "search_systems",
        %{"text" => text} = _event,
        socket
      ) do
    systems =
      WandererApp.Api.MapSolarSystem.find_by_name!(%{name: text})
      |> Enum.take(100)
      |> Enum.map(&map_system/1)

    {:reply, %{systems: systems}, socket}
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

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  def map_system(
        %{
          solar_system_name: solar_system_name,
          constellation_name: constellation_name,
          region_name: region_name,
          solar_system_id: solar_system_id,
          class_title: class_title
        } = _system
      ) do
    system_static_info = MapEventHandler.get_system_static_info(solar_system_id)

    %{
      label: solar_system_name,
      value: solar_system_id,
      constellation_name: constellation_name,
      region_name: region_name,
      class_title: class_title,
      system_static_info: system_static_info
    }
  end

  defp can_update_system?(:locked, %{lock_system: false} = _user_permissions), do: false
  defp can_update_system?(_key, _user_permissions), do: true

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
end
