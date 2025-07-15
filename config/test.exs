import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :wanderer_app, WandererApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "wanderer_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Optimize pool size for concurrent test execution
  pool_size: System.schedulers_online() |> max(20) |> min(50),
  # Reduce timeouts for faster test failures and better resource management
  # Reduced from 60s
  ownership_timeout: 30_000,
  # Reduced from 60s for faster feedback
  timeout: 15_000,
  # Performance optimizations for test database
  # Skip statement preparation for test speed
  prepare: :unnamed,
  parameters: [
    # PostgreSQL performance tuning for tests
    # 15s statement timeout
    {"statement_timeout", "15000"},
    # 10s lock timeout
    {"lock_timeout", "10000"},
    # 30s idle timeout
    {"idle_in_transaction_session_timeout", "30000"}
  ]

# Set environment variable before config runs to ensure character API is enabled in tests
System.put_env("WANDERER_CHARACTER_API_DISABLED", "false")

config :wanderer_app,
  ddrt: Test.DDRTMock,
  logger: Test.LoggerMock,
  # Use real PubSub for integration tests
  pubsub_client: Phoenix.PubSub,
  cached_info: WandererApp.CachedInfo.Mock,
  character_api_disabled: false,
  websocket_events_enabled: true,
  environment: :test

# Disable Ash async loading in tests to prevent database ownership issues
config :ash, :disable_async?, true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wanderer_app, WandererAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "EwyoYRR07BYb4vIbKfPni4LVtxAxEIRtyNPpeKx2sJbErbvWrT+0pOMzONlJDzcL",
  server: false

# In test we don't send emails.
config :wanderer_app, WandererApp.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure MIME types for testing, including XML for error response contract tests
config :mime, :types, %{
  "application/xml" => ["xml"]
}
