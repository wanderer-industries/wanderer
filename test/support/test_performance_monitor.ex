defmodule WandererApp.TestPerformanceMonitor do
  @moduledoc """
  Test performance monitoring utilities.

  This module provides functions to monitor test execution performance,
  track slow tests, and ensure test suite execution stays within acceptable limits.

  Based on testplan.md goal: Maximum 5 minutes for full test suite.
  """

  require Logger

  # 5 seconds for individual tests
  @performance_threshold_ms 5000
  # 5 minutes for full suite
  @suite_threshold_ms 300_000

  @doc """
  Starts performance monitoring for a test suite.
  Returns a reference that can be used to stop monitoring.
  """
  def start_suite_monitoring do
    start_time = System.monotonic_time(:millisecond)
    Process.put(:suite_start_time, start_time)

    Logger.info("🧪 Test suite performance monitoring started")
    start_time
  end

  @doc """
  Stops suite monitoring and reports results.
  """
  def stop_suite_monitoring do
    case Process.get(:suite_start_time) do
      nil ->
        Logger.warning("Suite monitoring was not started")

      start_time ->
        end_time = System.monotonic_time(:millisecond)
        duration_ms = end_time - start_time

        log_suite_performance(duration_ms)
        Process.delete(:suite_start_time)
        duration_ms
    end
  end

  @doc """
  Monitors execution time of a single test or block of code.
  """
  def monitor_test(test_name, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      log_test_performance(test_name, duration_ms)
      result
    rescue
      error ->
        end_time = System.monotonic_time(:millisecond)
        duration_ms = end_time - start_time

        Logger.warning("🧪 Test '#{test_name}' failed after #{duration_ms}ms: #{inspect(error)}")
        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Records test performance data for later analysis.
  This can be used in test setup/teardown to automatically track all test performance.
  """
  def record_test_time(test_name, duration_ms) do
    test_data = %{
      name: test_name,
      duration_ms: duration_ms,
      timestamp: DateTime.utc_now(),
      threshold_exceeded: duration_ms > @performance_threshold_ms
    }

    # Store in process dictionary for this test run
    existing_data = Process.get(:test_performance_data, [])
    Process.put(:test_performance_data, [test_data | existing_data])

    test_data
  end

  @doc """
  Gets all recorded test performance data for the current test run.
  """
  def get_performance_data do
    Process.get(:test_performance_data, [])
  end

  @doc """
  Clears recorded performance data.
  """
  def clear_performance_data do
    Process.delete(:test_performance_data)
  end

  @doc """
  Generates a performance report for the current test run.
  """
  def generate_performance_report do
    data = get_performance_data()

    if Enum.empty?(data) do
      "No performance data available"
    else
      total_tests = length(data)
      total_time = Enum.sum(Enum.map(data, & &1.duration_ms))
      slow_tests = Enum.filter(data, & &1.threshold_exceeded)
      avg_time = if total_tests > 0, do: total_time / total_tests, else: 0

      slowest_tests =
        data
        |> Enum.sort_by(& &1.duration_ms, :desc)
        |> Enum.take(5)

      """

      📊 Test Performance Report
      ========================

      Total Tests: #{total_tests}
      Total Time: #{format_duration(total_time)}
      Average Time: #{format_duration(trunc(avg_time))}
      Slow Tests (>#{@performance_threshold_ms}ms): #{length(slow_tests)}

      🐌 Slowest Tests:
      #{format_test_list(slowest_tests)}

      #{if length(slow_tests) > 0, do: format_slow_test_warning(slow_tests), else: "✅ All tests within performance threshold"}
      """
    end
  end

  @doc """
  Checks if the test suite execution time is within acceptable limits.
  """
  def suite_within_limits?(duration_ms) do
    duration_ms <= @suite_threshold_ms
  end

  @doc """
  Gets the current performance threshold for individual tests.
  """
  def performance_threshold_ms, do: @performance_threshold_ms

  @doc """
  Gets the current performance threshold for the full test suite.
  """
  def suite_threshold_ms, do: @suite_threshold_ms

  # Private helper functions

  defp log_suite_performance(duration_ms) do
    formatted_duration = format_duration(duration_ms)

    if suite_within_limits?(duration_ms) do
      Logger.info(
        "✅ Test suite completed in #{formatted_duration} (within #{format_duration(@suite_threshold_ms)} limit)"
      )
    else
      Logger.warning(
        "⚠️ Test suite took #{formatted_duration} (exceeds #{format_duration(@suite_threshold_ms)} limit)"
      )
    end
  end

  defp log_test_performance(test_name, duration_ms) do
    if duration_ms > @performance_threshold_ms do
      Logger.warning(
        "🐌 Slow test: '#{test_name}' took #{duration_ms}ms (threshold: #{@performance_threshold_ms}ms)"
      )
    else
      Logger.debug("🧪 Test '#{test_name}' completed in #{duration_ms}ms")
    end
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{div(ms, 60_000)}m #{rem(div(ms, 1000), 60)}s"

  defp format_test_list(tests) do
    tests
    |> Enum.with_index(1)
    |> Enum.map(fn {test, index} ->
      "  #{index}. #{test.name} - #{format_duration(test.duration_ms)}"
    end)
    |> Enum.join("\n")
  end

  defp format_slow_test_warning(slow_tests) do
    """
    ⚠️ Performance Warning:
    #{length(slow_tests)} tests exceeded the #{@performance_threshold_ms}ms threshold.
    Consider optimizing these tests or breaking them into smaller units.
    """
  end
end
