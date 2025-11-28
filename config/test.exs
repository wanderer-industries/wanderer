import Config

# Disable Ash async operations in tests to ensure transactional safety
# This prevents Ash from spawning tasks that could bypass the Ecto sandbox
config :ash, :disable_async?, true

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
  pool_size: 20,
  ownership_timeout: 60_000,
  timeout: 60_000

# Set environment variable before config runs to ensure character API is enabled in tests
System.put_env("WANDERER_CHARACTER_API_DISABLED", "false")

config :wanderer_app,
  ddrt: Test.DDRTMock,
  logger: Test.LoggerMock,
  pubsub_client: Test.PubSubMock,
  cached_info: WandererApp.CachedInfo.Mock,
  character_api_disabled: false,
  environment: :test,
  map_subscriptions_enabled: false,
  wanderer_kills_service_enabled: false,
  sse: [enabled: false],
  external_events: [webhooks_enabled: false]

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
