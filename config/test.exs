import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :wanderer_app, WandererApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  database: "wanderer_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  log: false

config :wanderer_app,
  ddrt: Test.DDRTMock,
  logger: Test.LoggerMock,
  pubsub_client: Test.PubSubMock,
  esi_client: WandererApp.Esi.Mock,
  map_server: Test.MapServerMock,
  character_api_disabled: false,
  public_api_disabled: false,
  env: :test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wanderer_app, WandererAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "EwyoYRR07BYb4vIbKfPni4LVtxAxEIRtyNPpeKx2sJbErbvWrT+0pOMzONlJDzcL",
  server: false,
  log_requests: false

# In test we don't send emails.
config :wanderer_app, WandererApp.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test (suppress info/debug)
config :logger, level: :warning

# Reduce Ecto logging noise in tests  
config :logger, :console,
  format: "[$level] $message\n",
  level: :warning

# Suppress Phoenix access logs in tests
config :phoenix, :logger, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Guardian configuration for tests - use a fixed secret for reproducible tests
config :wanderer_app, WandererApp.Guardian,
  issuer: "wanderer_app",
  secret_key: "test_secret_key_that_is_exactly_64_characters_long_for_guardian",
  ttl: {30, :days}
