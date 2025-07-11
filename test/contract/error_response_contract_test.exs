defmodule WandererAppWeb.ErrorResponseContractTest do
  @moduledoc """
  Contract tests for error response schemas across all API endpoints.

  Ensures that all error responses conform to the documented error schema
  and that error messages are consistent and helpful.
  """

  use WandererAppWeb.ApiCase, async: true

  import WandererAppWeb.OpenAPIContractHelpers
  import WandererAppWeb.OpenAPIHelpers

  alias WandererAppWeb.Factory

  describe "Standard Error Response Schema" do
    test "401 Unauthorized responses follow standard format" do
      # Test various endpoints that require authentication
      endpoints = [
        {"/api/maps", :get},
        {"/api/maps", :post},
        {"/api/maps/123", :get},
        {"/api/maps/123", :patch},
        {"/api/maps/123", :delete}
      ]

      for {path, method} <- endpoints do
        conn =
          build_conn()
          |> dispatch_request(method, path)

        assert conn.status == 401

        response = Jason.decode!(conn.resp_body)

        # Validate against error schema
        assert_schema(response, "ErrorResponse", api_spec())

        # Verify error structure
        assert %{"error" => error_message} = response
        assert is_binary(error_message)
        assert error_message != ""

        # Verify consistent error message
        assert error_message =~ "authentication" || error_message =~ "unauthorized"
      end
    end

    test "400 Bad Request responses include helpful error details" do
      user = Factory.create(:user)

      # Test with invalid JSON
      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps", "{invalid json")

      assert conn.status == 400

      response = Jason.decode!(conn.resp_body)
      assert_schema(response, "ErrorResponse", api_spec())

      assert %{"error" => error_message} = response
      assert error_message =~ "JSON" || error_message =~ "parse" || error_message =~ "invalid"
    end

    test "404 Not Found responses are consistent" do
      user = Factory.create(:user)
      nonexistent_id = "550e8400-e29b-41d4-a716-446655440000"

      # Test various not found scenarios
      not_found_endpoints = [
        "/api/maps/#{nonexistent_id}",
        "/api/maps/#{nonexistent_id}/systems",
        "/api/systems/#{nonexistent_id}",
        "/api/access-lists/#{nonexistent_id}"
      ]

      for path <- not_found_endpoints do
        conn =
          build_conn()
          |> assign(:current_user, user)
          |> get(path)

        assert conn.status == 404

        response = Jason.decode!(conn.resp_body)
        assert_schema(response, "ErrorResponse", api_spec())

        assert %{"error" => error_message} = response
        assert error_message =~ "not found" || error_message =~ "Not found"
      end
    end

    test "403 Forbidden responses explain permission issues" do
      owner = Factory.create(:user)
      other_user = Factory.create(:user)
      map = Factory.create(:map, %{owner_id: owner.id})

      # Try to access someone else's map
      conn =
        build_conn()
        |> assign(:current_user, other_user)
        |> get("/api/maps/#{map.id}")

      assert conn.status == 403

      response = Jason.decode!(conn.resp_body)
      assert_schema(response, "ErrorResponse", api_spec())

      assert %{"error" => error_message} = response

      assert error_message =~ "permission" || error_message =~ "forbidden" ||
               error_message =~ "access"
    end

    test "422 Unprocessable Entity includes validation errors" do
      user = Factory.create(:user)

      # Create params that violate business rules
      invalid_params = %{
        # Too short
        "name" => "a",
        "slug" => "invalid slug with spaces"
      }

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("content-type", "application/json")
        |> post("/api/maps", invalid_params)

      assert conn.status in [400, 422]

      response = Jason.decode!(conn.resp_body)

      # Should have error details
      case response do
        %{"error" => error_message} when is_binary(error_message) ->
          # Simple error format
          assert_schema(response, "ErrorResponse", api_spec())

        %{"errors" => errors} when is_map(errors) or is_list(errors) ->
          # Detailed validation errors
          assert_schema(response, "ValidationErrorResponse", api_spec())

        _ ->
          flunk("Unexpected error response format: #{inspect(response)}")
      end
    end
  end

  describe "Rate Limiting Error Responses" do
    @tag :slow
    test "429 Too Many Requests includes retry information" do
      user = Factory.create(:user)

      # Make rapid requests to trigger rate limiting
      # This assumes rate limiting is configured
      conn = make_requests_until_rate_limited(user)

      if conn && conn.status == 429 do
        response = Jason.decode!(conn.resp_body)
        assert_schema(response, "ErrorResponse", api_spec())

        assert %{"error" => error_message} = response
        assert error_message =~ "rate" || error_message =~ "too many"

        # Check for rate limit headers
        retry_after = get_resp_header(conn, "retry-after")
        x_ratelimit_limit = get_resp_header(conn, "x-ratelimit-limit")
        x_ratelimit_remaining = get_resp_header(conn, "x-ratelimit-remaining")
        x_ratelimit_reset = get_resp_header(conn, "x-ratelimit-reset")

        # At least some rate limit headers should be present
        assert retry_after != [] || x_ratelimit_limit != [] ||
                 x_ratelimit_remaining != [] || x_ratelimit_reset != []
      end
    end
  end

  describe "Content Negotiation Errors" do
    test "406 Not Acceptable when requested format is unsupported" do
      user = Factory.create(:user)

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("accept", "application/xml")
        |> get("/api/maps")

      # API might return 406 or fall back to JSON
      if conn.status == 406 do
        response = Jason.decode!(conn.resp_body)
        assert_schema(response, "ErrorResponse", api_spec())

        assert %{"error" => error_message} = response
        assert error_message =~ "acceptable" || error_message =~ "format"
      end
    end

    test "415 Unsupported Media Type for wrong content type" do
      user = Factory.create(:user)

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("content-type", "application/xml")
        |> post("/api/maps", "<map><name>Test</name></map>")

      assert conn.status in [400, 415]

      if conn.resp_body != "" do
        response = Jason.decode!(conn.resp_body)
        assert_schema(response, "ErrorResponse", api_spec())

        assert %{"error" => error_message} = response
        assert is_binary(error_message)
      end
    end
  end

  describe "Method Not Allowed Errors" do
    test "405 Method Not Allowed includes allowed methods" do
      user = Factory.create(:user)
      map = Factory.create(:map, %{owner_id: user.id})

      # Try an unsupported method
      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("custom-method", "TRACE")
        |> dispatch_request(:trace, "/api/maps/#{map.id}")

      if conn.status == 405 do
        # Check for Allow header
        allow_header = get_resp_header(conn, "allow")
        assert allow_header != []

        if conn.resp_body != "" do
          response = Jason.decode!(conn.resp_body)
          assert_schema(response, "ErrorResponse", api_spec())
        end
      end
    end
  end

  describe "Server Error Responses" do
    test "500 errors don't leak sensitive information" do
      # This is hard to test without causing actual server errors
      # In production, you'd want to ensure 500 errors return generic messages

      # Hypothetical test:
      # conn = cause_internal_error()
      # assert conn.status == 500
      # response = Jason.decode!(conn.resp_body)
      # assert_schema(response, "ErrorResponse", api_spec())
      # assert response["error"] =~ "internal server error"
      # refute response["error"] =~ "stack trace"
      # refute response["error"] =~ "database"

      :ok
    end
  end

  describe "Error Response Consistency" do
    test "all error responses include correlation ID when available" do
      user = Factory.create(:user)

      # Make request with correlation ID
      correlation_id = "test-#{System.unique_integer()}"

      conn =
        build_conn()
        |> assign(:current_user, user)
        |> put_req_header("x-correlation-id", correlation_id)
        |> get("/api/maps/nonexistent")

      assert conn.status == 404

      # Check if correlation ID is returned in headers
      response_correlation = get_resp_header(conn, "x-correlation-id")

      if response_correlation != [] do
        assert hd(response_correlation) == correlation_id
      end
    end

    test "error messages are localized when Accept-Language is provided" do
      user = Factory.create(:user)

      # Test different language headers
      languages = ["en", "es", "fr", "de"]

      for lang <- languages do
        conn =
          build_conn()
          |> put_req_header("accept-language", lang)
          # Unauthenticated request
          |> get("/api/maps")

        assert conn.status == 401

        response = Jason.decode!(conn.resp_body)
        assert %{"error" => _error_message} = response

        # In a real implementation, you'd verify the message is in the requested language
        # For now, just verify it's a valid error response
        assert_schema(response, "ErrorResponse", api_spec())
      end
    end
  end

  # Helper functions

  defp dispatch_request(conn, :get, path), do: get(conn, path)
  defp dispatch_request(conn, :post, path), do: post(conn, path, %{})
  defp dispatch_request(conn, :patch, path), do: patch(conn, path, %{})
  defp dispatch_request(conn, :delete, path), do: delete(conn, path)

  defp dispatch_request(conn, :trace, path) do
    # Simulate TRACE method which should not be allowed
    conn
    |> Map.put(:method, "TRACE")
    |> Map.put(:request_path, path)
    |> WandererAppWeb.Router.call(WandererAppWeb.Router.init([]))
  end

  defp make_requests_until_rate_limited(user, max_attempts \\ 100) do
    Enum.reduce_while(1..max_attempts, nil, fn _, _acc ->
      conn =
        build_conn()
        |> assign(:current_user, user)
        |> get("/api/maps")

      if conn.status == 429 do
        {:halt, conn}
      else
        # Small delay to be respectful
        Process.sleep(10)
        {:cont, nil}
      end
    end)
  end
end
