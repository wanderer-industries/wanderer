defmodule WandererApp.Map.MapPoolSupervisor do
  @moduledoc false
  use Supervisor

  @name __MODULE__
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry

  def start_link(_args) do
    Supervisor.start_link(@name, [], name: @name)
  end

  def init(_args) do
    children = [
      {Registry, [keys: :unique, name: @unique_registry]},
      {Registry, [keys: :duplicate, name: @registry]},
      {WandererApp.Map.MapPoolDynamicSupervisor, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 10)
  end
end
