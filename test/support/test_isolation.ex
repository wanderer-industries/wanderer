defmodule WandererApp.Test.TestIsolation do
  @moduledoc """
  Comprehensive test isolation strategy for integration tests.

  This module provides utilities to ensure that integration tests are properly
  isolated from each other while still testing realistic scenarios.
  """

  @doc """
  Isolates a test by setting up proper boundaries and cleanup.

  This should be called at the beginning of integration tests that need
  to spawn real GenServers or other stateful processes.
  """
  def isolate_test(test_name, opts \\ []) do
    # Set up unique test namespace
    test_namespace = "test_#{System.unique_integer()}_#{test_name}"

    # Configure isolation boundaries
    setup_process_isolation(test_namespace, opts)
    setup_data_isolation(test_namespace, opts)
    setup_cache_isolation(test_namespace, opts)

    # Return cleanup function
    fn ->
      cleanup_test_isolation(test_namespace)
    end
  end

  @doc """
  Determines the appropriate isolation level for a test.

  Returns one of:
  - :unit - Mock everything, test in isolation
  - :integration - Use real dependencies, test interactions
  - :system - Use real system, test end-to-end
  """
  def determine_isolation_level(test_module, test_name) do
    cond do
      # Unit tests should be fully isolated
      String.contains?(to_string(test_module), "Unit") ->
        :unit

      # Integration tests should use real dependencies where safe
      String.contains?(to_string(test_module), "Integration") ->
        :integration

      # System tests should use real system
      String.contains?(to_string(test_module), "System") ->
        :system

      # Default to unit test isolation
      true ->
        :unit
    end
  end

  @doc """
  Sets up process isolation for a test.

  This ensures that GenServers and other processes spawned during
  the test don't interfere with other tests.
  """
  def setup_process_isolation(test_namespace, opts) do
    # Set up process group for this test
    case Process.whereis(test_namespace) do
      nil ->
        {:ok, _} = Registry.start_link(keys: :unique, name: test_namespace)

      _ ->
        :ok
    end

    # Configure process naming to use test namespace
    configure_process_naming(test_namespace, opts)
  end

  @doc """
  Sets up data isolation for a test.

  This ensures that database changes and other data modifications
  don't leak between tests.
  """
  def setup_data_isolation(test_namespace, opts) do
    # Database isolation is handled by Ecto.Adapters.SQL.Sandbox
    # This function can be extended for other data stores

    # Set up cache namespace
    cache_namespace = "#{test_namespace}_cache"
    configure_cache_namespace(cache_namespace, opts)

    # Set up PubSub topic isolation
    pubsub_namespace = "#{test_namespace}_pubsub"
    configure_pubsub_namespace(pubsub_namespace, opts)
  end

  @doc """
  Sets up cache isolation for a test.

  This ensures that cache entries from one test don't affect another.
  """
  def setup_cache_isolation(test_namespace, opts) do
    # Clear any existing cache entries that might affect this test
    if Process.whereis(WandererApp.Cache) do
      try do
        Cachex.clear(WandererApp.Cache)
      rescue
        _ -> :ok
      end
    end

    # Set up cache key prefixing for this test
    cache_prefix = "#{test_namespace}:"
    configure_cache_prefix(cache_prefix, opts)
  end

  @doc """
  Cleans up all isolation artifacts for a test.
  """
  def cleanup_test_isolation(test_namespace) do
    # Clean up process registry
    if Process.whereis(test_namespace) do
      Registry.stop(test_namespace)
    end

    # Clean up cache entries
    cleanup_cache_namespace(test_namespace)

    # Clean up PubSub subscriptions
    cleanup_pubsub_namespace(test_namespace)

    :ok
  end

  # Private helper functions

  defp configure_process_naming(test_namespace, _opts) do
    # This could be extended to configure process naming
    # For now, we rely on the registry setup
    :ok
  end

  defp configure_cache_namespace(cache_namespace, _opts) do
    # Set up cache namespace in persistent term for fast access
    :persistent_term.put({:cache_namespace, self()}, cache_namespace)
  end

  defp configure_cache_prefix(cache_prefix, _opts) do
    # Set up cache prefix in persistent term for fast access
    :persistent_term.put({:cache_prefix, self()}, cache_prefix)
  end

  defp configure_pubsub_namespace(pubsub_namespace, _opts) do
    # Set up PubSub namespace in persistent term for fast access
    :persistent_term.put({:pubsub_namespace, self()}, pubsub_namespace)
  end

  defp cleanup_cache_namespace(test_namespace) do
    # Clean up cache entries for this test
    if Process.whereis(WandererApp.Cache) do
      try do
        # Get all keys with this test namespace
        keys = Cachex.keys!(WandererApp.Cache)

        test_keys =
          Enum.filter(keys, fn key ->
            String.contains?(to_string(key), test_namespace)
          end)

        # Delete test-specific keys
        Enum.each(test_keys, fn key ->
          Cachex.del(WandererApp.Cache, key)
        end)
      rescue
        _ -> :ok
      end
    end
  end

  defp cleanup_pubsub_namespace(test_namespace) do
    # Clean up PubSub subscriptions for this test
    # This is handled automatically by Phoenix.PubSub when processes exit
    :ok
  end
end
