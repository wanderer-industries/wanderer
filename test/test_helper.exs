# Just require the mocks module - it will handle loading everything else
require WandererApp.Test.Mocks

# Start enhanced test components
{:ok, _} = WandererApp.Support.FlakyTestDetector.start_link()

# Configure ExUnit with enhanced formatter
ExUnit.start(
  formatters: [
    WandererApp.Support.FlakyTestFormatter,
    ExUnit.CLIFormatter
  ]
)

# Import Mox for test-specific expectations
# import Mox

# Start the application in test mode
{:ok, _} = Application.ensure_all_started(:wanderer_app)

# Ensure critical services are ready
case GenServer.whereis(WandererApp.Repo) do
  nil ->
    IO.puts("WARNING: WandererApp.Repo not started!")
    raise "Repository not available for tests"

  _pid ->
    :ok
end

case GenServer.whereis(WandererApp.Cache) do
  nil ->
    IO.puts("WARNING: WandererApp.Cache not started!")
    raise "Cache not available for tests"

  _pid ->
    :ok
end

case Process.whereis(WandererApp.MapRegistry) do
  nil ->
    IO.puts("WARNING: WandererApp.MapRegistry not started!")
    raise "MapRegistry not available for tests"

  _pid ->
    :ok
end

# Setup Ecto Sandbox for database isolation
Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)

# Add global setup for test isolation
ExUnit.configure(
  setup: fn _tags ->
    # Ensure test isolation
    :ok
  end
)

# Set up test configuration - exclude integration tests by default for faster unit tests
# Use performance optimizer for dynamic configuration
case Code.ensure_loaded(WandererApp.Test.Optimizer) do
  {:module, _} ->
    # Use the performance optimizer if available
    config = WandererApp.Test.Optimizer.configure_optimal_settings()

    ExUnit.configure(
      exclude: [:pending, :integration],
      timeout: config.timeout,
      max_cases: config.max_cases,
      capture_log: false,
      refute_receive_timeout: 100,
      # Re-enable autorun for normal test execution
      autorun: true
    )

  {:error, _} ->
    # Fallback to static configuration
    System.schedulers_online()
    |> max(4)
    |> min(24)
    |> then(fn max_cases ->
      ExUnit.configure(
        exclude: [:pending, :integration],
        timeout: 30_000,
        max_cases: max_cases,
        capture_log: false,
        refute_receive_timeout: 100
      )
    end)
end

# Start enhanced performance monitoring if enabled
if System.get_env("PERFORMANCE_MONITORING") do
  # Start performance monitoring services
  case WandererApp.EnhancedPerformanceMonitor.start_link() do
    {:ok, _pid} ->
      IO.puts("🔬 Enhanced performance monitoring enabled")

    {:error, {:already_started, _pid}} ->
      IO.puts("🔬 Enhanced performance monitoring already running")

    error ->
      IO.puts("⚠️  Failed to start performance monitoring: #{inspect(error)}")
  end

  # Start test monitor for flaky test detection
  case WandererApp.TestMonitor.start_link() do
    {:ok, _pid} ->
      IO.puts("📊 Test monitoring and flaky test detection enabled")

    {:error, {:already_started, _pid}} ->
      IO.puts("📊 Test monitor already running")

    error ->
      IO.puts("⚠️  Failed to start test monitor: #{inspect(error)}")
  end

  # Add performance formatter to ExUnit
  current_formatters = ExUnit.configuration()[:formatters] || [ExUnit.CLIFormatter]
  updated_formatters = [WandererApp.TestMonitor.ExUnitFormatter | current_formatters]

  ExUnit.configure(formatters: updated_formatters)
end

# Optional: Print test configuration info
if System.get_env("VERBOSE_TESTS") do
  IO.puts("🧪 Test environment configured:")
  IO.puts("   Database: wanderer_test#{System.get_env("MIX_TEST_PARTITION")}")
  IO.puts("   Repo: #{WandererApp.Repo}")
  IO.puts("   Sandbox mode: manual")

  config = ExUnit.configuration()
  IO.puts("   Max cases: #{config[:max_cases]}")
  IO.puts("   Timeout: #{config[:timeout]}ms")
  IO.puts("   Formatters: #{Enum.join(Enum.map(config[:formatters], &inspect/1), ", ")}")
end
