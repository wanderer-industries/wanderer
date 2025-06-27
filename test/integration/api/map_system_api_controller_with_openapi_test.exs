defmodule WandererAppWeb.MapSystemAPIControllerWithOpenAPITest do
  use WandererAppWeb.ApiCase

  alias WandererApp.Factory
  alias WandererAppWeb.OpenAPIHelpers

  describe "GET /api/maps/:map_identifier/systems (index) with OpenAPI validation" do
    setup :setup_map_authentication

    test "returns systems and connections for a map with schema validation", %{
      conn: conn,
      map: map
    } do
      # Create test systems
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      # Create test connection
      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: system1.solar_system_id,
        solar_system_target: system2.solar_system_id
      })

      conn = get(conn, ~p"/api/maps/#{map.slug}/systems")

      response = json_response(conn, 200)

      # Validate response against OpenAPI schema
      OpenAPIHelpers.assert_schema(response, "MapSystemListResponse", OpenAPIHelpers.api_spec())

      assert %{
               "data" => %{
                 "systems" => systems,
                 "connections" => connections
               }
             } = response

      assert length(systems) == 2
      assert length(connections) == 1

      # Validate individual system schemas
      Enum.each(systems, fn system ->
        OpenAPIHelpers.assert_schema(system, "MapSystem", OpenAPIHelpers.api_spec())
      end)

      # Validate individual connection schemas
      Enum.each(connections, fn connection ->
        OpenAPIHelpers.assert_schema(connection, "MapConnection", OpenAPIHelpers.api_spec())
      end)
    end
  end

  describe "POST /api/maps/:map_identifier/systems (create) with OpenAPI validation" do
    setup :setup_map_authentication

    test "creates a single system with schema validation", %{conn: conn, map: map} do
      system_params = %{
        "systems" => [
          %{
            "solar_system_id" => 30_000_142,
            "solar_system_name" => "Jita",
            "position_x" => 100,
            "position_y" => 200,
            "visible" => true,
            "labels" => "market,hub"
          }
        ]
      }

      # Validate request schema
      OpenAPIHelpers.assert_request_schema(
        system_params,
        "MapSystemBatchRequest",
        OpenAPIHelpers.api_spec()
      )

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", system_params)

      response = json_response(conn, 200)

      # Validate response against OpenAPI schema
      OpenAPIHelpers.assert_schema(response, "MapSystemBatchResponse", OpenAPIHelpers.api_spec())

      assert %{
               "data" => %{
                 "systems" => %{"created" => 1, "updated" => 0},
                 "connections" => %{"created" => 0, "updated" => 0, "deleted" => 0}
               }
             } = response

      # Verify system was created
      conn2 = get(conn, ~p"/api/maps/#{map.slug}/systems/30000142")
      detail_response = json_response(conn2, 200)

      # Validate detail response schema
      OpenAPIHelpers.assert_schema(
        detail_response,
        "MapSystemDetailResponse",
        OpenAPIHelpers.api_spec()
      )

      assert %{"data" => system} = detail_response
      assert system["solar_system_id"] == 30_000_142
      assert system["solar_system_name"] == "Jita"
    end

    test "validates error response schema", %{conn: conn, map: map} do
      invalid_params = %{
        "systems" => [
          # Missing required solar_system_id
          %{"position_x" => 100}
        ]
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", invalid_params)

      error_response = json_response(conn, 422)

      # Validate error response against OpenAPI schema
      OpenAPIHelpers.assert_schema(error_response, "ErrorResponse", OpenAPIHelpers.api_spec())

      # Check that response contains error information in expected format
      has_error = Map.has_key?(error_response, "error")
      has_errors = Map.has_key?(error_response, "errors")

      assert has_error or has_errors,
             "Expected response to contain either 'error' or 'errors' key"
    end
  end

  describe "PUT /api/maps/:map_identifier/systems/:id (update) with OpenAPI validation" do
    setup :setup_map_authentication

    test "updates system attributes with schema validation", %{conn: conn, map: map} do
      system =
        Factory.insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 100,
          position_y: 100,
          visible: true,
          status: 0
        })

      update_params = %{
        "position_x" => 200,
        "position_y" => 300,
        "visible" => false,
        "status" => 1,
        "tag" => "HQ",
        "labels" => "market,hub"
      }

      # Validate request schema
      OpenAPIHelpers.assert_request_schema(
        update_params,
        "MapSystemUpdateRequest",
        OpenAPIHelpers.api_spec()
      )

      conn = put(conn, ~p"/api/maps/#{map.slug}/systems/#{system.solar_system_id}", update_params)

      response = json_response(conn, 200)

      # Validate response against OpenAPI schema
      OpenAPIHelpers.assert_schema(response, "MapSystemDetailResponse", OpenAPIHelpers.api_spec())

      assert %{"data" => data} = response
      assert data["position_x"] == 200
      assert data["position_y"] == 300
      assert data["visible"] == false
      assert data["status"] == 1
      assert data["tag"] == "HQ"
      assert data["labels"] == "market,hub"
    end
  end

  describe "DELETE /api/maps/:map_identifier/systems (batch delete) with OpenAPI validation" do
    setup :setup_map_authentication

    test "deletes multiple systems with schema validation", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})
      Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_144})

      delete_params = %{
        "system_ids" => [30_000_142, 30_000_143]
      }

      # Validate request schema
      OpenAPIHelpers.assert_request_schema(
        delete_params,
        "MapSystemBatchDeleteRequest",
        OpenAPIHelpers.api_spec()
      )

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems", delete_params)

      response = json_response(conn, 200)

      # Validate response against OpenAPI schema
      OpenAPIHelpers.assert_schema(
        response,
        "MapSystemBatchDeleteResponse",
        OpenAPIHelpers.api_spec()
      )

      assert %{"data" => %{"deleted_count" => 2}} = response
    end
  end
end
