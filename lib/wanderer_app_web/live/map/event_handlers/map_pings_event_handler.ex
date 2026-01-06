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
    |> Enum.filter(fn ping ->
      # Skip pings where system or character associations are nil (deleted)
      not is_nil(ping.system) and not is_nil(ping.character)
    end)
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

  def handle_server_event(%{event: :ping_cancelled, payload: ping_info}, socket) do
    Logger.debug(
      "handle_server_event :ping_cancelled - id: #{ping_info.id}, is_version_valid?: #{inspect(socket.assigns[:is_version_valid?])}"
    )

    socket
    |> MapEventHandler.push_map_event("ping_cancelled", %{
      id: ping_info.id,
      solar_system_id: ping_info.solar_system_id,
      type: ping_info.type
    })
  end

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

    # Filter out orphaned pings (system/character deleted or system hidden)
    # These should not block new ping creation
    valid_pings =
      pings
      |> Enum.filter(fn ping ->
        not is_nil(ping.system) and not is_nil(ping.character) and
          (is_nil(ping.system.visible) or ping.system.visible == true)
      end)

    existing_rally_pings =
      valid_pings
      |> Enum.filter(fn %{type: type} ->
        type == 1
      end)

    no_exisiting_pings = Enum.empty?(existing_rally_pings)
    orphaned_count = length(pings) - length(valid_pings)

    # Log detailed info about existing pings for debugging
    if length(existing_rally_pings) > 0 do
      ping_details =
        existing_rally_pings
        |> Enum.map(fn p ->
          "id=#{p.id}, type=#{p.type}, system_id=#{inspect(p.system_id)}, character_id=#{inspect(p.character_id)}, inserted_at=#{p.inserted_at}"
        end)
        |> Enum.join("; ")

      Logger.warning(
        "add_ping BLOCKED: map_id=#{map_id}, existing_rally_pings=#{length(existing_rally_pings)}: [#{ping_details}]"
      )
    else
      Logger.debug(
        "add_ping check: map_id=#{map_id}, total_pings=#{length(pings)}, valid_pings=#{length(valid_pings)}, orphaned=#{orphaned_count}, rally_pings=0, can_create=true"
      )
    end

    if no_exisiting_pings do
      map_id
      |> WandererApp.Map.Server.add_ping(%{
        solar_system_id: solar_system_id,
        message: message,
        type: type,
        character_id: main_character_id,
        user_id: current_user.id
      })

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> MapEventHandler.push_map_event("ping_blocked", %{
         reason: "rally_point_exists",
         message: "A rally point already exists on this map"
       })}
    end
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

  # Catch add_ping when main_character_id is nil
  def handle_ui_event(
        "add_ping",
        _event,
        %{assigns: %{main_character_id: nil}} = socket
      ) do
    {:noreply,
     socket
     |> MapEventHandler.push_map_event("ping_blocked", %{
       reason: "no_main_character",
       message: "Please select a main character to create pings"
     })}
  end

  # Catch add_ping when has_tracked_characters? is false
  def handle_ui_event(
        "add_ping",
        _event,
        %{assigns: %{has_tracked_characters?: false}} = socket
      ) do
    {:noreply,
     socket
     |> MapEventHandler.push_map_event("ping_blocked", %{
       reason: "no_tracked_characters",
       message: "Please add a tracked character to create pings"
     })}
  end

  # Catch add_ping when subscription is not active
  def handle_ui_event(
        "add_ping",
        _event,
        %{assigns: %{is_subscription_active?: false}} = socket
      ) do
    {:noreply,
     socket
     |> MapEventHandler.push_map_event("ping_blocked", %{
       reason: "subscription_inactive",
       message: "Map subscription is not active"
     })}
  end

  # Catch add_ping when user doesn't have update_system permission
  def handle_ui_event(
        "add_ping",
        _event,
        %{assigns: %{user_permissions: %{update_system: false}}} = socket
      ) do
    {:noreply,
     socket
     |> MapEventHandler.push_map_event("ping_blocked", %{
       reason: "no_permission",
       message: "You don't have permission to create pings on this map"
     })}
  end

  # Catch cancel_ping failures with feedback
  def handle_ui_event(
        "cancel_ping",
        _event,
        %{assigns: %{main_character_id: nil}} = socket
      ) do
    {:noreply, socket}
  end

  # Catch-all for cancel_ping to debug why it doesn't match
  def handle_ui_event(
        "cancel_ping",
        event,
        %{assigns: assigns} = socket
      ) do
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
