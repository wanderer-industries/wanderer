defmodule WandererApp.Character.TrackerPoolDynamicSupervisor do
  @moduledoc false
  use DynamicSupervisor

  require Logger

  @cache :tracked_characters
  @registry :tracker_pool_registry
  @unique_registry :unique_tracker_pool_registry
  @tracker_pool_limit 50

  @name __MODULE__

  def start_link(_arg) do
    DynamicSupervisor.start_link(@name, [], name: @name, max_restarts: 10)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_tracking(tracked_id) do
    case Registry.lookup(@registry, WandererApp.Character.TrackerPool) do
      [] ->
        start_child([tracked_id], 0)

      pools ->
        case get_available_pool(pools) do
          nil ->
            start_child([tracked_id], pools |> Enum.count())

          pid ->
            GenServer.cast(pid, {:add_tracked_id, tracked_id})
        end
    end
  end

  @doc "Returns the set of tracked ids held by all running tracker pools."
  def tracked_ids do
    @registry
    |> Registry.lookup(WandererApp.Character.TrackerPool)
    |> Enum.flat_map(fn {_pid, uuid} ->
      case Registry.lookup(
             @unique_registry,
             Module.concat(WandererApp.Character.TrackerPool, uuid)
           ) do
        [{_pool_pid, tracked_ids}] -> tracked_ids
        _ -> []
      end
    end)
    |> MapSet.new()
  end

  def stop_tracking(tracked_id) do
    case find_pool_pid(tracked_id) do
      nil ->
        :ok

      pool_pid ->
        GenServer.cast(pool_pid, {:remove_tracked_id, tracked_id})
    end
  end

  defp find_pool_pid(tracked_id) do
    with {:ok, uuid} when not is_nil(uuid) <- Cachex.get(@cache, tracked_id),
         [{pool_pid, _}] <-
           Registry.lookup(
             @unique_registry,
             Module.concat(WandererApp.Character.TrackerPool, uuid)
           ) do
      pool_pid
    else
      _ -> find_pool_pid_by_scanning_registry(tracked_id)
    end
  end

  # Cache miss or stale pool uuid - find the pool that actually holds this tracked_id
  defp find_pool_pid_by_scanning_registry(tracked_id) do
    @registry
    |> Registry.lookup(WandererApp.Character.TrackerPool)
    |> Enum.find_value(fn {_pid, uuid} ->
      case Registry.lookup(
             @unique_registry,
             Module.concat(WandererApp.Character.TrackerPool, uuid)
           ) do
        [{pool_pid, tracked_ids}] -> if tracked_id in tracked_ids, do: pool_pid
        _ -> nil
      end
    end)
  end

  defp get_available_pool([]), do: nil

  defp get_available_pool([{_pid, uuid} | pools]) do
    case Registry.lookup(@unique_registry, Module.concat(WandererApp.Character.TrackerPool, uuid)) do
      [] ->
        nil

      uuid_pools ->
        case get_available_pool_pid(uuid_pools) do
          nil ->
            get_available_pool(pools)

          pool_pid ->
            pool_pid
        end
    end
  end

  defp get_available_pool_pid([]), do: nil

  defp get_available_pool_pid([{pid, tracked_ids} | pools]) do
    if Enum.count(tracked_ids) < @tracker_pool_limit do
      pid
    else
      get_available_pool_pid(pools)
    end
  end

  defp start_child(tracked_ids, pools_count) do
    # Generate the uuid here so it is part of the child spec and survives restarts
    uuid = UUID.uuid1()

    case DynamicSupervisor.start_child(
           @name,
           {WandererApp.Character.TrackerPool, {uuid, tracked_ids}}
         ) do
      {:ok, pid} ->
        Logger.info("Starting tracking pool, total pools: #{pools_count + 1}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end
end
