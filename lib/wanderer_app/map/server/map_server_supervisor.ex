defmodule WandererApp.Map.ServerSupervisor do
  @moduledoc false
  use Supervisor, restart: :transient

  alias WandererApp.Map.Server
  alias WandererApp.Map.CacheRTree

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)

  @impl true
  def init(args) do
    # Initialize cache-based R-tree (no GenServer needed)
    map_id = args[:map_id]
    rtree_name = "rtree_#{map_id}"
    CacheRTree.init_tree(rtree_name, %{width: 150, verbose: false})

    children = [
      {Server, args}
    ]

    Supervisor.init(children, strategy: :one_for_one, auto_shutdown: :any_significant)
  end
end
