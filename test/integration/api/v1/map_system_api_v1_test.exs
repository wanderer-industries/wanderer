defmodule WandererAppWeb.Api.V1.MapSystemApiV1Test do
  use WandererAppWeb.ApiCase, async: false

  import WandererAppWeb.Factory

  describe "JSON:API V1 MapSystem endpoints" do
    setup %{conn: conn} do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      authenticated_conn = create_authenticated_conn(conn, map)

      %{conn: authenticated_conn, user: user, character: character, map: map}
    end

    test "GET /api/v1/map_systems returns systems for authenticated map", %{
      conn: conn,
      map: map
    } do
      # Create systems for the map
      system1 =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita",
          position_x: 100,
          position_y: 200
        })

      system2 =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_144,
          name: "Amarr",
          position_x: 300,
          position_y: 400
        })

      conn = get(conn, "/api/v1/map_systems")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert length(data) == 2

      ids = Enum.map(data, & &1["id"])
      assert system1.id in ids
      assert system2.id in ids
    end

    test "GET /api/v1/map_systems filters to only the authenticated map's systems", %{
      conn: conn,
      map: map
    } do
      # Create a system for our map
      _our_system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      # Create another map with its own system (should not be returned)
      other_user = insert(:user)
      other_character = insert(:character, %{user_id: other_user.id})
      other_map = insert(:map, %{owner_id: other_character.id})

      _other_system =
        insert(:map_system, %{
          map_id: other_map.id,
          solar_system_id: 30_000_144,
          name: "Amarr"
        })

      conn = get(conn, "/api/v1/map_systems")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1

      [returned_system] = data
      assert returned_system["attributes"]["name"] == "Jita"
    end

    test "POST /api/v1/map_systems creates a system with map_id injected", %{
      conn: conn,
      map: map
    } do
      payload = %{
        "data" => %{
          "type" => "map_systems",
          "attributes" => %{
            "solar_system_id" => 30_000_142,
            "name" => "Jita",
            "position_x" => 100,
            "position_y" => 200
          }
        }
      }

      conn = post(conn, "/api/v1/map_systems", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "map_systems"
      assert data["attributes"]["name"] == "Jita"
      assert data["attributes"]["solar_system_id"] == 30_000_142

      # Verify the system was created with the correct map_id
      # Use Ecto directly to bypass security filter for test verification
      system_id = data["id"]
      system = WandererApp.Repo.get!(WandererApp.Api.MapSystem, system_id)
      assert system.map_id == map.id
    end

    test "POST /api/v1/map_systems ignores client-supplied map_id and uses authenticated map", %{
      conn: conn,
      map: map
    } do
      # Create another map that the client will try to inject
      other_user = insert(:user)
      other_character = insert(:character, %{user_id: other_user.id})
      other_map = insert(:map, %{owner_id: other_character.id})

      # Client tries to supply a different map_id in the payload
      payload = %{
        "data" => %{
          "type" => "map_systems",
          "attributes" => %{
            "solar_system_id" => 30_000_145,
            "name" => "Dodixie",
            "position_x" => 150,
            "position_y" => 250,
            "map_id" => other_map.id
          }
        }
      }

      conn = post(conn, "/api/v1/map_systems", payload)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "map_systems"
      assert data["attributes"]["name"] == "Dodixie"

      # Verify the system was created with the authenticated map's ID, not the client-supplied one
      # Use Ecto directly to bypass security filter for test verification
      system_id = data["id"]
      system = WandererApp.Repo.get!(WandererApp.Api.MapSystem, system_id)
      assert system.map_id == map.id
      refute system.map_id == other_map.id
    end

    test "GET /api/v1/map_systems/:id returns a single system", %{conn: conn, map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      conn = get(conn, "/api/v1/map_systems/#{system.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == system.id
      assert data["attributes"]["name"] == "Jita"
    end

    test "PATCH /api/v1/map_systems/:id updates a system", %{conn: conn, map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita",
          description: nil
        })

      payload = %{
        "data" => %{
          "type" => "map_systems",
          "id" => system.id,
          "attributes" => %{
            "description" => "Trade hub"
          }
        }
      }

      conn = patch(conn, "/api/v1/map_systems/#{system.id}", payload)

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["description"] == "Trade hub"
    end

    test "DELETE /api/v1/map_systems/:id deletes a system", %{conn: conn, map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      conn = delete(conn, "/api/v1/map_systems/#{system.id}")

      assert response(conn, 200)

      # Verify the system was deleted
      # Use Ecto directly to bypass security filter for test verification
      assert WandererApp.Repo.get(WandererApp.Api.MapSystem, system.id) == nil
    end

    test "returns 401 for unauthenticated requests" do
      conn = build_conn()
      conn = get(conn, "/api/v1/map_systems")

      assert json_response(conn, 401)
    end

    test "returns 401 for invalid token" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid-token")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/map_systems")

      assert json_response(conn, 401)
    end

    test "GET /api/v1/map_systems/:id returns 404 for system from different map", %{
      conn: conn
    } do
      # Create another map with a system
      other_user = insert(:user)
      other_character = insert(:character, %{user_id: other_user.id})
      other_map = insert(:map, %{owner_id: other_character.id})

      other_system =
        insert(:map_system, %{
          map_id: other_map.id,
          solar_system_id: 30_000_144,
          name: "Amarr"
        })

      conn = get(conn, "/api/v1/map_systems/#{other_system.id}")

      assert json_response(conn, 404)
    end

    test "POST /api/v1/map_systems returns 400 when missing required fields", %{conn: conn} do
      payload = %{
        "data" => %{
          "type" => "map_systems",
          "attributes" =>
            %{
              # Missing solar_system_id - JSON:API returns 400 for schema validation
            }
        }
      }

      conn = post(conn, "/api/v1/map_systems", payload)

      # JSON:API returns 400 for schema validation errors
      assert json_response(conn, 400)
    end

    test "PATCH /api/v1/map_systems/:id returns 404 for system from different map", %{
      conn: conn
    } do
      # Create another map with a system
      other_user = insert(:user)
      other_character = insert(:character, %{user_id: other_user.id})
      other_map = insert(:map, %{owner_id: other_character.id})

      other_system =
        insert(:map_system, %{
          map_id: other_map.id,
          solar_system_id: 30_000_144,
          name: "Amarr"
        })

      payload = %{
        "data" => %{
          "type" => "map_systems",
          "id" => other_system.id,
          "attributes" => %{
            "description" => "Should not update"
          }
        }
      }

      conn = patch(conn, "/api/v1/map_systems/#{other_system.id}", payload)

      assert json_response(conn, 404)
    end

    test "DELETE /api/v1/map_systems/:id returns 404 for system from different map", %{
      conn: conn
    } do
      # Create another map with a system
      other_user = insert(:user)
      other_character = insert(:character, %{user_id: other_user.id})
      other_map = insert(:map, %{owner_id: other_character.id})

      other_system =
        insert(:map_system, %{
          map_id: other_map.id,
          solar_system_id: 30_000_144,
          name: "Amarr"
        })

      conn = delete(conn, "/api/v1/map_systems/#{other_system.id}")

      assert json_response(conn, 404)

      # Verify the system was NOT deleted
      assert WandererApp.Repo.get(WandererApp.Api.MapSystem, other_system.id) != nil
    end
  end
end
