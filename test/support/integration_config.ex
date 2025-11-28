defmodule WandererApp.Test.IntegrationConfig do
  @moduledoc """
  Configuration utilities for integration tests.

  This module provides utilities to configure the application for integration
  tests, including deciding when to use real dependencies vs mocks.
  """

  @doc """
  Configures the test environment for integration tests.

  This sets up the application to use real dependencies where appropriate
  for integration testing, while still maintaining isolation.
  """
  def setup_integration_environment do
    # Use real PubSub for integration tests
    Application.put_env(:wanderer_app, :pubsub_client, Phoenix.PubSub)

    # Use real cache for integration tests (but with shorter TTLs)
    configure_cache_for_tests()

    # Ensure PubSub server is started for integration tests
    ensure_pubsub_server()

    # Ensure map supervisors are started for map-related integration tests
    ensure_map_supervisors_started()

    :ok
  end

  @doc """
  Configures cache settings optimized for integration tests.
  """
  def configure_cache_for_tests do
    # Set shorter TTLs for cache entries in tests
    Application.put_env(:wanderer_app, :cache_ttl, :timer.seconds(10))

    # Ensure cache is started
    case Process.whereis(WandererApp.Cache) do
      nil ->
        {:ok, _} = WandererApp.Cache.start_link([])

      _ ->
        :ok
    end
  end

  @doc """
  Ensures PubSub server is available for integration tests.
  """
  def ensure_pubsub_server do
    case Process.whereis(WandererApp.PubSub) do
      nil ->
        # PubSub should be started by the application supervisor
        # If it's not started, there's a configuration issue
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Ensures map supervisors are started for integration tests.

  This starts both MapPoolSupervisor and Map.Manager which are
  required for character location tracking and map management tests.

  IMPORTANT: MapPoolSupervisor must be started BEFORE Map.Manager
  because Map.Manager depends on the registries created by MapPoolSupervisor.
  """
  def ensure_map_supervisors_started do
    # Start MapPoolSupervisor FIRST if not running
    # This supervisor creates the required registries (:map_pool_registry, :unique_map_pool_registry)
    # and starts MapPoolDynamicSupervisor
    case Process.whereis(WandererApp.Map.MapPoolSupervisor) do
      nil ->
        {:ok, _} = WandererApp.Map.MapPoolSupervisor.start_link([])

      _ ->
        :ok
    end

    # Wait for MapPoolDynamicSupervisor to be ready using efficient polling
    # instead of a fixed 100ms sleep
    wait_for_process(WandererApp.Map.MapPoolDynamicSupervisor, 2000)

    # Start Map.Manager AFTER MapPoolSupervisor
    case GenServer.whereis(WandererApp.Map.Manager) do
      nil ->
        {:ok, _} = WandererApp.Map.Manager.start_link([])

      _ ->
        :ok
    end

    :ok
  end

  # Efficiently wait for a process to be registered
  defp wait_for_process(name, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_process(name, deadline)
  end

  defp do_wait_for_process(name, deadline) do
    case Process.whereis(name) do
      pid when is_pid(pid) ->
        :ok

      nil ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(5)
          do_wait_for_process(name, deadline)
        else
          :ok
        end
    end
  end

  @doc """
  Cleans up integration test environment.

  This should be called after integration tests to clean up any
  state that might affect other tests.
  """
  def cleanup_integration_environment do
    # Clear cache
    if Process.whereis(WandererApp.Cache) do
      try do
        Cachex.clear(WandererApp.Cache)
      rescue
        _ -> :ok
      end
    end

    # Note: PubSub cleanup is handled by Phoenix during test shutdown
    # Note: Map supervisors are not cleaned up here as they may be shared
    # across tests and should persist for the test session

    :ok
  end

  @doc """
  Determines whether to use real dependencies or mocks for a given service.

  This allows fine-grained control over which services use real implementations
  in integration tests.
  """
  def use_real_dependency?(service) do
    case service do
      :pubsub -> true
      :cache -> true
      # Keep DDRT mocked for performance
      :ddrt -> false
      # Keep Logger mocked to avoid test output noise
      :logger -> false
      # Keep external APIs mocked
      :external_apis -> false
      _ -> false
    end
  end

  @doc """
  Sets up test-specific configurations that improve test reliability.
  """
  def setup_test_reliability_configs do
    # Disable async loading to prevent database ownership issues
    Application.put_env(:ash, :disable_async?, true)

    # Increase database connection pool size for integration tests
    configure_database_pool()

    # Set up error tracking for tests
    configure_error_tracking()

    :ok
  end

  defp configure_database_pool do
    # Increase pool size for integration tests
    current_config = Application.get_env(:wanderer_app, WandererApp.Repo, [])
    new_config = Keyword.put(current_config, :pool_size, 25)
    Application.put_env(:wanderer_app, WandererApp.Repo, new_config)
  end

  defp configure_error_tracking do
    # Configure error tracking to be less noisy in tests
    Application.put_env(:error_tracker, :enabled, false)
  end
end
