defmodule WandererApp.PerformanceTestFramework do
  @moduledoc """
  Performance testing framework that integrates with existing test infrastructure.

  Provides:
  - Performance-focused test macros
  - Load testing capabilities for API endpoints
  - Database performance testing
  - Memory leak detection
  - Benchmarking integration with Benchee
  """

  defmacro __using__(opts \\ []) do
    quote do
      import WandererApp.PerformanceTestFramework

      # Set up performance monitoring for each test
      setup do
        test_name = "#{__MODULE__}.#{unquote(opts[:test_name] || "unknown")}"
        test_type = unquote(opts[:test_type] || :unit_test)

        monitor_ref =
          case GenServer.whereis(WandererApp.EnhancedPerformanceMonitor) do
            nil ->
              # Performance monitor not started, use stub
              WandererApp.EnhancedPerformanceMonitor.start_test_monitoring(test_name, test_type)

            _pid ->
              # Performance monitor is running
              GenServer.call(
                WandererApp.EnhancedPerformanceMonitor,
                {:start_monitoring, test_name, test_type}
              )
          end

        on_exit(fn ->
          case GenServer.whereis(WandererApp.EnhancedPerformanceMonitor) do
            nil ->
              WandererApp.EnhancedPerformanceMonitor.stop_test_monitoring(monitor_ref)

            _pid ->
              GenServer.call(
                WandererApp.EnhancedPerformanceMonitor,
                {:stop_monitoring, monitor_ref}
              )
          end
        end)

        %{performance_monitor: monitor_ref}
      end
    end
  end

  @doc """
  Macro for performance-critical tests with specific budgets.

  ## Examples

      performance_test "should load user dashboard quickly", budget: 500 do
        # Test code that should complete within 500ms
      end
  """
  defmacro performance_test(description, opts \\ [], do: block) do
    budget = Keyword.get(opts, :budget, 1000)
    test_type = Keyword.get(opts, :type, :performance_test)

    quote do
      test unquote(description) do
        test_name = "#{__MODULE__}.#{unquote(description)}"

        # Set performance budget
        WandererApp.EnhancedPerformanceMonitor.set_performance_budget(
          unquote(test_type),
          unquote(budget)
        )

        # Monitor the test execution
        monitor_ref =
          WandererApp.EnhancedPerformanceMonitor.start_test_monitoring(
            test_name,
            unquote(test_type)
          )

        try do
          start_time = System.monotonic_time(:millisecond)
          result = unquote(block)
          end_time = System.monotonic_time(:millisecond)
          duration = end_time - start_time

          # Check if test exceeded budget
          if duration > unquote(budget) do
            flunk("Performance test exceeded budget: #{duration}ms > #{unquote(budget)}ms")
          end

          result
        after
          WandererApp.EnhancedPerformanceMonitor.stop_test_monitoring(monitor_ref)
        end
      end
    end
  end

  @doc """
  Benchmarks a function using Benchee and validates performance requirements.
  """
  defmacro benchmark_test(description, opts \\ [], do: block) do
    _iterations = Keyword.get(opts, :iterations, 1000)
    max_avg_time = Keyword.get(opts, :max_avg_time, 1000)

    quote do
      test unquote(description) do
        fun = fn -> unquote(block) end

        # Run benchmark
        benchmark_result =
          Benchee.run(
            %{"benchmark" => fun},
            time: 2,
            memory_time: 1,
            formatters: []
          )

        # Extract results - Benchee might return string keys instead of atoms
        results =
          case benchmark_result.scenarios do
            %{"benchmark" => data} -> data
            %{benchmark: data} -> data
            _ -> flunk("Unexpected benchmark result structure")
          end

        avg_time_ms = results.run_time_data.statistics.average / 1_000_000

        # Validate performance
        if avg_time_ms > unquote(max_avg_time) do
          flunk(
            "Benchmark failed: average time #{Float.round(avg_time_ms, 2)}ms exceeds limit #{unquote(max_avg_time)}ms"
          )
        end

        # Log benchmark results
        IO.puts("""
        📊 Benchmark Results for #{unquote(description)}:
           Average: #{Float.round(avg_time_ms, 2)}ms
           Min: #{Float.round(results.run_time_data.statistics.minimum / 1_000_000, 2)}ms
           Max: #{Float.round(results.run_time_data.statistics.maximum / 1_000_000, 2)}ms
           Memory: #{results.memory_usage_data.statistics.average} bytes
        """)
      end
    end
  end

  @doc """
  Load testing for API endpoints.
  """
  def load_test_endpoint(endpoint_config, load_config \\ %{}) do
    %{
      method: method,
      path: path,
      headers: headers,
      body: body
    } = endpoint_config

    %{
      concurrent_users: concurrent_users,
      duration_seconds: duration_seconds,
      ramp_up_seconds: ramp_up_seconds
    } =
      Map.merge(
        %{
          concurrent_users: 10,
          duration_seconds: 30,
          ramp_up_seconds: 5
        },
        load_config
      )

    # Start load testing
    tasks =
      for i <- 1..concurrent_users do
        Task.async(fn ->
          # Ramp up gradually
          Process.sleep(trunc(i * ramp_up_seconds * 1000 / concurrent_users))

          run_load_test_user(method, path, headers, body, duration_seconds)
        end)
      end

    # Collect results
    results = Task.await_many(tasks, (duration_seconds + ramp_up_seconds + 10) * 1000)

    analyze_load_test_results(results)
  end

  @doc """
  Memory leak detection test.
  """
  def memory_leak_test(test_function, iterations \\ 100) do
    initial_memory = :erlang.memory(:total)

    # Run test multiple times and collect memory samples
    memory_samples = run_memory_test_iterations(test_function, iterations, [])

    final_memory = :erlang.memory(:total)
    memory_growth = final_memory - initial_memory

    # Analyze memory trend
    memory_trend = analyze_memory_trend(Enum.reverse(memory_samples))

    %{
      initial_memory: initial_memory,
      final_memory: final_memory,
      memory_growth: memory_growth,
      memory_samples: Enum.reverse(memory_samples),
      # Consider leak if >1MB growth
      leak_detected: memory_growth > 1_000_000,
      trend_slope: memory_trend.slope
    }
  end

  defp run_memory_test_iterations(_test_function, 0, memory_samples) do
    memory_samples
  end

  defp run_memory_test_iterations(test_function, iterations, memory_samples) do
    test_function.()

    # Force garbage collection
    :erlang.garbage_collect()

    updated_samples =
      if rem(iterations, 10) == 0 do
        current_memory = :erlang.memory(:total)
        [current_memory | memory_samples]
      else
        memory_samples
      end

    run_memory_test_iterations(test_function, iterations - 1, updated_samples)
  end

  @doc """
  Database performance testing.
  """
  def database_performance_test(query_function, opts \\ %{}) do
    %{
      iterations: iterations,
      max_avg_time: max_avg_time,
      check_n_plus_one: check_n_plus_one
    } =
      Map.merge(
        %{
          iterations: 100,
          max_avg_time: 100,
          check_n_plus_one: true
        },
        opts
      )

    {query_times, query_counts} =
      run_database_iterations(query_function, iterations, check_n_plus_one, [], [])

    avg_time_ms = Enum.sum(query_times) / length(query_times) / 1000
    max_time_ms = Enum.max(query_times) / 1000
    min_time_ms = Enum.min(query_times) / 1000

    results = %{
      iterations: iterations,
      avg_time_ms: avg_time_ms,
      max_time_ms: max_time_ms,
      min_time_ms: min_time_ms,
      performance_ok: avg_time_ms <= max_avg_time
    }

    if check_n_plus_one and not Enum.empty?(query_counts) do
      avg_queries = Enum.sum(query_counts) / length(query_counts)
      max_queries = Enum.max(query_counts)

      Map.merge(results, %{
        avg_queries: avg_queries,
        max_queries: max_queries,
        n_plus_one_detected: max_queries > avg_queries * 2
      })
    else
      results
    end
  end

  defp run_database_iterations(_query_function, 0, _check_n_plus_one, query_times, query_counts) do
    {query_times, query_counts}
  end

  defp run_database_iterations(
         query_function,
         iterations,
         check_n_plus_one,
         query_times,
         query_counts
       ) do
    # Reset query counter
    Ecto.Adapters.SQL.Sandbox.allow(WandererApp.Repo, self(), self())

    # Count queries if N+1 detection is enabled
    query_count_before = if check_n_plus_one, do: get_query_count(), else: 0

    # Time the query
    {time_us, _result} = :timer.tc(query_function)
    updated_query_times = [time_us | query_times]

    updated_query_counts =
      if check_n_plus_one do
        query_count_after = get_query_count()
        [query_count_after - query_count_before | query_counts]
      else
        query_counts
      end

    run_database_iterations(
      query_function,
      iterations - 1,
      check_n_plus_one,
      updated_query_times,
      updated_query_counts
    )
  end

  @doc """
  Stress testing that gradually increases load until failure.
  """
  def stress_test(test_function, opts \\ %{}) do
    %{
      initial_load: initial_load,
      max_load: max_load,
      step_size: step_size,
      step_duration: step_duration
    } =
      Map.merge(
        %{
          initial_load: 1,
          max_load: 100,
          step_size: 5,
          step_duration: 10
        },
        opts
      )

    results =
      stress_test_loop(test_function, initial_load, max_load, step_size, step_duration, [])

    analyze_stress_test_results(Enum.reverse(results))
  end

  defp stress_test_loop(test_function, current_load, max_load, step_size, step_duration, results) do
    if current_load > max_load do
      results
    else
      IO.puts("🔥 Stress testing with load: #{current_load}")

      step_result = run_stress_test_step(test_function, current_load, step_duration)
      updated_results = [step_result | results]

      # Check if this step failed
      if step_result.success_rate < 0.95 do
        IO.puts("💥 Stress test failure detected at load: #{current_load}")
        updated_results
      else
        stress_test_loop(
          test_function,
          current_load + step_size,
          max_load,
          step_size,
          step_duration,
          updated_results
        )
      end
    end
  end

  ## Private Helper Functions

  defp run_load_test_user(method, path, headers, body, duration_seconds) do
    end_time = System.monotonic_time(:second) + duration_seconds

    requests = load_test_request_loop(method, path, headers, body, end_time, [])

    %{
      total_requests: length(requests),
      successful_requests: Enum.count(requests, & &1.success),
      avg_response_time:
        if(length(requests) > 0,
          do: Enum.sum(Enum.map(requests, & &1.duration_us)) / length(requests) / 1000,
          else: 0
        ),
      requests: requests
    }
  end

  defp load_test_request_loop(method, path, headers, body, end_time, requests) do
    if System.monotonic_time(:second) >= end_time do
      requests
    else
      start_time = System.monotonic_time(:microsecond)

      # Make HTTP request (simplified - in real implementation use HTTPoison or similar)
      result = make_http_request(method, path, headers, body)

      end_time_req = System.monotonic_time(:microsecond)
      duration_us = end_time_req - start_time

      request_result = %{
        duration_us: duration_us,
        status: result.status,
        success: result.status in 200..299
      }

      updated_requests = [request_result | requests]

      # Small delay to prevent overwhelming
      Process.sleep(10)

      load_test_request_loop(method, path, headers, body, end_time, updated_requests)
    end
  end

  defp make_http_request(_method, _path, _headers, _body) do
    # Placeholder - implement actual HTTP request
    %{status: 200, body: "OK"}
  end

  defp analyze_load_test_results(results) do
    total_requests = Enum.sum(Enum.map(results, & &1.total_requests))
    successful_requests = Enum.sum(Enum.map(results, & &1.successful_requests))
    success_rate = if total_requests > 0, do: successful_requests / total_requests, else: 0

    avg_response_times = Enum.map(results, & &1.avg_response_time)
    overall_avg_response = Enum.sum(avg_response_times) / length(avg_response_times)

    %{
      total_requests: total_requests,
      successful_requests: successful_requests,
      success_rate: success_rate,
      avg_response_time_ms: overall_avg_response,
      # Assuming 30 second test
      throughput_rps: total_requests / 30,
      performance_acceptable: success_rate >= 0.95 and overall_avg_response <= 1000
    }
  end

  defp analyze_memory_trend(memory_samples) do
    if length(memory_samples) < 2 do
      %{slope: 0, trend: :stable}
    else
      # Simple linear regression
      points = memory_samples |> Enum.with_index() |> Enum.map(fn {mem, i} -> {i, mem} end)
      slope = calculate_slope(points)

      trend =
        cond do
          slope > 100_000 -> :increasing
          slope < -100_000 -> :decreasing
          true -> :stable
        end

      %{slope: slope, trend: trend}
    end
  end

  defp calculate_slope(points) do
    n = length(points)
    sum_x = points |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    sum_y = points |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    sum_xy = points |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    sum_x2 = points |> Enum.map(fn {x, _} -> x * x end) |> Enum.sum()

    (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
  end

  defp get_query_count do
    # Placeholder - implement actual query counting
    # This would integrate with Ecto's telemetry or logging
    0
  end

  defp run_stress_test_step(test_function, load, duration) do
    # Run multiple concurrent instances of the test function
    tasks =
      for _i <- 1..load do
        Task.async(fn ->
          try do
            test_function.()
            :success
          rescue
            _ -> :failure
          end
        end)
      end

    # Wait for completion
    results = Task.await_many(tasks, duration * 1000)

    successful = Enum.count(results, &(&1 == :success))
    total = length(results)

    %{
      load: load,
      total_executions: total,
      successful_executions: successful,
      success_rate: successful / total,
      timestamp: DateTime.utc_now()
    }
  end

  defp analyze_stress_test_results(results) do
    max_successful_load =
      results
      |> Enum.filter(&(&1.success_rate >= 0.95))
      |> Enum.map(& &1.load)
      |> Enum.max(fn -> 0 end)

    breaking_point =
      results
      |> Enum.find(&(&1.success_rate < 0.95))
      |> case do
        nil -> nil
        result -> result.load
      end

    %{
      max_successful_load: max_successful_load,
      breaking_point: breaking_point,
      results: results,
      performance_summary: %{
        can_handle_load: max_successful_load,
        breaks_at_load: breaking_point,
        # Arbitrary threshold
        stress_test_passed: max_successful_load >= 10
      }
    }
  end
end
