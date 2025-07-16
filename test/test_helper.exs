# Start ExUnit
ExUnit.start()

# Ensure we're in test environment before starting the application
Application.put_env(:wanderer_app, :environment, :test)

# Start the application
{:ok, _} = Application.ensure_all_started(:wanderer_app)

# Setup Ecto Sandbox for database isolation
Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)

# Basic ExUnit configuration
ExUnit.configure(
  exclude: [:pending, :integration],
  capture_log: false,
  max_cases: System.schedulers_online()
)
