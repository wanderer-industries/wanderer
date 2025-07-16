defmodule Mix.Tasks.CiMonitoring do
  @moduledoc """
  Continuous integration test monitoring and analytics.

  ## Usage

      mix ci_monitoring
      mix ci_monitoring --collect
      mix ci_monitoring --analyze
      mix ci_monitoring --report --days 7

  ## Options

    * `--collect` - Collect test metrics from current run
    * `--analyze` - Analyze historical test data
    * `--report` - Generate monitoring report
    * `--days` - Number of days for historical analysis (default: 30)
    * `--export` - Export data to external monitoring systems
  """

  use Mix.Task

  @shortdoc "Monitor CI test health and performance"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          collect: :boolean,
          analyze: :boolean,
          report: :boolean,
          days: :integer,
          export: :boolean
        ]
      )

    collect = Keyword.get(opts, :collect, false)
    analyze = Keyword.get(opts, :analyze, false)
    report = Keyword.get(opts, :report, false)
    days = Keyword.get(opts, :days, 30)
    export = Keyword.get(opts, :export, false)

    cond do
      collect -> collect_test_metrics()
      analyze -> analyze_test_trends(days)
      report -> generate_monitoring_report(days)
      export -> export_metrics_to_external()
      true -> run_full_monitoring(days)
    end
  end

  defp run_full_monitoring(days) do
    Mix.shell().info("🔍 Running full CI monitoring pipeline...")

    # Collect current metrics
    collect_test_metrics()

    # Analyze trends
    _trends = analyze_test_trends(days)

    # Generate report
    generate_monitoring_report(days)

    # Export if configured
    if should_export_metrics?() do
      export_metrics_to_external()
    end

    Mix.shell().info("✅ CI monitoring completed")
  end

  defp collect_test_metrics do
    Mix.shell().info("📊 Collecting test metrics...")

    start_time = System.monotonic_time(:millisecond)

    # Run tests with detailed metrics collection
    {output, exit_code} =
      System.cmd("mix", ["test", "--cover"],
        stderr_to_stdout: true,
        env: [
          {"MIX_ENV", "test"},
          {"CI_MONITORING", "true"},
          {"TEST_METRICS_COLLECTION", "true"}
        ]
      )

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Parse test results
    metrics = parse_test_metrics(output, exit_code, duration)

    # Add environment context
    metrics = add_environment_context(metrics)

    # Store metrics
    store_test_metrics(metrics)

    Mix.shell().info("✅ Test metrics collected and stored")
    metrics
  end

  defp parse_test_metrics(output, exit_code, duration) do
    lines = String.split(output, "\n")

    # Extract basic test statistics
    {total_tests, failures, excluded} = extract_test_counts(output)

    # Extract test timings
    test_timings = extract_test_timings(lines)

    # Extract module-level results
    module_results = extract_module_results(lines)

    # Extract coverage information
    coverage = extract_coverage_info(output)

    # Calculate performance metrics
    performance = calculate_performance_metrics(test_timings, duration)

    %{
      timestamp: DateTime.utc_now(),
      exit_code: exit_code,
      duration_ms: duration,
      test_counts: %{
        total: total_tests,
        passed: total_tests - failures,
        failed: failures,
        excluded: excluded
      },
      performance: performance,
      coverage: coverage,
      module_results: module_results,
      test_timings: test_timings,
      # Will be filled by add_environment_context
      environment: %{},
      quality_indicators: calculate_quality_indicators(total_tests, failures, duration)
    }
  end

  defp extract_test_counts(output) do
    # Match patterns like "179 tests, 0 failures, 5 excluded"
    case Regex.run(~r/(\d+) tests?, (\d+) failures?(?:, (\d+) excluded)?/, output) do
      [_, total, failures] ->
        {String.to_integer(total), String.to_integer(failures), 0}

      [_, total, failures, excluded] ->
        {String.to_integer(total), String.to_integer(failures), String.to_integer(excluded)}

      _ ->
        {0, 0, 0}
    end
  end

  defp extract_test_timings(lines) do
    lines
    |> Enum.filter(&String.contains?(&1, "ms]"))
    |> Enum.map(&parse_test_timing_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_test_timing_line(line) do
    case Regex.run(~r/test (.+) \((.+)\) \[(\d+)ms\]/, line) do
      [_, test_name, module, time_str] ->
        %{
          test: test_name,
          module: module,
          duration_ms: String.to_integer(time_str),
          status: if(String.contains?(line, "FAILED"), do: :failed, else: :passed)
        }

      _ ->
        nil
    end
  end

  defp extract_module_results(lines) do
    # Group test results by module
    module_lines = Enum.filter(lines, &String.match?(&1, ~r/^\s*\d+\) test/))

    module_lines
    |> Enum.map(&extract_module_from_line/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(& &1.module)
    |> Map.new(fn {module, tests} ->
      {module,
       %{
         total_tests: length(tests),
         failed_tests: Enum.count(tests, &(&1.status == :failed)),
         avg_duration: tests |> Enum.map(& &1.duration) |> average()
       }}
    end)
  end

  defp extract_module_from_line(line) do
    case Regex.run(~r/test (.+) \((.+)\)/, line) do
      [_, test_name, module] ->
        %{
          test: test_name,
          module: module,
          status: if(String.contains?(line, "FAILED"), do: :failed, else: :passed),
          duration: extract_duration_from_line(line)
        }

      _ ->
        nil
    end
  end

  defp extract_duration_from_line(line) do
    case Regex.run(~r/\[(\d+)ms\]/, line) do
      [_, time_str] -> String.to_integer(time_str)
      _ -> 0
    end
  end

  defp extract_coverage_info(output) do
    case Regex.run(~r/(\d+\.\d+)%/, output) do
      [_, percentage] ->
        %{
          percentage: String.to_float(percentage),
          status: :measured
        }

      _ ->
        %{percentage: 0.0, status: :not_available}
    end
  end

  defp calculate_performance_metrics(test_timings, total_duration) do
    if length(test_timings) > 0 do
      durations = Enum.map(test_timings, & &1.duration_ms)

      %{
        avg_test_duration: average(durations),
        median_test_duration: median(durations),
        slowest_tests: Enum.take(Enum.sort_by(test_timings, & &1.duration_ms, :desc), 10),
        fastest_tests: Enum.take(Enum.sort_by(test_timings, & &1.duration_ms, :asc), 5),
        total_test_time: Enum.sum(durations),
        overhead_time: total_duration - Enum.sum(durations),
        parallel_efficiency: calculate_parallel_efficiency(durations, total_duration)
      }
    else
      %{
        avg_test_duration: 0,
        median_test_duration: 0,
        slowest_tests: [],
        fastest_tests: [],
        total_test_time: 0,
        overhead_time: total_duration,
        parallel_efficiency: 0.0
      }
    end
  end

  defp calculate_parallel_efficiency(durations, total_duration) do
    total_test_time = Enum.sum(durations)

    if total_duration > 0 do
      total_test_time / total_duration * 100
    else
      0.0
    end
  end

  defp calculate_quality_indicators(total, failures, duration) do
    success_rate = if total > 0, do: (total - failures) / total * 100, else: 0

    %{
      success_rate: success_rate,
      failure_rate: 100 - success_rate,
      # tests per second
      test_density: total / max(duration / 1000, 1),
      stability_score: calculate_stability_score(success_rate, duration)
    }
  end

  defp calculate_stability_score(success_rate, duration) do
    # Combine success rate with execution time consistency
    # Normalize to minutes
    time_factor = min(duration / 60000, 1.0)
    success_rate * 0.8 + (1.0 - time_factor) * 20
  end

  defp add_environment_context(metrics) do
    env_context = %{
      ci_system: detect_ci_system(),
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      mix_env: System.get_env("MIX_ENV", "unknown"),
      github_sha: System.get_env("GITHUB_SHA"),
      github_ref: System.get_env("GITHUB_REF"),
      github_workflow: System.get_env("GITHUB_WORKFLOW"),
      machine_info: get_machine_info()
    }

    Map.put(metrics, :environment, env_context)
  end

  defp detect_ci_system do
    cond do
      System.get_env("GITHUB_ACTIONS") -> "github_actions"
      System.get_env("GITLAB_CI") -> "gitlab_ci"
      System.get_env("TRAVIS") -> "travis_ci"
      System.get_env("CIRCLECI") -> "circle_ci"
      true -> "unknown"
    end
  end

  defp get_machine_info do
    %{
      schedulers: System.schedulers_online(),
      memory_total: :erlang.memory(:total),
      architecture: :erlang.system_info(:system_architecture) |> to_string()
    }
  end

  defp store_test_metrics(metrics) do
    # Ensure metrics directory exists
    File.mkdir_p!("test_metrics")

    # Store with timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    filename = "test_metrics/ci_metrics_#{timestamp}.json"

    json = Jason.encode!(metrics, pretty: true)
    File.write!(filename, json)

    # Also update latest metrics
    File.write!("test_metrics/latest_metrics.json", json)

    Mix.shell().info("📁 Metrics stored in #{filename}")
  end

  defp analyze_test_trends(days) do
    Mix.shell().info("📈 Analyzing test trends for last #{days} days...")

    # Load historical metrics
    historical_data = load_historical_metrics(days)

    if Enum.empty?(historical_data) do
      Mix.shell().info("⚠️  No historical data available for analysis")
      %{}
    else
      # Calculate trends
      trends = %{
        success_rate_trend: calculate_success_rate_trend(historical_data),
        performance_trend: calculate_performance_trend(historical_data),
        coverage_trend: calculate_coverage_trend(historical_data),
        stability_analysis: analyze_test_stability(historical_data),
        failure_patterns: analyze_failure_patterns(historical_data)
      }

      # Store trend analysis
      store_trend_analysis(trends)

      display_trend_summary(trends)

      trends
    end
  end

  defp load_historical_metrics(days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    "test_metrics/ci_metrics_*.json"
    |> Path.wildcard()
    |> Enum.map(&load_metrics_file/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn metrics ->
      case DateTime.from_iso8601(metrics.timestamp) do
        {:ok, timestamp, _} -> DateTime.compare(timestamp, cutoff_date) != :lt
        _ -> false
      end
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp load_metrics_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, metrics} -> metrics
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp calculate_success_rate_trend(data) do
    success_rates = Enum.map(data, &get_in(&1, [:quality_indicators, :success_rate]))

    %{
      current: List.last(success_rates) || 0,
      average: average(success_rates),
      trend: calculate_linear_trend(success_rates),
      volatility: calculate_volatility(success_rates)
    }
  end

  defp calculate_performance_trend(data) do
    durations = Enum.map(data, & &1.duration_ms)

    %{
      current: List.last(durations) || 0,
      average: average(durations),
      trend: calculate_linear_trend(durations),
      percentile_95: percentile(durations, 95)
    }
  end

  defp calculate_coverage_trend(data) do
    coverages = Enum.map(data, &get_in(&1, [:coverage, :percentage]))

    %{
      current: List.last(coverages) || 0,
      average: average(coverages),
      trend: calculate_linear_trend(coverages)
    }
  end

  defp analyze_test_stability(data) do
    # Look for patterns in test failures
    failure_counts = Enum.map(data, &get_in(&1, [:test_counts, :failed]))
    durations = Enum.map(data, & &1.duration_ms)

    %{
      failure_frequency: calculate_failure_frequency(failure_counts),
      duration_stability: calculate_volatility(durations),
      consistency_score: calculate_consistency_score(data)
    }
  end

  defp analyze_failure_patterns(data) do
    # Aggregate failure information across runs
    all_failures =
      data
      |> Enum.flat_map(&extract_failed_tests/1)
      |> Enum.frequencies()

    %{
      frequent_failures: all_failures |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(10),
      total_unique_failures: map_size(all_failures),
      flaky_test_candidates: identify_flaky_tests(all_failures, length(data))
    }
  end

  defp extract_failed_tests(metrics) do
    case get_in(metrics, [:test_timings]) do
      nil ->
        []

      timings ->
        timings
        |> Enum.filter(&(&1.status == :failed))
        |> Enum.map(&"#{&1.module}: #{&1.test}")
    end
  end

  defp identify_flaky_tests(failure_frequencies, total_runs) do
    failure_frequencies
    |> Enum.filter(fn {_test, count} ->
      failure_rate = count / total_runs
      # Fails sometimes but not always
      failure_rate > 0.1 and failure_rate < 0.9
    end)
    |> Enum.map(fn {test, count} ->
      %{test: test, failure_count: count, failure_rate: count / total_runs}
    end)
  end

  defp calculate_linear_trend(values) when length(values) < 2, do: 0

  defp calculate_linear_trend(values) do
    # Simple linear regression slope
    n = length(values)
    x_values = Enum.to_list(1..n)

    x_mean = average(x_values)
    y_mean = average(values)

    numerator =
      Enum.zip(x_values, values)
      |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
      |> Enum.sum()

    denominator =
      x_values
      |> Enum.map(fn x -> (x - x_mean) * (x - x_mean) end)
      |> Enum.sum()

    if denominator != 0, do: numerator / denominator, else: 0
  end

  defp calculate_volatility(values) when length(values) < 2, do: 0

  defp calculate_volatility(values) do
    mean = average(values)

    variance =
      values
      |> Enum.map(fn x -> (x - mean) * (x - mean) end)
      |> average()

    :math.sqrt(variance)
  end

  defp calculate_failure_frequency(failure_counts) do
    total_runs = length(failure_counts)
    failing_runs = Enum.count(failure_counts, &(&1 > 0))

    if total_runs > 0, do: failing_runs / total_runs, else: 0
  end

  defp calculate_consistency_score(data) do
    # Score based on variance in key metrics
    durations = Enum.map(data, & &1.duration_ms)
    success_rates = Enum.map(data, &get_in(&1, [:quality_indicators, :success_rate]))

    duration_cv = coefficient_of_variation(durations)
    success_cv = coefficient_of_variation(success_rates)

    # Lower coefficient of variation = higher consistency
    100 - min((duration_cv + success_cv) * 10, 100)
  end

  defp coefficient_of_variation(values) when length(values) < 2, do: 0

  defp coefficient_of_variation(values) do
    mean = average(values)

    if mean != 0 do
      std_dev = :math.sqrt(calculate_variance(values))
      std_dev / mean
    else
      0
    end
  end

  defp calculate_variance(values) do
    mean = average(values)

    values
    |> Enum.map(fn x -> (x - mean) * (x - mean) end)
    |> average()
  end

  defp store_trend_analysis(trends) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    filename = "test_metrics/trend_analysis_#{timestamp}.json"

    json = Jason.encode!(trends, pretty: true)
    File.write!(filename, json)
    File.write!("test_metrics/latest_trends.json", json)
  end

  defp display_trend_summary(trends) do
    Mix.shell().info("")
    Mix.shell().info("📊 Test Trend Analysis Summary")
    Mix.shell().info("=" |> String.duplicate(50))

    success_trend = trends.success_rate_trend

    Mix.shell().info(
      "Success Rate: #{Float.round(success_trend.current, 1)}% (avg: #{Float.round(success_trend.average, 1)}%)"
    )

    Mix.shell().info("  Trend: #{format_trend(success_trend.trend)}")

    perf_trend = trends.performance_trend

    Mix.shell().info(
      "Performance: #{perf_trend.current}ms (avg: #{Float.round(perf_trend.average, 1)}ms)"
    )

    Mix.shell().info("  Trend: #{format_trend(perf_trend.trend)}")

    if length(trends.failure_patterns.flaky_test_candidates) > 0 do
      Mix.shell().info("")
      Mix.shell().info("⚠️  Flaky Test Candidates:")

      for flaky <- Enum.take(trends.failure_patterns.flaky_test_candidates, 3) do
        Mix.shell().info(
          "  - #{flaky.test} (#{Float.round(flaky.failure_rate * 100, 1)}% failure rate)"
        )
      end
    end
  end

  defp format_trend(trend) when trend > 0.1, do: "📈 Improving"
  defp format_trend(trend) when trend < -0.1, do: "📉 Declining"
  defp format_trend(_), do: "➡️  Stable"

  defp generate_monitoring_report(days) do
    Mix.shell().info("📄 Generating CI monitoring report...")

    # Load data
    historical_data = load_historical_metrics(days)
    latest_trends = load_latest_trends()

    # Generate report
    report = build_comprehensive_report(historical_data, latest_trends, days)

    # Save reports in multiple formats
    save_monitoring_report(report)

    Mix.shell().info("✅ Monitoring report generated")
  end

  defp load_latest_trends do
    case File.read("test_metrics/latest_trends.json") do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, trends} -> trends
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp build_comprehensive_report(historical_data, trends, days) do
    latest_metrics = List.last(historical_data) || %{}

    %{
      generated_at: DateTime.utc_now(),
      period_days: days,
      summary: build_report_summary(historical_data, trends),
      current_status: build_current_status(latest_metrics),
      trends: trends,
      recommendations: build_recommendations(historical_data, trends),
      raw_data: %{
        total_runs: length(historical_data),
        data_points: length(historical_data)
      }
    }
  end

  defp build_report_summary(data, trends) do
    if length(data) > 0 do
      success_rates = Enum.map(data, &get_in(&1, [:quality_indicators, :success_rate]))
      durations = Enum.map(data, & &1.duration_ms)

      %{
        overall_health: calculate_overall_health(trends),
        avg_success_rate: average(success_rates),
        avg_duration: average(durations),
        total_test_runs: length(data),
        stability_score: get_in(trends, [:stability_analysis, :consistency_score]) || 0
      }
    else
      %{
        overall_health: "insufficient_data",
        total_test_runs: 0
      }
    end
  end

  defp calculate_overall_health(trends) do
    success_rate = get_in(trends, [:success_rate_trend, :current]) || 0
    stability = get_in(trends, [:stability_analysis, :consistency_score]) || 0

    health_score = success_rate * 0.6 + stability * 0.4

    cond do
      health_score >= 90 -> "excellent"
      health_score >= 80 -> "good"
      health_score >= 70 -> "fair"
      true -> "needs_attention"
    end
  end

  defp build_current_status(latest_metrics) do
    if map_size(latest_metrics) > 0 do
      %{
        last_run: latest_metrics.timestamp,
        success_rate: get_in(latest_metrics, [:quality_indicators, :success_rate]) || 0,
        duration: latest_metrics.duration_ms,
        test_count: get_in(latest_metrics, [:test_counts, :total]) || 0,
        coverage: get_in(latest_metrics, [:coverage, :percentage]) || 0
      }
    else
      %{status: "no_recent_data"}
    end
  end

  defp build_recommendations(_data, trends) do
    recommendations = []

    # Check for performance issues
    recommendations =
      if (get_in(trends, [:performance_trend, :trend]) || 0) > 1000 do
        [
          %{
            type: "performance",
            priority: "high",
            message: "Test execution time is increasing. Consider optimizing slow tests."
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Check for flaky tests
    flaky_count = length(get_in(trends, [:failure_patterns, :flaky_test_candidates]) || [])

    recommendations =
      if flaky_count > 0 do
        [
          %{
            type: "stability",
            priority: "medium",
            message:
              "#{flaky_count} potentially flaky tests detected. Consider investigating intermittent failures."
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Check success rate trends
    success_trend = get_in(trends, [:success_rate_trend, :trend]) || 0

    recommendations =
      if success_trend < -0.5 do
        [
          %{
            type: "quality",
            priority: "high",
            message:
              "Test success rate is declining. Review recent test failures and fix underlying issues."
          }
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      [
        %{
          type: "status",
          priority: "info",
          message: "Test suite health looks good. Continue monitoring trends."
        }
      ]
    else
      recommendations
    end
  end

  defp save_monitoring_report(report) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    # JSON format
    json_report = Jason.encode!(report, pretty: true)
    File.write!("test_metrics/monitoring_report_#{timestamp}.json", json_report)
    File.write!("test_metrics/latest_monitoring_report.json", json_report)

    # Markdown format
    markdown_report = format_report_as_markdown(report)
    File.write!("test_metrics/monitoring_report_#{timestamp}.md", markdown_report)
    File.write!("test_metrics/latest_monitoring_report.md", markdown_report)

    Mix.shell().info("📁 Reports saved:")
    Mix.shell().info("  - JSON: test_metrics/latest_monitoring_report.json")
    Mix.shell().info("  - Markdown: test_metrics/latest_monitoring_report.md")
  end

  defp format_report_as_markdown(report) do
    """
    # 🔍 CI Test Monitoring Report

    **Generated:** #{DateTime.to_string(report.generated_at)}  
    **Period:** Last #{report.period_days} days

    ## 📊 Summary

    - **Overall Health:** #{format_health_status(report.summary.overall_health)}
    - **Average Success Rate:** #{Float.round(report.summary.avg_success_rate || 0, 1)}%
    - **Average Duration:** #{Float.round((report.summary.avg_duration || 0) / 1000, 1)}s
    - **Total Test Runs:** #{report.summary.total_test_runs}
    - **Stability Score:** #{Float.round(report.summary.stability_score || 0, 1)}%

    ## 🎯 Current Status

    #{format_current_status_markdown(report.current_status)}

    ## 📈 Trends

    #{format_trends_markdown(report.trends)}

    ## 💡 Recommendations

    #{format_recommendations_markdown(report.recommendations)}

    ---

    *This report was automatically generated by the CI monitoring system.*
    """
  end

  defp format_health_status("excellent"), do: "🌟 Excellent"
  defp format_health_status("good"), do: "✅ Good"
  defp format_health_status("fair"), do: "⚠️ Fair"
  defp format_health_status("needs_attention"), do: "❌ Needs Attention"
  defp format_health_status(_), do: "❓ Unknown"

  defp format_current_status_markdown(status) do
    if Map.has_key?(status, :status) do
      "No recent test data available."
    else
      """
      - **Last Run:** #{status.last_run}
      - **Success Rate:** #{Float.round(status.success_rate, 1)}%
      - **Duration:** #{Float.round(status.duration / 1000, 1)}s
      - **Test Count:** #{status.test_count}
      - **Coverage:** #{Float.round(status.coverage, 1)}%
      """
    end
  end

  defp format_trends_markdown(trends) when map_size(trends) == 0 do
    "No trend data available."
  end

  defp format_trends_markdown(trends) do
    """
    ### Success Rate
    - Current: #{Float.round(trends.success_rate_trend.current, 1)}%
    - Average: #{Float.round(trends.success_rate_trend.average, 1)}%
    - Trend: #{format_trend(trends.success_rate_trend.trend)}

    ### Performance
    - Current: #{trends.performance_trend.current}ms
    - Average: #{Float.round(trends.performance_trend.average, 1)}ms
    - Trend: #{format_trend(trends.performance_trend.trend)}

    ### Flaky Tests
    #{if length(trends.failure_patterns.flaky_test_candidates) > 0 do
      "Found #{length(trends.failure_patterns.flaky_test_candidates)} potentially flaky tests."
    else
      "No flaky tests detected."
    end}
    """
  end

  defp format_recommendations_markdown(recommendations) do
    recommendations
    |> Enum.map(fn rec ->
      priority_icon =
        case rec.priority do
          "high" -> "🔴"
          "medium" -> "🟡"
          "low" -> "🟢"
          _ -> "ℹ️"
        end

      "- #{priority_icon} **#{String.upcase(rec.type)}:** #{rec.message}"
    end)
    |> Enum.join("\n")
  end

  defp export_metrics_to_external do
    Mix.shell().info("📤 Exporting metrics to external systems...")

    # Load latest metrics
    latest_metrics =
      case File.read("test_metrics/latest_metrics.json") do
        {:ok, content} ->
          case Jason.decode(content, keys: :atoms) do
            {:ok, metrics} -> metrics
            _ -> nil
          end

        _ ->
          nil
      end

    if latest_metrics do
      # Export to different systems based on configuration
      export_to_prometheus(latest_metrics)
      export_to_datadog(latest_metrics)
      export_to_custom_webhook(latest_metrics)
    else
      Mix.shell().info("⚠️  No metrics available for export")
    end
  end

  defp export_to_prometheus(metrics) do
    if prometheus_enabled?() do
      # Format metrics for Prometheus
      prometheus_metrics = format_for_prometheus(metrics)

      # Write to file that Prometheus can scrape
      File.write!("test_metrics/prometheus_metrics.txt", prometheus_metrics)
      Mix.shell().info("📊 Prometheus metrics exported")
    end
  end

  defp export_to_datadog(_metrics) do
    if datadog_enabled?() do
      # Format and send to DataDog API
      Mix.shell().info("📊 DataDog export would happen here")
    end
  end

  defp export_to_custom_webhook(_metrics) do
    webhook_url = System.get_env("CI_METRICS_WEBHOOK_URL")

    if webhook_url do
      # Send metrics to custom webhook
      Mix.shell().info("📊 Custom webhook export would happen here")
    end
  end

  defp format_for_prometheus(metrics) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    """
    # HELP ci_test_success_rate Test success rate percentage
    # TYPE ci_test_success_rate gauge
    ci_test_success_rate #{metrics.quality_indicators.success_rate} #{timestamp}

    # HELP ci_test_duration_ms Test execution duration in milliseconds
    # TYPE ci_test_duration_ms gauge
    ci_test_duration_ms #{metrics.duration_ms} #{timestamp}

    # HELP ci_test_count Total number of tests
    # TYPE ci_test_count gauge
    ci_test_count #{metrics.test_counts.total} #{timestamp}

    # HELP ci_test_coverage_percent Test coverage percentage
    # TYPE ci_test_coverage_percent gauge
    ci_test_coverage_percent #{metrics.coverage.percentage} #{timestamp}
    """
  end

  defp should_export_metrics?,
    do: prometheus_enabled?() or datadog_enabled?() or System.get_env("CI_METRICS_WEBHOOK_URL")

  defp prometheus_enabled?, do: System.get_env("PROMETHEUS_ENABLED") == "true"
  defp datadog_enabled?, do: System.get_env("DATADOG_API_KEY") != nil

  # Utility functions
  defp average([]), do: 0
  defp average(list), do: Enum.sum(list) / length(list)

  defp median([]), do: 0

  defp median(list) do
    sorted = Enum.sort(list)
    count = length(sorted)

    if rem(count, 2) == 0 do
      (Enum.at(sorted, div(count, 2) - 1) + Enum.at(sorted, div(count, 2))) / 2
    else
      Enum.at(sorted, div(count, 2))
    end
  end

  defp percentile([], _), do: 0

  defp percentile(list, p) do
    sorted = Enum.sort(list)
    index = Float.round(length(sorted) * p / 100) |> trunc() |> max(0) |> min(length(sorted) - 1)
    Enum.at(sorted, index)
  end
end
