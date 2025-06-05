defmodule WandererApp.Zkb.Supervisor do
  @moduledoc """
  Supervises the zKillboard-related processes.
  """

  use Supervisor

  @type child_spec :: Supervisor.child_spec()
  @type children :: [child_spec()]

  @doc """
  Start the supervisor.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(keyword()) :: {:ok, {Supervisor.strategy(), children()}}
  def init(_opts) do
    children = [
      # Static workers
      WandererApp.Zkb.Preloader,
      WandererApp.Zkb.Provider.Redisq
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
