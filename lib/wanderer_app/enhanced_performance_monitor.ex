defmodule WandererApp.EnhancedPerformanceMonitor do
  @moduledoc """
  Stub implementation of the Enhanced Performance Monitor.

  This provides minimal functionality to allow performance tests to run
  while the full implementation is being developed.
  """

  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start_test_monitoring(_test_name, _test_type) do
    # Return a fake monitor reference
    make_ref()
  end

  def stop_test_monitoring(_monitor_ref) do
    :ok
  end

  def set_performance_budget(_test_type, _budget) do
    :ok
  end

  def get_real_time_metrics do
    %{}
  end

  def get_performance_trends(_days) do
    []
  end

  def detect_performance_regressions do
    []
  end

  def generate_performance_dashboard do
    %{alerts: []}
  end

  # GenServer callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_call({:start_monitoring, _test_name, _test_type}, _from, state) do
    {:reply, make_ref(), state}
  end

  def handle_call({:stop_monitoring, _monitor_ref}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end
end
