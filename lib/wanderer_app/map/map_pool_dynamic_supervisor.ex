defmodule WandererApp.Map.MapPoolDynamicSupervisor do
  @moduledoc false
  use DynamicSupervisor

  require Logger

  @cache :map_pool_cache
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry
  @map_pool_limit 20

  @name __MODULE__

  def start_link(_arg) do
    DynamicSupervisor.start_link(@name, [], name: @name, max_restarts: 10)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_map(map_id) do
    try do
      case Registry.lookup(@registry, WandererApp.Map.MapPool) do
        [] ->
          start_child([map_id], 0)

        pools ->
          case get_available_pool(pools) do
            nil ->
              start_child([map_id], pools |> Enum.count())

            pid ->
              GenServer.cast(pid, {:start_map, map_id})
          end
      end
    rescue
      ArgumentError ->
        Logger.warning(fn ->
          "Map pool registry not available, cannot start map #{map_id}"
        end)

        {:error, :registry_not_available}
    end
  end

  def stop_map(map_id) do
    case Cachex.get(@cache, map_id) do
      {:ok, nil} ->
        # Cache miss - try to find the pool by scanning the registry
        Logger.warning(
          "Cache miss for map #{map_id}, scanning registry for pool containing this map"
        )

        find_pool_by_scanning_registry(map_id)

      {:ok, pool_uuid} ->
        # Cache hit - use the pool_uuid to lookup the pool
        case Registry.lookup(
               @unique_registry,
               Module.concat(WandererApp.Map.MapPool, pool_uuid)
             ) do
          [] ->
            Logger.warning(
              "Pool with UUID #{pool_uuid} not found in registry for map #{map_id}, scanning registry"
            )

            find_pool_by_scanning_registry(map_id)

          [{pool_pid, _}] ->
            GenServer.call(pool_pid, {:stop_map, map_id})
        end

      {:error, reason} ->
        Logger.error("Failed to lookup map #{map_id} in cache: #{inspect(reason)}")
        :ok
    end
  end

  defp find_pool_by_scanning_registry(map_id) do
    case Registry.lookup(@registry, WandererApp.Map.MapPool) do
      [] ->
        Logger.debug("No map pools found in registry for map #{map_id}")
        :ok

      pools ->
        # Scan all pools to find the one containing this map_id
        found_pool =
          Enum.find_value(pools, fn {_pid, uuid} ->
            case Registry.lookup(
                   @unique_registry,
                   Module.concat(WandererApp.Map.MapPool, uuid)
                 ) do
              [{pool_pid, map_ids}] ->
                if map_id in map_ids do
                  {pool_pid, uuid}
                else
                  nil
                end

              _ ->
                nil
            end
          end)

        case found_pool do
          {pool_pid, pool_uuid} ->
            Logger.info(
              "Found map #{map_id} in pool #{pool_uuid} via registry scan, updating cache"
            )

            # Update the cache to fix the inconsistency
            Cachex.put(@cache, map_id, pool_uuid)
            GenServer.call(pool_pid, {:stop_map, map_id})

          nil ->
            Logger.debug("Map #{map_id} not found in any pool registry")
            :ok
        end
    end
  end

  defp get_available_pool([]), do: nil

  defp get_available_pool([{pid, uuid} | pools]) do
    case Registry.lookup(@unique_registry, Module.concat(WandererApp.Map.MapPool, uuid)) do
      [] ->
        nil

      uuid_pools ->
        case get_available_pool_pid(uuid_pools) do
          nil ->
            get_available_pool(pools)

          pid ->
            pid
        end
    end
  end

  defp get_available_pool_pid([]), do: nil

  defp get_available_pool_pid([{pid, map_ids} | pools]) do
    if Enum.count(map_ids) < @map_pool_limit do
      pid
    else
      get_available_pool_pid(pools)
    end
  end

  defp start_child(map_ids, pools_count) do
    case DynamicSupervisor.start_child(@name, {WandererApp.Map.MapPool, map_ids}) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  defp stop_child(uuid) do
    case Registry.lookup(@registry, uuid) do
      [{pid, _}] ->
        GenServer.cast(pid, :stop)

      _ ->
        Logger.warn("Unable to locate pool assigned to #{inspect(uuid)}")
        :ok
    end
  end
end
