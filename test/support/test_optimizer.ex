defmodule WandererApp.Test.Optimizer do
  @moduledoc """
  Test execution optimizer for improved performance.

  Provides utilities for running tests more efficiently, including
  parallel execution strategies and resource management.
  """

  @doc """
  Optimize test database operations by running them in a single transaction
  when possible, reducing commit overhead.
  """
  def with_optimized_db(test_fn) do
    WandererApp.Repo.transaction(fn ->
      # Set up sandbox for this transaction
      Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, self(), self())

      try do
        result = test_fn.()
        # Always rollback to keep tests isolated
        WandererApp.Repo.rollback(:test_optimization)
        result
      rescue
        error ->
          WandererApp.Repo.rollback(:test_error)
          reraise error, __STACKTRACE__
      end
    end)
    |> case do
      {:error, :test_optimization} -> :ok
      {:error, :test_error} -> :error
      {:error, reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  Reduce database queries by preloading common associations
  in a single efficient query.
  """
  def preload_common_data do
    # Pre-warm commonly accessed data to reduce individual queries
    spawn(fn ->
      try do
        # Preload system data that's frequently accessed
        import Ecto.Query

        WandererApp.Repo.all(
          from s in WandererApp.Api.MapSolarSystem,
            limit: 100,
            preload: []
        )

        # Preload common lookup data
        WandererApp.Cache.warm_cache()
      rescue
        # Ignore errors in optimization
        _ -> :ok
      end
    end)
  end

  @doc """
  Configure ExUnit for optimal performance based on system capabilities.
  """
  def configure_optimal_settings do
    # Get system information
    cores = System.schedulers_online()
    memory_gb = get_memory_gb()

    # Calculate optimal settings
    max_cases = calculate_optimal_max_cases(cores, memory_gb)
    timeout = calculate_optimal_timeout(memory_gb)

    # Apply configuration
    ExUnit.configure(
      max_cases: max_cases,
      timeout: timeout,
      # Disable for performance
      capture_log: false,
      refute_receive_timeout: 100,
      # We'll control when tests run
      autorun: false
    )

    %{
      cores: cores,
      memory_gb: memory_gb,
      max_cases: max_cases,
      timeout: timeout
    }
  end

  @doc """
  Run tests with performance monitoring and automatic optimization.
  """
  def run_optimized_tests(test_pattern \\ nil) do
    config = configure_optimal_settings()
    IO.puts("🚀 Running tests with optimized configuration:")
    IO.puts("   Max concurrent cases: #{config.max_cases}")
    IO.puts("   Timeout: #{config.timeout}ms")
    IO.puts("   CPU cores: #{config.cores}")
    IO.puts("   Memory: #{config.memory_gb}GB")

    # Preload common data
    preload_common_data()

    # Start timing
    start_time = System.monotonic_time(:millisecond)

    # Run tests
    result =
      if test_pattern do
        ExUnit.run([test_pattern])
      else
        ExUnit.run()
      end

    # Calculate elapsed time
    elapsed = System.monotonic_time(:millisecond) - start_time

    IO.puts("✅ Tests completed in #{elapsed}ms")

    result
  end

  @doc """
  Set up database connection pool optimization for tests.
  """
  def optimize_db_pool do
    # Get current pool configuration
    current_config = WandererApp.Repo.config()

    # Calculate optimal pool size
    cores = System.schedulers_online()
    optimal_pool_size = max(cores * 2, 20) |> min(50)

    # Apply if different from current
    if current_config[:pool_size] != optimal_pool_size do
      IO.puts("📊 Optimizing DB pool size to #{optimal_pool_size}")

      # Note: In a real implementation, you'd need to restart the repo
      # with new configuration. For now, just log the recommendation.
      IO.puts("   Current: #{current_config[:pool_size]}")
      IO.puts("   Recommended: #{optimal_pool_size}")
    end
  end

  # Private helper functions

  defp get_memory_gb do
    case :memsup.get_system_memory_data() do
      data when is_list(data) ->
        case Keyword.get(data, :available_memory) || Keyword.get(data, :total_memory) do
          # Default fallback
          nil -> 8
          bytes -> max(bytes / (1024 * 1024 * 1024), 1) |> trunc()
        end

      # Default fallback
      _ ->
        8
    end
  rescue
    # Default fallback if memsup not available
    _ -> 8
  end

  defp calculate_optimal_max_cases(cores, memory_gb) do
    # Base calculation on cores, but consider memory constraints
    base_cases = cores

    # Adjust for memory - each test case can use significant memory
    # Assume ~128MB per test case max
    memory_limit = div(memory_gb * 1024, 128)

    # Take the minimum to avoid overwhelming system
    # Cap at 24 for stability
    [base_cases, memory_limit, 24]
    |> Enum.min()
    # Minimum of 4 for reasonable parallelization
    |> max(4)
  end

  defp calculate_optimal_timeout(memory_gb) do
    # Base timeout, adjusted for system capabilities
    # 30 seconds base
    base_timeout = 30_000

    # Reduce timeout on systems with more memory (assumed to be faster)
    if memory_gb >= 16 do
      base_timeout
    else
      # Add 15s for slower systems
      base_timeout + 15_000
    end
  end
end
