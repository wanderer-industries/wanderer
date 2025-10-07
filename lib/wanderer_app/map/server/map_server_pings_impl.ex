defmodule WandererApp.Map.Server.PingsImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.Server.Impl

  @ping_auto_expire_timeout :timer.minutes(15)

  def add_ping(
        %{map_id: map_id} = state,
        %{
          solar_system_id: solar_system_id,
          type: type,
          message: message,
          character_id: character_id,
          user_id: user_id
        } = ping_info
      ) do
    with {:ok, character} <- WandererApp.Character.get_character(character_id),
         system <-
           WandererApp.Map.find_system_by_location(map_id, %{
             solar_system_id: solar_system_id |> String.to_integer()
           }),
         {:ok, ping} <-
           WandererApp.MapPingsRepo.create(%{
             map_id: map_id,
             character_id: character_id,
             system_id: system.id,
             message: message,
             type: type
           }) do
      Impl.broadcast!(
        map_id,
        :ping_added,
        ping |> Map.merge(%{character_eve_id: character.eve_id, solar_system_id: solar_system_id})
      )

      # Broadcast rally point events to external clients (webhooks/SSE)
      if type == 1 do
        WandererApp.ExternalEvents.broadcast(map_id, :rally_point_added, %{
          rally_point_id: ping.id,
          solar_system_id: solar_system_id,
          system_id: system.id,
          character_id: character_id,
          character_name: character.name,
          character_eve_id: character.eve_id,
          system_name: system.name,
          message: message,
          created_at: ping.inserted_at
        })
      end

      WandererApp.User.ActivityTracker.track_map_event(:map_rally_added, %{
        character_id: character_id,
        user_id: user_id,
        map_id: map_id,
        solar_system_id: "#{solar_system_id}"
      })

      state
    else
      error ->
        Logger.error("Failed to add_ping: #{inspect(error, pretty: true)}")
        state
    end
  end

  def cancel_ping(
        %{map_id: map_id} = state,
        %{
          id: ping_id,
          character_id: character_id,
          user_id: user_id,
          type: type
        } = ping_info
      ) do
    with {:ok, character} <- WandererApp.Character.get_character(character_id),
         {:ok,
          %{system: %{id: system_id, name: system_name, solar_system_id: solar_system_id}} = ping} <-
           WandererApp.MapPingsRepo.get_by_id(ping_id),
         :ok <- WandererApp.MapPingsRepo.destroy(ping) do
      Impl.broadcast!(map_id, :ping_cancelled, %{
        id: ping_id,
        solar_system_id: solar_system_id,
        type: type
      })

      # Broadcast rally point removal events to external clients (webhooks/SSE)
      if type == 1 do
        WandererApp.ExternalEvents.broadcast(map_id, :rally_point_removed, %{
          id: ping_id,
          solar_system_id: solar_system_id,
          system_id: system_id,
          character_id: character_id,
          character_name: character.name,
          character_eve_id: character.eve_id,
          system_name: system_name
        })
      end

      WandererApp.User.ActivityTracker.track_map_event(:map_rally_cancelled, %{
        character_id: character_id,
        user_id: user_id,
        map_id: map_id,
        solar_system_id: solar_system_id
      })

      state
    else
      error ->
        Logger.error("Failed to cancel_ping: #{inspect(error, pretty: true)}")
        state
    end
  end
end
