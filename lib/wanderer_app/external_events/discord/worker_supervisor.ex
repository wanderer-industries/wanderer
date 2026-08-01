defmodule WandererApp.ExternalEvents.Discord.WorkerSupervisor do
  @moduledoc """
  Owns the per-map Discord delivery workers.

  Filled in by a later task; for now only `stop_worker/1` exists so the Ash
  resource's destroy hook can reference it.
  """

  @registry WandererApp.ExternalEvents.Discord.Registry

  @doc """
  Stops a map's delivery worker if one is running. A no-op when the worker
  infrastructure is not started (e.g. webhooks globally disabled).
  """
  def stop_worker(map_id) do
    case Process.whereis(@registry) do
      nil ->
        :ok

      _ ->
        case Registry.lookup(@registry, map_id) do
          [{pid, _}] -> GenServer.stop(pid, :normal)
          [] -> :ok
        end

        :ok
    end
  end
end
