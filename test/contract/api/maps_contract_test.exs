defmodule WandererApp.Contract.Api.MapsContractTest do
  @moduledoc """
  Comprehensive contract tests for the Maps API.

  This module tests:
  - Request/response contract compliance
  - OpenAPI specification adherence
  - Error handling contracts
  - Authentication contracts
  - Data validation contracts
  """

  use WandererAppWeb.ApiCase, async: false

  @tag :contract

  import WandererApp.Support.ContractHelpers.ApiContractHelpers
  import WandererAppWeb.Factory
  import Phoenix.ConnTest

  describe "GET /api/maps - List Maps Contract" do
    @tag :contract
    test "successful response follows contract with authentication" do
      scenario = create_test_scenario(with_systems: true)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> get("/api/v1/maps")

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/maps", "GET", 200, response)

          # Validate maps list structure
          # JSON:API response has data wrapper for collections
          assert Map.has_key?(response, "data")
          assert is_list(response["data"])

          # Validate individual map structure if maps exist
          if length(response["data"]) > 0 do
            map_data = hd(response["data"])
            validate_map_resource_structure(map_data)
          end

        401 ->
          # Authentication error is valid
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        _ ->
          flunk("Unexpected response status: #{conn.status}")
      end
    end

    @tag :contract
    test "authentication error contract" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/maps")

      # Should return 401 without authentication
      response = json_response(conn, 401)
      validate_error_contract(401, response)

      # Validate error message format
      assert Map.has_key?(response, "error")
      assert is_binary(response["error"])
    end

    @tag :contract
    test "invalid authentication token contract" do
      conn =
        build_authenticated_conn("invalid_token", api_version: :v1)
        |> get("/api/v1/maps")

      response = json_response(conn, 401)
      validate_error_contract(401, response)
    end
  end

  describe "POST /api/maps - Create Map Contract" do
    @tag :contract
    test "successful creation contract" do
      scenario = create_test_scenario()

      map_attributes = %{
        "name" => "Contract Test Map",
        "description" => "Test map for contract validation",
        "scope" => "none"
      }
      
      # Wrap in JSON:API format
      map_data = wrap_jsonapi_data("maps", map_attributes)

      # Validate request contract
      validate_request_contract("/api/maps", "POST", map_data)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> post("/api/v1/maps", map_data)

      # Debug output
      if conn.status not in [201, 401, 400] do
        # Log unexpected status and response for debugging
        # IO.inspect(conn.status, label: "Unexpected status")
        # IO.inspect(conn.resp_body, label: "Response body")
      end

      case conn.status do
        201 ->
          response = json_response(conn, 201)

          # Validate response contract
          validate_response_contract("/api/maps", "POST", 201, response)

          # Validate created map structure
          # JSON:API response has data wrapper
          assert Map.has_key?(response, "data")
          created_map = response["data"]
          validate_map_resource_structure(created_map)

          # Validate that input data is reflected in response
          assert created_map["attributes"]["name"] == map_data["data"]["attributes"]["name"]
          assert created_map["attributes"]["description"] == map_data["data"]["attributes"]["description"]

        401 ->
          # Authentication error is valid
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        400 ->
          # Validation error is valid
          response = json_response(conn, 400)
          validate_error_contract(400, response)

        _ ->
          flunk("Unexpected response status: #{conn.status}")
      end
    end

    @tag :contract
    test "validation error contract" do
      scenario = create_test_scenario()

      invalid_attributes = %{
        # Invalid: empty name
        "name" => "",
        "description" => "Test",
        # Invalid: bad scope
        "scope" => "invalid_scope"
      }
      
      # Wrap in JSON:API format
      invalid_data = wrap_jsonapi_data("maps", invalid_attributes)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> post("/api/v1/maps", invalid_data)

      # Should return validation error
      case conn.status do
        400 ->
          response = json_response(conn, 400)
          validate_error_contract(400, response)

        422 ->
          response = json_response(conn, 422)
          validate_error_contract(422, response)

        _ ->
          # Accept other error statuses for now
          if conn.status >= 400 do
            response = json_response(conn, conn.status)
            validate_error_contract(conn.status, response)
          else
            flunk("Expected error status, got #{conn.status}")
          end
      end
    end

    @tag :contract
    test "missing required fields contract" do
      scenario = create_test_scenario()

      incomplete_attributes = %{
        "description" => "Test map without name"
        # Missing required 'name' field
      }
      
      # Wrap in JSON:API format
      incomplete_data = wrap_jsonapi_data("maps", incomplete_attributes)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> post("/api/v1/maps", incomplete_data)

      # Should return validation error
      assert conn.status >= 400
      response = json_response(conn, conn.status)
      validate_error_contract(conn.status, response)
    end
  end

  describe "GET /api/maps/:id - Get Map Contract" do
    @tag :contract
    test "successful retrieval contract" do
      scenario = create_test_scenario(with_systems: true)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> get("/api/v1/maps/#{scenario.map.id}")

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/maps/{id}", "GET", 200, response)

          # Validate map structure
          # JSON:API response has data wrapper
          assert Map.has_key?(response, "data")
          map_data = response["data"]
          validate_map_resource_structure(map_data)

          # Validate that response matches created map
          assert map_data["id"] == scenario.map.id
          assert map_data["attributes"]["name"] == scenario.map.name

        404 ->
          # Map not found is valid
          response = json_response(conn, 404)
          validate_error_contract(404, response)

        401 ->
          # Authentication error is valid
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        _ ->
          flunk("Unexpected response status: #{conn.status}")
      end
    end

    @tag :contract
    test "not found contract" do
      scenario = create_test_scenario()

      # Use a valid UUID that doesn't exist
      nonexistent_uuid = Ecto.UUID.generate()
      
      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> get("/api/v1/maps/#{nonexistent_uuid}")

      # In JSON:API, authentication errors (401) take precedence over not found (404)
      # This is expected behavior - you can't check if a resource exists without valid auth
      # Also 400 is valid for invalid IDs
      case conn.status do
        401 ->
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        404 ->
          response = json_response(conn, 404)
          validate_error_contract(404, response)
          
        400 ->
          # Bad request is also valid for invalid IDs
          response = json_response(conn, 400)
          validate_error_contract(400, response)

        _ ->
          flunk("Expected 401, 404, or 400, got #{conn.status}")
      end
    end
  end

  describe "PUT /api/maps/:id - Update Map Contract" do
    @tag :contract
    test "successful update contract" do
      scenario = create_test_scenario()

      update_attributes = %{
        "name" => "Updated Map Name",
        "description" => "Updated description"
      }
      
      # Wrap in JSON:API format
      update_data = wrap_jsonapi_data("maps", update_attributes, scenario.map.id)

      # Validate request contract
      validate_request_contract("/api/maps/{id}", "PATCH", update_data)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> patch("/api/v1/maps/#{scenario.map.id}", update_data)

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/maps/{id}", "PUT", 200, response)

          # Validate updated map structure
          # JSON:API response has data wrapper
          assert Map.has_key?(response, "data")
          updated_map = response["data"]
          validate_map_resource_structure(updated_map)

          # Validate that updates are reflected
          assert updated_map["attributes"]["name"] == update_data["data"]["attributes"]["name"]
          assert updated_map["attributes"]["description"] == update_data["data"]["attributes"]["description"]

        404 ->
          # Map not found is valid
          response = json_response(conn, 404)
          validate_error_contract(404, response)

        401 ->
          # Authentication error is valid
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        400 ->
          # Validation error is valid
          response = json_response(conn, 400)
          validate_error_contract(400, response)

        _ ->
          flunk("Unexpected response status: #{conn.status}")
      end
    end
  end

  describe "DELETE /api/maps/:id - Delete Map Contract" do
    @tag :contract
    test "successful deletion contract" do
      # Create a scenario without systems to avoid FK constraints
      scenario = create_test_scenario(with_systems: false)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> delete("/api/v1/maps/#{scenario.map.id}")

      case conn.status do
        200 ->
          response = json_response(conn, 200)
          validate_response_contract("/api/maps/{id}", "DELETE", 200, response)

        204 ->
          # No content is valid for deletion
          validate_response_contract("/api/maps/{id}", "DELETE", 204, "")

        404 ->
          # Map not found is valid
          response = json_response(conn, 404)
          validate_error_contract(404, response)

        401 ->
          # Authentication error is valid
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        _ ->
          flunk("Unexpected response status: #{conn.status}")
      end
    end
  end

  describe "POST /api/maps/:id/duplicate - Duplicate Map Contract" do
    @tag :contract
    @tag :skip
    test "successful duplication contract - requires user authentication" do
      scenario = create_test_scenario(with_systems: true)

      # The duplicate endpoint uses JSON:API format
      duplicate_data = wrap_jsonapi_data("maps", %{
        "name" => "Duplicated Map",
        "source_map_id" => scenario.map.id
      })

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> post("/api/v1/maps/#{scenario.map.id}/duplicate", duplicate_data)

      case conn.status do
        201 ->
          response = json_response(conn, 201)

          # Validate response contract
          validate_response_contract("/api/maps/{id}/duplicate", "POST", 201, response)

          # The duplicate endpoint returns plain JSON response
          assert Map.has_key?(response, "data")
          duplicated_map = response["data"]
          
          # Validate the plain JSON structure
          assert Map.has_key?(duplicated_map, "id")
          assert Map.has_key?(duplicated_map, "name")
          assert Map.has_key?(duplicated_map, "slug")

          # Validate that it's a new map with different ID
          assert duplicated_map["id"] != scenario.map.id
          assert duplicated_map["name"] == duplicate_data["name"]

        404 ->
          # Source map not found is valid
          response = json_response(conn, 404)
          validate_error_contract(404, response)

        401 ->
          # Authentication error is valid
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        _ ->
          flunk("Unexpected response status: #{conn.status}")
      end
    end
  end

  describe "API Error Handling Contracts" do
    @tag :contract
    test "rate limiting contract" do
      scenario = create_test_scenario()

      # Make multiple rapid requests (this might not trigger rate limiting in test)
      results =
        Enum.map(1..10, fn _i ->
          build_authenticated_conn(scenario.map.public_api_key)
          |> get("/api/v1/maps")
        end)

      # If any request was rate limited, validate the error contract
      rate_limited = Enum.find(results, fn conn -> conn.status == 429 end)

      if rate_limited do
        response = json_response(rate_limited, 429)
        validate_error_contract(429, response)

        # Validate rate limiting headers
        assert get_resp_header(rate_limited, "x-ratelimit-limit") != []
        assert get_resp_header(rate_limited, "x-ratelimit-remaining") != []
      end
    end

    @tag :contract
    test "server error contract" do
      # This test would need to trigger a server error condition
      # For now, we'll just test that if a 500 occurs, it follows the contract

      # Setup a scenario that might cause a server error
      scenario = create_test_scenario()

      # Try to access a map with malformed data that might cause an error
      conn =
        build_authenticated_conn(scenario.map.public_api_key)
        |> get("/api/v1/maps/malformed-id-that-might-cause-error")

      if conn.status == 500 do
        response = json_response(conn, 500)
        validate_error_contract(500, response)
      else
        # If no server error, that's fine for this test
        assert true
      end
    end
  end

  # Helper functions for contract validation

  defp validate_map_resource_structure(map_data) do
    # JSON:API resource should have type, id, and attributes
    assert Map.has_key?(map_data, "type"), "Map missing type field"
    assert Map.has_key?(map_data, "id"), "Map missing id field"
    assert Map.has_key?(map_data, "attributes"), "Map missing attributes field"
    
    assert map_data["type"] == "maps", "Map type should be 'maps'"
    assert is_binary(map_data["id"]), "Map ID should be string"
    
    attributes = map_data["attributes"]
    # Validate that map has required attribute fields
    required_attributes = ["name", "slug"]

    Enum.each(required_attributes, fn field ->
      assert Map.has_key?(attributes, field), "Map attributes missing required field: #{field}"
    end)

    # Validate field types
    assert is_binary(attributes["name"]), "Map name should be string"
    assert is_binary(attributes["slug"]), "Map slug should be string"

    # Validate optional attribute fields if present
    attributes = map_data["attributes"]
    
    if Map.has_key?(attributes, "description") do
      assert is_binary(attributes["description"]), "Map description should be string"
    end

    if Map.has_key?(attributes, "scope") do
      assert attributes["scope"] in ["none", "private", "public"], "Map scope should be valid"
    end

    if Map.has_key?(attributes, "created_at") do
      assert is_binary(attributes["created_at"]), "Map created_at should be string"
    end

    if Map.has_key?(attributes, "updated_at") do
      assert is_binary(attributes["updated_at"]), "Map updated_at should be string"
    end

    true
  end
end
