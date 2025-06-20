defmodule WandererApp.TestCleanup do
  @moduledoc """
  Helper module for cleaning up test data and processes between test runs.

  This helps prevent race conditions and ensures test isolation.
  """

  @doc """
  Stops all named processes that might be running from previous tests.
  """
  def cleanup_processes do
    processes_to_stop = [
      WandererApp.Test.EsiMock,
      WandererApp.Test.MapServerMock
    ]

    Enum.each(processes_to_stop, fn process_name ->
      case Process.whereis(process_name) do
        nil ->
          :ok

        pid ->
          Process.exit(pid, :kill)
          # Wait a bit for process to fully terminate
          Process.sleep(10)
      end
    end)
  end

  @doc """
  Ensures all async tasks are completed before proceeding.
  """
  def wait_for_async_tasks do
    # Give async operations time to complete
    Process.sleep(50)
  end

  @doc """
  Full cleanup routine for tests.
  """
  def cleanup do
    cleanup_processes()
    wait_for_async_tasks()
  end
end
