defmodule WandererApp.MapPingsRepo do
  use WandererApp, :repository

  require Logger

  def get_by_id(ping_id),
    do: WandererApp.Api.MapPing.by_id!(ping_id) |> Ash.load([:system])

  def get_by_map(map_id),
    do: WandererApp.Api.MapPing.by_map!(%{map_id: map_id}) |> Ash.load([:character, :system])

  def get_by_map_and_system!(map_id, system_id),
    do: WandererApp.Api.MapPing.by_map_and_system!(%{map_id: map_id, system_id: system_id})

  def get_by_inserted_before(inserted_before_date),
    do: WandererApp.Api.MapPing.by_inserted_before(inserted_before_date)

  def create(%{map_id: map_id} = ping) do
    # Load map to provide context for InjectMapFromActor
    case Ash.get(WandererApp.Api.Map, map_id) do
      {:ok, map} ->
        # Remove map_id from attrs since it's now injected from context
        attrs = Map.delete(ping, :map_id)
        # Pass map via context
        attrs |> WandererApp.Api.MapPing.new(context: %{map: map})

      {:error, _} = error ->
        error
    end
  end

  def create!(ping) do
    case create(ping) do
      {:ok, result} -> result
      {:error, error} -> raise "Failed to create ping: #{inspect(error)}"
    end
  end

  def destroy(ping) do
    ping
    |> WandererApp.Api.MapPing.destroy!()

    :ok
  end

  def destroy(_ping_id), do: :ok
end
