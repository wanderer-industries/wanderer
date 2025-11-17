defmodule WandererAppWeb.Api.V1.MapSystemApiV1Test do
  use WandererAppWeb.ConnCase, async: false

  import Mox
  import WandererAppWeb.Factory

  setup :verify_on_exit!
  setup :set_mox_private

  describe "POST /api/v1/map_systems (token-only)" do
    setup do
      Mox.stub(Test.SpatialIndexMock, :insert, fn _data, _tree_name -> :ok end)

      Mox.stub(WandererApp.CachedInfo.Mock, :get_system_static_info, fn _ ->
        {:ok,
         %{
           solar_system_id: 30_000_142,
           solar_system_name: "Jita",
           region_name: "The Forge",
           constellation_name: "Kimotoro"
         }}
      end)

      Mox.stub(Test.PubSubMock, :broadcast!, fn _, _, _ -> :ok end)

      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      {:ok, updated_map} =
        WandererApp.MapRepo.update(map, %{
          public_api_key: "test_token_#{System.unique_integer([:positive])}"
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{updated_map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")

      %{conn: conn, user: user, character: character, map: updated_map}
    end

    test "creates system without map_id in body (token-only)", %{conn: conn, map: map} do
      # Initialize map in cache
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{},
        connections: %{}
      })

      payload = %{
        "data" => %{
          "type" => "map_systems",
          "attributes" => %{
            # NO map_id provided - should be auto-injected from token
            "solar_system_id" => 30_000_142,
            "name" => "Jita",
            "position_x" => 100,
            "position_y" => 200,
            "visible" => true
          }
        }
      }

      response = post(conn, "/api/v1/map_systems", payload)

      assert response.status == 201
      assert %{"data" => %{"id" => system_id}} = json_response(response, 201)

      # Verify system was created with correct map_id
      {:ok, system} = Ash.get(WandererApp.Api.MapSystem, system_id, action: :read_bypassing_actor)
      assert system.map_id == map.id
      assert system.solar_system_id == 30_000_142
      assert system.position_x == 100
      assert system.position_y == 200
    end

    test "ignores client-provided map_id (uses token's map)", %{conn: conn, map: map} do
      other_user = insert(:user)
      other_character = insert(:character, user_id: other_user.id)
      other_map = insert(:map, owner_id: other_character.id)

      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{},
        connections: %{}
      })

      payload = %{
        "data" => %{
          "type" => "map_systems",
          "attributes" => %{
            "map_id" => other_map.id,
            # Wrong map - should be ignored
            "solar_system_id" => 30_000_142,
            "name" => "Jita",
            "position_x" => 100,
            "position_y" => 200,
            "visible" => true
          }
        }
      }

      response = post(conn, "/api/v1/map_systems", payload)

      assert response.status == 201

      {:ok, system} =
        Ash.get(WandererApp.Api.MapSystem, json_response(response, 201)["data"]["id"],
          action: :read_bypassing_actor
        )

      # Should use token's map, not client's
      assert system.map_id == map.id
      assert system.map_id != other_map.id
    end

    test "fails with invalid token", %{map: map} do
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{},
        connections: %{}
      })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_token_12345")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")

      payload = %{
        "data" => %{
          "type" => "map_systems",
          "attributes" => %{
            "solar_system_id" => 30_000_142,
            "name" => "Jita",
            "visible" => true
          }
        }
      }

      response = post(conn, "/api/v1/map_systems", payload)

      # Should be unauthorized
      assert response.status in [401, 403]
    end
  end

  describe "GET /api/v1/map_systems (token-only)" do
    setup do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      {:ok, updated_map} =
        WandererApp.MapRepo.update(map, %{
          public_api_key: "test_token_#{System.unique_integer([:positive])}"
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{updated_map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")

      %{conn: conn, user: user, character: character, map: updated_map}
    end

    test "only returns systems from token's map", %{conn: conn, map: map} do
      other_user = insert(:user)
      other_character = insert(:character, user_id: other_user.id)
      other_map = insert(:map, owner_id: other_character.id)

      # Create system on our map
      our_system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Create system on different map
      _other_system = insert(:map_system, map_id: other_map.id, solar_system_id: 30_000_144)

      response = get(conn, "/api/v1/map_systems")

      assert response.status == 200
      systems = json_response(response, 200)["data"]

      # Should only see our map's system
      system_ids = Enum.map(systems, & &1["id"])
      assert our_system.id in system_ids
      assert length(systems) == 1
    end

    test "returns empty list when map has no systems", %{conn: conn} do
      response = get(conn, "/api/v1/map_systems")

      assert response.status == 200
      systems = json_response(response, 200)["data"]
      assert systems == []
    end

    test "does not require map_id filter parameter", %{conn: conn, map: map} do
      insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Request WITHOUT map_id filter - should still work
      response = get(conn, "/api/v1/map_systems")

      assert response.status == 200
      systems = json_response(response, 200)["data"]
      assert length(systems) == 1
    end

    test "returns empty results when filtering by different map_id", %{conn: conn, map: map} do
      other_user = insert(:user)
      other_character = insert(:character, user_id: other_user.id)
      other_map = insert(:map, owner_id: other_character.id)

      # Create systems on both maps
      _our_system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)
      _other_system = insert(:map_system, map_id: other_map.id, solar_system_id: 30_000_144)

      # Try to filter by other_map.id - security filter (from token) is ANDed with this filter
      # Since token says map A but filter says map B, the result is empty (secure behavior)
      response = get(conn, "/api/v1/map_systems?filter[map_id]=#{other_map.id}")

      assert response.status == 200
      systems = json_response(response, 200)["data"]

      # Should return empty results because map_id = A AND map_id = B is always false
      assert systems == []
    end
  end

  describe "GET /api/v1/map_systems/:id (token-only)" do
    setup do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      {:ok, updated_map} =
        WandererApp.MapRepo.update(map, %{
          public_api_key: "test_token_#{System.unique_integer([:positive])}"
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{updated_map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")

      %{conn: conn, user: user, character: character, map: updated_map}
    end

    test "can get system from own map", %{conn: conn, map: map} do
      system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      response = get(conn, "/api/v1/map_systems/#{system.id}")

      assert response.status == 200
      returned_system = json_response(response, 200)["data"]
      assert returned_system["id"] == system.id
    end

    test "cannot get system from other map", %{conn: conn} do
      other_user = insert(:user)
      other_character = insert(:character, user_id: other_user.id)
      other_map = insert(:map, owner_id: other_character.id)
      other_system = insert(:map_system, map_id: other_map.id, solar_system_id: 30_000_142)

      response = get(conn, "/api/v1/map_systems/#{other_system.id}")

      # Should not find the system (filtered by map context)
      assert response.status == 404
    end
  end

  describe "PATCH /api/v1/map_systems/:id (token-only)" do
    setup do
      Mox.stub(Test.PubSubMock, :broadcast!, fn _, _, _ -> :ok end)

      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      {:ok, updated_map} =
        WandererApp.MapRepo.update(map, %{
          public_api_key: "test_token_#{System.unique_integer([:positive])}"
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{updated_map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")

      %{conn: conn, user: user, character: character, map: updated_map}
    end

    test "can update system on own map", %{conn: conn, map: map} do
      system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142, position_x: 100)

      # Initialize cache
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{system.solar_system_id => system},
        connections: %{}
      })

      payload = %{
        "data" => %{
          "type" => "map_systems",
          "id" => system.id,
          "attributes" => %{
            "position_x" => 200
          }
        }
      }

      response = patch(conn, "/api/v1/map_systems/#{system.id}", payload)

      assert response.status == 200

      {:ok, updated_system} =
        Ash.get(WandererApp.Api.MapSystem, system.id, action: :read_bypassing_actor)

      assert updated_system.position_x == 200
    end

    test "cannot update system on other map", %{conn: conn} do
      other_user = insert(:user)
      other_character = insert(:character, user_id: other_user.id)
      other_map = insert(:map, owner_id: other_character.id)
      other_system = insert(:map_system, map_id: other_map.id, solar_system_id: 30_000_142)

      payload = %{
        "data" => %{
          "type" => "map_systems",
          "id" => other_system.id,
          "attributes" => %{
            "position_x" => 200
          }
        }
      }

      response = patch(conn, "/api/v1/map_systems/#{other_system.id}", payload)

      # Should fail - system not found (filtered by map)
      assert response.status in [404, 403]
    end
  end

  describe "DELETE /api/v1/map_systems/:id (token-only)" do
    setup do
      Mox.stub(Test.PubSubMock, :broadcast!, fn _, _, _ -> :ok end)

      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      {:ok, updated_map} =
        WandererApp.MapRepo.update(map, %{
          public_api_key: "test_token_#{System.unique_integer([:positive])}"
        })

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{updated_map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")

      %{conn: conn, user: user, character: character, map: updated_map}
    end

    test "can delete system from own map", %{conn: conn, map: map} do
      system = insert(:map_system, map_id: map.id, solar_system_id: 30_000_142)

      # Initialize cache
      WandererApp.Map.update_map(map.id, %{
        id: map.id,
        name: map.name,
        systems: %{system.solar_system_id => system},
        connections: %{}
      })

      response = delete(conn, "/api/v1/map_systems/#{system.id}")

      # Should return 204 No Content per REST/JSON:API standards
      assert response.status == 204

      # Verify deletion
      assert {:error, _} =
               Ash.get(WandererApp.Api.MapSystem, system.id, action: :read_bypassing_actor)
    end

    test "cannot delete system from other map", %{conn: conn} do
      other_user = insert(:user)
      other_character = insert(:character, user_id: other_user.id)
      other_map = insert(:map, owner_id: other_character.id)
      other_system = insert(:map_system, map_id: other_map.id, solar_system_id: 30_000_142)

      response = delete(conn, "/api/v1/map_systems/#{other_system.id}")

      # Should fail - system not found (filtered by map)
      assert response.status in [404, 403]

      # Verify system still exists
      assert {:ok, _} =
               Ash.get(WandererApp.Api.MapSystem, other_system.id, action: :read_bypassing_actor)
    end
  end
end
