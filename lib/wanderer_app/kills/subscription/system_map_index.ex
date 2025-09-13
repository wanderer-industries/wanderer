defmodule WandererApp.Kills.Subscription.SystemMapIndex do
  @moduledoc """
  Maintains an in-memory index of system_id -> [map_ids] for efficient kill broadcasting.

  This index prevents N+1 queries when broadcasting kills to relevant maps.
  """

  use GenServer
  require Logger

  @table_name :kills_system_map_index
  @refresh_interval :timer.minutes(5)

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets all map IDs that contain the given system.
  """
  @spec get_maps_for_system(integer()) :: [String.t()]
  def get_maps_for_system(system_id) do
    case :ets.lookup(@table_name, system_id) do
      [{^system_id, map_ids}] -> map_ids
      [] -> []
    end
  end

  @doc """
  Refreshes the index immediately.
  """
  @spec refresh() :: :ok
  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for fast lookups
    :ets.new(@table_name, [:set, :protected, :named_table, read_concurrency: true])

    # Initial build
    send(self(), :build_index)

    # Schedule periodic refresh
    schedule_refresh()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:build_index, state) do
    build_index()
    {:noreply, state}
  end

  def handle_info(:refresh, state) do
    build_index()
    schedule_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    build_index()
    {:noreply, state}
  end

  # Private functions

  defp build_index do
    Logger.debug("[SystemMapIndex] Building system->maps index")

    case fetch_all_map_systems() do
      {:ok, index_data} ->
        # Clear and rebuild the table
        :ets.delete_all_objects(@table_name)

        # Insert all entries
        Enum.each(index_data, fn {system_id, map_ids} ->
          :ets.insert(@table_name, {system_id, map_ids})
        end)

        Logger.debug("[SystemMapIndex] Index built with #{map_size(index_data)} systems")

      {:error, reason} ->
        Logger.error("[SystemMapIndex] Failed to build index: #{inspect(reason)}")
    end
  end

  defp fetch_all_map_systems do
    try do
      {:ok, maps} = WandererApp.Maps.get_available_maps()

      # Build the index: system_id -> [map_ids]
      index =
        maps
        |> Enum.reduce(%{}, fn map, acc ->
          case WandererApp.MapSystemRepo.get_all_by_map(map.id) do
            {:ok, systems} ->
              # Add this map to each system's list
              Enum.reduce(systems, acc, fn system, acc2 ->
                Map.update(acc2, system.solar_system_id, [map.id], &[map.id | &1])
              end)

            _ ->
              acc
          end
        end)
        |> Enum.map(fn {system_id, map_ids} ->
          # Remove duplicates and convert to list
          {system_id, Enum.uniq(map_ids)}
        end)
        |> Map.new()

      {:ok, index}
    rescue
      e ->
        {:error, e}
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
