defmodule Mix.Tasks.TestHealthDashboard do
  @moduledoc """
  Generates an interactive test health dashboard.

  ## Usage

      mix test_health_dashboard
      mix test_health_dashboard --serve
      mix test_health_dashboard --export

  ## Options

    * `--serve` - Start a local web server to view the dashboard
    * `--export` - Export dashboard to static files
    * `--port` - Port for local server (default: 4001)
  """

  use Mix.Task

  @shortdoc "Generate interactive test health dashboard"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          serve: :boolean,
          export: :boolean,
          port: :integer
        ]
      )

    serve = Keyword.get(opts, :serve, false)
    export = Keyword.get(opts, :export, false)
    port = Keyword.get(opts, :port, 4001)

    Mix.shell().info("🎛️ Generating test health dashboard...")

    # Generate dashboard data
    dashboard_data = generate_dashboard_data()

    # Create dashboard files
    create_dashboard_files(dashboard_data)

    cond do
      serve -> serve_dashboard(port)
      export -> export_dashboard()
      true -> Mix.shell().info("✅ Dashboard generated at test_metrics/dashboard/")
    end
  end

  defp generate_dashboard_data do
    # Load historical metrics
    historical_data = load_all_historical_data()

    # Load latest trends
    latest_trends = load_latest_trends()

    # Load latest metrics
    latest_metrics = load_latest_metrics()

    %{
      overview: generate_overview_data(latest_metrics, latest_trends),
      trends: generate_trends_data(historical_data),
      test_details: generate_test_details_data(historical_data),
      performance: generate_performance_data(historical_data),
      alerts: generate_alerts_data(latest_trends),
      recommendations: generate_recommendations_data(latest_trends)
    }
  end

  defp load_all_historical_data do
    "test_metrics/ci_metrics_*.json"
    |> Path.wildcard()
    |> Enum.map(&load_metrics_file/1)
    |> Enum.reject(&is_nil/1)
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

  defp load_latest_metrics do
    case File.read("test_metrics/latest_metrics.json") do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, metrics} -> metrics
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp generate_overview_data(latest_metrics, trends) do
    %{
      current_status: extract_current_status(latest_metrics),
      health_score: calculate_health_score(latest_metrics, trends),
      key_metrics: extract_key_metrics(latest_metrics),
      trend_indicators: extract_trend_indicators(trends)
    }
  end

  defp extract_current_status(metrics) when map_size(metrics) == 0 do
    %{status: "no_data", message: "No recent test data available"}
  end

  defp extract_current_status(metrics) do
    success_rate = get_in(metrics, [:quality_indicators, :success_rate]) || 0

    status =
      cond do
        success_rate >= 95 -> "excellent"
        success_rate >= 90 -> "good"
        success_rate >= 80 -> "warning"
        true -> "critical"
      end

    %{
      status: status,
      success_rate: success_rate,
      last_run: metrics.timestamp,
      test_count: get_in(metrics, [:test_counts, :total]) || 0,
      duration: metrics.duration_ms
    }
  end

  defp calculate_health_score(metrics, trends) do
    if map_size(metrics) == 0 do
      0
    else
      success_rate = get_in(metrics, [:quality_indicators, :success_rate]) || 0
      stability = get_in(trends, [:stability_analysis, :consistency_score]) || 0
      coverage = get_in(metrics, [:coverage, :percentage]) || 0

      # Weighted health score
      success_rate * 0.5 + stability * 0.3 + min(coverage, 100) * 0.2
    end
  end

  defp extract_key_metrics(metrics) do
    %{
      total_tests: get_in(metrics, [:test_counts, :total]) || 0,
      failed_tests: get_in(metrics, [:test_counts, :failed]) || 0,
      duration_seconds: Float.round((metrics[:duration_ms] || 0) / 1000, 1),
      coverage_percent: get_in(metrics, [:coverage, :percentage]) || 0,
      parallel_efficiency: get_in(metrics, [:performance, :parallel_efficiency]) || 0
    }
  end

  defp extract_trend_indicators(trends) do
    %{
      success_rate_trend: get_trend_direction(get_in(trends, [:success_rate_trend, :trend]) || 0),
      # Negative for performance
      performance_trend:
        get_trend_direction((get_in(trends, [:performance_trend, :trend]) || 0) * -1),
      coverage_trend: get_trend_direction(get_in(trends, [:coverage_trend, :trend]) || 0),
      flaky_test_count: length(get_in(trends, [:failure_patterns, :flaky_test_candidates]) || [])
    }
  end

  defp get_trend_direction(trend) when trend > 0.5, do: "improving"
  defp get_trend_direction(trend) when trend < -0.5, do: "declining"
  defp get_trend_direction(_), do: "stable"

  defp generate_trends_data(historical_data) do
    if length(historical_data) < 2 do
      %{insufficient_data: true}
    else
      dates = Enum.map(historical_data, &parse_date/1)

      %{
        success_rates:
          Enum.map(historical_data, &get_in(&1, [:quality_indicators, :success_rate])),
        durations: Enum.map(historical_data, fn data -> data.duration_ms / 1000 end),
        test_counts: Enum.map(historical_data, &get_in(&1, [:test_counts, :total])),
        coverage: Enum.map(historical_data, &get_in(&1, [:coverage, :percentage])),
        dates: dates,
        data_points: length(historical_data)
      }
    end
  end

  defp parse_date(metrics) do
    case DateTime.from_iso8601(metrics.timestamp) do
      {:ok, datetime, _} -> DateTime.to_date(datetime) |> Date.to_string()
      _ -> "unknown"
    end
  end

  defp generate_test_details_data(historical_data) do
    if Enum.empty?(historical_data) do
      %{no_data: true}
    else
      # Get all unique test modules and their performance
      all_module_results =
        historical_data
        |> Enum.flat_map(&extract_module_results/1)
        |> Enum.group_by(& &1.module)

      module_stats =
        all_module_results
        |> Map.new(fn {module, results} ->
          {module,
           %{
             total_runs: length(results),
             avg_duration: results |> Enum.map(& &1.avg_duration) |> average(),
             failure_rate: Enum.count(results, &(&1.failed_tests > 0)) / length(results) * 100,
             test_count: results |> Enum.map(& &1.total_tests) |> Enum.max(fn -> 0 end)
           }}
        end)

      %{
        module_statistics: module_stats,
        slowest_modules: find_slowest_modules(module_stats),
        most_failing_modules: find_most_failing_modules(module_stats)
      }
    end
  end

  defp extract_module_results(metrics) do
    case get_in(metrics, [:module_results]) do
      nil ->
        []

      module_results ->
        Enum.map(module_results, fn {module, stats} ->
          Map.put(stats, :module, module)
        end)
    end
  end

  defp find_slowest_modules(module_stats) do
    module_stats
    |> Enum.sort_by(fn {_module, stats} -> stats.avg_duration end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {module, stats} ->
      %{module: module, avg_duration: stats.avg_duration}
    end)
  end

  defp find_most_failing_modules(module_stats) do
    module_stats
    |> Enum.sort_by(fn {_module, stats} -> stats.failure_rate end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {module, stats} ->
      %{module: module, failure_rate: stats.failure_rate}
    end)
  end

  defp generate_performance_data(historical_data) do
    if Enum.empty?(historical_data) do
      %{no_data: true}
    else
      all_slow_tests =
        historical_data
        |> Enum.flat_map(&extract_slow_tests/1)
        |> Enum.group_by(& &1.test)

      slow_test_stats =
        all_slow_tests
        |> Map.new(fn {test, instances} ->
          {test,
           %{
             avg_duration: instances |> Enum.map(& &1.duration_ms) |> average(),
             max_duration: instances |> Enum.map(& &1.duration_ms) |> Enum.max(fn -> 0 end),
             occurrences: length(instances)
           }}
        end)

      %{
        slowest_tests:
          slow_test_stats
          |> Enum.sort_by(fn {_test, stats} -> stats.avg_duration end, :desc)
          |> Enum.take(20),
        performance_distribution: calculate_performance_distribution(historical_data)
      }
    end
  end

  defp extract_slow_tests(metrics) do
    case get_in(metrics, [:performance, :slowest_tests]) do
      nil -> []
      slow_tests -> slow_tests
    end
  end

  defp calculate_performance_distribution(historical_data) do
    all_durations = historical_data |> Enum.map(& &1.duration_ms)

    %{
      min: Enum.min(all_durations, fn -> 0 end),
      max: Enum.max(all_durations, fn -> 0 end),
      avg: average(all_durations),
      median: median(all_durations),
      p95: percentile(all_durations, 95)
    }
  end

  defp generate_alerts_data(trends) do
    alerts = []

    # Check for declining success rate
    success_trend = get_in(trends, [:success_rate_trend, :trend]) || 0

    alerts =
      if success_trend < -1.0 do
        [
          %{
            type: "warning",
            title: "Declining Success Rate",
            message: "Test success rate has been declining",
            priority: "high"
          }
          | alerts
        ]
      else
        alerts
      end

    # Check for performance degradation
    perf_trend = get_in(trends, [:performance_trend, :trend]) || 0

    alerts =
      if perf_trend > 1000 do
        [
          %{
            type: "warning",
            title: "Performance Degradation",
            message: "Test execution time has been increasing",
            priority: "medium"
          }
          | alerts
        ]
      else
        alerts
      end

    # Check for flaky tests
    flaky_count = length(get_in(trends, [:failure_patterns, :flaky_test_candidates]) || [])

    alerts =
      if flaky_count > 0 do
        [
          %{
            type: "info",
            title: "Flaky Tests Detected",
            message: "#{flaky_count} potentially flaky tests found",
            priority: "medium"
          }
          | alerts
        ]
      else
        alerts
      end

    %{
      active_alerts: alerts,
      alert_count: length(alerts)
    }
  end

  defp generate_recommendations_data(trends) do
    recommendations = []

    # Performance recommendations
    perf_trend = get_in(trends, [:performance_trend, :trend]) || 0

    recommendations =
      if perf_trend > 500 do
        [
          %{
            category: "Performance",
            title: "Optimize Slow Tests",
            description: "Consider optimizing tests that take longer than expected",
            action: "Review slowest tests and optimize database setup or test logic"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Stability recommendations
    flaky_tests = get_in(trends, [:failure_patterns, :flaky_test_candidates]) || []

    recommendations =
      if length(flaky_tests) > 0 do
        [
          %{
            category: "Stability",
            title: "Address Flaky Tests",
            description: "Intermittent test failures reduce confidence",
            action:
              "Investigate and fix flaky tests: #{Enum.take(flaky_tests, 3) |> Enum.map(& &1.test) |> Enum.join(", ")}"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Coverage recommendations
    coverage_trend = get_in(trends, [:coverage_trend, :trend]) || 0

    recommendations =
      if coverage_trend < -0.5 do
        [
          %{
            category: "Coverage",
            title: "Improve Test Coverage",
            description: "Test coverage has been declining",
            action: "Add tests for uncovered code paths"
          }
          | recommendations
        ]
      else
        recommendations
      end

    %{
      recommendations: recommendations,
      recommendation_count: length(recommendations)
    }
  end

  defp create_dashboard_files(data) do
    # Ensure directory exists
    File.mkdir_p!("test_metrics/dashboard")

    # Create main dashboard HTML
    create_main_dashboard(data)

    # Create dashboard data JSON
    create_dashboard_data_file(data)

    # Create CSS and JS files
    create_dashboard_assets()

    Mix.shell().info("✅ Dashboard files created in test_metrics/dashboard/")
  end

  defp create_main_dashboard(data) do
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Test Health Dashboard - Wanderer</title>
        <link rel="stylesheet" href="dashboard.css">
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/date-fns@2.28.0/index.min.js"></script>
    </head>
    <body>
        <div class="dashboard">
            <!-- Header -->
            <header class="dashboard-header">
                <h1>🧪 Test Health Dashboard</h1>
                <div class="header-info">
                    <span>Wanderer Project</span>
                    <span id="last-updated">Last updated: Loading...</span>
                </div>
            </header>
            
            <!-- Overview Section -->
            <section class="overview-section">
                <div class="overview-grid">
                    <div class="metric-card health-score">
                        <h3>Overall Health</h3>
                        <div class="metric-value" id="health-score">#{Float.round(data.overview.health_score, 1)}%</div>
                        <div class="metric-status" id="health-status">#{get_status_text(data.overview.current_status[:status])}</div>
                    </div>
                    
                    <div class="metric-card">
                        <h3>Success Rate</h3>
                        <div class="metric-value success-rate" id="success-rate">#{Float.round(data.overview.current_status[:success_rate] || 0, 1)}%</div>
                        <div class="trend-indicator #{data.overview.trend_indicators.success_rate_trend}" id="success-trend">#{get_trend_text(data.overview.trend_indicators.success_rate_trend)}</div>
                    </div>
                    
                    <div class="metric-card">
                        <h3>Test Count</h3>
                        <div class="metric-value" id="test-count">#{data.overview.key_metrics.total_tests}</div>
                        <div class="metric-label">Total Tests</div>
                    </div>
                    
                    <div class="metric-card">
                        <h3>Duration</h3>
                        <div class="metric-value" id="duration">#{data.overview.key_metrics.duration_seconds}s</div>
                        <div class="trend-indicator #{data.overview.trend_indicators.performance_trend}" id="duration-trend">#{get_trend_text(data.overview.trend_indicators.performance_trend)}</div>
                    </div>
                </div>
            </section>
            
            <!-- Alerts Section -->
            <section class="alerts-section">
                <h2>🚨 Active Alerts</h2>
                <div id="alerts-container">
                    #{render_alerts(data.alerts.active_alerts)}
                </div>
            </section>
            
            <!-- Charts Section -->
            <section class="charts-section">
                <div class="charts-grid">
                    <div class="chart-card">
                        <h3>📈 Success Rate Trend</h3>
                        <canvas id="successRateChart"></canvas>
                    </div>
                    
                    <div class="chart-card">
                        <h3>⏱️ Performance Trend</h3>
                        <canvas id="performanceChart"></canvas>
                    </div>
                </div>
            </section>
            
            <!-- Details Sections -->
            <section class="details-section">
                <div class="details-grid">
                    <div class="detail-card">
                        <h3>🐌 Slowest Tests</h3>
                        <div id="slow-tests-list">
                            #{render_slow_tests(data.performance[:slowest_tests] || [])}
                        </div>
                    </div>
                    
                    <div class="detail-card">
                        <h3>💡 Recommendations</h3>
                        <div id="recommendations-list">
                            #{render_recommendations(data.recommendations.recommendations)}
                        </div>
                    </div>
                </div>
            </section>
        </div>
        
        <script src="dashboard.js"></script>
        <script>
            // Initialize dashboard with data
            window.dashboardData = #{Jason.encode!(data)};
            initializeDashboard();
        </script>
    </body>
    </html>
    """

    File.write!("test_metrics/dashboard/index.html", html_content)
  end

  defp get_status_text("excellent"), do: "🌟 Excellent"
  defp get_status_text("good"), do: "✅ Good"
  defp get_status_text("warning"), do: "⚠️ Warning"
  defp get_status_text("critical"), do: "❌ Critical"
  defp get_status_text(_), do: "❓ Unknown"

  defp get_trend_text("improving"), do: "📈 Improving"
  defp get_trend_text("declining"), do: "📉 Declining"
  defp get_trend_text("stable"), do: "➡️ Stable"

  defp render_alerts([]), do: "<div class='no-alerts'>✅ No active alerts</div>"

  defp render_alerts(alerts) do
    alerts
    |> Enum.map(fn alert ->
      """
      <div class="alert alert-#{alert.type} priority-#{alert.priority}">
          <div class="alert-title">#{alert.title}</div>
          <div class="alert-message">#{alert.message}</div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_slow_tests([]), do: "<div class='no-data'>No performance data available</div>"

  defp render_slow_tests(slow_tests) do
    slow_tests
    |> Enum.take(10)
    |> Enum.map(fn {test, stats} ->
      """
      <div class="test-item">
          <div class="test-name">#{test}</div>
          <div class="test-duration">#{Float.round(stats.avg_duration, 1)}ms avg</div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_recommendations([]),
    do: "<div class='no-recommendations'>✅ No recommendations at this time</div>"

  defp render_recommendations(recommendations) do
    recommendations
    |> Enum.map(fn rec ->
      """
      <div class="recommendation">
          <div class="rec-category">#{rec.category}</div>
          <div class="rec-title">#{rec.title}</div>
          <div class="rec-description">#{rec.description}</div>
          <div class="rec-action">Action: #{rec.action}</div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp create_dashboard_data_file(data) do
    json_content = Jason.encode!(data, pretty: true)
    File.write!("test_metrics/dashboard/data.json", json_content)
  end

  defp create_dashboard_assets do
    create_dashboard_css()
    create_dashboard_js()
  end

  defp create_dashboard_css do
    css_content = """
    /* Dashboard CSS */
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: #f8f9fa;
        color: #333;
        line-height: 1.6;
    }

    .dashboard {
        max-width: 1400px;
        margin: 0 auto;
        padding: 20px;
    }

    .dashboard-header {
        background: white;
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 20px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .dashboard-header h1 {
        font-size: 2rem;
        color: #2c3e50;
    }

    .header-info {
        text-align: right;
        color: #666;
    }

    .overview-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: 20px;
        margin-bottom: 30px;
    }

    .metric-card {
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        text-align: center;
    }

    .metric-card h3 {
        margin-bottom: 10px;
        color: #666;
        font-size: 0.9rem;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }

    .metric-value {
        font-size: 2.5rem;
        font-weight: bold;
        margin-bottom: 5px;
    }

    .health-score .metric-value {
        color: #28a745;
    }

    .success-rate {
        color: #17a2b8;
    }

    .metric-status {
        font-size: 0.9rem;
        color: #666;
    }

    .trend-indicator {
        font-size: 0.8rem;
        padding: 4px 8px;
        border-radius: 4px;
    }

    .trend-indicator.improving {
        background: #d4edda;
        color: #155724;
    }

    .trend-indicator.declining {
        background: #f8d7da;
        color: #721c24;
    }

    .trend-indicator.stable {
        background: #d1ecf1;
        color: #0c5460;
    }

    .alerts-section {
        margin-bottom: 30px;
    }

    .alerts-section h2 {
        margin-bottom: 15px;
        color: #2c3e50;
    }

    .alert {
        background: white;
        padding: 15px;
        border-radius: 8px;
        margin-bottom: 10px;
        border-left: 4px solid;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .alert-warning {
        border-left-color: #ffc107;
    }

    .alert-info {
        border-left-color: #17a2b8;
    }

    .alert-title {
        font-weight: bold;
        margin-bottom: 5px;
    }

    .no-alerts {
        background: white;
        padding: 20px;
        border-radius: 8px;
        text-align: center;
        color: #28a745;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .charts-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
        gap: 20px;
        margin-bottom: 30px;
    }

    .chart-card {
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .chart-card h3 {
        margin-bottom: 15px;
        color: #2c3e50;
    }

    .details-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
        gap: 20px;
    }

    .detail-card {
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .detail-card h3 {
        margin-bottom: 15px;
        color: #2c3e50;
    }

    .test-item {
        display: flex;
        justify-content: space-between;
        padding: 8px 0;
        border-bottom: 1px solid #eee;
    }

    .test-name {
        flex: 1;
        font-family: monospace;
        font-size: 0.9rem;
    }

    .test-duration {
        color: #666;
        font-size: 0.9rem;
    }

    .recommendation {
        margin-bottom: 15px;
        padding: 10px;
        background: #f8f9fa;
        border-radius: 4px;
    }

    .rec-category {
        font-size: 0.8rem;
        color: #666;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }

    .rec-title {
        font-weight: bold;
        margin: 5px 0;
    }

    .rec-description {
        color: #666;
        margin-bottom: 5px;
    }

    .rec-action {
        font-size: 0.9rem;
        color: #0066cc;
    }

    .no-data, .no-recommendations {
        text-align: center;
        color: #666;
        padding: 20px;
    }

    @media (max-width: 768px) {
        .dashboard {
            padding: 10px;
        }
        
        .dashboard-header {
            flex-direction: column;
            text-align: center;
            gap: 10px;
        }
        
        .overview-grid,
        .charts-grid,
        .details-grid {
            grid-template-columns: 1fr;
        }
    }
    """

    File.write!("test_metrics/dashboard/dashboard.css", css_content)
  end

  defp create_dashboard_js do
    js_content = """
    // Dashboard JavaScript
    function initializeDashboard() {
        updateLastUpdated();
        createCharts();
        setupAutoRefresh();
    }

    function updateLastUpdated() {
        const now = new Date();
        document.getElementById('last-updated').textContent = 
            `Last updated: ${now.toLocaleString()}`;
    }

    function createCharts() {
        if (window.dashboardData.trends.insufficient_data) {
            return;
        }
        
        createSuccessRateChart();
        createPerformanceChart();
    }

    function createSuccessRateChart() {
        const ctx = document.getElementById('successRateChart').getContext('2d');
        const data = window.dashboardData.trends;
        
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.dates,
                datasets: [{
                    label: 'Success Rate %',
                    data: data.success_rates,
                    borderColor: '#28a745',
                    backgroundColor: 'rgba(40, 167, 69, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    }

    function createPerformanceChart() {
        const ctx = document.getElementById('performanceChart').getContext('2d');
        const data = window.dashboardData.trends;
        
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.dates,
                datasets: [{
                    label: 'Duration (seconds)',
                    data: data.durations,
                    borderColor: '#17a2b8',
                    backgroundColor: 'rgba(23, 162, 184, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            callback: function(value) {
                                return value + 's';
                            }
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    }

    function setupAutoRefresh() {
        // Auto-refresh every 5 minutes if served dynamically
        if (window.location.protocol === 'http:') {
            setInterval(() => {
                window.location.reload();
            }, 5 * 60 * 1000);
        }
    }

    // Export function for external use
    window.refreshDashboard = function() {
        window.location.reload();
    };
    """

    File.write!("test_metrics/dashboard/dashboard.js", js_content)
  end

  defp serve_dashboard(port) do
    Mix.shell().info("🌐 Starting dashboard server on http://localhost:#{port}")

    # Simple HTTP server for the dashboard
    # In a real implementation, you might use Plug.Cowboy or similar
    Mix.shell().info("Dashboard available at: test_metrics/dashboard/index.html")
    Mix.shell().info("💡 Use 'python -m http.server #{port}' in test_metrics/dashboard/ to serve")
  end

  defp export_dashboard do
    Mix.shell().info("📦 Exporting dashboard to static files...")

    # Create a zip file with all dashboard assets
    files = [
      "index.html",
      "dashboard.css",
      "dashboard.js",
      "data.json"
    ]

    # Create export directory
    File.mkdir_p!("test_metrics/export")

    # Copy files to export directory
    for file <- files do
      source = "test_metrics/dashboard/#{file}"
      dest = "test_metrics/export/#{file}"

      if File.exists?(source) do
        File.cp!(source, dest)
      end
    end

    Mix.shell().info("✅ Dashboard exported to test_metrics/export/")
  end

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
