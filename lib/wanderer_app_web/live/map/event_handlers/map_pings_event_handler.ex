defmodule WandererAppWeb.MapPingsEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(
        %{event: :load_map_pings},
        %{
          assigns: %{
            map_id: map_id,
            user_permissions: %{update_system: true}
          }
        } = socket
      ) do
    {:ok, pings} = WandererApp.MapPingsRepo.get_by_map(map_id)

    pings
    |> Enum.reduce(socket, fn %{
                                id: id,
                                type: type,
                                message: message,
                                system: system,
                                character: character,
                                inserted_at: inserted_at
                              } = _ping,
                              socket ->
      socket
      |> MapEventHandler.push_map_event("ping_added", [
        map_ui_ping(%{
          id: id,
          inserted_at: inserted_at,
          character_eve_id: character.eve_id,
          solar_system_id: "#{system.solar_system_id}",
          message: message,
          type: type
        })
      ])
    end)
  end

  def handle_server_event(%{event: :ping_added, payload: ping_info}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("ping_added", [
        map_ui_ping(ping_info)
      ])

  def handle_server_event(%{event: :ping_cancelled, payload: ping_info}, socket),
    do:
      socket
      |> MapEventHandler.push_map_event("ping_cancelled", %{
        id: ping_info.id,
        solar_system_id: ping_info.solar_system_id,
        type: ping_info.type
      })

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "add_ping",
        %{"solar_system_id" => solar_system_id, "message" => message, "type" => type} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            is_subscription_active?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    {:ok, pings} = WandererApp.MapPingsRepo.get_by_map(map_id)

    no_exisiting_pings =
      pings
      |> Enum.filter(fn %{type: type} ->
        type == 1
      end)
      |> Enum.empty?()

    if no_exisiting_pings do
      map_id
      |> WandererApp.Map.Server.add_ping(%{
        solar_system_id: solar_system_id,
        message: message,
        type: type,
        character_id: main_character_id,
        user_id: current_user.id
      })
    end

    {:noreply, socket}
  end

  def handle_ui_event(
        "cancel_ping",
        %{"id" => id, "type" => type} = _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } =
          socket
      )
      when not is_nil(main_character_id) do
    map_id
    |> WandererApp.Map.Server.cancel_ping(%{
      id: id,
      type: type,
      character_id: main_character_id,
      user_id: current_user.id
    })

    {:noreply, socket}
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  def map_ui_ping(
        %{
          id: id,
          inserted_at: inserted_at,
          character_eve_id: character_eve_id,
          solar_system_id: solar_system_id,
          message: message,
          type: type
        } = _ping
      ) do
    %{
      id: id,
      inserted_at: inserted_at,
      character_eve_id: character_eve_id,
      solar_system_id: solar_system_id,
      message: message,
      type: type
    }
  end
end
