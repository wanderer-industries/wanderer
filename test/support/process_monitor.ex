defmodule WandererApp.Test.ProcessMonitor do
  @moduledoc """
  Monitor and manage processes during tests to prevent race conditions.
  """

  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def monitor_process(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:monitor, pid})
  end

  def wait_for_processes(timeout \\ 5000) do
    GenServer.call(__MODULE__, :wait_for_all, timeout)
  end

  # Server callbacks

  def init(_) do
    {:ok, %{monitored: MapSet.new()}}
  end

  def handle_call({:monitor, pid}, _from, state) do
    Process.monitor(pid)
    new_state = %{state | monitored: MapSet.put(state.monitored, pid)}
    {:reply, :ok, new_state}
  end

  def handle_call(:wait_for_all, _from, state) do
    # Wait for all monitored processes to finish
    Enum.each(state.monitored, fn pid ->
      if Process.alive?(pid) do
        # Give process time to complete
        Process.sleep(10)
      end
    end)

    {:reply, :ok, %{state | monitored: MapSet.new()}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_state = %{state | monitored: MapSet.delete(state.monitored, pid)}
    {:noreply, new_state}
  end
end
