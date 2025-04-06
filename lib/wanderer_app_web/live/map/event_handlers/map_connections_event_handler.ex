defmodule WandererAppWeb.MapConnectionsEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(%{event: :update_connection, payload: connection}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event(
        "update_connection",
        MapEventHandler.map_ui_connection(connection)
      )

  def handle_server_event(%{event: :remove_connections, payload: connections}, socket) do
    connection_ids =
      connections |> Enum.map(&MapEventHandler.map_ui_connection/1) |> Enum.map(& &1.id)

    socket
    |> MapEventHandler.push_map_event(
      "remove_connections",
      connection_ids
    )
  end

  def handle_server_event(%{event: :add_connection, payload: connection}, socket) do
    connections = [MapEventHandler.map_ui_connection(connection)]

    socket
    |> MapEventHandler.push_map_event(
      "add_connections",
      connections
    )
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "manual_add_connection",
        %{"source" => solar_system_source_id, "target" => solar_system_target_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: %{id: current_user_id},
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{add_connection: true}
          }
        } =
          socket
      ) do
    map_id
    |> WandererApp.Map.Server.add_connection(%{
      solar_system_source_id: solar_system_source_id |> String.to_integer(),
      solar_system_target_id: solar_system_target_id |> String.to_integer(),
      character_id: main_character_id
    })

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:map_connection_added, %{
        character_id: main_character_id,
        user_id: current_user_id,
        map_id: map_id,
        solar_system_source_id: "#{solar_system_source_id}" |> String.to_integer(),
        solar_system_target_id: "#{solar_system_target_id}" |> String.to_integer()
      })

    {:noreply, socket}
  end

  def handle_ui_event(
        "manual_delete_connection",
        %{"source" => solar_system_source_id, "target" => solar_system_target_id} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: %{id: current_user_id},
            main_character_id: main_character_id,
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
        character_id: main_character_id,
        user_id: current_user_id,
        map_id: map_id,
        solar_system_source_id: "#{solar_system_source_id}" |> String.to_integer(),
        solar_system_target_id: "#{solar_system_target_id}" |> String.to_integer()
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
            current_user: %{id: current_user_id},
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      ) do
    method_atom =
      case param do
        "time_status" -> :update_connection_time_status
        "type" -> :update_connection_type
        "mass_status" -> :update_connection_mass_status
        "ship_size_type" -> :update_connection_ship_size_type
        "locked" -> :update_connection_locked
        "custom_info" -> :update_connection_custom_info
        _ -> nil
      end

    key_atom =
      case param do
        "time_status" -> :time_status
        "type" -> :type
        "mass_status" -> :mass_status
        "ship_size_type" -> :ship_size_type
        "locked" -> :locked
        "custom_info" -> :custom_info
        _ -> nil
      end

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:map_connection_updated, %{
        character_id: main_character_id,
        user_id: current_user_id,
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
        "get_connection_info",
        %{"from" => from, "to" => to} = _event,
        %{assigns: %{map_id: map_id}} = socket
      ) do
    {:ok, info} = map_id |> get_connection_info(from, to)

    {:reply, info, socket}
  end

  def handle_ui_event(
        "get_passages",
        %{"from" => from, "to" => to} = _event,
        %{assigns: %{map_id: map_id}} = socket
      ) do
    {:ok, passages} = map_id |> get_connection_passages(from, to)

    {:reply, passages, socket}
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  defp get_connection_passages(map_id, from, to) do
    {:ok, passages} = WandererApp.MapChainPassagesRepo.by_connection(map_id, from, to)

    passages =
      passages
      |> Enum.map(fn p ->
        %{
          p
          | character: p.character |> MapEventHandler.map_ui_character_stat()
        }
        |> Map.put_new(
          :ship,
          WandererApp.Character.get_ship(%{ship: p.ship_type_id, ship_name: p.ship_name})
        )
        |> Map.drop([:ship_type_id, :ship_name])
      end)

    {:ok, %{passages: passages}}
  end

  defp get_connection_info(map_id, from, to) do
    map_id
    |> WandererApp.Map.Server.get_connection_info(%{
      solar_system_source_id: "#{from}" |> String.to_integer(),
      solar_system_target_id: "#{to}" |> String.to_integer()
    })
    |> case do
      {:ok, info} ->
        {:ok, info}

      _ ->
        {:ok, %{}}
    end
  end
end
