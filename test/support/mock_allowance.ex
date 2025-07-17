defmodule WandererApp.Test.MockAllowance do
  @moduledoc """
  Comprehensive mock allowance system for integration tests.

  This module provides utilities to ensure that mocks are properly
  allowed for all processes spawned during integration tests.
  """

  @doc """
  Allows all configured mocks for a given process.

  This should be called for every process that will use mocked dependencies.
  """
  def allow_mocks_for_process(pid, owner_pid \\ self()) do
    if Code.ensure_loaded?(Mox) do
      try do
        # Allow DDRT mock for the process
        Mox.allow(Test.DDRTMock, owner_pid, pid)

        # Allow Logger mock for the process
        Mox.allow(Test.LoggerMock, owner_pid, pid)

        # Note: PubSub now uses real Phoenix.PubSub, no mocking needed

        :ok
      rescue
        # Ignore errors in case Mox is in global mode
        _ -> :ok
      end
    end
  end

  @doc """
  Sets up mock allowances for a GenServer and its potential child processes.

  This includes both the GenServer itself and any processes it might spawn.
  """
  def setup_genserver_mocks(genserver_pid, owner_pid \\ self()) do
    allow_mocks_for_process(genserver_pid, owner_pid)

    # Set up a monitor to automatically allow mocks for any child processes
    # This is a safety net for processes spawned by the GenServer
    if Process.alive?(genserver_pid) do
      spawn_link(fn ->
        Process.monitor(genserver_pid)
        monitor_for_child_processes(genserver_pid, owner_pid)
      end)
    end

    :ok
  end

  @doc """
  Ensures all mocks are set up in global mode for integration tests.

  This is called during test setup to ensure mocks work across all processes.
  """
  def ensure_global_mocks do
    if Code.ensure_loaded?(Mox) do
      Mox.set_mox_global()

      # Re-setup mocks to ensure they're available globally
      WandererApp.Test.Mocks.setup_mocks()
    end
  end

  # Private helper to monitor for child processes
  defp monitor_for_child_processes(parent_pid, owner_pid) do
    # Get initial process info
    initial_children = get_process_children(parent_pid)

    # Monitor for new processes
    :timer.sleep(100)

    current_children = get_process_children(parent_pid)
    new_children = current_children -- initial_children

    # Allow mocks for any new child processes
    Enum.each(new_children, fn child_pid ->
      allow_mocks_for_process(child_pid, owner_pid)
    end)

    # Continue monitoring if the parent is still alive
    if Process.alive?(parent_pid) do
      monitor_for_child_processes(parent_pid, owner_pid)
    end
  end

  # Get all child processes of a given process
  defp get_process_children(pid) do
    case Process.info(pid, :links) do
      {:links, links} ->
        links
        |> Enum.filter(&is_pid/1)
        |> Enum.filter(&Process.alive?/1)

      nil ->
        []
    end
  end
end
