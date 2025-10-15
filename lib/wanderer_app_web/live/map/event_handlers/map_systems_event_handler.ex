defmodule WandererAppWeb.MapSystemsEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(%{event: :add_system, payload: system}, socket) do
    # Schedule kill update for the new system after a short delay to allow subscription
    Process.send_after(
      self(),
      %{event: :update_system_kills, payload: system.solar_system_id},
      2000
    )

    socket
    |> MapEventHandler.push_map_event("add_systems", [
      MapEventHandler.map_ui_system(system)
    ])
  end

  def handle_server_event(%{event: :update_system, payload: system}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("update_systems", [
        MapEventHandler.map_ui_system(system, false)
      ])

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
        %{
          assigns: %{
            current_user: current_user,
            tracked_characters: tracked_characters,
            map_id: map_id,
            map_user_settings: map_user_settings,
            main_character_eve_id: main_character_eve_id,
            following_character_eve_id: following_character_eve_id
          }
        } = socket
      ) do
    character =
      if is_nil(character_id) do
        tracked_characters
        |> Enum.find(fn tracked_character ->
          tracked_character.eve_id == (following_character_eve_id || main_character_eve_id)
        end)
      else
        tracked_characters
        |> Enum.find(fn tracked_character -> tracked_character.id == character_id end)
      end

    is_user_character = not is_nil(character)

    is_select_on_spash =
      map_user_settings
      |> WandererApp.MapUserSettingsRepo.to_form_data!()
      |> WandererApp.MapUserSettingsRepo.get_boolean_setting("select_on_spash")

    is_following =
      case is_user_character && not is_nil(following_character_eve_id) do
        true ->
          following_character_eve_id == character.eve_id

        _ ->
          false
      end

    must_select? = is_user_character && (is_select_on_spash || is_following)

    if not must_select? do
      socket
    else
      # Always select the system when auto-select is enabled (following or select_on_spash).
      # The frontend will handle deselecting other systems
      #
      select_solar_system_id =
        if not is_nil(solar_system_id) do
          "#{solar_system_id}"
        else
          {:ok, character} = WandererApp.Character.get_map_character(map_id, character.id)
          "#{character.solar_system_id}"
        end

      socket
      |> MapEventHandler.push_map_event("select_system", select_solar_system_id)
    end
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "manual_add_system",
        %{"solar_system_id" => solar_system_id, "coordinates" => coordinates} = _event,
        %{
          assigns: %{
            current_user: current_user,
            has_tracked_characters?: true,
            map_id: map_id,
            main_character_id: main_character_id,
            user_permissions: %{add_system: true}
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    WandererApp.Map.Server.add_system(
      map_id,
      %{
        solar_system_id: solar_system_id,
        coordinates: coordinates
      },
      current_user.id,
      main_character_id
    )

    {:noreply, socket}
  end

  def handle_ui_event(
        "manual_paste_systems_and_connections",
        %{
          "connections" => connections,
          "systems" => systems
        } = _event,
        %{
          assigns: %{
            current_user: current_user,
            has_tracked_characters?: true,
            map_id: map_id,
            main_character_id: main_character_id,
            user_permissions: %{add_system: true}
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    WandererApp.Map.Server.paste_systems(
      map_id,
      systems,
      current_user.id,
      main_character_id
    )

    WandererApp.Map.Server.paste_connections(
      map_id,
      connections,
      current_user.id,
      main_character_id
    )

    {:noreply, socket}
  end

  def handle_ui_event(
        "update_system_position",
        position,
        %{
          assigns: %{
            map_id: map_id,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } = socket
      )
      when not is_nil(main_character_id) do
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
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } = socket
      )
      when not is_nil(main_character_id) do
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
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true} = user_permissions
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    method_atom =
      case param do
        "name" -> :update_system_name
        "description" -> :update_system_description
        "labels" -> :update_system_labels
        "locked" -> :update_system_locked
        "tag" -> :update_system_tag
        "temporary_name" -> :update_system_temporary_name
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
        "temporary_name" -> :temporary_name
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
          character_id: main_character_id,
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
      |> Enum.filter(fn system ->
        not is_nil(system) && not is_nil(system.system_static_info) &&
          not WandererApp.Map.Server.ConnectionsImpl.is_prohibited_system_class?(
            system.system_static_info.system_class
          )
      end)

    {:reply, %{systems: systems}, socket}
  end

  def handle_ui_event(
        "delete_systems",
        solar_system_ids,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{delete_system: true}
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    map_id
    |> WandererApp.Map.Server.delete_systems(
      solar_system_ids |> Enum.map(&String.to_integer/1),
      current_user.id,
      main_character_id
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
       })
       when not is_nil(x) and not is_nil(y) and not is_nil(solar_system_id),
       do:
         map_id
         |> WandererApp.Map.Server.update_system_position(%{
           solar_system_id: solar_system_id |> String.to_integer(),
           position_x: x,
           position_y: y
         })

  defp update_system_position(_map_id, _position), do: :ok
end
