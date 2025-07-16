defmodule WandererApp.TestMonitor do
  @moduledoc """
  Stub implementation of the Test Monitor.
  """

  def generate_report do
    %{}
  end
end

defmodule WandererApp.TestMonitor.ExUnitFormatter do
  @moduledoc """
  Stub ExUnit formatter for performance monitoring.
  """

  use GenServer

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_cast(_event, state) do
    {:noreply, state}
  end
end
