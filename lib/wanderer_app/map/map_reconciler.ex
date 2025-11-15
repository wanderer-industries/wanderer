defmodule WandererApp.Map.Reconciler do
  @moduledoc """
  Periodically reconciles map state across different stores (Cache, Registry, GenServer state)
  to detect and fix inconsistencies that may prevent map servers from restarting.
  """
  use GenServer

  require Logger

  @cache :map_pool_cache
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry
  @reconciliation_interval :timer.minutes(5)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Map Reconciler")
    schedule_reconciliation()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:reconcile, state) do
    schedule_reconciliation()

    try do
      reconcile_state()
    rescue
      e ->
        Logger.error("""
        [Map Reconciler] reconciliation error: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  @doc """
  Manually trigger a reconciliation (useful for testing or manual cleanup)
  """
  def trigger_reconciliation do
    GenServer.cast(__MODULE__, :reconcile_now)
  end

  @impl true
  def handle_cast(:reconcile_now, state) do
    try do
      reconcile_state()
    rescue
      e ->
        Logger.error("""
        [Map Reconciler] manual reconciliation error: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  defp schedule_reconciliation do
    Process.send_after(self(), :reconcile, @reconciliation_interval)
  end

  defp reconcile_state do
    Logger.debug("[Map Reconciler] Starting state reconciliation")

    # Get started_maps from cache
    {:ok, started_maps} = WandererApp.Cache.lookup("started_maps", [])

    # Get all maps from registries
    registry_maps = get_all_registry_maps()

    # Detect zombie maps (in started_maps but not in any registry)
    zombie_maps = started_maps -- registry_maps
    # Detect orphan maps (in registry but not in started_maps)
    orphan_maps = registry_maps -- started_maps

    # Detect cache inconsistencies (map_pool_cache pointing to wrong or non-existent pools)
    cache_inconsistencies = find_cache_inconsistencies(registry_maps)

    stats = %{
      total_started_maps: length(started_maps),
      total_registry_maps: length(registry_maps),
      zombie_maps: length(zombie_maps),
      orphan_maps: length(orphan_maps),
      cache_inconsistencies: length(cache_inconsistencies)
    }

    Logger.info("[Map Reconciler] Reconciliation stats: #{inspect(stats)}")

    # Emit telemetry
    :telemetry.execute(
      [:wanderer_app, :map, :reconciliation],
      stats,
      %{}
    )

    # Clean up zombie maps
    cleanup_zombie_maps(zombie_maps)

    # Fix orphan maps
    fix_orphan_maps(orphan_maps)

    # Fix cache inconsistencies
    fix_cache_inconsistencies(cache_inconsistencies)

    Logger.debug("[Map Reconciler] State reconciliation completed")
  end

  defp get_all_registry_maps do
    case Registry.lookup(@registry, WandererApp.Map.MapPool) do
      [] ->
        []

      pools ->
        pools
        |> Enum.flat_map(fn {_pid, uuid} ->
          case Registry.lookup(
                 @unique_registry,
                 Module.concat(WandererApp.Map.MapPool, uuid)
               ) do
            [{_pool_pid, map_ids}] -> map_ids
            _ -> []
          end
        end)
        |> Enum.uniq()
    end
  end

  defp find_cache_inconsistencies(registry_maps) do
    registry_maps
    |> Enum.filter(fn map_id ->
      case Cachex.get(@cache, map_id) do
        {:ok, nil} ->
          # Map in registry but not in cache
          true

        {:ok, pool_uuid} ->
          # Check if the pool_uuid actually exists in registry
          case Registry.lookup(
                 @unique_registry,
                 Module.concat(WandererApp.Map.MapPool, pool_uuid)
               ) do
            [] ->
              # Cache points to non-existent pool
              true

            [{_pool_pid, map_ids}] ->
              # Check if this map is actually in the pool's map_ids
              map_id not in map_ids

            _ ->
              false
          end

        {:error, _} ->
          true
      end
    end)
  end

  defp cleanup_zombie_maps([]), do: :ok

  defp cleanup_zombie_maps(zombie_maps) do
    Logger.warning(
      "[Map Reconciler] Found #{length(zombie_maps)} zombie maps: #{inspect(zombie_maps)}"
    )

    Enum.each(zombie_maps, fn map_id ->
      Logger.info("[Map Reconciler] Cleaning up zombie map: #{map_id}")

      # Remove from started_maps cache
      WandererApp.Cache.insert_or_update(
        "started_maps",
        [],
        fn started_maps ->
          started_maps |> Enum.reject(fn started_map_id -> started_map_id == map_id end)
        end
      )

      # Clean up any stale map_pool_cache entries
      Cachex.del(@cache, map_id)

      # Clean up map-specific caches
      WandererApp.Cache.delete("map_#{map_id}:started")
      WandererApp.Cache.delete("map_characters-#{map_id}")
      WandererApp.Map.CacheRTree.clear_tree("rtree_#{map_id}")
      WandererApp.Map.delete_map_state(map_id)

      :telemetry.execute(
        [:wanderer_app, :map, :reconciliation, :zombie_cleanup],
        %{count: 1},
        %{map_id: map_id}
      )
    end)
  end

  defp fix_orphan_maps([]), do: :ok

  defp fix_orphan_maps(orphan_maps) do
    Logger.warning(
      "[Map Reconciler] Found #{length(orphan_maps)} orphan maps: #{inspect(orphan_maps)}"
    )

    Enum.each(orphan_maps, fn map_id ->
      Logger.info("[Map Reconciler] Fixing orphan map: #{map_id}")

      # Add to started_maps cache
      WandererApp.Cache.insert_or_update(
        "started_maps",
        [map_id],
        fn existing ->
          [map_id | existing] |> Enum.uniq()
        end
      )

      :telemetry.execute(
        [:wanderer_app, :map, :reconciliation, :orphan_fixed],
        %{count: 1},
        %{map_id: map_id}
      )
    end)
  end

  defp fix_cache_inconsistencies([]), do: :ok

  defp fix_cache_inconsistencies(inconsistent_maps) do
    Logger.warning(
      "[Map Reconciler] Found #{length(inconsistent_maps)} cache inconsistencies: #{inspect(inconsistent_maps)}"
    )

    Enum.each(inconsistent_maps, fn map_id ->
      Logger.info("[Map Reconciler] Fixing cache inconsistency for map: #{map_id}")

      # Find the correct pool for this map
      case find_pool_for_map(map_id) do
        {:ok, pool_uuid} ->
          Logger.info("[Map Reconciler] Updating cache: #{map_id} -> #{pool_uuid}")
          Cachex.put(@cache, map_id, pool_uuid)

          :telemetry.execute(
            [:wanderer_app, :map, :reconciliation, :cache_fixed],
            %{count: 1},
            %{map_id: map_id, pool_uuid: pool_uuid}
          )

        :error ->
          Logger.warning(
            "[Map Reconciler] Could not find pool for map #{map_id}, removing from cache"
          )

          Cachex.del(@cache, map_id)
      end
    end)
  end

  defp find_pool_for_map(map_id) do
    case Registry.lookup(@registry, WandererApp.Map.MapPool) do
      [] ->
        :error

      pools ->
        pools
        |> Enum.find_value(:error, fn {_pid, uuid} ->
          case Registry.lookup(
                 @unique_registry,
                 Module.concat(WandererApp.Map.MapPool, uuid)
               ) do
            [{_pool_pid, map_ids}] ->
              if map_id in map_ids do
                {:ok, uuid}
              else
                nil
              end

            _ ->
              nil
          end
        end)
    end
  end
end
