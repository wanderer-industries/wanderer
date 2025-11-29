defmodule WandererAppWeb.ApiCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require testing API endpoints with OpenAPI validation.

  Such tests rely on `Phoenix.ConnTest` and include helpers for:
  - OpenAPI schema validation
  - API authentication setup
  - Common response assertions
  - Test data factories
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint WandererAppWeb.Endpoint

      use WandererAppWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import WandererAppWeb.ApiCase

      # Import OpenAPI helpers
      import WandererAppWeb.OpenAPIHelpers

      # Import factories
      import WandererAppWeb.Factory
    end
  end

  setup tags do
    # Determine if this is an integration test based on the test file path
    # Integration tests are in test/integration/ directory
    integration_test? = tags[:file] && String.contains?(tags[:file], "/integration/")

    # Use shared mode for async integration tests
    if integration_test? do
      IO.puts("DEBUG: Integration test detected: #{tags[:file]}")
      WandererAppWeb.IntegrationConnCase.setup_sandbox(tags)
    else
      IO.puts("DEBUG: Unit test detected: #{tags[:file]}")
      WandererApp.DataCase.setup_sandbox(tags)
    end

    # Set up mocks for this test process
    # Use global mode for integration tests so mocks work in spawned processes
    mock_mode = if integration_test?, do: :global, else: :private
    WandererApp.Test.Mocks.setup_test_mocks(mode: mock_mode)

    # Set up integration test environment if needed
    if integration_test? do
      WandererApp.Test.IntegrationConfig.setup_integration_environment()
      WandererApp.Test.IntegrationConfig.setup_test_reliability_configs()

      on_exit(fn ->
        WandererApp.Test.IntegrationConfig.cleanup_integration_environment()
      end)
    end

    # Handle skip_if_api_disabled tag
    # Note: ExUnit skip functionality isn't available in setup, so we'll return :skip
    if Map.has_key?(tags, :skip_if_api_disabled) and WandererApp.Env.character_api_disabled?() do
      {:skip, "Character API is disabled"}
    else
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end
  end

  @doc """
  Helper for creating API authentication headers
  """
  def put_api_key(conn, api_key) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key}")
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  @doc """
  Helper for creating map-specific API authentication
  """
  def authenticate_map_api(conn, map) do
    # Use the map's actual public_api_key if available
    api_key = map.public_api_key || "test_api_key_#{map.id}"
    put_api_key(conn, api_key)
  end

  @doc """
  Helper for asserting successful JSON responses with optional schema validation
  """
  def assert_json_response(conn, status, schema_name \\ nil) do
    response = Phoenix.ConnTest.json_response(conn, status)

    if schema_name do
      WandererAppWeb.OpenAPIHelpers.assert_schema(
        response,
        schema_name,
        WandererAppWeb.OpenAPIHelpers.api_spec()
      )
    end

    response
  end

  @doc """
  Helper for asserting error responses
  """
  def assert_error_response(conn, status, expected_error \\ nil) do
    response = Phoenix.ConnTest.json_response(conn, status)
    assert %{"error" => error_msg} = response

    if expected_error do
      assert error_msg =~ expected_error
    end

    response
  end

  @doc """
  Setup callback for tests that need map authentication.
  Creates a test map and authenticates the connection.
  """
  def setup_map_authentication(%{conn: conn}) do
    # Create a test map
    map = WandererAppWeb.Factory.insert(:map, %{slug: "test-map-#{System.unique_integer()}"})

    # Create an active subscription for the map if subscriptions are enabled
    if WandererApp.Env.map_subscriptions_enabled?() do
      create_active_subscription_for_map(map.id)
    end

    # Ensure the map server is started
    # Note: Map servers are granted database/mock access via the MapPoolSupervisor in DataCase
    WandererApp.TestHelpers.ensure_map_server_started(map.id)

    # Grant database/mock access to MapEventRelay if running
    if pid = Process.whereis(WandererApp.ExternalEvents.MapEventRelay) do
      WandererApp.DataCase.allow_database_access(pid)
      WandererApp.Test.MockOwnership.allow_mocks_for_process(pid)
    end

    # Authenticate the connection with the map's actual public_api_key
    authenticated_conn = put_api_key(conn, map.public_api_key)
    {:ok, conn: authenticated_conn, map: map}
  end

  @doc """
  Setup callback for tests that need map authentication without starting map servers.
  Creates a test map and authenticates the connection, but doesn't start the map server.
  Use this for integration tests that don't need the full map server infrastructure.
  """
  def setup_map_authentication_without_server(%{conn: conn}) do
    # Create a test map
    map = WandererAppWeb.Factory.insert(:map, %{slug: "test-map-#{System.unique_integer()}"})
    # Authenticate the connection with the map's actual public_api_key
    authenticated_conn = put_api_key(conn, map.public_api_key)
    {:ok, conn: authenticated_conn, map: map}
  end

  @doc """
  Helper for creating authenticated connection for JSON:API V1 endpoints.
  Sets both authorization and content-type headers for JSON:API format.
  """
  def create_authenticated_conn(conn, map) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{map.public_api_key}")
    |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
  end

  # Creates an active subscription for a map to bypass subscription checks in tests.
  defp create_active_subscription_for_map(map_id) do
    # Create a subscription with a non-alpha plan (status defaults to :active)
    {:ok, _subscription} =
      Ash.create(WandererApp.Api.MapSubscription, %{
        map_id: map_id,
        plan: :omega,
        characters_limit: 100,
        hubs_limit: 10,
        auto_renew?: true,
        active_till: DateTime.utc_now() |> DateTime.add(30, :day)
      })
  end
end
