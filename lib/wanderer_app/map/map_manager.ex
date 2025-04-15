defmodule WandererApp.Map.Manager do
  @moduledoc """
  Manager maps with no active characters and bulk start
  """

  use GenServer

  require Logger

  alias WandererApp.Map.Server
  alias WandererApp.Map.ServerSupervisor

  @maps_start_per_second 5
  @maps_start_interval 1000
  @maps_queue :maps_queue
  @garbage_collection_interval :timer.hours(1)
  @check_maps_queue_interval :timer.seconds(1)

  def start_map(map_id) when is_binary(map_id),
    do: WandererApp.Queue.push_uniq(@maps_queue, map_id)

  def stop_map(map_id) when is_binary(map_id) do
    case Server.map_pid(map_id) do
      pid when is_pid(pid) ->
        GenServer.cast(
          pid,
          :stop
        )

      nil ->
        :ok
    end
  end

  def start_link(_), do: GenServer.start(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    WandererApp.Queue.new(@maps_queue, [])

    {:ok, check_maps_queue_timer} =
      :timer.send_interval(@check_maps_queue_interval, :check_maps_queue)

    {:ok, garbage_collector_timer} =
      :timer.send_interval(@garbage_collection_interval, :garbage_collect)

    try do
      Task.async(fn ->
        start_last_active_maps()
      end)
    rescue
      e ->
        Logger.error(Exception.message(e))
    end

    {:ok,
     %{
       garbage_collector_timer: garbage_collector_timer,
       check_maps_queue_timer: check_maps_queue_timer
     }}
  end

  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_maps_queue, state) do
    try do
      case not WandererApp.Queue.empty?(@maps_queue) do
        true ->
          Task.async(fn ->
            start_maps()
          end)

        _ ->
          :ok
      end

      {:noreply, state}
    rescue
      e ->
        Logger.error(Exception.message(e))

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:garbage_collect, state) do
    try do
      WandererApp.Map.RegistryHelper.list_all_maps()
      |> Enum.each(fn %{id: map_id, pid: server_pid} ->
        case Process.alive?(server_pid) do
          true ->
            presence_character_ids =
              WandererApp.Cache.lookup!("map_#{map_id}:presence_character_ids", [])

            if presence_character_ids |> Enum.empty?() do
              Logger.info("No more characters present on: #{map_id}, shutting down map server...")
              stop_map(map_id)
            end

          false ->
            Logger.warning("Server not alive: #{inspect(server_pid)}")
            :ok
        end
      end)

      {:noreply, state}
    rescue
      e ->
        Logger.error(Exception.message(e))

        {:noreply, state}
    end
  end

  defp start_last_active_maps() do
    {:ok, last_map_states} =
      WandererApp.Api.MapState.get_last_active(
        DateTime.utc_now()
        |> DateTime.add(-30, :minute)
      )

    last_map_states
    |> Enum.map(fn %{map_id: map_id} -> map_id end)
    |> Enum.each(fn map_id -> start_map(map_id) end)

    :ok
  end

  defp start_maps() do
    chunks =
      @maps_queue
      |> WandererApp.Queue.to_list!()
      |> Enum.uniq()
      |> Enum.chunk_every(@maps_start_per_second)

    WandererApp.Queue.clear(@maps_queue)

    tasks =
      for chunk <- chunks do
        task =
          Task.async(fn ->
            chunk
            |> Enum.map(&start_map_server/1)
          end)

        :timer.sleep(@maps_start_interval)

        task
      end

    Logger.debug(fn -> "Waiting for maps to start" end)
    Task.await_many(tasks)
    Logger.debug(fn -> "All maps started" end)
  end

  defp start_map_server(map_id) do
    case DynamicSupervisor.start_child(
           {:via, PartitionSupervisor, {WandererApp.Map.DynamicSupervisors, self()}},
           {ServerSupervisor, map_id: map_id}
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, {:shutdown, {:failed_to_start_child, Server, {:already_started, pid}}}} ->
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
