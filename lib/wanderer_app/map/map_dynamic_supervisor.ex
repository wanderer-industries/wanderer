defmodule WandererApp.Map.DynamicSupervisor do
  @moduledoc """
  Dynamically starts a map server
  """

  use DynamicSupervisor

  require Logger

  alias WandererApp.Map.Server

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def _start_child(map_id) do
    child_spec = %{
      id: Server,
      start: {Server, :start_link, [map_id]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, _} ->
        :ok

      {:error, {:already_started, _}} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def which_children do
    Supervisor.which_children(__MODULE__)
  end
end
