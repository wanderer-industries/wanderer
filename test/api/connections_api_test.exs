defmodule WandererApp.ConnectionsApiTest do
  use WandererApp.ApiCase
  use WandererApp.Test.CrudTestScaffolding

  @moduletag :api

  # Enhanced CRUD operations using scaffolding patterns
  describe "Map Connections API - Enhanced CRUD patterns" do
    setup do
      map_data = create_test_map_with_auth()

      # Create systems to connect
      system1 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 100
          },
          map_data.owner
        )

      system2 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_144,
            name: "Perimeter",
            position_x: 200,
            position_y: 100
          },
          map_data.owner
        )

      system3 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_145,
            name: "Maurasi",
            position_x: 300,
            position_y: 100
          },
          map_data.owner
        )

      {:ok, map_data: map_data, system1: system1, system2: system2, system3: system3}
    end

    test "connection lifecycle and state transitions", context do
      %{map_data: map_data, system1: system1, system2: system2} = context

      # Create fresh wormhole
      connection =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system1,
            target_system: system2,
            # Fresh
            mass_status: 0,
            # Fresh
            time_status: 0,
            # Large
            ship_size_type: 2
          },
          map_data.owner
        )

      # Simulate usage progression: Fresh -> Half Mass -> Critical
      context[:conn]
      |> authenticate_map(map_data.api_key)
      |> put("/api/maps/#{map_data.map_slug}/connections/#{connection.id}", %{
        # Half mass
        "mass_status" => 1
      })
      |> assert_success_response(200)

      # Further degradation
      context[:conn]
      |> authenticate_map(map_data.api_key)
      |> put("/api/maps/#{map_data.map_slug}/connections/#{connection.id}", %{
        # Critical
        "mass_status" => 2,
        # EOL
        "time_status" => 1
      })
      |> assert_success_response(200)

      # Final verification
      final_state =
        context[:conn]
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/connections/#{connection.id}")
        |> assert_success_response(200)

      assert final_state["data"]["mass_status"] == 2
      assert final_state["data"]["time_status"] == 1
    end
  end

  describe "Legacy Map Connections API CRUD operations" do
    setup do
      map_data = create_test_map_with_auth()

      # Create systems to connect
      system1 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 100
          },
          map_data.owner
        )

      system2 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_144,
            name: "Perimeter",
            position_x: 200,
            position_y: 100
          },
          map_data.owner
        )

      system3 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_145,
            name: "Maurasi",
            position_x: 300,
            position_y: 100
          },
          map_data.owner
        )

      {:ok, map_data: map_data, system1: system1, system2: system2, system3: system3}
    end

    test "GET /api/maps/:map_id/connections - lists all connections", %{
      conn: conn,
      map_data: map_data,
      system1: system1,
      system2: system2
    } do
      # Create a connection
      connection =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system1,
            target_system: system2
          },
          map_data.owner
        )

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/connections")
        |> assert_success_response(200)

      assert length(response["data"]) == 1
      conn_data = hd(response["data"])
      assert conn_data["id"] == connection.id
      assert conn_data["solar_system_source"] == system1.solar_system_id
      assert conn_data["solar_system_target"] == system2.solar_system_id
    end

    test "POST /api/maps/:map_id/connections - creates new connection", %{
      conn: conn,
      map_data: map_data,
      system1: system1,
      system2: system2
    } do
      connection_params = %{
        "solar_system_source" => system1.solar_system_id,
        "solar_system_target" => system2.solar_system_id,
        # Wormhole
        "type" => 0,
        # Fresh
        "mass_status" => 0,
        # Fresh
        "time_status" => 0,
        # Medium
        "ship_size_type" => 1
      }

      conn
      |> authenticate_map(map_data.api_key)
      |> post("/api/maps/#{map_data.map_slug}/connections", connection_params)
      |> assert_success_response(201)

      # Verify the connection was actually created by fetching it
      list_response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/connections")
        |> json_response!(200)

      assert length(list_response["data"]) == 1
      created_conn = hd(list_response["data"])
      assert created_conn["solar_system_source"] == system1.solar_system_id
      assert created_conn["solar_system_target"] == system2.solar_system_id
    end

    test "GET /api/maps/:map_id/connections/:id - gets single connection", %{
      conn: conn,
      map_data: map_data,
      system1: system1,
      system2: system2
    } do
      connection =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system1,
            target_system: system2,
            type: 0,
            mass_status: 1,
            time_status: 0
          },
          map_data.owner
        )

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/connections/#{connection.id}")
        |> assert_success_response(200)

      assert response["data"]["id"] == connection.id
      assert response["data"]["mass_status"] == 1
      assert response["data"]["time_status"] == 0
    end

    test "PUT /api/maps/:map_id/connections/:id - updates connection", %{
      conn: conn,
      map_data: map_data,
      system1: system1,
      system2: system2
    } do
      connection =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system1,
            target_system: system2,
            mass_status: 0,
            time_status: 0
          },
          map_data.owner
        )

      update_params = %{
        # Critical
        "mass_status" => 2,
        # End of Life
        "time_status" => 1,
        # Small only
        "ship_size_type" => 0
      }

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> put("/api/maps/#{map_data.map_slug}/connections/#{connection.id}", update_params)
        |> assert_success_response(200)

      assert response["data"]["mass_status"] == 2
      assert response["data"]["time_status"] == 1
      assert response["data"]["ship_size_type"] == 0
    end

    test "POST /api/maps/:map_id/connections - validates systems exist", %{
      conn: conn,
      map_data: map_data,
      system1: system1
    } do
      connection_params = %{
        "solar_system_source" => system1.solar_system_id,
        # Non-existent system
        "solar_system_target" => 99_999_999,
        "type" => 0
      }

      conn
      |> authenticate_map(map_data.api_key)
      |> post("/api/maps/#{map_data.map_slug}/connections", connection_params)
      |> assert_error_format(400)
    end

    test "POST /api/maps/:map_id/connections - allows duplicate connections (current behavior)", %{
      conn: conn,
      map_data: map_data,
      system1: system1,
      system2: system2
    } do
      # Create first connection
      create_map_connection(
        %{
          map: map_data.map,
          source_system: system1,
          target_system: system2
        },
        map_data.owner
      )

      # Try to create duplicate
      connection_params = %{
        "solar_system_source" => system1.solar_system_id,
        "solar_system_target" => system2.solar_system_id,
        "type" => 0
      }

      # NOTE: This test documents the current behavior which allows duplicate connections.
      # This may be intentional to support multiple connections between the same systems
      # (e.g., multiple wormholes), or it may be a bug that needs to be fixed.
      conn
      |> authenticate_map(map_data.api_key)
      |> post("/api/maps/#{map_data.map_slug}/connections", connection_params)
      |> assert_success_response(201)
    end

    test "POST /api/maps/:map_id/connections - allows self-connections", %{
      conn: conn,
      map_data: map_data,
      system1: system1
    } do
      connection_params = %{
        "solar_system_source" => system1.solar_system_id,
        "solar_system_target" => system1.solar_system_id,
        "type" => 0
      }

      conn
      |> authenticate_map(map_data.api_key)
      |> post("/api/maps/#{map_data.map_slug}/connections", connection_params)
      |> assert_success_response(201)
    end
  end

  describe "Connection mass and time tracking" do
    setup do
      map_data = create_test_map_with_auth()

      system1 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_142}, map_data.owner)

      system2 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_144}, map_data.owner)

      connection =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system1,
            target_system: system2,
            mass_status: 0,
            time_status: 0,
            # Large
            ship_size_type: 2
          },
          map_data.owner
        )

      {:ok, map_data: map_data, connection: connection}
    end

    test "PUT /api/maps/:map_id/connections/:id - updates mass status", %{
      conn: conn,
      map_data: map_data,
      connection: connection
    } do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> put("/api/maps/#{map_data.map_slug}/connections/#{connection.id}", %{
          # Half mass
          "mass_status" => 1
        })
        |> assert_success_response(200)

      assert response["data"]["mass_status"] == 1
    end

    test "PUT /api/maps/:map_id/connections/:id - updates time status", %{
      conn: conn,
      map_data: map_data,
      connection: connection
    } do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> put("/api/maps/#{map_data.map_slug}/connections/#{connection.id}", %{
          # EOL
          "time_status" => 1
        })
        |> assert_success_response(200)

      assert response["data"]["time_status"] == 1
    end

    test "PUT /api/maps/:map_id/connections/:id - updates ship size", %{
      conn: conn,
      map_data: map_data,
      connection: connection
    } do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> put("/api/maps/#{map_data.map_slug}/connections/#{connection.id}", %{
          # Small only
          "ship_size_type" => 0
        })
        |> assert_success_response(200)

      assert response["data"]["ship_size_type"] == 0
    end
  end

  describe "Connection filtering" do
    setup do
      map_data = create_test_map_with_auth()

      # Create multiple systems
      system1 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_142}, map_data.owner)

      system2 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_144}, map_data.owner)

      system3 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_145}, map_data.owner)

      system4 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_146}, map_data.owner)

      # Create various connections
      _conn1 =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system1,
            target_system: system2,
            # Wormhole
            type: 0,
            mass_status: 0
          },
          map_data.owner
        )

      _conn2 =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system2,
            target_system: system3,
            # Stargate
            type: 1,
            mass_status: 0
          },
          map_data.owner
        )

      _conn3 =
        create_map_connection(
          %{
            map: map_data.map,
            source_system: system3,
            target_system: system4,
            # Wormhole
            type: 0,
            # Critical
            mass_status: 2
          },
          map_data.owner
        )

      {:ok, map_data: map_data, system1: system1, system2: system2}
    end

    test "GET /api/maps/:map_id/connections - type filter not implemented", %{
      conn: conn,
      map_data: map_data
    } do
      # Type filtering is not currently implemented - returns all connections
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/connections", %{"type" => "0"})
        |> json_response!(200)

      # Returns all connections
      assert length(response["data"]) == 3
    end

    test "GET /api/maps/:map_id/connections - mass_status filter not implemented", %{
      conn: conn,
      map_data: map_data
    } do
      # Mass status filtering is not currently implemented - returns all connections
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/connections", %{"mass_status" => "2"})
        |> json_response!(200)

      # Returns all connections
      assert length(response["data"]) == 3
    end

    test "GET /api/maps/:map_id/connections - filters by source system", %{
      conn: conn,
      map_data: map_data,
      system1: system1
    } do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/connections", %{
          "solar_system_source" => system1.solar_system_id
        })
        |> json_response!(200)

      # Should return connections where system1 is the source
      assert length(response["data"]) == 1

      assert Enum.all?(response["data"], fn conn ->
               conn["solar_system_source"] == system1.solar_system_id
             end)
    end
  end
end
