defmodule WandererApp.MapPingsRepo do
  use WandererApp, :repository

  require Logger

  def get_by_id(ping_id),
    do: WandererApp.Api.MapPing.by_id(ping_id)

  def get_by_map(map_id),
    do: WandererApp.Api.MapPing.by_map!(%{map_id: map_id}) |> Ash.load([:character, :system])

  def create(ping), do: ping |> WandererApp.Api.MapPing.new()
  def create!(ping), do: ping |> WandererApp.Api.MapPing.new!()

  def destroy(map_id, system_id) when is_binary(map_id) and is_binary(system_id) do
    {:ok, ping} =
      WandererApp.Api.MapPing.by_map_and_system(%{
        map_id: map_id,
        system_id: system_id
      })

    ping
    |> WandererApp.Api.MapPing.destroy!()
  end

  def destroy(_ping), do: :ok
end
