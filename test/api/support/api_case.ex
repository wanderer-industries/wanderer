defmodule WandererApp.ApiCase do
  @moduledoc """
  This module defines the test case to be used by
  API tests.

  It provides helper functions for setting up authenticated requests,
  creating test data, and common API test assertions.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import WandererApp.ApiCase
      import WandererApp.Factory
      import WandererApp.FactoryHelpers
      import WandererApp.Test.AuthHelpers
      import WandererApp.Test.OpenApiAssert
      import WandererApp.Test.MapTestHelpers

      require Phoenix.ConnTest
      require WandererApp.Test.OpenApiAssert

      alias WandererApp.Repo
      alias WandererApp.Test.MapServerMock

      # The default endpoint for testing
      @endpoint WandererAppWeb.Endpoint

      # Re-export helper functions that need @endpoint
      def get_paginated(conn, path, params \\ %{}) do
        query_string = URI.encode_query(params)
        get(conn, "#{path}?#{query_string}")
      end

      def api_request(conn, method, path, params \\ %{}) do
        case method do
          :get -> get(conn, path)
          :post -> post(conn, path, Jason.encode!(params))
          :put -> put(conn, path, Jason.encode!(params))
          :patch -> patch(conn, path, Jason.encode!(params))
          :delete -> delete(conn, path)
        end
      end

      def assert_json_response(conn, status, expected) do
        conn
        |> WandererApp.ApiCase.assert_status(status)
        |> json_response(status)
        |> WandererApp.ApiCase.assert_json_match(expected)
      end

      def assert_error_response(conn, status, error_key) do
        response = json_response(conn, status)

        assert Map.has_key?(response, "errors")
        assert Map.has_key?(response["errors"], to_string(error_key))

        response
      end

      def json_response!(conn, expected_status \\ 200) do
        actual_status = conn.status

        if actual_status != expected_status do
          body = conn.resp_body
          raise "Expected status #{expected_status}, got #{actual_status}. Response: #{body}"
        end

        json_response(conn, expected_status)
      end

      def validated_request(conn, method, path, params \\ %{}) do
        conn = api_request(conn, method, path, params)

        # Always validate against OpenAPI spec
        WandererApp.Test.OpenApiAssert.assert_conforms!(conn, conn.status)

        conn
      end

      def assert_success_response(conn, expected_status \\ 200) do
        assert conn.status == expected_status

        # Always validate against OpenAPI spec
        WandererApp.Test.OpenApiAssert.assert_conforms!(conn, expected_status)

        # Handle 204 No Content responses
        if expected_status == 204 do
          nil
        else
          json_response!(conn, expected_status)
        end
      end

      def with_pagination(conn, path, opts \\ []) do
        default_params = %{
          "page" => Keyword.get(opts, :page, 1),
          "page_size" => Keyword.get(opts, :page_size, 20)
        }

        params = Map.merge(default_params, Keyword.get(opts, :params, %{}))
        get_paginated(conn, path, params)
      end
    end
  end

  setup tags do
    # Clean up any leftover processes from previous tests
    WandererApp.TestCleanup.cleanup()

    # Setup Ecto sandbox - handle both async and shared mode
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WandererApp.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, {:shared, self()})
    end

    # Load environment variables if not already loaded
    WandererApp.EnvHelper.load_env_file()

    # Setup map server mocking if requested
    if tags[:with_map_mock] do
      # This tag can be used to automatically set up map mocking
      # Usage: @tag with_map_mock: true
      on_exit(fn ->
        # Cleanup will be handled by individual test cleanup
        :ok
      end)
    end

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("content-type", "application/json")

    {:ok, conn: conn}
  end

  @doc """
  Setup helper that authenticates a user for API requests.
  Uses proper JWT token generation.
  """
  def authenticate_user(conn, user) do
    token = WandererApp.Test.AuthHelpers.generate_jwt_token(user)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
  end

  @doc """
  Setup helper that authenticates a character for API requests.
  """
  def authenticate_character(conn, character) do
    token = WandererApp.Test.AuthHelpers.generate_character_token(character)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
  end

  @doc """
  Setup helper that adds API key authentication for maps.
  Uses Bearer token authentication as per the CheckMapApiKey plug.
  """
  def authenticate_map(conn, api_key) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key}")
  end

  @doc """
  Setup helper that adds API key authentication for ACLs.
  Uses Bearer token authentication as per the CheckAclApiKey plug.
  """
  def authenticate_acl(conn, api_key) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key}")
  end

  @doc """
  Deprecated: Use authenticate_map or authenticate_acl instead.
  """
  def authenticate_api_key(conn, api_key) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key}")
  end

  @doc """
  Helper to generate authentication token for a user.
  Delegates to AuthHelpers for proper JWT generation.
  """
  def generate_auth_token(user) do
    WandererApp.Test.AuthHelpers.generate_jwt_token(user)
  end

  @doc """
  Assert that the response has a specific status code.
  """
  def assert_status(conn, status) do
    assert conn.status == status
    conn
  end

  @doc """
  Assert that the JSON response matches the expected structure.
  """

  # Note: This function must be called from within a test case
  # where Phoenix.ConnTest is imported and @endpoint is defined

  def assert_json_match(actual, expected) when is_map(expected) do
    Enum.each(expected, fn {key, value} ->
      assert Map.has_key?(actual, to_string(key)), "Expected key #{key} not found in response"

      if is_map(value) or is_list(value) do
        assert_json_match(Map.get(actual, to_string(key)), value)
      else
        assert Map.get(actual, to_string(key)) == value
      end
    end)

    actual
  end

  def assert_json_match(actual, expected) when is_list(expected) and is_list(actual) do
    assert length(actual) == length(expected)

    Enum.zip(actual, expected)
    |> Enum.each(fn {actual_item, expected_item} ->
      assert_json_match(actual_item, expected_item)
    end)

    actual
  end

  def assert_json_match(actual, expected) do
    assert actual == expected
    actual
  end

  @doc """
  Create default headers for API requests.
  """
  def api_headers(additional \\ %{}) do
    Map.merge(
      %{
        "accept" => "application/json",
        "content-type" => "application/json"
      },
      additional
    )
  end

  # This function needs to be called within a test case where @endpoint is defined

  @doc """
  Assert pagination metadata in response.
  """
  def assert_pagination(response, expected \\ %{}) do
    assert Map.has_key?(response, "data")
    assert Map.has_key?(response, "meta")

    meta = response["meta"]

    Enum.each(expected, fn {key, value} ->
      assert meta[to_string(key)] == value
    end)

    response
  end

  # This function needs to be called within a test case where @endpoint is defined

  @doc """
  Assert error response structure.
  """

  # Note: This function must be called from within a test case
  # where Phoenix.ConnTest is imported and @endpoint is defined

  # Authenticate using API token from environment variable.
  def authenticate_with_env_token(conn) do
    api_token = WandererApp.EnvHelper.get_env!("API_TOKEN")

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{api_token}")
  end

  @doc """
  Authenticate using ACL API token from environment variable.
  """
  def authenticate_with_env_acl_token(conn) do
    acl_token = WandererApp.EnvHelper.get_env!("ACL_API_TOKEN")

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{acl_token}")
  end

  # Get test map slug from environment.
  def test_map_slug do
    WandererApp.EnvHelper.get_env!("MAP_SLUG")
  end

  # Get test ACL ID from environment.
  def test_acl_id do
    WandererApp.EnvHelper.get_env!("ACL_ID")
  end

  @doc """
  Helper that raises on non-2xx responses.
  Useful for happy-path testing where you expect success.
  """
  # Note: This function must be called from within a test case
  # where Phoenix.ConnTest is imported and @endpoint is defined

  # These functions are defined in the using block where @endpoint is available

  # Helper to create test data with proper Ash actions.
  def create_test_map_with_auth(attrs \\ %{}) do
    map_data = WandererApp.Factory.setup_test_map_with_auth(attrs)

    # Automatically setup map server mock
    WandererApp.Test.MapServerMock.setup_map_mock(map_data.map.id)

    # Register cleanup
    ExUnit.Callbacks.on_exit(fn ->
      WandererApp.Test.MapServerMock.cleanup_map_mock(map_data.map.id)
    end)

    map_data
  end

  # Helper to create test ACL with proper Ash actions.
  def create_test_acl_with_auth(attrs \\ %{}) do
    WandererApp.Factory.setup_test_acl_with_auth(attrs)
  end

  # Helper for testing error scenarios.
  def assert_error_format(conn, expected_status) do
    assert conn.status == expected_status
    response = Phoenix.ConnTest.json_response(conn, expected_status)

    # Common error response format validation
    case expected_status do
      400 ->
        assert response["error"] || response["errors"]

      401 ->
        assert (response["error"] && response["error"] =~ "Unauthorized") ||
                 (response["message"] && response["message"] =~ "Unauthorized")

      403 ->
        assert (response["error"] && response["error"] =~ "Forbidden") ||
                 (response["message"] && response["message"] =~ "Forbidden")

      404 ->
        assert (response["error"] && response["error"] =~ "not found") ||
                 (response["message"] && response["message"] =~ "not found")

      422 ->
        assert response["errors"] || response["error"]

      _ ->
        response
    end

    response
  end

  # with_pagination is defined in the using block where get_paginated is available

  @doc """
  Test helper for async tests that need database access.
  """
  def setup_sandbox_for_async(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WandererApp.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, {:shared, self()})
    :ok
  end
end
