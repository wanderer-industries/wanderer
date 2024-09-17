defmodule WandererApp.Map.ServerSupervisor do
  @moduledoc false
  use Supervisor, restart: :transient

  alias WandererApp.Map.Server

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)

  @impl true
  def init(args) do
    children = [
      {Server, args},
      {DDRT.DynamicRtree,
       [
         conf: [name: "rtree_#{args[:map_id]}", width: 150, verbose: false, seed: 0],
         name: Module.concat([args[:map_id], DDRT.DynamicRtree])
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one, auto_shutdown: :any_significant)
  end
end
