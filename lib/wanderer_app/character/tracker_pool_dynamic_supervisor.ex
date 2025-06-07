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

  def stop_tracking(tracked_id) do
    {:ok, uuid} = Cachex.get(@cache, tracked_id)

    case Registry.lookup(
           @unique_registry,
           Module.concat(WandererApp.Character.TrackerPool, uuid)
         ) do
      [] ->
        :ok

      [{pool_pid, _}] ->
        GenServer.cast(pool_pid, {:remove_tracked_id, tracked_id})
    end
  end

  def is_not_tracked?(tracked_id) do
    {:ok, tracked_ids} = Cachex.get(@cache, :tracked_characters)
    tracked_ids |> Enum.member?(tracked_id) |> Kernel.not()
  end

  defp get_available_pool([]), do: nil

  defp get_available_pool([{pid, uuid} | pools]) do
    case Registry.lookup(@unique_registry, Module.concat(WandererApp.Character.TrackerPool, uuid)) do
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

  defp get_available_pool_pid([{pid, tracked_ids} | pools]) do
    if Enum.count(tracked_ids) < @tracker_pool_limit do
      pid
    else
      get_available_pool_pid(pools)
    end
  end

  defp start_child(tracked_ids, pools_count) do
    case DynamicSupervisor.start_child(@name, {WandererApp.Character.TrackerPool, tracked_ids}) do
      {:ok, pid} ->
        Logger.info("Starting tracking pool, total pools: #{pools_count + 1}")
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
