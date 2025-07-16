defmodule WandererApp.PerformanceDashboard do
  @moduledoc """
  Real-time performance dashboard for monitoring test execution.

  Provides a web interface to view:
  - Live test execution metrics
  - Performance trends and charts
  - Resource usage graphs
  - Performance alerts and notifications
  """

  use GenServer
  require Logger

  @dashboard_port 4001
  @update_interval 1000

  defmodule DashboardState do
    defstruct [
      :cowboy_pid,
      :subscribers,
      :metrics_history,
      :last_update
    ]
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_dashboard(port \\ @dashboard_port) do
    GenServer.call(__MODULE__, {:start_dashboard, port})
  end

  def stop_dashboard do
    GenServer.call(__MODULE__, :stop_dashboard)
  end

  def get_dashboard_url do
    GenServer.call(__MODULE__, :get_dashboard_url)
  end

  ## Server Callbacks

  def init(_opts) do
    # Start periodic updates
    :timer.send_interval(@update_interval, :update_dashboard)

    state = %DashboardState{
      cowboy_pid: nil,
      subscribers: [],
      metrics_history: [],
      last_update: DateTime.utc_now()
    }

    {:ok, state}
  end

  def handle_call({:start_dashboard, port}, _from, state) do
    case start_web_server(port) do
      {:ok, cowboy_pid} ->
        Logger.info("Performance dashboard started on http://localhost:#{port}")
        updated_state = %{state | cowboy_pid: cowboy_pid}
        {:reply, {:ok, "http://localhost:#{port}"}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:stop_dashboard, _from, state) do
    if state.cowboy_pid do
      :cowboy.stop_listener(:performance_dashboard)
    end

    updated_state = %{state | cowboy_pid: nil}
    {:reply, :ok, updated_state}
  end

  def handle_call(:get_dashboard_url, _from, state) do
    url = if state.cowboy_pid, do: "http://localhost:#{@dashboard_port}", else: nil
    {:reply, url, state}
  end

  def handle_info(:update_dashboard, state) do
    # Collect current metrics
    current_metrics = collect_dashboard_metrics()

    # Update history (keep last 100 samples)
    updated_history =
      [current_metrics | state.metrics_history]
      |> Enum.take(100)

    # Broadcast to subscribers
    broadcast_update(state.subscribers, current_metrics)

    updated_state = %{
      state
      | metrics_history: updated_history,
        last_update: DateTime.utc_now()
    }

    {:noreply, updated_state}
  end

  ## Private Functions

  defp start_web_server(port) do
    routes = [
      {"/", __MODULE__.IndexHandler, []},
      {"/api/metrics", __MODULE__.MetricsHandler, []},
      {"/api/websocket", __MODULE__.WebSocketHandler, []},
      {"/static/[...]", :cowboy_static, {:priv_dir, :wanderer_app, "static"}}
    ]

    dispatch = :cowboy_router.compile([{:_, routes}])

    :cowboy.start_clear(
      :performance_dashboard,
      [{:port, port}],
      %{env: %{dispatch: dispatch}}
    )
  end

  defp collect_dashboard_metrics do
    # Get metrics from the enhanced performance monitor
    real_time_metrics =
      case Process.whereis(WandererApp.EnhancedPerformanceMonitor) do
        nil -> %{}
        _pid -> WandererApp.EnhancedPerformanceMonitor.get_real_time_metrics()
      end

    %{
      timestamp: DateTime.utc_now(),
      system_metrics: %{
        memory_usage: :erlang.memory(:total),
        process_count: :erlang.system_info(:process_count),
        cpu_usage: get_cpu_usage(),
        test_processes: count_test_processes()
      },
      test_metrics: real_time_metrics,
      performance_alerts: get_performance_alerts()
    }
  end

  defp broadcast_update(subscribers, metrics) do
    message = Jason.encode!(%{type: "metrics_update", data: metrics})

    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:websocket_message, message})
      end
    end)
  end

  defp get_cpu_usage do
    case :cpu_sup.util() do
      {:error, _} -> 0.0
      usage when is_number(usage) -> usage
      _ -> 0.0
    end
  end

  defp count_test_processes do
    Process.list()
    |> Enum.count(fn pid ->
      case Process.info(pid, :current_function) do
        {:current_function, {ExUnit, _, _}} -> true
        {:current_function, {_, :test, _}} -> true
        _ -> false
      end
    end)
  end

  defp get_performance_alerts do
    case Process.whereis(WandererApp.EnhancedPerformanceMonitor) do
      nil ->
        []

      _pid ->
        dashboard_data = WandererApp.EnhancedPerformanceMonitor.generate_performance_dashboard()
        Map.get(dashboard_data, :alerts, [])
    end
  end

  ## HTTP Handlers

  defmodule IndexHandler do
    def init(req, state) do
      html = generate_dashboard_html()

      req =
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/html"},
          html,
          req
        )

      {:ok, req, state}
    end

    defp generate_dashboard_html do
      """
      <!DOCTYPE html>
      <html>
      <head>
          <title>Test Performance Dashboard</title>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
          <style>
              body { 
                  font-family: Arial, sans-serif; 
                  margin: 0; 
                  padding: 20px; 
                  background-color: #f5f5f5; 
              }
              .dashboard { 
                  display: grid; 
                  grid-template-columns: 1fr 1fr; 
                  gap: 20px; 
              }
              .widget { 
                  background: white; 
                  padding: 20px; 
                  border-radius: 8px; 
                  box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
              }
              .metric { 
                  display: flex; 
                  justify-content: space-between; 
                  margin: 10px 0; 
              }
              .alert { 
                  background: #ffebee; 
                  border-left: 4px solid #f44336; 
                  padding: 10px; 
                  margin: 10px 0; 
              }
              .warning { 
                  background: #fff3e0; 
                  border-left: 4px solid #ff9800; 
              }
              .success { 
                  background: #e8f5e8; 
                  border-left: 4px solid #4caf50; 
              }
              h1, h2 { 
                  color: #333; 
              }
              .status-dot { 
                  display: inline-block; 
                  width: 10px; 
                  height: 10px; 
                  border-radius: 50%; 
                  margin-right: 8px; 
              }
              .running { background-color: #4caf50; }
              .warning { background-color: #ff9800; }
              .error { background-color: #f44336; }
              .chart-container { 
                  position: relative; 
                  height: 300px; 
                  margin-top: 20px; 
              }
          </style>
      </head>
      <body>
          <h1>🧪 Test Performance Dashboard</h1>
          
          <div class="dashboard">
              <div class="widget">
                  <h2>System Metrics</h2>
                  <div id="system-metrics">
                      <div class="metric">
                          <span>Memory Usage:</span>
                          <span id="memory-usage">Loading...</span>
                      </div>
                      <div class="metric">
                          <span>Process Count:</span>
                          <span id="process-count">Loading...</span>
                      </div>
                      <div class="metric">
                          <span>CPU Usage:</span>
                          <span id="cpu-usage">Loading...</span>
                      </div>
                      <div class="metric">
                          <span>Test Processes:</span>
                          <span id="test-processes">Loading...</span>
                      </div>
                  </div>
              </div>

              <div class="widget">
                  <h2>Active Tests</h2>
                  <div id="active-tests">
                      <p>No active tests</p>
                  </div>
              </div>

              <div class="widget">
                  <h2>Performance Alerts</h2>
                  <div id="alerts">
                      <div class="alert success">
                          <span class="status-dot running"></span>
                          All systems operational
                      </div>
                  </div>
              </div>

              <div class="widget">
                  <h2>Memory Usage Trend</h2>
                  <div class="chart-container">
                      <canvas id="memory-chart"></canvas>
                  </div>
              </div>
          </div>

          <script>
              // WebSocket connection for real-time updates
              const ws = new WebSocket('ws://localhost:#{@dashboard_port}/api/websocket');
              
              let memoryChart;
              const memoryData = [];
              
              // Initialize charts
              function initCharts() {
                  const ctx = document.getElementById('memory-chart').getContext('2d');
                  memoryChart = new Chart(ctx, {
                      type: 'line',
                      data: {
                          labels: [],
                          datasets: [{
                              label: 'Memory Usage (MB)',
                              data: [],
                              borderColor: 'rgb(75, 192, 192)',
                              tension: 0.1
                          }]
                      },
                      options: {
                          responsive: true,
                          maintainAspectRatio: false,
                          scales: {
                              y: {
                                  beginAtZero: true
                              }
                          }
                      }
                  });
              }

              // Update dashboard with new metrics
              function updateDashboard(metrics) {
                  // Update system metrics
                  document.getElementById('memory-usage').textContent = 
                      formatBytes(metrics.system_metrics.memory_usage);
                  document.getElementById('process-count').textContent = 
                      metrics.system_metrics.process_count;
                  document.getElementById('cpu-usage').textContent = 
                      metrics.system_metrics.cpu_usage.toFixed(1) + '%';
                  document.getElementById('test-processes').textContent = 
                      metrics.system_metrics.test_processes;

                  // Update memory chart
                  const now = new Date().toLocaleTimeString();
                  memoryChart.data.labels.push(now);
                  memoryChart.data.datasets[0].data.push(
                      metrics.system_metrics.memory_usage / 1024 / 1024
                  );
                  
                  // Keep only last 20 data points
                  if (memoryChart.data.labels.length > 20) {
                      memoryChart.data.labels.shift();
                      memoryChart.data.datasets[0].data.shift();
                  }
                  
                  memoryChart.update('none');

                  // Update active tests
                  updateActiveTests(metrics.test_metrics);
                  
                  // Update alerts
                  updateAlerts(metrics.performance_alerts || []);
              }

              function updateActiveTests(testMetrics) {
                  const container = document.getElementById('active-tests');
                  
                  if (Object.keys(testMetrics).length === 0) {
                      container.innerHTML = '<p>No active tests</p>';
                      return;
                  }

                  let html = '';
                  for (const [testName, metrics] of Object.entries(testMetrics)) {
                      const statusClass = metrics.budget_exceeded ? 'error' : 'running';
                      html += `
                          <div class="metric">
                              <span>
                                  <span class="status-dot ${statusClass}"></span>
                                  ${testName}
                              </span>
                              <span>${metrics.duration_ms}ms</span>
                          </div>
                      `;
                  }
                  
                  container.innerHTML = html;
              }

              function updateAlerts(alerts) {
                  const container = document.getElementById('alerts');
                  
                  if (alerts.length === 0) {
                      container.innerHTML = `
                          <div class="alert success">
                              <span class="status-dot running"></span>
                              All systems operational
                          </div>
                      `;
                      return;
                  }

                  let html = '';
                  alerts.forEach(alert => {
                      const alertClass = alert.severity === 'error' ? 'alert' : 'alert warning';
                      const dotClass = alert.severity === 'error' ? 'error' : 'warning';
                      
                      html += `
                          <div class="${alertClass}">
                              <span class="status-dot ${dotClass}"></span>
                              <strong>${alert.test_name}:</strong> ${alert.message}
                          </div>
                      `;
                  });
                  
                  container.innerHTML = html;
              }

              function formatBytes(bytes) {
                  if (bytes === 0) return '0 Bytes';
                  const k = 1024;
                  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
                  const i = Math.floor(Math.log(bytes) / Math.log(k));
                  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
              }

              // WebSocket event handlers
              ws.onopen = function(event) {
                  console.log('Connected to performance dashboard');
                  initCharts();
              };

              ws.onmessage = function(event) {
                  const message = JSON.parse(event.data);
                  if (message.type === 'metrics_update') {
                      updateDashboard(message.data);
                  }
              };

              ws.onclose = function(event) {
                  console.log('Disconnected from performance dashboard');
                  setTimeout(() => {
                      window.location.reload();
                  }, 5000);
              };

              ws.onerror = function(error) {
                  console.error('WebSocket error:', error);
              };
          </script>
      </body>
      </html>
      """
    end
  end

  defmodule MetricsHandler do
    def init(req, state) do
      metrics = WandererApp.PerformanceDashboard.collect_dashboard_metrics()
      json = Jason.encode!(metrics)

      req =
        :cowboy_req.reply(
          200,
          %{"content-type" => "application/json"},
          json,
          req
        )

      {:ok, req, state}
    end
  end

  defmodule WebSocketHandler do
    def init(req, _state) do
      {:cowboy_websocket, req, %{}}
    end

    def websocket_init(state) do
      # Register this WebSocket with the dashboard
      GenServer.cast(WandererApp.PerformanceDashboard, {:subscribe, self()})
      {:ok, state}
    end

    def websocket_handle({:text, msg}, state) do
      # Handle incoming WebSocket messages if needed
      {:ok, state}
    end

    def websocket_info({:websocket_message, msg}, state) do
      {:reply, {:text, msg}, state}
    end

    def websocket_info(_info, state) do
      {:ok, state}
    end

    def terminate(_reason, _req, _state) do
      # Unregister from dashboard
      GenServer.cast(WandererApp.PerformanceDashboard, {:unsubscribe, self()})
      :ok
    end
  end

  def handle_cast({:subscribe, pid}, state) do
    updated_subscribers = [pid | state.subscribers]
    {:noreply, %{state | subscribers: updated_subscribers}}
  end

  def handle_cast({:unsubscribe, pid}, state) do
    updated_subscribers = Enum.reject(state.subscribers, &(&1 == pid))
    {:noreply, %{state | subscribers: updated_subscribers}}
  end
end
