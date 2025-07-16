defmodule WandererApp.Test.IntegrationMonitoring do
  @moduledoc """
  Monitoring and metrics collection for integration tests.

  This module provides utilities to monitor integration test performance,
  reliability, and resource usage.
  """

  @doc """
  Starts monitoring for an integration test.

  Returns a monitoring context that should be passed to stop_monitoring/1.
  """
  def start_monitoring(test_name) do
    start_time = System.monotonic_time(:millisecond)

    # Collect initial metrics
    initial_metrics = collect_system_metrics()

    # Set up test-specific monitoring
    monitoring_context = %{
      test_name: test_name,
      start_time: start_time,
      initial_metrics: initial_metrics,
      events: []
    }

    # Store monitoring context
    :persistent_term.put({:test_monitoring, self()}, monitoring_context)

    monitoring_context
  end

  @doc """
  Records an event during test execution.
  """
  def record_event(event_name, metadata \\ %{}) do
    case :persistent_term.get({:test_monitoring, self()}, nil) do
      nil ->
        :ok

      monitoring_context ->
        timestamp = System.monotonic_time(:millisecond)

        event = %{
          name: event_name,
          timestamp: timestamp,
          metadata: metadata
        }

        updated_context = %{
          monitoring_context
          | events: [event | monitoring_context.events]
        }

        :persistent_term.put({:test_monitoring, self()}, updated_context)
    end
  end

  @doc """
  Stops monitoring and returns test metrics.
  """
  def stop_monitoring do
    case :persistent_term.get({:test_monitoring, self()}, nil) do
      nil ->
        %{}

      monitoring_context ->
        end_time = System.monotonic_time(:millisecond)
        final_metrics = collect_system_metrics()

        # Calculate test metrics
        test_metrics =
          calculate_test_metrics(
            monitoring_context,
            end_time,
            final_metrics
          )

        # Log metrics if test took longer than threshold
        if test_metrics.duration_ms > 1000 do
          log_slow_test(monitoring_context.test_name, test_metrics)
        end

        # Clean up monitoring context
        :persistent_term.erase({:test_monitoring, self()})

        test_metrics
    end
  end

  @doc """
  Collects system metrics for monitoring.
  """
  def collect_system_metrics do
    %{
      memory_usage: get_memory_usage(),
      process_count: get_process_count(),
      database_connections: get_database_connection_count(),
      cache_size: get_cache_size()
    }
  end

  @doc """
  Analyzes test reliability over multiple runs.
  """
  def analyze_test_reliability(test_results) do
    total_runs = length(test_results)
    failures = Enum.count(test_results, fn result -> result.status == :failed end)

    success_rate = if total_runs > 0, do: (total_runs - failures) / total_runs, else: 0

    %{
      total_runs: total_runs,
      failures: failures,
      success_rate: success_rate,
      is_flaky: success_rate > 0.0 and success_rate < 1.0,
      is_reliable: success_rate >= 0.95
    }
  end

  @doc """
  Generates a monitoring report for integration tests.
  """
  def generate_monitoring_report(test_results) do
    # Group results by test name
    grouped_results = Enum.group_by(test_results, fn result -> result.test_name end)

    # Analyze each test
    test_analyses =
      Enum.map(grouped_results, fn {test_name, results} ->
        {test_name, analyze_test_reliability(results)}
      end)

    # Generate summary
    summary = generate_summary(test_analyses)

    %{
      summary: summary,
      test_analyses: test_analyses,
      generated_at: DateTime.utc_now()
    }
  end

  # Private helper functions

  defp calculate_test_metrics(monitoring_context, end_time, final_metrics) do
    duration_ms = end_time - monitoring_context.start_time

    %{
      test_name: monitoring_context.test_name,
      duration_ms: duration_ms,
      events: Enum.reverse(monitoring_context.events),
      memory_delta: final_metrics.memory_usage - monitoring_context.initial_metrics.memory_usage,
      process_delta:
        final_metrics.process_count - monitoring_context.initial_metrics.process_count,
      database_connections_delta:
        final_metrics.database_connections -
          monitoring_context.initial_metrics.database_connections,
      cache_size_delta: final_metrics.cache_size - monitoring_context.initial_metrics.cache_size
    }
  end

  defp get_memory_usage do
    :erlang.memory(:total)
  end

  defp get_process_count do
    :erlang.system_info(:process_count)
  end

  defp get_database_connection_count do
    try do
      # Get connection pool size
      case Process.whereis(WandererApp.Repo) do
        nil ->
          0

        _ ->
          # This is a simplified version - in a real implementation,
          # you'd query the actual connection pool
          5
      end
    rescue
      _ -> 0
    end
  end

  defp get_cache_size do
    try do
      case Process.whereis(WandererApp.Cache) do
        nil -> 0
        _ -> Cachex.size!(WandererApp.Cache)
      end
    rescue
      _ -> 0
    end
  end

  defp log_slow_test(test_name, metrics) do
    IO.puts("""
    [SLOW TEST] #{test_name} took #{metrics.duration_ms}ms
    Memory delta: #{metrics.memory_delta} bytes
    Process delta: #{metrics.process_delta}
    Events: #{length(metrics.events)}
    """)
  end

  defp generate_summary(test_analyses) do
    total_tests = length(test_analyses)
    reliable_tests = Enum.count(test_analyses, fn {_name, analysis} -> analysis.is_reliable end)
    flaky_tests = Enum.count(test_analyses, fn {_name, analysis} -> analysis.is_flaky end)

    reliability_percentage =
      if total_tests > 0 do
        reliable_tests / total_tests * 100
      else
        0
      end

    %{
      total_tests: total_tests,
      reliable_tests: reliable_tests,
      flaky_tests: flaky_tests,
      reliability_percentage: reliability_percentage
    }
  end
end
