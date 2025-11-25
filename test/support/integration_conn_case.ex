defmodule WandererAppWeb.IntegrationConnCase do
  @moduledoc """
  This module defines the test case for integration tests that require a connection.

  Integration tests use shared sandbox mode (`shared: true`) when running async
  to avoid timing issues with dynamically spawned processes like MapPool GenServers
  that need database access immediately upon spawn.

  This is specifically designed for API controller integration tests that:
  - Spawn map servers dynamically
  - Need database access in background processes
  - Run async for better performance

  The key difference from ConnCase:
  - Uses shared: true for async tests (avoiding MapPool timing issues)
  - Uses shared: false for sync tests (better isolation)

  Use this case for:
  - API controller integration tests
  - Tests involving map operations that spawn servers
  - Tests with real-time features requiring background processes

  Do NOT use this for:
  - Simple controller tests without map servers (use ConnCase)
  - Pure unit tests (use ExUnit.Case)
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint WandererAppWeb.Endpoint

      use WandererAppWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import WandererAppWeb.IntegrationConnCase

      # Import test utilities
      import WandererAppWeb.Factory
      import WandererApp.TestHelpers
    end
  end

  setup tags do
    WandererAppWeb.IntegrationConnCase.setup_sandbox(tags)

    # Set up mocks for this test process in global mode
    # Integration tests spawn processes (MapPool, etc.) that need mock access
    WandererApp.Test.Mocks.setup_test_mocks(mode: :global)

    # Set up integration test environment (including Map.Manager)
    WandererApp.Test.IntegrationConfig.setup_integration_environment()
    WandererApp.Test.IntegrationConfig.setup_test_reliability_configs()

    # Cleanup after test
    on_exit(fn ->
      WandererApp.Test.IntegrationConfig.cleanup_integration_environment()
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Sets up the sandbox with shared mode for async integration tests.

  For async tests (async: true):
  - Uses shared: true to allow dynamically spawned processes database access
  - Allows MapPool GenServers to query database immediately upon spawn

  For sync tests (async: false):
  - Uses shared: false for better isolation
  - Child processes require explicit allowance
  """
  def setup_sandbox(_tags) do
    # Ensure the repo is started before setting up sandbox
    unless Process.whereis(WandererApp.Repo) do
      {:ok, _} = WandererApp.Repo.start_link()
    end

    # For integration tests:
    # - Always use shared: true to avoid MapPool timing issues and ownership errors
    # - This requires tests to be synchronous (async: false) if they share the same case
    shared_mode = true

    # Set up sandbox mode - always use start_owner! for proper ownership setup
    # This ensures that spawned processes (like Ash transactions) can access the database
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WandererApp.Repo, shared: shared_mode)

    # Store the sandbox owner pid BEFORE registering on_exit
    # This ensures it's available for use in setup callbacks
    Process.put(:sandbox_owner_pid, pid)

    # Register cleanup - this will be called last (LIFO order)
    on_exit(fn ->
      # Only stop if the owner is still alive
      if Process.alive?(pid) do
        Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
      end
    end)

    # Allow critical system processes to access the database
    allow_system_processes_database_access()

    # For non-shared mode, set $callers to enable automatic allowance propagation
    unless shared_mode do
      Process.put(:"$callers", [pid])
    end
  end

  @doc """
  Allows a process to access the database by granting it sandbox access.
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
      WandererApp.ExternalEvents.SseStreamManager,
      # Task.Supervisor for Task.async_stream calls
      Task.Supervisor
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

  # Monitor for dynamically spawned children and grant them mock and database access
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
              # Grant both mock and database access
              WandererApp.Test.MockOwnership.allow_mocks_for_process(child_pid, owner_pid)
              allow_database_access(child_pid)
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
  Creates an active subscription for a map to bypass subscription checks in tests.
  """
  def create_active_subscription_for_map(map_id) do
    if WandererApp.Env.map_subscriptions_enabled?() do
      create_subscription_with_retry(map_id, 5)
    end

    :ok
  end

  # Helper to create subscription with retry logic for async tests
  defp create_subscription_with_retry(map_id, retries_left) when retries_left > 0 do
    case Ash.create(WandererApp.Api.MapSubscription, %{
           map_id: map_id,
           plan: :omega,
           characters_limit: 100,
           hubs_limit: 10,
           auto_renew?: true,
           active_till: DateTime.utc_now() |> DateTime.add(30, :day)
         }) do
      {:ok, subscription} ->
        subscription

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if it's a foreign key constraint error
        has_fkey_error =
          Enum.any?(errors, fn
            %Ash.Error.Changes.InvalidAttribute{private_vars: private_vars} ->
              Enum.any?(private_vars, fn
                {:constraint_type, :foreign_key} -> true
                _ -> false
              end)

            _ ->
              false
          end)

        if has_fkey_error do
          # Exponential backoff: wait longer on each retry
          sleep_time = (6 - retries_left) * 20 + 10
          Process.sleep(sleep_time)
          create_subscription_with_retry(map_id, retries_left - 1)
        else
          # If it's not a foreign key error, raise it
          raise "Failed to create map subscription: #{inspect(errors)}"
        end

      {:error, error} ->
        raise "Failed to create map subscription: #{inspect(error)}"
    end
  end

  defp create_subscription_with_retry(_map_id, 0) do
    raise "Failed to create map subscription after 5 retries: map_id foreign key constraint"
  end
end
