defmodule WandererApp.Map.Server.PingsImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.Server.Impl

  # @ping_auto_expire_timeout :timer.minutes(15) # reserved for future use

  def add_ping(
        map_id,
        %{
          solar_system_id: solar_system_id,
          type: type,
          message: message,
          character_id: character_id,
          user_id: user_id
        } = _ping_info
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
    else
      error ->
        Logger.error("Failed to add_ping: #{inspect(error, pretty: true)}")
    end
  end

  def cancel_ping(
        map_id,
        %{
          id: ping_id,
          character_id: character_id,
          user_id: user_id,
          type: type
        } = _ping_info
      ) do

    result = WandererApp.MapPingsRepo.get_by_id(ping_id)

    case result do
      {:ok,
       %{system: %{id: system_id, name: system_name, solar_system_id: solar_system_id}} = ping} ->
        with {:ok, character} <- WandererApp.Character.get_character(character_id),
             :ok <- WandererApp.MapPingsRepo.destroy(ping) do
          Logger.debug("Ping #{ping_id} destroyed successfully, broadcasting :ping_cancelled")

          Impl.broadcast!(map_id, :ping_cancelled, %{
            id: ping_id,
            solar_system_id: solar_system_id,
            type: type
          })

          Logger.debug("Broadcast :ping_cancelled sent for ping #{ping_id}")

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
        else
          error ->
            Logger.error("Failed to destroy ping: #{inspect(error, pretty: true)}")
        end

      # Handle case where ping exists but system was deleted (nil)
      {:ok, %{system: nil} = ping} ->
        case WandererApp.MapPingsRepo.destroy(ping) do
          :ok ->
            Impl.broadcast!(map_id, :ping_cancelled, %{
              id: ping_id,
              solar_system_id: nil,
              type: type
            })

          error ->
            Logger.error("Failed to destroy orphaned ping: #{inspect(error, pretty: true)}")
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        # Ping already deleted (possibly by cascade deletion from map/system/character removal,
        # auto-expiry, or concurrent cancellation). Broadcast cancellation so frontend updates.
        Impl.broadcast!(map_id, :ping_cancelled, %{
          id: ping_id,
          solar_system_id: nil,
          type: type
        })

        :ok

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
        # Same as above, but Ash wraps NotFound inside Invalid in some cases
        Impl.broadcast!(map_id, :ping_cancelled, %{
          id: ping_id,
          solar_system_id: nil,
          type: type
        })

        :ok

      other ->
        Logger.error(
          "Failed to cancel ping #{ping_id}: unexpected result from get_by_id: #{inspect(other, pretty: true)}"
        )
    end
  end
end
