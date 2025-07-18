defmodule WandererApp.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use WandererApp.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias WandererApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import WandererApp.DataCase

      # Import Ash test helpers
      import WandererAppWeb.Factory

      # Import test utilities
      import WandererApp.TestHelpers
    end
  end

  setup tags do
    WandererApp.DataCase.setup_sandbox(tags)

    # Set up integration test environment
    WandererApp.Test.IntegrationConfig.setup_integration_environment()
    WandererApp.Test.IntegrationConfig.setup_test_reliability_configs()

    # Ensure Mox is in global mode for each test
    # This prevents tests that set private mode from affecting other tests
    WandererApp.Test.MockAllowance.ensure_global_mocks()

    # Cleanup after test
    on_exit(fn ->
      WandererApp.Test.IntegrationConfig.cleanup_integration_environment()
    end)

    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # Ensure the repo is started before setting up sandbox
    unless Process.whereis(WandererApp.Repo) do
      {:ok, _} = WandererApp.Repo.start_link()
    end

    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WandererApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    # Store the sandbox owner pid for allowing background processes
    Process.put(:sandbox_owner_pid, pid)

    # Allow critical system processes to access the database
    allow_system_processes_database_access()
  end

  @doc """
  Allows a process to access the database by granting it sandbox access.
  This is necessary for background processes like map servers that need database access.
  """
  def allow_database_access(pid) when is_pid(pid) do
    owner_pid = Process.get(:sandbox_owner_pid)

    if owner_pid do
      Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, owner_pid, pid)
    end
  end

  @doc """
  Allows a process to access the database by granting it sandbox access with monitoring.
  This version provides enhanced monitoring for child processes.
  """
  def allow_database_access(pid, owner_pid) when is_pid(pid) and is_pid(owner_pid) do
    Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, owner_pid, pid)
    # Note: Skip the manager call to avoid recursion
  end

  @doc """
  Allows critical system processes to access the database during tests.
  This prevents DBConnection.OwnershipError for processes that are started
  during application boot and need database access.
  """
  def allow_system_processes_database_access do
    # List of system processes that may need database access during tests
    system_processes = [
      WandererApp.Map.Manager,
      WandererApp.Character.TrackerManager,
      WandererApp.Server.TheraDataFetcher,
      WandererApp.ExternalEvents.MapEventRelay,
      WandererApp.ExternalEvents.WebhookDispatcher,
      WandererApp.ExternalEvents.SseStreamManager
    ]

    Enum.each(system_processes, fn process_name ->
      case GenServer.whereis(process_name) do
        pid when is_pid(pid) ->
          allow_database_access(pid)

        _ ->
          :ok
      end
    end)
  end

  @doc """
  Grants database access to a process with comprehensive monitoring.

  This function provides enhanced database access granting with monitoring
  for child processes and automatic access granting.
  """
  def allow_database_access(pid, owner_pid \\ self()) do
    WandererApp.Test.DatabaseAccessManager.grant_database_access(pid, owner_pid)
  end

  @doc """
  Grants database access to a GenServer and all its child processes.
  """
  def allow_genserver_database_access(genserver_pid, owner_pid \\ self()) do
    WandererApp.Test.DatabaseAccessManager.grant_genserver_database_access(
      genserver_pid,
      owner_pid
    )
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Truncates all tables in the test database.
  Use with caution - this will delete all test data.
  """
  def truncate_all_tables do
    Ecto.Adapters.SQL.query!(
      WandererApp.Repo,
      "TRUNCATE #{tables_to_truncate()} RESTART IDENTITY CASCADE",
      []
    )
  end

  @doc """
  Resets the database to a clean state.
  """
  def reset_database do
    # Use checkout and checkin to reset sandbox mode
    Ecto.Adapters.SQL.Sandbox.checkout(WandererApp.Repo)
    Ecto.Adapters.SQL.Sandbox.checkin(WandererApp.Repo)
  end

  @doc """
  Waits for async operations to complete using polling.
  Useful when testing async processes.
  """
  # Backward compatibility - accepts just timeout
  def wait_for_async(timeout) when is_integer(timeout) do
    :timer.sleep(timeout)
  end

  def wait_for_async(condition_fn) when is_function(condition_fn) do
    wait_for_async(condition_fn, 1000)
  end

  def wait_for_async(condition_fn, timeout) when is_function(condition_fn) do
    wait_for_async_poll(condition_fn, timeout, 50)
  end

  defp wait_for_async_poll(condition_fn, timeout, interval) when timeout > 0 do
    if condition_fn.() do
      :ok
    else
      :timer.sleep(interval)
      wait_for_async_poll(condition_fn, timeout - interval, interval)
    end
  end

  defp wait_for_async_poll(_condition_fn, _timeout, _interval) do
    raise "Timeout waiting for async condition"
  end

  @doc """
  Asserts that an Ash action succeeds and returns the result.
  """
  def assert_ash_success({:ok, result}), do: result

  def assert_ash_success({:error, error}) do
    flunk("Expected Ash action to succeed, but got error: #{inspect(error)}")
  end

  @doc """
  Asserts that an Ash action fails with expected error.
  """
  def assert_ash_error({:error, _error} = result), do: result

  def assert_ash_error({:ok, result}) do
    flunk("Expected Ash action to fail, but got success: #{inspect(result)}")
  end

  @doc """
  Asserts that an Ash action fails with a specific error message.
  """
  def assert_ash_error({:error, error}, expected_message) when is_binary(expected_message) do
    error_string = inspect(error)

    assert error_string =~ expected_message,
           "Expected error to contain '#{expected_message}', but got: #{error_string}"

    {:error, error}
  end

  # Private helpers

  defp tables_to_truncate do
    "users, characters, maps, map_systems, map_connections, access_lists, access_list_members"
  end
end
