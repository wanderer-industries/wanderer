defmodule WandererApp.MapPingsRepo do
  use WandererApp, :repository

  require Logger

  def get_by_id(ping_id),
    do: WandererApp.Api.MapPing.by_id(ping_id)

  def get_by_map_id(map_id),
    do: WandererApp.Api.MapPing.by_map_id(map_id)

  def create(ping), do: ping |> WandererApp.Api.MapPing.create()
  def create!(ping), do: ping |> WandererApp.Api.MapPing.create!()

  def destroy(ping) when not is_nil(ping),
    do:
      ping
      |> WandererApp.Api.MapPing.destroy!()

  def destroy(_ping), do: :ok
end
