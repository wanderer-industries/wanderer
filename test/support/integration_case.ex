defmodule WandererApp.IntegrationCase do
  @moduledoc """
  This module defines the test case for integration tests.

  Integration tests use shared sandbox mode (`shared: true`) when running async
  to avoid timing issues with dynamically spawned processes like MapPool GenServers
  that need database access immediately upon spawn.

  For async integration tests, shared mode allows:
  - MapPool GenServers to access the database without explicit allowance
  - Tests to run in parallel without complex permission granting
  - Reliable test execution without race conditions

  For synchronous integration tests, shared mode is disabled (shared: false)
  for better isolation.

  Use this case for:
  - API controller integration tests that spawn map servers
  - Tests involving dynamic supervision trees
  - Tests with background processes that immediately query the database

  Do NOT use this for:
  - Pure unit tests (use ExUnit.Case, async: true)
  - Tests requiring strict database isolation (use DataCase with async: false)
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias WandererApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import WandererApp.IntegrationCase

      # Import Ash test helpers
      import WandererAppWeb.Factory

      # Import test utilities
      import WandererApp.TestHelpers
    end
  end

  setup tags do
    WandererApp.IntegrationCase.setup_sandbox(tags)

    # Set up mocks for this test process
    WandererApp.Test.Mocks.setup_test_mocks()

    # Set up integration test environment
    WandererApp.Test.IntegrationConfig.setup_integration_environment()
    WandererApp.Test.IntegrationConfig.setup_test_reliability_configs()

    # Cleanup after test
    on_exit(fn ->
      WandererApp.Test.IntegrationConfig.cleanup_integration_environment()
    end)

    :ok
  end

  @doc """
  Sets up the sandbox with shared mode for async integration tests.

  For async tests (async: true):
  - Uses shared: true to allow dynamically spawned processes database access
  - Trades some isolation for reliability and simplicity

  For sync tests (async: false):
  - Uses shared: false for better isolation
  - Child processes require explicit allowance
  """
  def setup_sandbox(tags) do
    # Ensure the repo is started before setting up sandbox
    unless Process.whereis(WandererApp.Repo) do
      {:ok, _} = WandererApp.Repo.start_link()
    end

    # For integration tests:
    # - Use shared: true for async tests to avoid MapPool timing issues
    # - Use shared: false for sync tests for better isolation
    shared_mode = tags[:async] == true

    # Set up sandbox mode based on test type
    pid =
      if shared_mode do
        # For async tests with shared mode:
        # Checkout the sandbox connection instead of starting an owner
        # This allows multiple async tests to use the same connection pool
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(WandererApp.Repo)
        # Put the connection in shared mode
        Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, {:shared, self()})
        self()
      else
        # For sync tests, start a dedicated owner
        pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WandererApp.Repo, shared: false)
        on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
        pid
      end

    # Store the sandbox owner pid for allowing background processes
    Process.put(:sandbox_owner_pid, pid)

    # Allow critical system processes to access the database
    # This is still needed for processes that aren't dynamically spawned
    allow_system_processes_database_access()

    # For non-shared mode, set $callers to enable automatic allowance propagation
    unless shared_mode do
      Process.put(:"$callers", [pid])
    end
  end

  @doc """
  Allows a process to access the database by granting it sandbox access.
  This is necessary for background processes that need database access in non-shared mode.
  """
  def allow_database_access(pid) when is_pid(pid) do
    owner_pid = Process.get(:sandbox_owner_pid)

    if owner_pid do
      Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, owner_pid, pid)
    end
  end

  @doc """
  Allows critical system processes to access the database during tests.
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

    # Grant database access and mock ownership to MapPoolSupervisor and MapPoolDynamicSupervisor
    # Note: In shared mode, this is less critical, but still good for consistency
    owner_pid = Process.get(:sandbox_owner_pid) || self()

    case Process.whereis(WandererApp.Map.MapPoolSupervisor) do
      pid when is_pid(pid) ->
        WandererApp.Test.DatabaseAccessManager.grant_supervision_tree_access(pid, owner_pid)
        WandererApp.Test.MockOwnership.allow_supervision_tree(pid, owner_pid)

        # Additionally, monitor for new children and grant them mock access
        spawn_link(fn -> monitor_and_allow_children(pid, owner_pid) end)

      _ ->
        :ok
    end

    case Process.whereis(WandererApp.Map.MapPoolDynamicSupervisor) do
      pid when is_pid(pid) ->
        WandererApp.Test.DatabaseAccessManager.grant_supervision_tree_access(pid, owner_pid)
        WandererApp.Test.MockOwnership.allow_supervision_tree(pid, owner_pid)

        # Additionally, monitor for new children and grant them mock access
        spawn_link(fn -> monitor_and_allow_children(pid, owner_pid) end)

      _ ->
        :ok
    end
  end

  # Monitor for dynamically spawned children and grant them mock access
  defp monitor_and_allow_children(supervisor_pid, owner_pid, interval \\ 50) do
    if Process.alive?(supervisor_pid) do
      :timer.sleep(interval)

      # Get current children and grant them access
      try do
        case Supervisor.which_children(supervisor_pid) do
          children when is_list(children) ->
            children
            |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
            |> Enum.filter(&is_pid/1)
            |> Enum.filter(&Process.alive?/1)
            |> Enum.each(fn child_pid ->
              WandererApp.Test.MockOwnership.allow_mocks_for_process(child_pid, owner_pid)
            end)

          _ ->
            :ok
        end
      rescue
        _ -> :ok
      catch
        :exit, _ -> :ok
      end

      monitor_and_allow_children(supervisor_pid, owner_pid, interval)
    end
  end

  @doc """
  Grants database access to a GenServer and all its child processes.
  Only needed in non-shared mode.
  """
  def allow_genserver_database_access(genserver_pid, owner_pid \\ self()) do
    WandererApp.Test.DatabaseAccessManager.grant_genserver_database_access(
      genserver_pid,
      owner_pid
    )
  end
end
