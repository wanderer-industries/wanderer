defmodule WandererApp.Character.TrackerPoolSupervisor do
  @moduledoc false
  use Supervisor

  @name __MODULE__
  @registry :tracker_pool_registry
  @unique_registry :unique_tracker_pool_registry

  def start_link(_args) do
    Supervisor.start_link(@name, [], name: @name)
  end

  def init(_args) do
    children = [
      {Registry, [keys: :unique, name: @unique_registry]},
      {Registry, [keys: :duplicate, name: @registry]},
      {WandererApp.Character.TrackerPoolDynamicSupervisor, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 10)
  end
end
