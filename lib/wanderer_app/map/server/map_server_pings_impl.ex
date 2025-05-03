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
          character_id: character_eve_id,
          user_id: user_id
        } = ping_info
      ) do
    Impl.broadcast!(map_id, :ping_added, %{
      inserted_at: DateTime.utc_now(),
      character_eve_id: character_eve_id,
      solar_system_id: solar_system_id,
      message: message,
      type: type
    })

    state
  end

  def cancel_ping(
        %{map_id: map_id} = state,
        %{
          solar_system_id: solar_system_id,
          character_id: character_id,
          user_id: user_id,
          type: type
        } = ping_info
      ) do
    Impl.broadcast!(map_id, :ping_cancelled, %{
      solar_system_id: solar_system_id,
      type: type
    })

    state
  end
end
