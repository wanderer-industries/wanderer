defmodule WandererApp.Kills.Supervisor do
  @moduledoc """
  Supervisor for the kills subsystem.
  """
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Task.Supervisor, name: WandererApp.Kills.TaskSupervisor},
      {WandererApp.Kills.Subscription.SystemMapIndex, []},
      {WandererApp.Kills.Client, []},
      {WandererApp.Kills.MapEventListener, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
