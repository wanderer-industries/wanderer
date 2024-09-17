defmodule WandererApp.Character.TrackerSupervisor do
  @moduledoc false
  use Supervisor, restart: :transient

  alias WandererApp.Character.Tracker

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)

  @impl true
  def init(args) do
    children = [
      {Tracker, args}
    ]

    Supervisor.init(children, strategy: :one_for_one, auto_shutdown: :all_significant)
  end
end
