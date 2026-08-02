defmodule WandererApp.ExternalEvents.Discord.WorkerSupervisor do
  @moduledoc """
  Starts one delivery worker per map on demand, addressed through a Registry.

  Workers are transient: they own an in-memory queue, shut down when idle, and
  are not restarted with their queue intact. Losing a queued notification on
  crash is acceptable; duplicating a delivered one is not.
  """

  use Supervisor

  require Logger

  alias WandererApp.ExternalEvents.Discord.Worker

  @registry WandererApp.ExternalEvents.Discord.Registry
  @dyn_sup WandererApp.ExternalEvents.Discord.DynamicSupervisor

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {Task.Supervisor, name: WandererApp.ExternalEvents.Discord.TaskSupervisor},
      {DynamicSupervisor, name: @dyn_sup, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Enqueues messages for a map, starting its worker if it is not running.

  Takes the notification *id*, never the record: the worker reloads it just
  before each send so a replaced or deleted webhook is not used, and so a stale
  `consecutive_failures` snapshot cannot corrupt the counter.
  """
  def deliver(_map_id, _notification_id, []), do: :ok

  def deliver(map_id, notification_id, messages) do
    case ensure_worker(map_id) do
      {:ok, pid} ->
        Worker.enqueue(pid, notification_id, messages)

      {:error, reason} ->
        Logger.warning("[Discord] could not start worker for #{map_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops a map's delivery worker if one is running, discarding its queue.

  Called from the resource's custom destroy: without it, a removed webhook keeps
  receiving whatever was already queued. A no-op when the worker infrastructure
  is not running at all (e.g. webhooks globally disabled, or in tests that do
  not start this supervisor).
  """
  def stop_worker(map_id) do
    case Process.whereis(@registry) do
      nil ->
        :ok

      _ ->
        case Registry.lookup(@registry, map_id) do
          # The worker may have idled out or crashed between the lookup and the
          # stop; either way the post-condition (no worker running) holds.
          [{pid, _}] -> try_stop(pid)
          [] -> :ok
        end

        :ok
    end
  end

  defp try_stop(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _ -> :ok
  end

  defp ensure_worker(map_id) do
    case Registry.lookup(@registry, map_id) do
      # Registry releases a dead owner's key asynchronously, so a lookup can
      # still return a pid that has just exited (idle shutdown or stop_worker).
      [{pid, _}] when is_pid(pid) ->
        if Process.alive?(pid), do: {:ok, pid}, else: start_worker(map_id)

      [] ->
        start_worker(map_id)
    end
  end

  defp start_worker(map_id) do
    spec = {Worker, map_id: map_id, registry: @registry}

    case DynamicSupervisor.start_child(@dyn_sup, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  def registry, do: @registry
end
