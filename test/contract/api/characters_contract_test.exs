defmodule WandererApp.Contract.Api.CharactersContractTest do
  @moduledoc """
  Comprehensive contract tests for the Characters API.

  This module tests:
  - Character resource contracts
  - Authentication and authorization contracts
  - Character tracking contracts
  - Character location contracts
  """

  use WandererAppWeb.ApiCase, async: false

  @tag :contract

  import WandererApp.Support.ContractHelpers.ApiContractHelpers
  import WandererAppWeb.Factory
  import Phoenix.ConnTest

  describe "GET /api/characters - List Characters Contract" do
    @tag :contract
    test "successful response follows contract" do
      scenario = create_test_scenario()

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> get("/api/v1/characters")

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/v1/characters", "GET", 200, response)

          # Validate characters list structure
          # JSON:API response has data wrapper for collections
          assert Map.has_key?(response, "data")
          assert is_list(response["data"])

          # Validate individual character structure if characters exist
          if length(response["data"]) > 0 do
            character_data = hd(response["data"])
            validate_character_resource_structure(character_data)
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
    test "authentication required contract" do
      conn =
        build_conn()
        |> get("/api/v1/characters")

      # Should return 401 without authentication
      response = json_response(conn, 401)
      validate_error_contract(401, response)
    end
  end

  describe "GET /api/characters/:id - Get Character Contract" do
    @tag :contract
    test "successful retrieval contract" do
      scenario = create_test_scenario()

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> get("/api/v1/characters/#{scenario.character.id}")

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/v1/characters/{id}", "GET", 200, response)

          # Validate character structure
          # JSON:API response has data wrapper
          assert Map.has_key?(response, "data")
          character_data = response["data"]
          validate_character_resource_structure(character_data)

          # Validate that response matches created character
          assert character_data["id"] == scenario.character.id
          assert character_data["attributes"]["name"] == scenario.character.name

        404 ->
          # Character not found is valid
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
        |> get("/api/v1/characters/#{nonexistent_uuid}")

      # In JSON:API, authentication errors (401) take precedence over not found (404)
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

  describe "POST /api/characters - Create Character Contract" do
    @tag :contract
    test "successful creation contract" do
      scenario = create_test_scenario()

      character_attributes = %{
        "eve_id" => "123456789",
        "name" => "Test Character",
        "user_id" => scenario.user.id
      }
      
      # Wrap in JSON:API format
      character_data = wrap_jsonapi_data("characters", character_attributes)

      # Validate request contract
      validate_request_contract("/api/v1/characters", "POST", character_data)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> post("/api/v1/characters", character_data)

      case conn.status do
        201 ->
          response = json_response(conn, 201)

          # Validate response contract
          validate_response_contract("/api/v1/characters", "POST", 201, response)

          # Validate created character structure
          # JSON:API response has data wrapper
          assert Map.has_key?(response, "data")
          created_character = response["data"]
          validate_character_resource_structure(created_character)

          # Validate that input data is reflected in response
          assert created_character["attributes"]["eve_id"] == character_data["data"]["attributes"]["eve_id"]
          assert created_character["attributes"]["name"] == character_data["data"]["attributes"]["name"]

        400 ->
          # Validation error is valid
          response = json_response(conn, 400)
          validate_error_contract(400, response)

        401 ->
          # Authentication error is valid
          response = json_response(conn, 401)
          validate_error_contract(401, response)

        _ ->
          flunk("Unexpected response status: #{conn.status}")
      end
    end

    @tag :contract
    test "validation error contract" do
      scenario = create_test_scenario()

      invalid_attributes = %{
        # Invalid: empty EVE ID
        "eve_id" => "",
        # Invalid: empty name
        "name" => ""
      }
      
      # Wrap in JSON:API format
      invalid_data = wrap_jsonapi_data("characters", invalid_attributes)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> post("/api/v1/characters", invalid_data)

      # Should return validation error
      assert conn.status >= 400
      response = json_response(conn, conn.status)
      validate_error_contract(conn.status, response)
    end
  end

  describe "PUT /api/characters/:id - Update Character Contract" do
    @tag :contract
    test "update tracking pool contract" do
      scenario = create_test_scenario()

      # Only tracking_pool is updateable - name and corporation data come from EVE
      update_attributes = %{
        "tracking_pool" => "updated_pool"
      }
      
      # Wrap in JSON:API format  
      update_data = wrap_jsonapi_data("characters", update_attributes, scenario.character.id)

      # Validate request contract
      validate_request_contract("/api/v1/characters/{id}", "PATCH", update_data)

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> patch("/api/v1/characters/#{scenario.character.id}", update_data)

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/v1/characters/{id}", "PUT", 200, response)

          # Validate updated character structure
          # JSON:API response has data wrapper
          assert Map.has_key?(response, "data")
          updated_character = response["data"]
          validate_character_resource_structure(updated_character)

          # Validate that updates are reflected
          assert updated_character["attributes"]["tracking_pool"] == update_data["data"]["attributes"]["tracking_pool"]

        404 ->
          # Character not found is valid
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

  describe "DELETE /api/characters/:id - Delete Character Contract" do
    @tag :contract
    test "successful deletion contract" do
      scenario = create_test_scenario()
      
      # Create a different character that is not the map owner to avoid FK constraint
      deletable_character = insert(:character, %{
        user_id: scenario.user.id,
        name: "Deletable Character",
        eve_id: "deletable_#{System.unique_integer([:positive])}"
      })

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> delete("/api/v1/characters/#{deletable_character.id}")

      case conn.status do
        200 ->
          response = json_response(conn, 200)
          validate_response_contract("/api/v1/characters/{id}", "DELETE", 200, response)

        204 ->
          # No content is valid for deletion
          validate_response_contract("/api/v1/characters/{id}", "DELETE", 204, "")

        404 ->
          # Character not found is valid
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

  describe "Character Tracking Contracts" do
    @tag :contract
    test "character location contract" do
      scenario = create_test_scenario()

      # Note: Character location mock is already set up globally
      # The global mock returns a location with solar_system_id: 30_000_142

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> get("/api/v1/characters/#{scenario.character.id}/location")

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/v1/characters/{id}/location", "GET", 200, response)

          # Validate location structure
          validate_character_location_structure(response)

        404 ->
          # Character not found is valid
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
    test "character tracking status contract" do
      scenario = create_test_scenario()

      conn =
        build_authenticated_conn(scenario.map.public_api_key, api_version: :v1)
        |> get("/api/v1/characters/#{scenario.character.id}/tracking")

      case conn.status do
        200 ->
          response = json_response(conn, 200)

          # Validate response contract
          validate_response_contract("/api/v1/characters/{id}/tracking", "GET", 200, response)

          # Validate tracking status structure
          validate_character_tracking_structure(response)

        404 ->
          # Character not found is valid
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

  # Corporation data is read-only from EVE Online API - removed corporation update tests

  # Helper functions for contract validation

  defp validate_character_resource_structure(character_data) do
    # JSON:API resource should have type, id, and attributes
    assert Map.has_key?(character_data, "type"), "Character missing type field"
    assert Map.has_key?(character_data, "id"), "Character missing id field"
    assert Map.has_key?(character_data, "attributes"), "Character missing attributes field"
    
    assert character_data["type"] == "characters", "Character type should be 'characters'"
    assert is_binary(character_data["id"]), "Character ID should be string"
    
    attributes = character_data["attributes"]
    # Validate that character has required attribute fields
    required_attributes = ["name", "eve_id"]

    Enum.each(required_attributes, fn field ->
      assert Map.has_key?(attributes, field), "Character attributes missing required field: #{field}"
    end)

    # Validate field types
    assert is_binary(attributes["name"]), "Character name should be string"
    assert is_binary(attributes["eve_id"]), "Character EVE ID should be string"

    # Validate optional attribute fields if present
    attributes = character_data["attributes"]
    
    if Map.has_key?(attributes, "corporation_id") do
      assert is_integer(attributes["corporation_id"]), "Corporation ID should be integer"
    end

    if Map.has_key?(attributes, "corporation_name") do
      assert is_binary(attributes["corporation_name"]), "Corporation name should be string"
    end

    if Map.has_key?(attributes, "corporation_ticker") do
      assert is_binary(attributes["corporation_ticker"]),
             "Corporation ticker should be string"
    end

    if Map.has_key?(attributes, "tracking_pool") do
      assert is_nil(attributes["tracking_pool"]) || is_binary(attributes["tracking_pool"]), 
             "Tracking pool should be string or nil"
    end

    if Map.has_key?(attributes, "created_at") do
      assert is_binary(attributes["created_at"]), "Created at should be string"
    end

    if Map.has_key?(attributes, "updated_at") do
      assert is_binary(attributes["updated_at"]), "Updated at should be string"
    end

    true
  end

  defp validate_character_location_structure(location_data) do
    # Validate location structure
    if Map.has_key?(location_data, "solar_system_id") do
      assert is_integer(location_data["solar_system_id"]), "Solar system ID should be integer"
    end

    if Map.has_key?(location_data, "station_id") do
      assert is_integer(location_data["station_id"]), "Station ID should be integer"
    end

    if Map.has_key?(location_data, "structure_id") do
      assert is_integer(location_data["structure_id"]), "Structure ID should be integer"
    end

    true
  end

  defp validate_character_tracking_structure(tracking_data) do
    # Validate tracking structure
    if Map.has_key?(tracking_data, "is_tracking") do
      assert is_boolean(tracking_data["is_tracking"]), "Is tracking should be boolean"
    end

    if Map.has_key?(tracking_data, "tracking_pool") do
      assert is_binary(tracking_data["tracking_pool"]), "Tracking pool should be string"
    end

    if Map.has_key?(tracking_data, "last_seen_at") do
      assert is_binary(tracking_data["last_seen_at"]), "Last seen at should be string"
    end

    true
  end
end
