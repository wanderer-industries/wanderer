# API Test Configuration
import Config

# Configure test environment specifically for API tests
config :wanderer_app, WandererAppWeb.Endpoint,
  http: [port: 4002],
  debug_errors: false,
  code_reloader: false,
  check_origin: false,
  watchers: []

# Disable logging during tests for cleaner output
config :logger, level: :warning

# Configure database for test isolation
config :wanderer_app, WandererApp.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# API test specific configurations
config :wanderer_app, :api_tests,
  # Rate limiting configuration for tests
  rate_limit: %{
    requests_per_minute: 60,
    burst_size: 10
  },

  # API versioning
  default_api_version: "v1",
  supported_versions: ["v1"],

  # Test API keys for authentication tests
  test_api_keys: %{
    valid: "test-api-key-valid",
    invalid: "test-api-key-invalid",
    rate_limited: "test-api-key-rate-limited"
  },

  # Mock EVE SSO responses
  mock_eve_sso: true,

  # Pagination defaults
  pagination: %{
    default_page_size: 20,
    max_page_size: 100
  },

  # Response time assertions (in milliseconds)
  performance: %{
    max_response_time: 500,
    max_db_query_time: 100
  }

# Configure mocks for external services
config :wanderer_app, :mocks,
  pubsub: WandererApp.Test.PubSubMock,
  logger: WandererApp.Test.LoggerMock,
  ddrt: WandererApp.Test.DDRTMock

# Disable external API calls during tests
config :wanderer_app, :external_apis,
  eve_esi_enabled: false,
  zkillboard_enabled: false,
  eve_sso_enabled: false

# Test-specific feature flags
config :wanderer_app, :features,
  public_api_enabled: true,
  character_api_enabled: true,
  rate_limiting_enabled: true,
  api_key_auth_enabled: true,
  jwt_auth_enabled: true

# Import environment specific config if it exists
if File.exists?("api-test/config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
