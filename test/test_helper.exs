# Load mocks first, before anything else starts
require WandererApp.Test.Mocks

ExUnit.start()

# Import Mox for test-specific expectations
import Mox

# Only start the repo for integration tests, not for unit tests
unless "--only unit" in System.argv() do
  # Start the repository only when needed
  _ = WandererApp.Repo.start_link()

  # Start the Vault for encryption
  _ = WandererApp.Vault.start_link()

  # Setup Ecto Sandbox for database isolation
  Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)
end

# Set up test configuration - exclude integration tests by default for faster unit tests
ExUnit.configure(exclude: [:pending, :integration], timeout: 60_000)

# Optional: Print test configuration info
if System.get_env("VERBOSE_TESTS") do
  IO.puts("🧪 Test environment configured:")
  IO.puts("   Database: wanderer_test#{System.get_env("MIX_TEST_PARTITION")}")
  IO.puts("   Repo: #{WandererApp.Repo}")
  IO.puts("   Sandbox mode: manual")
end
