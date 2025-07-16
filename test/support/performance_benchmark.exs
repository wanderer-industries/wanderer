defmodule WandererApp.Test.PerformanceBenchmark do
  @moduledoc """
  Performance benchmarking utilities for test suite optimization.

  Tracks and compares test execution times before and after optimizations.
  """

  @doc """
  Benchmark test execution time for a specific test suite.
  """
  def benchmark_tests(suite_path, label \\ "Test Suite") do
    IO.puts("🚀 Benchmarking #{label}...")

    {elapsed_time, result} =
      :timer.tc(fn ->
        {output, exit_code} =
          System.cmd("mix", ["test", suite_path, "--seed", "0"],
            stderr_to_stdout: true,
            into: IO.stream(:stdio, :line)
          )

        {output, exit_code}
      end)

    elapsed_seconds = elapsed_time / 1_000_000

    IO.puts("📊 #{label} completed in #{Float.round(elapsed_seconds, 2)}s")

    %{
      label: label,
      path: suite_path,
      elapsed_seconds: elapsed_seconds,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Compare performance between baseline and optimized runs.
  """
  def compare_performance(baseline, optimized) do
    improvement = baseline.elapsed_seconds - optimized.elapsed_seconds
    improvement_percent = improvement / baseline.elapsed_seconds * 100

    IO.puts("📈 Performance Comparison:")
    IO.puts("   Baseline: #{Float.round(baseline.elapsed_seconds, 2)}s")
    IO.puts("   Optimized: #{Float.round(optimized.elapsed_seconds, 2)}s")

    IO.puts(
      "   Improvement: #{Float.round(improvement, 2)}s (#{Float.round(improvement_percent, 1)}%)"
    )

    cond do
      improvement_percent >= 30 ->
        IO.puts("✅ Target 30% improvement achieved!")

      improvement_percent >= 20 ->
        IO.puts("🎯 Good improvement, approaching 30% target")

      improvement_percent >= 10 ->
        IO.puts("📊 Moderate improvement, more optimization needed")

      improvement_percent > 0 ->
        IO.puts("⚡ Minor improvement detected")

      true ->
        IO.puts("⚠️  Performance regression detected!")
    end

    %{
      baseline: baseline,
      optimized: optimized,
      improvement_seconds: improvement,
      improvement_percent: improvement_percent
    }
  end

  @doc """
  Quick performance test for all test suites.
  """
  def benchmark_all_suites do
    suites = [
      {"test/unit", "Unit Tests"},
      {"test/integration", "Integration Tests"},
      {"test", "Full Test Suite"}
    ]

    Enum.map(suites, fn {path, label} ->
      benchmark_tests(path, label)
    end)
  end
end
