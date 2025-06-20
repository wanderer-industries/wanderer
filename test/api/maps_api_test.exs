defmodule WandererApp.MapsApiTest do
  use WandererApp.ApiCase

  @moduletag :api

  describe "Maps API CRUD operations" do
    setup do
      # Create test user and character
      user = create_user()
      character = create_character(%{user_id: user.id})

      {:ok, user: user, character: character}
    end

    test "GET /api/maps/:slug/systems - retrieves map systems with valid authentication", %{
      conn: conn
    } do
      # Create a map with API key and systems
      map_data = create_map_with_systems_and_connections()

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map.slug}/systems")
        |> assert_success_response(200)

      assert length(response["data"]["systems"]) == 3
      assert Enum.all?(response["data"]["systems"], &(&1["map_id"] == map_data.map.id))
    end

    test "GET /api/maps/:slug/systems - returns 401 without authentication", %{conn: conn} do
      map_data = create_test_map_with_auth()

      response =
        conn
        |> get("/api/maps/#{map_data.map_slug}/systems")

      assert response.status == 401
    end

    test "GET /api/maps/:slug/systems - returns 401 with invalid API key", %{conn: conn} do
      map_data = create_test_map_with_auth()

      response =
        conn
        |> authenticate_map("invalid-api-key")
        |> get("/api/maps/#{map_data.map_slug}/systems")

      assert response.status == 401
    end

    test "GET /api/maps/:slug/systems - returns 404 for non-existent map", %{conn: conn} do
      response =
        conn
        |> authenticate_map("some-api-key")
        |> get("/api/maps/non-existent-slug/systems")

      assert response.status == 404
    end

    test "GET /api/map/acls - lists map ACLs with valid authentication", %{conn: conn} do
      # Create a map with ACLs
      map_data = create_test_map_with_auth()

      # Create an ACL and associate it with the map
      acl = create_access_list(%{name: "Test ACL", owner_id: map_data.owner.id}, map_data.owner)

      _map_acl =
        Ash.create!(
          WandererApp.Api.MapAccessList,
          %{
            map_id: map_data.map.id,
            access_list_id: acl.id
          },
          actor: map_data.owner
        )

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/map/acls", %{"map_id" => map_data.map.id})
        |> assert_success_response(200)

      assert length(response["data"]) >= 1
    end

    test "POST /api/maps/:slug/systems - adds systems to map", %{conn: conn} do
      map_data = create_test_map_with_auth()

      systems_params = [
        %{
          "solar_system_id" => 30_000_142,
          "solar_system_name" => "Jita",
          "position_x" => 100,
          "position_y" => 100
        },
        %{
          "solar_system_id" => 30_000_144,
          "solar_system_name" => "Perimeter",
          "position_x" => 200,
          "position_y" => 100
        }
      ]

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: systems_params)
        |> assert_success_response(200)

      # The response format is: %{data: %{systems: %{created: X, updated: Y}, connections: %{...}}}
      assert response["data"]["systems"]["created"] == 2
    end

    test "DELETE /api/maps/:slug/systems - removes systems from map", %{conn: conn} do
      map_data = create_map_with_systems_and_connections()

      # Delete first two systems
      system_ids = Enum.take(map_data.systems, 2) |> Enum.map(& &1.solar_system_id)

      conn
      |> authenticate_map(map_data.api_key)
      |> delete("/api/maps/#{map_data.map.slug}/systems", %{"system_ids" => system_ids})
      |> assert_success_response(200)

      # Verify only one system remains
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map.slug}/systems")
        |> json_response!(200)

      assert length(response["data"]["systems"]) == 1
    end

    test "GET /api/map/characters - lists tracked characters", %{conn: conn} do
      map_data = create_test_map_with_auth()

      # Add tracked character
      _tracked =
        Ash.create!(
          WandererApp.Api.MapCharacterSettings,
          %{
            map_id: map_data.map.id,
            character_id: map_data.owner.id,
            tracked: true
          },
          actor: map_data.owner
        )

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/map/characters", %{"map_id" => map_data.map.id})
        |> assert_success_response(200)

      assert length(response["data"]) >= 1
    end
  end

  describe "Map permissions and access control" do
    setup do
      owner = create_character(%{name: "Map Owner"})
      other_user = create_character(%{name: "Other User"})
      map_data = create_test_map_with_auth(%{character: %{name: "Map Owner"}})

      {:ok, owner: owner, other_user: other_user, map_data: map_data}
    end

    test "owner can add systems to their own map", %{conn: conn, owner: owner, map_data: map_data} do
      system_params = %{
        "solar_system_id" => 30_000_142,
        "name" => "Jita",
        "position_x" => 100,
        "position_y" => 100
      }

      conn
      |> authenticate_map(map_data.api_key)
      |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])
      |> assert_success_response(200)
    end

    test "non-owner cannot access map without permission", %{
      conn: conn,
      other_user: other_user,
      map_data: map_data
    } do
      # Try to access with a different user's auth
      other_token = generate_character_token(other_user)

      response =
        conn
        |> put_req_header("authorization", "Bearer #{other_token}")
        |> get("/api/maps/#{map_data.map_slug}/systems")

      assert response.status == 401
    end

    test "API key provides full access to map resources", %{conn: conn, map_data: map_data} do
      conn
      |> authenticate_map(map_data.api_key)
      |> get("/api/maps/#{map_data.map_slug}/systems")
      |> assert_success_response(200)
    end
  end

  describe "Map validation" do
    setup do
      character = create_character()
      {:ok, character: character}
    end

    test "POST /api/maps/:slug/systems - validates required fields", %{conn: conn} do
      map_data = create_test_map_with_auth()

      # Missing solar_system_id - API handles this gracefully and returns stats
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems",
          systems: [%{"solar_system_name" => "Test"}]
        )
        |> assert_success_response(200)

      # Should return 0 created since no valid systems were provided
      assert response["data"]["systems"]["created"] == 0
    end

    test "POST /api/maps/:slug/systems - prevents duplicate systems", %{conn: conn} do
      map_data = create_test_map_with_auth()

      system_params = %{
        "solar_system_id" => 30_000_142,
        "solar_system_name" => "Jita",
        "position_x" => 100,
        "position_y" => 100
      }

      # Add system first time
      response1 =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])
        |> assert_success_response(200)

      assert response1["data"]["systems"]["created"] == 1

      # Try to add same system again - should update existing
      response2 =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])
        |> assert_success_response(200)

      assert response2["data"]["systems"]["updated"] == 1
      assert response2["data"]["systems"]["created"] == 0
    end

    test "POST /api/maps/:slug/systems - validates connection endpoints", %{conn: conn} do
      map_data = create_test_map_with_auth()

      # Try to create connection with non-existent systems
      connection_params = %{
        "solar_system_source" => 30_000_142,
        "solar_system_target" => 30_000_144,
        "type" => 0
      }

      # This should succeed and create both the connection and systems
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", connections: [connection_params])
        |> assert_success_response(200)

      assert response["data"]["connections"]["created"] == 1
    end
  end
end
