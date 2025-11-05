defmodule WandererApp.Map.MapPoolDynamicSupervisor do
  @moduledoc false
  use DynamicSupervisor

  require Logger

  @cache :map_pool_cache
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry
  @map_pool_limit 10

  @name __MODULE__

  def start_link(_arg) do
    DynamicSupervisor.start_link(@name, [], name: @name, max_restarts: 10)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_map(map_id) do
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
  end

  def stop_map(map_id) do
    {:ok, pool_uuid} = Cachex.get(@cache, map_id)

    case Registry.lookup(
           @unique_registry,
           Module.concat(WandererApp.Map.MapPool, pool_uuid)
         ) do
      [] ->
        :ok

      [{pool_pid, _}] ->
        GenServer.cast(pool_pid, {:stop_map, map_id})
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
        Logger.info("Starting map pool, total map_pools: #{pools_count + 1}")
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
