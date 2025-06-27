defmodule WandererAppWeb.MapConnectionAPIControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererApp.Factory

  describe "GET /api/maps/:map_identifier/connections (index)" do
    setup :setup_map_authentication

    test "returns all connections for a map", %{conn: conn, map: map} do
      # Create test systems
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})
      system3 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_144})

      # Create test connections
      conn1 =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id,
          type: 0,
          mass_status: 1,
          time_status: 2
        })

      conn2 =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system2.solar_system_id,
          solar_system_target: system3.solar_system_id,
          type: 0
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/connections")

      assert %{"data" => connections} = json_response(conn, 200)
      assert length(connections) == 2

      # Verify connection data
      conn_ids = Enum.map(connections, & &1["id"])
      assert conn1.id in conn_ids
      assert conn2.id in conn_ids
    end

    test "filters connections by source system", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})
      system3 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_144})

      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: system1.solar_system_id,
        solar_system_target: system2.solar_system_id
      })

      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: system2.solar_system_id,
        solar_system_target: system3.solar_system_id
      })

      conn =
        get(conn, ~p"/api/maps/#{map.slug}/connections", %{"solar_system_source" => "30000142"})

      assert %{"data" => connections} = json_response(conn, 200)
      assert length(connections) == 1
      assert hd(connections)["solar_system_source"] == 30_000_142
    end

    test "filters connections by target system", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: system1.solar_system_id,
        solar_system_target: system2.solar_system_id
      })

      conn =
        get(conn, ~p"/api/maps/#{map.slug}/connections", %{"solar_system_target" => "30000143"})

      assert %{"data" => connections} = json_response(conn, 200)
      assert length(connections) == 1
      assert hd(connections)["solar_system_target"] == 30_000_143
    end

    test "returns empty array when no connections exist", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/connections")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without API key", %{map: map} do
      conn = build_conn()
      conn = get(conn, ~p"/api/maps/#{map.slug}/connections")
      assert json_response(conn, 401)
    end

    test "returns 400 for invalid filter parameter", %{conn: conn, map: map} do
      conn =
        get(conn, ~p"/api/maps/#{map.slug}/connections", %{"solar_system_source" => "invalid"})

      assert json_response(conn, 400)
    end
  end

  describe "GET /api/maps/:map_identifier/connections/:id (show)" do
    setup :setup_map_authentication

    test "returns a specific connection by ID", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      connection =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id,
          type: 0,
          mass_status: 1,
          time_status: 2,
          ship_size_type: 1,
          locked: false,
          custom_info: "Test connection"
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/connections/#{connection.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == connection.id
      assert data["solar_system_source"] == 30_000_142
      assert data["solar_system_target"] == 30_000_143
      assert data["custom_info"] == "Test connection"
    end

    test "returns connection by source/target systems", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: system1.solar_system_id,
        solar_system_target: system2.solar_system_id
      })

      conn =
        get(conn, ~p"/api/maps/#{map.slug}/connections/show", %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000143"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["solar_system_source"] == 30_000_142
      assert data["solar_system_target"] == 30_000_143
    end

    test "returns 404 for non-existent connection", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/connections/non-existent-id")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/maps/:map_identifier/connections (create)" do
    setup :setup_map_authentication

    test "creates a new connection", %{conn: conn, map: map} do
      # Create systems first
      Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      connection_params = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143,
        "type" => 0,
        "mass_status" => 1,
        "time_status" => 2,
        "ship_size_type" => 1,
        "locked" => false,
        "custom_info" => "New connection"
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/connections", connection_params)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["solar_system_source"] == 30_000_142
      assert data["solar_system_target"] == 30_000_143
      assert data["custom_info"] == "New connection"
    end

    test "returns existing connection if already exists", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      # Create existing connection
      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: system1.solar_system_id,
        solar_system_target: system2.solar_system_id
      })

      connection_params = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_143,
        "type" => 0
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/connections", connection_params)

      assert %{"data" => %{"result" => "exists"}} = json_response(conn, 200)
    end

    test "validates required fields", %{conn: conn, map: map} do
      invalid_params = %{
        # Missing required source and target
        "type" => 0
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/connections", invalid_params)
      assert json_response(conn, 400)
    end

    test "validates system existence", %{conn: conn, map: map} do
      # Try to create connection for non-existent systems
      connection_params = %{
        "solar_system_source" => 99999,
        "solar_system_target" => 99998,
        "type" => 0
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/connections", connection_params)
      assert json_response(conn, 400)
    end
  end

  describe "DELETE /api/maps/:map_identifier/connections/:id (delete)" do
    setup :setup_map_authentication

    test "deletes a connection by ID", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      connection =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id
        })

      conn = delete(conn, ~p"/api/maps/#{map.slug}/connections/#{connection.id}")

      assert %{"data" => %{"deleted" => true}} = json_response(conn, 200)

      # Verify connection was deleted
      conn2 = get(conn, ~p"/api/maps/#{map.slug}/connections/#{connection.id}")
      assert json_response(conn2, 404)
    end

    test "deletes a connection by source/target systems", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: system1.solar_system_id,
        solar_system_target: system2.solar_system_id
      })

      conn =
        delete(conn, ~p"/api/maps/#{map.slug}/connections/delete", %{
          "solar_system_source" => "30000142",
          "solar_system_target" => "30000143"
        })

      assert %{"data" => %{"deleted" => true}} = json_response(conn, 200)
    end

    test "returns appropriate response for non-existent connection", %{conn: conn, map: map} do
      conn = delete(conn, ~p"/api/maps/#{map.slug}/connections/non-existent-id")
      assert %{"data" => %{"deleted" => false}} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/maps/:map_identifier/connections (batch delete)" do
    setup :setup_map_authentication

    test "deletes multiple connections", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})
      system3 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_144})

      conn1 =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id
        })

      conn2 =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system2.solar_system_id,
          solar_system_target: system3.solar_system_id
        })

      delete_params = %{
        "connection_ids" => [conn1.id, conn2.id]
      }

      conn = delete(conn, ~p"/api/maps/#{map.slug}/connections", delete_params)

      assert %{"data" => %{"deleted_count" => 2}} = json_response(conn, 200)

      # Verify connections were deleted
      conn_check = get(conn, ~p"/api/maps/#{map.slug}/connections")
      assert %{"data" => []} = json_response(conn_check, 200)
    end

    test "handles empty batch delete", %{conn: conn, map: map} do
      delete_params = %{
        "connection_ids" => []
      }

      conn = delete(conn, ~p"/api/maps/#{map.slug}/connections", delete_params)
      assert %{"data" => %{"deleted_count" => 0}} = json_response(conn, 200)
    end
  end

  describe "Legacy endpoints" do
    setup :setup_map_authentication

    test "GET /api/map_connections (legacy list)", %{conn: conn, map: map} do
      Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      Factory.insert(:map_connection, %{
        map_id: map.id,
        solar_system_source: 30_000_142,
        solar_system_target: 30_000_143
      })

      conn = get(conn, ~p"/api/map_connections", %{"slug" => map.slug})
      assert %{"data" => connections} = json_response(conn, 200)
      assert length(connections) == 1
    end

    test "GET /api/map_connection (legacy show)", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      connection =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id
        })

      conn =
        get(conn, ~p"/api/map_connection", %{
          "slug" => map.slug,
          "id" => connection.id
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == connection.id
    end

    test "legacy endpoints require either map_id or slug", %{conn: conn} do
      conn = get(conn, ~p"/api/map_connections", %{})
      assert json_response(conn, 400)
    end
  end
end
