defmodule WandererAppWeb.MapSystemAPIControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererApp.Factory

  describe "GET /api/maps/:map_identifier/systems (index)" do
    setup :setup_map_authentication

    test "returns systems and connections for a map", %{conn: conn, map: map} do
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

      assert %{
               "data" => %{
                 "systems" => systems,
                 "connections" => connections
               }
             } = json_response(conn, 200)

      assert length(systems) == 2
      assert length(connections) == 1

      # Verify system data
      system_ids = Enum.map(systems, & &1["solar_system_id"])
      assert 30_000_142 in system_ids
      assert 30_000_143 in system_ids
    end

    test "returns empty arrays when no systems exist", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/systems")

      assert %{
               "data" => %{
                 "systems" => [],
                 "connections" => []
               }
             } = json_response(conn, 200)
    end

    test "returns 401 without API key", %{map: map} do
      conn = build_conn()
      conn = get(conn, ~p"/api/maps/#{map.slug}/systems")
      assert json_response(conn, 401)
    end

    test "returns 404 for non-existent map", %{conn: conn} do
      conn = get(conn, ~p"/api/maps/non-existent/systems")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/maps/:map_identifier/systems/:id (show)" do
    setup :setup_map_authentication

    test "returns a specific system", %{conn: conn, map: map} do
      system =
        Factory.insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 100,
          position_y: 200,
          visible: true,
          status: 1,
          labels: "hub,market"
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/systems/#{system.solar_system_id}")

      assert %{
               "data" => data
             } = json_response(conn, 200)

      assert data["solar_system_id"] == 30_000_142
      assert data["position_x"] == 100
      assert data["position_y"] == 200
      assert data["visible"] == true
      assert data["status"] == 1
      assert data["labels"] == "hub,market"
    end

    test "returns 404 for non-existent system", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/systems/99999")
      assert json_response(conn, 404)
    end

    test "returns 400 for invalid system ID", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/systems/invalid")
      assert json_response(conn, 400)
    end
  end

  describe "POST /api/maps/:map_identifier/systems (create)" do
    setup :setup_map_authentication

    test "creates a single system", %{conn: conn, map: map} do
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

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", system_params)

      assert %{
               "data" => %{
                 "systems" => %{"created" => 1, "updated" => 0},
                 "connections" => %{"created" => 0, "updated" => 0, "deleted" => 0}
               }
             } = json_response(conn, 200)

      # Verify system was created
      conn2 = get(conn, ~p"/api/maps/#{map.slug}/systems/30000142")
      assert %{"data" => system} = json_response(conn2, 200)
      assert system["solar_system_id"] == 30_000_142
      assert system["solar_system_name"] == "Jita"
    end

    test "updates existing system", %{conn: conn, map: map} do
      # Create existing system
      Factory.insert(:map_system, %{
        map_id: map.id,
        solar_system_id: 30_000_142,
        position_x: 50,
        position_y: 50
      })

      system_params = %{
        "systems" => [
          %{
            "solar_system_id" => 30_000_142,
            "position_x" => 100,
            "position_y" => 200
          }
        ]
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", system_params)

      assert %{
               "data" => %{
                 "systems" => %{"created" => 0, "updated" => 1}
               }
             } = json_response(conn, 200)
    end

    test "creates systems and connections in batch", %{conn: conn, map: map} do
      batch_params = %{
        "systems" => [
          %{"solar_system_id" => 30_000_142, "position_x" => 100, "position_y" => 100},
          %{"solar_system_id" => 30_000_143, "position_x" => 200, "position_y" => 200}
        ],
        "connections" => [
          %{
            "solar_system_source" => 30_000_142,
            "solar_system_target" => 30_000_143,
            "type" => 0
          }
        ]
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", batch_params)

      assert %{
               "data" => %{
                 "systems" => %{"created" => 2, "updated" => 0},
                 "connections" => %{"created" => 1, "updated" => 0, "deleted" => 0}
               }
             } = json_response(conn, 200)
    end

    test "validates required fields", %{conn: conn, map: map} do
      invalid_params = %{
        "systems" => [
          # Missing required solar_system_id
          %{"position_x" => 100}
        ]
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", invalid_params)
      assert json_response(conn, 422)
    end

    test "handles empty batch", %{conn: conn, map: map} do
      empty_params = %{
        "systems" => [],
        "connections" => []
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", empty_params)

      assert %{
               "data" => %{
                 "systems" => %{"created" => 0, "updated" => 0},
                 "connections" => %{"created" => 0, "updated" => 0, "deleted" => 0}
               }
             } = json_response(conn, 200)
    end
  end

  describe "PUT /api/maps/:map_identifier/systems/:id (update)" do
    setup :setup_map_authentication

    test "updates system attributes", %{conn: conn, map: map} do
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

      conn = put(conn, ~p"/api/maps/#{map.slug}/systems/#{system.solar_system_id}", update_params)

      assert %{
               "data" => data
             } = json_response(conn, 200)

      assert data["position_x"] == 200
      assert data["position_y"] == 300
      assert data["visible"] == false
      assert data["status"] == 1
      assert data["tag"] == "HQ"
      assert data["labels"] == "market,hub"
    end

    test "returns 404 for non-existent system", %{conn: conn, map: map} do
      conn = put(conn, ~p"/api/maps/#{map.slug}/systems/99999", %{"position_x" => 100})
      assert json_response(conn, 404)
    end

    test "ignores invalid fields", %{conn: conn, map: map} do
      system =
        Factory.insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142
        })

      update_params = %{
        "position_x" => 200,
        "invalid_field" => "should be ignored"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/systems/#{system.solar_system_id}", update_params)
      assert %{"data" => data} = json_response(conn, 200)
      assert data["position_x"] == 200
      refute Map.has_key?(data, "invalid_field")
    end
  end

  describe "DELETE /api/maps/:map_identifier/systems (batch delete)" do
    setup :setup_map_authentication

    test "deletes multiple systems", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})
      system3 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_144})

      delete_params = %{
        "system_ids" => [30_000_142, 30_000_143]
      }

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems", delete_params)

      assert %{
               "data" => %{"deleted_count" => 2}
             } = json_response(conn, 200)

      # Verify systems were deleted
      conn2 = get(conn, ~p"/api/maps/#{map.slug}/systems")
      assert %{"data" => %{"systems" => systems}} = json_response(conn2, 200)
      assert length(systems) == 1
      assert hd(systems)["solar_system_id"] == 30_000_144
    end

    test "deletes systems and connections", %{conn: conn, map: map} do
      system1 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_143})

      connection =
        Factory.insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id
        })

      delete_params = %{
        "system_ids" => [30_000_142],
        "connection_ids" => [connection.id]
      }

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems", delete_params)

      assert %{
               "data" => %{"deleted_count" => 2}
             } = json_response(conn, 200)
    end

    test "handles non-existent IDs gracefully", %{conn: conn, map: map} do
      delete_params = %{
        "system_ids" => [99999]
      }

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems", delete_params)

      assert %{
               "data" => %{"deleted_count" => 0}
             } = json_response(conn, 200)
    end

    test "handles empty delete request", %{conn: conn, map: map} do
      delete_params = %{
        "system_ids" => []
      }

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems", delete_params)

      assert %{
               "data" => %{"deleted_count" => 0}
             } = json_response(conn, 200)
    end
  end

  describe "DELETE /api/maps/:map_identifier/systems/:id (single delete)" do
    setup :setup_map_authentication

    test "deletes a single system", %{conn: conn, map: map} do
      system =
        Factory.insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142
        })

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems/#{system.solar_system_id}")

      assert %{
               "data" => %{"deleted" => true}
             } = json_response(conn, 200)

      # Verify system was deleted
      conn2 = get(conn, ~p"/api/maps/#{map.slug}/systems/#{system.solar_system_id}")
      assert json_response(conn2, 404)
    end

    test "returns appropriate response for non-existent system", %{conn: conn, map: map} do
      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems/99999")

      assert %{
               "data" => %{
                 "deleted" => false,
                 "error" => "System not found"
               }
             } = json_response(conn, 404)
    end

    test "returns 400 for invalid system ID", %{conn: conn, map: map} do
      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems/invalid")

      assert %{
               "data" => %{
                 "deleted" => false,
                 "error" => "Invalid system ID format"
               }
             } = json_response(conn, 400)
    end
  end

  describe "Legacy endpoints" do
    setup :setup_map_authentication

    test "GET /api/map_systems (legacy list)", %{conn: conn, map: map} do
      Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      conn = get(conn, ~p"/api/map_systems", %{"slug" => map.slug})
      assert %{"data" => %{"systems" => systems}} = json_response(conn, 200)
      assert length(systems) == 1
    end

    test "GET /api/map_system (legacy show)", %{conn: conn, map: map} do
      system =
        Factory.insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142
        })

      conn =
        get(conn, ~p"/api/map_system", %{
          "slug" => map.slug,
          "id" => "#{system.solar_system_id}"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["solar_system_id"] == 30_000_142
    end

    test "legacy endpoints require either map_id or slug", %{conn: conn} do
      conn = get(conn, ~p"/api/map_systems", %{})
      assert json_response(conn, 400)
    end
  end
end
