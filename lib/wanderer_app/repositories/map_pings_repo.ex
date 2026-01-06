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

  @doc """
  Returns all pings that have orphaned relationships (nil system, character, or map)
  or where the system has been soft-deleted (visible = false).
  These pings should be cleaned up as they can no longer be properly displayed or cancelled.
  """
  def get_orphaned_pings() do
    # Use :all_pings action which has no actor filtering (unlike primary :read)
    case WandererApp.Api.MapPing |> Ash.Query.for_read(:all_pings) |> Ash.read() do
      {:ok, pings} ->
        # Load relationships and filter for orphaned ones
        orphaned =
          pings
          |> Enum.map(fn ping ->
            {:ok, loaded} = ping |> Ash.load([:system, :character, :map], authorize?: false)
            loaded
          end)
          |> Enum.filter(fn ping ->
            is_nil(ping.system) or is_nil(ping.character) or is_nil(ping.map) or
              (not is_nil(ping.system) and ping.system.visible == false)
          end)

        {:ok, orphaned}

      error ->
        error
    end
  end

  def create(ping), do: ping |> WandererApp.Api.MapPing.new()
  def create!(ping), do: ping |> WandererApp.Api.MapPing.new!()

  def destroy(ping) do
    ping
    |> WandererApp.Api.MapPing.destroy!()

    :ok
  end

  @doc """
  Deletes all pings for a given map. Use with caution - for cleanup purposes.
  """
  def delete_all_for_map(map_id) do
    case get_by_map(map_id) do
      {:ok, pings} ->
        Logger.info("[MapPingsRepo] Deleting #{length(pings)} pings for map #{map_id}")

        Enum.each(pings, fn ping ->
          Logger.info("[MapPingsRepo] Deleting ping #{ping.id} (type: #{ping.type})")
          Ash.destroy!(ping)
        end)

        {:ok, length(pings)}

      error ->
        error
    end
  end
end
