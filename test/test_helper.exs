# Enable legacy API for tests by default
# Individual tests can disable it using WandererApp.DeprecationTestHelpers.with_legacy_api_disabled/1
System.put_env("FEATURE_LEGACY_API", "true")

# Load support files first to ensure mocks are available during compilation
Code.require_file("support/mocks.ex", __DIR__)

# Ensure all applications are started before tests
{:ok, _} = Application.ensure_all_started(:wanderer_app)

# Configure ExUnit
ExUnit.start()

# Set Ecto sandbox mode
Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)

# Ensure mox is started for mocking
Application.ensure_all_started(:mox)

# Load support files
Code.require_file("support/test_cleanup.ex", __DIR__)
