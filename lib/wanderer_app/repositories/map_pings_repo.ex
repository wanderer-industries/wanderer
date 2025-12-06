defmodule WandererApp.MapPingsRepo do
  use WandererApp, :repository

  require Logger

  def get_by_id(ping_id) do
    case WandererApp.Api.MapPing.by_id(ping_id) do
      {:ok, ping} ->
        ping |> Ash.load([:system])

      error ->
        error
    end
  end

  def get_by_map(map_id) do
    case WandererApp.Api.MapPing.by_map(%{map_id: map_id}) do
      {:ok, ping} ->
        ping |> Ash.load([:character, :system])

      error ->
        error
    end
  end

  def get_by_map_and_system!(map_id, system_id),
    do: WandererApp.Api.MapPing.by_map_and_system!(%{map_id: map_id, system_id: system_id})

  def get_by_inserted_before(inserted_before_date),
    do: WandererApp.Api.MapPing.by_inserted_before(inserted_before_date)

  def create(ping), do: ping |> WandererApp.Api.MapPing.new()
  def create!(ping), do: ping |> WandererApp.Api.MapPing.new!()

  def destroy(ping) do
    ping
    |> WandererApp.Api.MapPing.destroy!()

    :ok
  end
end
