defmodule WandererApp.Map.RtreeDynamicSupervisor do
  @moduledoc """
  Dynamically starts a map server
  """

  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start(map_id) do
    case DynamicSupervisor.start_child(
           __MODULE__,
           {DDRT.DynamicRtree,
            [
              conf: [name: "rtree_#{map_id}", width: 150, verbose: false, seed: 0],
              name: Module.concat([map_id, DDRT.DynamicRtree])
            ]}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  def stop(map_id) do
    case Process.whereis(Module.concat([map_id, DDRT.DynamicRtree])) do
      nil -> :ok
      pid when is_pid(pid) -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  def which_children do
    Supervisor.which_children(__MODULE__)
  end
end
