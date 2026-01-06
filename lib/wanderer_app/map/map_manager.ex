defmodule WandererApp.Map.Manager do
  @moduledoc """
  Manager maps with no active characters and bulk start
  """

  use GenServer

  require Logger

  alias WandererApp.Map.Server

  @environment Application.compile_env(:wanderer_app, :environment)

  @maps_start_chunk_size 20
  @maps_start_interval 500
  @maps_queue :maps_queue
  @check_maps_queue_interval :timer.seconds(1)

  @pings_cleanup_interval :timer.minutes(5)
  @pings_expire_minutes 60

  # Test-aware async task runner
  defp safe_async_task(fun) do
    if @environment == :test do
      # In tests, run synchronously to avoid database ownership issues
      try do
        fun.()
      rescue
        e ->
          Logger.error("Error in sync task: #{Exception.message(e)}")
      end
    else
      # In production, run async as normal
      Task.async(fun)
    end
  end

  def start_map(map_id) when is_binary(map_id),
    do: WandererApp.Queue.push_uniq(@maps_queue, map_id)

  def stop_map(map_id) when is_binary(map_id) do
    with {:ok, started_maps} <- WandererApp.Cache.lookup("started_maps", []),
         true <- Enum.member?(started_maps, map_id) do
      Logger.warning(fn -> "Shutting down map server: #{inspect(map_id)}" end)

      WandererApp.Map.MapPoolDynamicSupervisor.stop_map(map_id)
    end
  end

  def start_link(_), do: GenServer.start(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    WandererApp.Queue.new(@maps_queue, [])
    WandererApp.Cache.insert("started_maps", [])

    {:ok, check_maps_queue_timer} =
      :timer.send_interval(@check_maps_queue_interval, :check_maps_queue)

    {:ok, pings_cleanup_timer} =
      :timer.send_interval(@pings_cleanup_interval, :cleanup_pings)

    {:ok,
     %{
       check_maps_queue_timer: check_maps_queue_timer,
       pings_cleanup_timer: pings_cleanup_timer
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
          safe_async_task(fn ->
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
  def handle_info(:cleanup_pings, state) do
    try do
      cleanup_expired_pings()
      cleanup_orphaned_pings()
      {:noreply, state}
    rescue
      e ->
        Logger.error("Failed to cleanup pings: #{inspect(e)}")
        {:noreply, state}
    end
  end

  defp cleanup_expired_pings() do
    delete_after_date = DateTime.utc_now() |> DateTime.add(-1 * @pings_expire_minutes, :minute)

    case WandererApp.MapPingsRepo.get_by_inserted_before(delete_after_date) do
      {:ok, pings} ->
        Enum.each(pings, fn %{id: ping_id, map_id: map_id, type: type} = ping ->
          {:ok, %{system: system}} = ping |> Ash.load([:system])

          # Handle case where parent system was already deleted
          case system do
            nil ->
              Logger.warning(
                "[cleanup_expired_pings] ping #{ping_id} destroyed (parent system already deleted)"
              )

            %{solar_system_id: solar_system_id} ->
              Server.Impl.broadcast!(map_id, :ping_cancelled, %{
                id: ping_id,
                solar_system_id: solar_system_id,
                type: type
              })
          end

          Ash.destroy!(ping)
        end)

        :ok

      {:error, error} ->
        Logger.error("Failed to fetch expired pings: #{inspect(error)}")
        {:error, error}
    end
  end

  defp cleanup_orphaned_pings() do
    case WandererApp.MapPingsRepo.get_orphaned_pings() do
      {:ok, []} ->
        :ok

      {:ok, orphaned_pings} ->
        Logger.info(
          "[cleanup_orphaned_pings] Found #{length(orphaned_pings)} orphaned pings, cleaning up..."
        )

        Enum.each(orphaned_pings, fn %{id: ping_id, map_id: map_id, type: type, system: system} = ping ->
          reason =
            cond do
              is_nil(ping.system) -> "system deleted"
              is_nil(ping.character) -> "character deleted"
              is_nil(ping.map) -> "map deleted"
              not is_nil(system) and system.visible == false -> "system hidden (visible=false)"
              true -> "unknown"
            end

          Logger.warning(
            "[cleanup_orphaned_pings] Destroying orphaned ping #{ping_id} (map_id: #{map_id}, reason: #{reason})"
          )

          # Broadcast cancellation if map_id is still valid
          if map_id do
            Server.Impl.broadcast!(map_id, :ping_cancelled, %{
              id: ping_id,
              solar_system_id: nil,
              type: type
            })
          end

          Ash.destroy!(ping)
        end)

        Logger.info("[cleanup_orphaned_pings] Cleaned up #{length(orphaned_pings)} orphaned pings")
        :ok

      {:error, error} ->
        Logger.error("Failed to fetch orphaned pings: #{inspect(error)}")
        {:error, error}
    end
  end

  defp start_maps() do
    chunks =
      @maps_queue
      |> WandererApp.Queue.to_list!()
      |> Enum.uniq()
      |> Enum.chunk_every(@maps_start_chunk_size)

    WandererApp.Queue.clear(@maps_queue)

    if @environment == :test do
      # In tests, run synchronously to avoid database ownership issues
      Logger.debug(fn -> "Starting maps synchronously in test mode" end)

      for chunk <- chunks do
        chunk
        |> Enum.each(&start_map_server/1)

        :timer.sleep(@maps_start_interval)
      end

      Logger.debug(fn -> "All maps started" end)
    else
      # In production, run async as normal
      chunks
      |> Task.async_stream(
        fn chunk ->
          chunk
          |> Enum.map(&start_map_server/1)

          :timer.sleep(@maps_start_interval)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.seconds(60)
      )
      |> Enum.each(fn result ->
        case result do
          {:ok, _} ->
            :ok

          _ ->
            :ok
        end
      end)

      Logger.info(fn -> "All maps started" end)
    end
  end

  defp start_map_server(map_id) do
    with {:ok, started_maps} <- WandererApp.Cache.lookup("started_maps", []),
         false <- Enum.member?(started_maps, map_id) do
      WandererApp.Cache.insert_or_update(
        "started_maps",
        [map_id],
        fn existing ->
          [map_id | existing] |> Enum.uniq()
        end
      )

      WandererApp.Map.MapPoolDynamicSupervisor.start_map(map_id)
    else
      _error ->
        Logger.warning("Map already started: #{map_id}")
        :ok
    end
  end
end
