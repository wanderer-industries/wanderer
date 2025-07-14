# Simplified test helper to debug test startup issues
ExUnit.start()

# Import Mox for test-specific expectations
import Mox

# Start the application in test mode
{:ok, _} = Application.ensure_all_started(:wanderer_app)

# Setup Ecto Sandbox for database isolation
Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)

# Set up test configuration
ExUnit.configure(timeout: 60_000)

IO.puts("🧪 Simplified test environment configured successfully")
