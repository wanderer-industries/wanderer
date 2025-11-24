# Ensure we're in test environment BEFORE anything else
Application.put_env(:wanderer_app, :environment, :test)

# Start ExUnit
ExUnit.start()

# Start the application
{:ok, _} = Application.ensure_all_started(:wanderer_app)

# Setup Ecto Sandbox for database isolation
# This must happen AFTER app start so Repo is available
Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)

# Set Mox to private mode
# This enables async tests by ensuring mocks are isolated per test process
# Each test that uses mocks must call set_mox_private() in setup to claim ownership
if Code.ensure_loaded?(Mox) do
  Mox.set_mox_private()
end

# Ensure map supervisors are started for all tests
# This creates the required registries (:map_pool_registry, :unique_map_pool_registry)
# that are needed by Map.Manager and other map-related components
WandererApp.Test.IntegrationConfig.ensure_map_supervisors_started()

# Basic ExUnit configuration
ExUnit.configure(
  exclude: [:pending, :integration],
  capture_log: false,
  max_cases: System.schedulers_online()
)
