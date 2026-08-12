defmodule WandererApp.IntegrationCase do
  @moduledoc """
  This module defines the test case for integration tests.

  Integration tests default to a private sandbox owner. Suites that start real
  map servers must opt into shared sandbox mode:

      use WandererApp.IntegrationCase, async: false
      @moduletag :shared_sandbox

  Shared mode is required when a dynamically spawned process queries the
  database immediately upon spawn (MapPool GenServers load map state during
  `init`), because there is no window in which the test process can allow it
  onto the connection first.

  Shared mode is node-global, so it is opt-in and reverted on exit. It is only
  valid with `async: false`.

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
  Sets up the test sandbox, per the `:shared_sandbox` moduletag.

  With `@moduletag :shared_sandbox` (only valid with `async: false`):
  - Uses shared: true so dynamically spawned processes (e.g. MapPool
    GenServers that query the DB during `init`) get database access
  - Trades some isolation for reliability with background processes

  Without the tag (the default):
  - Starts a dedicated, private sandbox owner (shared: false)
  - Child processes require explicit allowance

  Raises `ArgumentError` if `:shared_sandbox` is set on an `async: true` suite.
  """
  def setup_sandbox(tags) do
    # Ensure the repo is started before setting up sandbox
    unless Process.whereis(WandererApp.Repo) do
      {:ok, _} = WandererApp.Repo.start_link()
    end

    # Shared mode is opt-in per suite via `@moduletag :shared_sandbox`.
    #
    # Suites that start real map servers need it: MapPool GenServers are spawned
    # dynamically and load map state from the DB *during init*, so there is no
    # point at which the test process can allow them onto the connection first
    # (polling loses the race). Shared mode is the only mechanism that covers a
    # process that queries immediately upon spawn.
    #
    # It is opt-in rather than global because Sandbox shared mode applies to the
    # whole node: enabling it for every sync integration suite regresses suites
    # that rely on owner-private connections. Ecto only permits shared mode when
    # the test is not async, so the tag is rejected on async suites.
    shared_mode = tags[:shared_sandbox] == true

    if shared_mode and tags[:async] == true do
      raise ArgumentError,
            "#{inspect(tags[:module])} sets @moduletag :shared_sandbox but is `async: true`. " <>
              "Ecto sandbox shared mode is node-global and is only safe with `async: false`."
    end

    # Set up sandbox mode based on test type
    pid =
      if shared_mode do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(WandererApp.Repo)
        Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, {:shared, self()})

        # Shared mode is node-global, so it MUST be reverted to :manual when the
        # test ends. Leaving it set leaks into every later suite on the node and
        # is why an earlier global-flip attempt broke unrelated controller tests.
        on_exit(fn ->
          Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)
        end)

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
  def allow_database_access(pid, owner_pid \\ nil) when is_pid(pid) do
    owner_pid = owner_pid || Process.get(:sandbox_owner_pid)

    if owner_pid do
      # Returns `:ok | {:already, :owner | :allowed}` on every poll tick;
      # re-allowing an already-allowed process is a normal, non-error case, so
      # both are treated as success here. It raises only for infrastructure
      # faults (repo not started, or `pid`/`owner_pid` not resolving to a live
      # process) -- those should surface rather than be swallowed.
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
              # Grant BOTH mock ownership and Ecto sandbox access.
              #
              # MapPool GenServers are spawned dynamically *after* the one-shot
              # grant_supervision_tree_access/2 call above has already run, so
              # they are never on the sandbox connection. Their map-state
              # loaders (Task.async in Map.Server.Impl.do_init_state/1) then die
              # with DBConnection.OwnershipError, the error is reported as
              # "map not loaded", and the test surfaces only a misleading
              # "Timeout waiting for map ... Check Map.Manager is running".
              #
              # Sandbox.allow/3 also propagates to the pool's Task.async
              # children via $callers, which is what the loaders rely on.
              #
              # owner_pid is passed explicitly: this runs inside the spawned
              # monitor process, where the :sandbox_owner_pid process dict entry
              # set by setup_sandbox/1 is not visible.
              allow_database_access(child_pid, owner_pid)
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
