defmodule Mix.Tasks.Test.Performance do
  @moduledoc """
  Enhanced performance testing and monitoring for the test suite.

  This task provides comprehensive performance monitoring capabilities:
  - Real-time performance dashboard
  - Performance trend analysis
  - Resource profiling
  - Performance regression detection
  - Load testing for API endpoints

  ## Usage

      # Run all tests with performance monitoring
      mix test.performance

      # Run with real-time dashboard
      mix test.performance --dashboard

      # Run specific test patterns with monitoring
      mix test.performance test/integration/

      # Run performance benchmarks only
      mix test.performance --benchmarks-only

      # Run with stress testing
      mix test.performance --stress-test

      # Generate performance report
      mix test.performance --report-only

  ## Options

    * `--dashboard` - Start real-time performance dashboard
    * `--benchmarks-only` - Run only performance benchmark tests
    * `--stress-test` - Include stress testing
    * `--report-only` - Generate performance report without running tests
    * `--port` - Dashboard port (default: 4001)
    * `--budget` - Set global performance budget in ms
    * `--save-results` - Save results to file for trend analysis
  """

  use Mix.Task
  require Logger

  @shortdoc "Run tests with enhanced performance monitoring"

  def run(args) do
    # Parse command line options
    {opts, test_args, _} =
      OptionParser.parse(args,
        switches: [
          dashboard: :boolean,
          benchmarks_only: :boolean,
          stress_test: :boolean,
          report_only: :boolean,
          port: :integer,
          budget: :integer,
          save_results: :boolean,
          help: :boolean
        ],
        aliases: [h: :help, d: :dashboard, b: :benchmarks_only]
      )

    if opts[:help] do
      print_help()
    else
      # Start the application
      Mix.Task.run("app.start")

      # Start performance monitoring services
      start_performance_monitoring(opts)

      cond do
        opts[:report_only] ->
          generate_performance_report()

        opts[:benchmarks_only] ->
          run_performance_benchmarks(test_args, opts)

        true ->
          run_tests_with_monitoring(test_args, opts)
      end
    end
  end

  defp start_performance_monitoring(opts) do
    # Start enhanced performance monitor
    {:ok, _} = WandererApp.EnhancedPerformanceMonitor.start_link()

    # Start dashboard if requested
    if opts[:dashboard] do
      {:ok, _} = WandererApp.PerformanceDashboard.start_link()
      port = opts[:port] || 4001

      case WandererApp.PerformanceDashboard.start_dashboard(port) do
        {:ok, url} ->
          Logger.info("🚀 Performance dashboard available at: #{url}")

          # Try to open browser
          case System.cmd("which", ["open"]) do
            {_, 0} ->
              System.cmd("open", [url])

            _ ->
              case System.cmd("which", ["xdg-open"]) do
                {_, 0} -> System.cmd("xdg-open", [url])
                _ -> :ok
              end
          end

        {:error, reason} ->
          Logger.warning("Failed to start dashboard: #{inspect(reason)}")
      end
    end

    # Set global performance budget if specified
    if budget = opts[:budget] do
      WandererApp.EnhancedPerformanceMonitor.set_performance_budget(:unit_test, budget)
      WandererApp.EnhancedPerformanceMonitor.set_performance_budget(:integration_test, budget * 4)
      Logger.info("🎯 Performance budget set to #{budget}ms for unit tests")
    end
  end

  defp run_tests_with_monitoring(test_args, opts) do
    Logger.info("🧪 Starting tests with enhanced performance monitoring...")

    # Configure ExUnit with performance formatter
    ExUnit.configure(
      formatters: [
        ExUnit.CLIFormatter,
        WandererApp.TestMonitor.ExUnitFormatter
      ],
      exclude: if(opts[:stress_test], do: [], else: [:stress_test])
    )

    # Start performance monitoring
    _start_time = System.monotonic_time(:millisecond)
    WandererApp.TestPerformanceMonitor.start_suite_monitoring()

    # Run the tests
    test_result =
      if Enum.empty?(test_args) do
        Mix.Task.run("test", ["--no-start"])
      else
        Mix.Task.run("test", ["--no-start" | test_args])
      end

    # Stop monitoring and generate report
    suite_duration = WandererApp.TestPerformanceMonitor.stop_suite_monitoring()

    # Generate comprehensive performance report
    performance_report = generate_comprehensive_report()

    # Save results if requested
    if opts[:save_results] do
      save_performance_results(performance_report)
    end

    # Print performance summary
    print_performance_summary(performance_report, suite_duration)

    # Check for performance regressions
    check_performance_regressions()

    test_result
  end

  defp run_performance_benchmarks(test_args, _opts) do
    Logger.info("🏁 Running performance benchmarks...")

    # Configure ExUnit to run only benchmark tests
    ExUnit.configure(
      include: [:benchmark],
      exclude: [:test, :integration, :stress_test]
    )

    # Run benchmarks
    if Enum.empty?(test_args) do
      Mix.Task.run("test", ["--no-start", "--include", "benchmark"])
    else
      Mix.Task.run("test", ["--no-start", "--include", "benchmark" | test_args])
    end
  end

  defp generate_performance_report do
    Logger.info("📊 Generating performance report...")

    report = generate_comprehensive_report()

    # Write report to file
    report_file = "performance_report_#{Date.utc_today()}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))

    # Print summary
    print_performance_summary(report, nil)

    Logger.info("📁 Performance report saved to: #{report_file}")
  end

  defp generate_comprehensive_report do
    # Collect data from all monitoring sources
    real_time_metrics = WandererApp.EnhancedPerformanceMonitor.get_real_time_metrics()
    trends = WandererApp.EnhancedPerformanceMonitor.get_performance_trends(7)
    regressions = WandererApp.EnhancedPerformanceMonitor.detect_performance_regressions()
    dashboard_data = WandererApp.EnhancedPerformanceMonitor.generate_performance_dashboard()

    test_monitor_report =
      case Process.whereis(WandererApp.TestMonitor) do
        nil -> %{}
        _ -> WandererApp.TestMonitor.generate_report()
      end

    %{
      timestamp: DateTime.utc_now(),
      real_time_metrics: real_time_metrics,
      performance_trends: trends,
      regressions: regressions,
      dashboard_data: dashboard_data,
      test_monitor_report: test_monitor_report,
      system_info: collect_system_info()
    }
  end

  defp collect_system_info do
    %{
      elixir_version: System.version(),
      otp_release: System.otp_release(),
      system_architecture: :erlang.system_info(:system_architecture),
      cpu_count: :erlang.system_info(:logical_processors_available),
      memory_total: :erlang.memory(:total),
      memory_processes: :erlang.memory(:processes),
      memory_atom: :erlang.memory(:atom),
      process_count: :erlang.system_info(:process_count)
    }
  end

  defp save_performance_results(report) do
    # Ensure results directory exists
    File.mkdir_p!("test/performance_results")

    # Save detailed report
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    detailed_file = "test/performance_results/performance_#{timestamp}.json"
    File.write!(detailed_file, Jason.encode!(report, pretty: true))

    # Update trend data
    update_trend_data(report)

    Logger.info("💾 Performance results saved to: #{detailed_file}")
  end

  defp update_trend_data(report) do
    trend_file = "test/performance_results/trends.json"

    # Load existing trend data
    existing_trends =
      case File.read(trend_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, data} -> data
            _ -> []
          end

        _ ->
          []
      end

    # Add current data point
    new_trend_point = %{
      timestamp: DateTime.utc_now(),
      suite_duration: report[:suite_duration],
      test_count: length(Map.keys(report.real_time_metrics)),
      regression_count: length(report.regressions),
      system_memory: report.system_info.memory_total
    }

    updated_trends =
      [new_trend_point | existing_trends]
      # Keep last 100 data points
      |> Enum.take(100)

    File.write!(trend_file, Jason.encode!(updated_trends, pretty: true))
  end

  defp print_performance_summary(report, suite_duration) do
    IO.puts("\n" <> IO.ANSI.cyan() <> "📊 Performance Summary" <> IO.ANSI.reset())
    IO.puts(String.duplicate("=", 50))

    # Suite timing
    if suite_duration do
      suite_status = if suite_duration <= 300_000, do: "✅", else: "⚠️"
      IO.puts("#{suite_status} Suite Duration: #{format_duration(suite_duration)}")
    end

    # Test metrics summary
    metrics_count = map_size(report.real_time_metrics)
    IO.puts("🧪 Tests Monitored: #{metrics_count}")

    # Performance trends
    if not Enum.empty?(report.performance_trends) do
      IO.puts("\n" <> IO.ANSI.yellow() <> "📈 Performance Trends:" <> IO.ANSI.reset())

      report.performance_trends
      |> Enum.take(5)
      |> Enum.each(fn trend ->
        trend_icon =
          case trend.trend_slope do
            slope when slope > 10 -> "📈"
            slope when slope < -10 -> "📉"
            _ -> "➡️"
          end

        IO.puts("  #{trend_icon} #{trend.test_name}: avg #{Float.round(trend.avg_duration, 1)}ms")
      end)
    end

    # Performance regressions
    if not Enum.empty?(report.regressions) do
      IO.puts("\n" <> IO.ANSI.red() <> "🚨 Performance Regressions Detected:" <> IO.ANSI.reset())

      Enum.each(report.regressions, fn regression ->
        slowdown = Float.round(regression.slowdown_factor, 1)
        IO.puts("  ⚠️  #{regression.test_name}: #{slowdown}x slower")
      end)
    else
      IO.puts("\n✅ No performance regressions detected")
    end

    # System health
    memory_mb = Float.round(report.system_info.memory_total / 1024 / 1024, 1)
    IO.puts("\n" <> IO.ANSI.blue() <> "🖥️  System Health:" <> IO.ANSI.reset())
    IO.puts("  Memory Usage: #{memory_mb} MB")
    IO.puts("  Process Count: #{report.system_info.process_count}")
    IO.puts("  CPU Count: #{report.system_info.cpu_count}")

    # Performance alerts
    if alerts = report.dashboard_data[:alerts] do
      if not Enum.empty?(alerts) do
        IO.puts("\n" <> IO.ANSI.yellow() <> "⚠️  Performance Alerts:" <> IO.ANSI.reset())

        Enum.each(alerts, fn alert ->
          icon =
            case alert.severity do
              :error -> "🔴"
              :warning -> "🟡"
              _ -> "🔵"
            end

          IO.puts("  #{icon} #{alert.message}")
        end)
      end
    end

    IO.puts("\n" <> String.duplicate("=", 50))
  end

  defp check_performance_regressions do
    regressions = WandererApp.EnhancedPerformanceMonitor.detect_performance_regressions()

    if not Enum.empty?(regressions) do
      Logger.warning("""

      🚨 Performance regressions detected!

      #{length(regressions)} tests have significantly slowed down.
      Review the performance report for details.
      """)
    end
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{div(ms, 60_000)}m #{rem(div(ms, 1000), 60)}s"

  defp print_help do
    IO.puts("""
    mix test.performance - Enhanced performance testing and monitoring

    Usage:
        mix test.performance [options] [test_patterns]

    Options:
        --dashboard         Start real-time performance dashboard
        --benchmarks-only   Run only performance benchmark tests
        --stress-test       Include stress testing
        --report-only       Generate performance report without running tests
        --port PORT         Dashboard port (default: 4001)
        --budget MS         Set global performance budget in milliseconds
        --save-results      Save results to file for trend analysis
        --help, -h          Show this help message

    Examples:
        # Run all tests with performance monitoring
        mix test.performance

        # Run with real-time dashboard
        mix test.performance --dashboard

        # Run integration tests with custom budget
        mix test.performance test/integration/ --budget 2000

        # Run only benchmarks
        mix test.performance --benchmarks-only

        # Generate report from previous runs
        mix test.performance --report-only
    """)
  end
end
