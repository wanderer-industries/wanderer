defmodule WandererApp.Map.MapPoolSupervisor do
  @moduledoc false
  use Supervisor

  alias WandererApp.Map.MapPoolState

  @name __MODULE__
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry

  def start_link(_args) do
    Supervisor.start_link(@name, [], name: @name)
  end

  def init(_args) do
    # Initialize ETS table for MapPool state persistence
    # This table survives individual MapPool crashes but is lost on node restart
    MapPoolState.init_table()

    children = [
      {Registry, [keys: :unique, name: @unique_registry]},
      {Registry, [keys: :duplicate, name: @registry]},
      {WandererApp.Map.MapPoolDynamicSupervisor, []},
      {WandererApp.Map.Reconciler, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 10)
  end
end
