defmodule WandererAppWeb.OpenAPIValidationTest do
  use WandererAppWeb.ApiCase, async: true

  describe "OpenAPI Specification" do
    test "GET /api/openapi returns valid OpenAPI spec", %{conn: conn} do
      response =
        conn
        |> get("/api/openapi")
        |> assert_json_response(200)

      # Verify basic OpenAPI structure
      assert %{
               "openapi" => openapi_version,
               "info" => info,
               "paths" => paths
             } = response

      # Verify OpenAPI version
      assert openapi_version =~ ~r/^3\./

      # Verify info section
      assert %{"title" => title, "version" => version} = info
      assert is_binary(title)
      assert is_binary(version)

      # Verify we have some paths defined
      assert is_map(paths)
      assert map_size(paths) > 0

      # Check for expected API endpoints
      expected_paths = [
        "/api/common/system-static-info",
        "/api/characters",
        "/api/maps/{map_identifier}/user-characters"
      ]

      for path <- expected_paths do
        assert Map.has_key?(paths, path), "Missing expected path: #{path}"
      end
    end

    test "OpenAPI spec includes proper schemas", %{conn: conn} do
      response =
        conn
        |> get("/api/openapi")
        |> assert_json_response(200)

      # Verify components section exists with schemas
      assert %{"components" => %{"schemas" => schemas}} = response
      assert is_map(schemas)
      assert map_size(schemas) > 0

      # Check for some expected schemas
      expected_schemas = ["Error", "Character"]

      for schema_name <- expected_schemas do
        if Map.has_key?(schemas, schema_name) do
          schema = schemas[schema_name]
          assert %{"type" => "object"} = schema
          assert %{"properties" => _} = schema
        end
      end
    end

    test "common API endpoint conforms to OpenAPI spec", %{conn: conn} do
      # Get the OpenAPI spec
      _spec_response =
        conn
        |> get("/api/openapi")
        |> assert_json_response(200)

      # Make a request to a documented endpoint
      api_response =
        conn
        |> get("/api/common/system-static-info?id=30000142")

      case api_response.status do
        200 ->
          response_data = json_response(api_response, 200)

          # Validate basic structure matches expected schema
          assert %{"data" => system_data} = response_data
          assert %{"solar_system_id" => _} = system_data
          assert %{"solar_system_name" => _} = system_data

        404 ->
          # System not found is also a valid response
          response_data = json_response(api_response, 404)
          assert %{"error" => _} = response_data

        _ ->
          flunk("Unexpected response status: #{api_response.status}")
      end
    end
  end

  describe "Response Schema Validation" do
    test "validates successful response structure", %{conn: conn} do
      # This is a basic test - in practice, we'd use our OpenAPIHelpers
      # to validate against the actual OpenAPI schema

      response =
        conn
        |> get("/api/common/system-static-info?id=30000142")

      case response.status do
        200 ->
          data = json_response(response, 200)
          assert_valid_api_response(data, "success")

        404 ->
          data = json_response(response, 404)
          assert_valid_api_response(data, "error")
      end
    end

    test "validates error response structure", %{conn: conn} do
      response =
        conn
        |> get("/api/common/system-static-info?id=invalid")
        |> assert_json_response(400)

      assert_valid_api_response(response, "error")
    end
  end

  # Helper function to validate API response structure
  defp assert_valid_api_response(response, type)

  defp assert_valid_api_response(%{"data" => _} = response, "success") do
    # Success responses should have a data field
    assert Map.has_key?(response, "data")
    refute Map.has_key?(response, "error")
  end

  defp assert_valid_api_response(%{"error" => error} = response, "error") do
    # Error responses should have an error field
    assert is_binary(error)
    refute Map.has_key?(response, "data")
  end

  defp assert_valid_api_response(response, expected_type) do
    flunk("Invalid response structure for #{expected_type}: #{inspect(response)}")
  end
end
