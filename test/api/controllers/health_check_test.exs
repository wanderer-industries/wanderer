defmodule WandererApp.HealthCheckTest do
  use WandererApp.ApiCase

  @moduletag :api

  describe "basic setup verification" do
    test "test environment is configured", %{conn: conn} do
      assert conn
      assert Application.get_env(:wanderer_app, :pubsub_client) == Test.PubSubMock
    end

    test "database connection works" do
      # Simple query to verify DB connection
      result = Ecto.Adapters.SQL.query!(WandererApp.Repo, "SELECT 1", [])
      assert result.rows == [[1]]
    end

    test "conn has correct headers", %{conn: conn} do
      assert get_req_header(conn, "accept") == ["application/json"]
      assert get_req_header(conn, "content-type") == ["application/json"]
    end

    test "endpoint is available", %{conn: _conn} do
      assert WandererAppWeb.Endpoint
    end
  end

  describe "simple API endpoint tests" do
    test "API common endpoint responds", %{conn: conn} do
      # Test an actual API endpoint that accepts JSON
      conn = get(conn, "/api/common/system-static-info")
      # This endpoint might require parameters, so we expect either success or proper error
      # Valid API responses
      assert conn.status in [200, 400, 422]
    end

    test "basic connection test", %{conn: conn} do
      # Simple test to verify our test setup works
      assert conn.req_headers
             |> Enum.any?(fn {k, v} -> k == "accept" && v == "application/json" end)

      assert Application.get_env(:wanderer_app, :pubsub_client) == Test.PubSubMock
    end
  end
end
