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
    WandererApp.DataCase.setup_sandbox(tags)

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

    # Ensure mocks are properly set up before starting map server
    if Code.ensure_loaded?(Mox) do
      Mox.set_mox_global()

      if Code.ensure_loaded?(WandererApp.Test.Mocks) do
        WandererApp.Test.Mocks.setup_additional_expectations()
      end
    end

    # Ensure the map server is started
    WandererApp.TestHelpers.ensure_map_server_started(map.id)

    # Also ensure MapEventRelay has database access if it's running
    if pid = Process.whereis(WandererApp.ExternalEvents.MapEventRelay) do
      WandererApp.DataCase.allow_database_access(pid)
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
end
