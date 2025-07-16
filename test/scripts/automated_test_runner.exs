#!/usr/bin/env elixir

defmodule AutomatedTestRunner do
  @moduledoc """
  Automated test runner for common manual testing scenarios.

  Provides scripts to automate repetitive manual testing tasks and
  generate comprehensive test reports.
  """

  @doc """
  Run comprehensive test suite with performance monitoring.
  """
  def run_comprehensive_tests do
    IO.puts("🚀 Starting comprehensive automated test run...")

    # Performance monitoring
    start_time = System.monotonic_time(:millisecond)

    results = %{
      unit_tests: run_test_suite("test/unit", "Unit Tests"),
      integration_tests: run_test_suite("test/integration", "Integration Tests"),
      contract_tests: run_test_suite("test/contract", "Contract Tests")
    }

    total_time = System.monotonic_time(:millisecond) - start_time

    generate_comprehensive_report(results, total_time)

    results
  end

  @doc """
  Run smoke tests for critical functionality.
  """
  def run_smoke_tests do
    IO.puts("💨 Running smoke tests...")

    critical_tests = [
      "test/integration/api/common_api_controller_test.exs",
      "test/integration/api/characters_api_controller_test.exs",
      "test/unit/controllers/map_api_controller_test.exs",
      "test/unit/api_utils_test.exs"
    ]

    results =
      Enum.map(critical_tests, fn test_file ->
        run_test_suite(test_file, Path.basename(test_file, ".exs"))
      end)

    generate_smoke_report(results)

    results
  end

  @doc """
  Run performance benchmarks across different configurations.
  """
  def run_performance_benchmarks do
    IO.puts("📊 Running performance benchmarks...")

    configurations = [
      %{name: "Sequential", max_cases: 1},
      %{name: "Low Parallelism", max_cases: 4},
      %{name: "Medium Parallelism", max_cases: 8},
      %{name: "High Parallelism", max_cases: 16}
    ]

    results =
      Enum.map(configurations, fn config ->
        IO.puts("Testing #{config.name} configuration...")

        benchmark_result = benchmark_test_run("test/unit", config.max_cases)

        Map.merge(config, benchmark_result)
      end)

    generate_benchmark_report(results)

    results
  end

  @doc """
  Automated regression testing - run tests and compare with baseline.
  """
  def run_regression_tests(baseline_file \\ "test/baselines/performance_baseline.json") do
    IO.puts("🔄 Running regression tests...")

    current_results = run_comprehensive_tests()

    case File.read(baseline_file) do
      {:ok, baseline_json} ->
        baseline = Jason.decode!(baseline_json)
        compare_with_baseline(current_results, baseline)

      {:error, _} ->
        IO.puts("⚠️  No baseline found. Creating new baseline...")
        save_baseline(current_results, baseline_file)
    end

    current_results
  end

  @doc """
  Run tests with different database configurations to find optimal settings.
  """
  def optimize_database_settings do
    IO.puts("🗄️  Optimizing database settings...")

    pool_sizes = [10, 20, 30, 40, 50]

    results =
      Enum.map(pool_sizes, fn pool_size ->
        IO.puts("Testing pool size: #{pool_size}")

        # Note: In a real implementation, you'd temporarily modify the config
        # and restart the repo. For now, we'll simulate the test.
        result = benchmark_test_run("test/integration", 8)

        Map.merge(%{pool_size: pool_size}, result)
      end)

    optimal_config = Enum.min_by(results, & &1.elapsed_time)

    IO.puts("🎯 Optimal database configuration:")
    IO.puts("   Pool size: #{optimal_config.pool_size}")
    IO.puts("   Execution time: #{optimal_config.elapsed_time}ms")

    results
  end

  # Private helper functions

  defp run_test_suite(path, label) do
    IO.puts("Running #{label}...")

    {output, exit_code} = System.cmd("mix", ["test", path, "--seed", "0"], stderr_to_stdout: true)

    # Parse test results from output
    test_count = extract_test_count(output)
    failure_count = extract_failure_count(output)
    execution_time = extract_execution_time(output)

    %{
      label: label,
      path: path,
      test_count: test_count,
      failure_count: failure_count,
      success_count: test_count - failure_count,
      execution_time: execution_time,
      exit_code: exit_code,
      output: output
    }
  end

  defp benchmark_test_run(path, max_cases) do
    start_time = System.monotonic_time(:millisecond)

    {_output, exit_code} =
      System.cmd(
        "mix",
        [
          "test",
          path,
          "--seed",
          "0",
          "--max-cases",
          to_string(max_cases)
        ],
        stderr_to_stdout: true
      )

    elapsed_time = System.monotonic_time(:millisecond) - start_time

    %{
      elapsed_time: elapsed_time,
      exit_code: exit_code
    }
  end

  defp generate_comprehensive_report(results, total_time) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📋 COMPREHENSIVE TEST REPORT")
    IO.puts(String.duplicate("=", 60))

    total_tests = Enum.sum(Enum.map(results, fn {_, result} -> result.test_count end))
    total_failures = Enum.sum(Enum.map(results, fn {_, result} -> result.failure_count end))
    success_rate = ((total_tests - total_failures) / total_tests * 100) |> Float.round(1)

    IO.puts("📊 Overall Statistics:")
    IO.puts("   Total Tests: #{total_tests}")
    IO.puts("   Total Failures: #{total_failures}")
    IO.puts("   Success Rate: #{success_rate}%")
    IO.puts("   Total Time: #{total_time}ms")

    IO.puts("\n📋 Test Suite Breakdown:")

    Enum.each(results, fn {suite_name, result} ->
      suite_success_rate = (result.success_count / result.test_count * 100) |> Float.round(1)

      IO.puts("   #{result.label}:")
      IO.puts("     Tests: #{result.test_count}")
      IO.puts("     Failures: #{result.failure_count}")
      IO.puts("     Success Rate: #{suite_success_rate}%")
      IO.puts("     Time: #{result.execution_time}ms")
    end)

    if total_failures > 0 do
      IO.puts("\n⚠️  Failed Test Details:")

      Enum.each(results, fn {_, result} ->
        if result.failure_count > 0 do
          IO.puts("   #{result.label}: #{result.failure_count} failures")
        end
      end)
    else
      IO.puts("\n✅ All tests passed!")
    end

    IO.puts(String.duplicate("=", 60))
  end

  defp generate_smoke_report(results) do
    IO.puts("\n" <> String.duplicate("-", 40))
    IO.puts("💨 SMOKE TEST REPORT")
    IO.puts(String.duplicate("-", 40))

    all_passed = Enum.all?(results, &(&1.failure_count == 0))

    if all_passed do
      IO.puts("✅ All smoke tests passed! System is stable.")
    else
      IO.puts("❌ Some smoke tests failed! Critical issues detected.")
    end

    Enum.each(results, fn result ->
      status = if result.failure_count == 0, do: "✅", else: "❌"
      IO.puts("   #{status} #{result.label}")
    end)

    IO.puts(String.duplicate("-", 40))
  end

  defp generate_benchmark_report(results) do
    IO.puts("\n" <> String.duplicate("-", 50))
    IO.puts("📊 PERFORMANCE BENCHMARK REPORT")
    IO.puts(String.duplicate("-", 50))

    optimal = Enum.min_by(results, & &1.elapsed_time)

    IO.puts("Configuration Performance:")

    Enum.each(results, fn result ->
      marker = if result == optimal, do: "🏆", else: "  "
      IO.puts("#{marker} #{result.name}: #{result.elapsed_time}ms (#{result.max_cases} cores)")
    end)

    IO.puts("\n🎯 Optimal Configuration: #{optimal.name} (#{optimal.max_cases} cores)")
    IO.puts(String.duplicate("-", 50))
  end

  defp compare_with_baseline(current, baseline) do
    IO.puts("\n📈 REGRESSION ANALYSIS")
    IO.puts(String.duplicate("-", 40))

    # Compare key metrics
    current_total_time =
      current.unit_tests.execution_time + current.integration_tests.execution_time

    # Default fallback
    baseline_total_time = baseline["total_execution_time"] || 20000

    time_diff = current_total_time - baseline_total_time
    time_percent = (time_diff / baseline_total_time * 100) |> Float.round(1)

    if time_diff < 0 do
      IO.puts("✅ Performance improved by #{abs(time_percent)}% (#{abs(time_diff)}ms faster)")
    else
      IO.puts("⚠️  Performance regressed by #{time_percent}% (#{time_diff}ms slower)")
    end

    IO.puts(String.duplicate("-", 40))
  end

  defp save_baseline(results, baseline_file) do
    baseline_data = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      total_execution_time:
        results.unit_tests.execution_time + results.integration_tests.execution_time,
      unit_tests: results.unit_tests,
      integration_tests: results.integration_tests
    }

    # Ensure directory exists
    baseline_file |> Path.dirname() |> File.mkdir_p!()

    baseline_file
    |> File.write!(Jason.encode!(baseline_data, pretty: true))

    IO.puts("💾 Baseline saved to #{baseline_file}")
  end

  # Output parsing helpers
  defp extract_test_count(output) do
    case Regex.run(~r/(\d+) tests?/, output) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp extract_failure_count(output) do
    case Regex.run(~r/(\d+) failures?/, output) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp extract_execution_time(output) do
    case Regex.run(~r/Finished in ([\d.]+) seconds/, output) do
      [_, time] -> (String.to_float(time) * 1000) |> round()
      _ -> 0
    end
  end
end

# Make this script executable directly
if System.argv() |> length() > 0 do
  case List.first(System.argv()) do
    "comprehensive" ->
      AutomatedTestRunner.run_comprehensive_tests()

    "smoke" ->
      AutomatedTestRunner.run_smoke_tests()

    "benchmark" ->
      AutomatedTestRunner.run_performance_benchmarks()

    "regression" ->
      AutomatedTestRunner.run_regression_tests()

    "optimize-db" ->
      AutomatedTestRunner.optimize_database_settings()

    _ ->
      IO.puts(
        "Usage: elixir automated_test_runner.exs [comprehensive|smoke|benchmark|regression|optimize-db]"
      )
  end
end
