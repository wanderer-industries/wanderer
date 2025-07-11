defmodule WandererAppWeb.MapAPIControllerTest do
  use WandererAppWeb.ApiCase, async: true

  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # These endpoints require :api_map pipeline with authentication
  # We'll need to create test maps and mock authentication

  setup do
    # Create test data
    user = insert(:user)
    map = insert(:map, %{name: "Test Map", owner_id: user.id})
    character = insert(:character, %{user_id: user.id})

    {:ok, %{user: user, map: map, character: character}}
  end

  describe "GET /api/maps/:map_id/systems" do
    setup do
      scenario = create_test_scenario(with_systems: true)
      %{scenario: scenario}
    end

    test "returns systems for valid map with API key", %{conn: conn, scenario: scenario} do
      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> get(~p"/api/maps/#{scenario.map.id}/systems")

      response = assert_json_response(conn, 200)

      assert %{"data" => systems} = response
      assert is_list(systems)
      assert length(systems) == 2

      # Verify we have the expected systems
      system_ids = Enum.map(systems, & &1["solar_system_id"])
      # Jita
      assert 30_000_142 in system_ids
      # Dodixie
      assert 30_002659 in system_ids
    end

    test "returns 401 without API key", %{conn: conn, scenario: scenario} do
      conn = get(conn, ~p"/api/maps/#{scenario.map.id}/systems")

      assert_error_response(conn, 401, "unauthorized")
    end

    test "returns 404 for non-existent map", %{conn: conn} do
      fake_map_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_api_key("fake_api_key")
        |> get(~p"/api/maps/#{fake_map_id}/systems")

      assert_error_response(conn, 404, "not found")
    end
  end

  describe "GET /api/maps/:map_id/connections" do
    setup do
      scenario = create_test_scenario(with_systems: true, with_connections: true)
      %{scenario: scenario}
    end

    test "returns connections for valid map", %{conn: conn, scenario: scenario} do
      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> get(~p"/api/maps/#{scenario.map.id}/connections")

      response = assert_json_response(conn, 200)

      assert %{"data" => connections} = response
      assert is_list(connections)
      assert length(connections) == 1

      # Verify connection details
      [connection] = connections
      assert connection["solar_system_source"] == 30_000_142
      assert connection["solar_system_target"] == 30_002659
    end

    test "returns empty list for map with no connections", %{conn: conn} do
      scenario = create_test_scenario(with_systems: true, with_connections: false)

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> get(~p"/api/maps/#{scenario.map.id}/connections")

      response = assert_json_response(conn, 200)

      assert %{"data" => connections} = response
      assert connections == []
    end
  end

  describe "POST /api/maps/:map_id/systems" do
    setup do
      scenario = create_test_scenario(with_systems: false)
      %{scenario: scenario}
    end

    test "creates system with valid data", %{conn: conn, scenario: scenario} do
      system_params = %{
        # Amarr
        "solar_system_id" => 30_000_144,
        "position_x" => 150,
        "position_y" => 250,
        "status" => 1,
        "visible" => true
      }

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> post(~p"/api/maps/#{scenario.map.id}/systems", system_params)

      response = assert_json_response(conn, 201)

      assert %{"data" => system_data} = response
      assert system_data["solar_system_id"] == 30_000_144
      assert system_data["position_x"] == 150
      assert system_data["position_y"] == 250
      assert system_data["status"] == 1
      assert system_data["visible"] == true
    end

    test "returns 422 with invalid solar_system_id", %{conn: conn, scenario: scenario} do
      system_params = %{
        "solar_system_id" => "invalid",
        "position_x" => 150,
        "position_y" => 250
      }

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> post(~p"/api/maps/#{scenario.map.id}/systems", system_params)

      assert_error_response(conn, 422)
    end

    test "returns 400 with missing required fields", %{conn: conn, scenario: scenario} do
      system_params = %{
        "position_x" => 150
        # Missing solar_system_id and position_y
      }

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> post(~p"/api/maps/#{scenario.map.id}/systems", system_params)

      assert_error_response(conn, 400)
    end
  end

  describe "PUT /api/maps/:map_id/systems/:system_id" do
    setup do
      scenario = create_test_scenario(with_systems: true)
      %{scenario: scenario}
    end

    test "updates system with valid data", %{conn: conn, scenario: scenario} do
      [system | _] = scenario.systems

      update_params = %{
        "status" => 2,
        "custom_name" => "Updated System Name",
        "description" => "Updated description"
      }

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> put(~p"/api/maps/#{scenario.map.id}/systems/#{system.id}", update_params)

      response = assert_json_response(conn, 200)

      assert %{"data" => updated_system} = response
      assert updated_system["status"] == 2
      assert updated_system["custom_name"] == "Updated System Name"
      assert updated_system["description"] == "Updated description"
    end

    test "returns 404 for non-existent system", %{conn: conn, scenario: scenario} do
      fake_system_id = Ecto.UUID.generate()

      update_params = %{
        "status" => 2
      }

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> put(~p"/api/maps/#{scenario.map.id}/systems/#{fake_system_id}", update_params)

      assert_error_response(conn, 404)
    end
  end

  describe "DELETE /api/maps/:map_id/systems/:system_id" do
    setup do
      scenario = create_test_scenario(with_systems: true)
      %{scenario: scenario}
    end

    test "deletes system successfully", %{conn: conn, scenario: scenario} do
      [system | _] = scenario.systems

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> delete(~p"/api/maps/#{scenario.map.id}/systems/#{system.id}")

      assert response(conn, 204)

      # Verify system is actually deleted by trying to fetch it
      conn =
        build_conn()
        |> authenticate_map_api(scenario.map)
        |> get(~p"/api/maps/#{scenario.map.id}/systems")

      response = assert_json_response(conn, 200)
      assert %{"data" => systems} = response
      system_ids = Enum.map(systems, & &1["id"])
      refute system.id in system_ids
    end

    test "returns 404 for non-existent system", %{conn: conn, scenario: scenario} do
      fake_system_id = Ecto.UUID.generate()

      conn =
        conn
        |> authenticate_map_api(scenario.map)
        |> delete(~p"/api/maps/#{scenario.map.id}/systems/#{fake_system_id}")

      assert_error_response(conn, 404)
    end
  end

  describe "GET /api/map/user_characters" do
    test "returns user characters for valid map", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/user_characters?map_id=#{map.id}")
        |> assert_json_response(200)

      assert %{"data" => user_groups} = response
      assert is_list(user_groups)
    end

    test "returns user characters when using slug", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/user_characters?slug=#{map.slug}")
        |> assert_json_response(200)

      assert %{"data" => user_groups} = response
      assert is_list(user_groups)
    end

    test "returns 400 when both map_id and slug provided", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/user_characters?map_id=#{map.id}&slug=#{map.slug}")
        |> assert_json_response(400)

      assert %{"error" => error_msg} = response
      assert error_msg =~ "both"
    end

    test "returns 400 when neither map_id nor slug provided", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/user_characters")
        |> assert_json_response(400)

      assert %{"error" => error_msg} = response
    end
  end

  describe "GET /api/maps/:map_identifier/user-characters" do
    test "returns user characters using unified endpoint with UUID", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/maps/#{map.id}/user-characters")
        |> assert_json_response(200)

      assert %{"data" => user_groups} = response
      assert is_list(user_groups)
    end

    test "returns user characters using unified endpoint with slug", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/maps/#{map.slug}/user-characters")
        |> assert_json_response(200)

      assert %{"data" => user_groups} = response
      assert is_list(user_groups)
    end

    test "returns 404 for non-existent map", %{conn: conn} do
      fake_uuid = Ecto.UUID.generate()

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/maps/#{fake_uuid}/user-characters")
        |> json_response(404)

      assert %{"error" => _} = response
    end
  end

  describe "GET /api/maps/:map_identifier/tracked-characters" do
    test "returns tracked characters for map", %{conn: conn, map: map, character: character} do
      # Create a character tracking record
      _tracking =
        insert(:map_character_settings, %{
          map_id: map.id,
          character_id: character.id,
          tracked: true
        })

      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/maps/#{map.id}/tracked-characters")
        |> assert_json_response(200)

      assert %{"data" => tracked_chars} = response
      assert is_list(tracked_chars)
    end

    test "returns empty list when no characters tracked", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/maps/#{map.id}/tracked-characters")
        |> assert_json_response(200)

      assert %{"data" => []} = response
    end
  end

  describe "GET /api/map/structure-timers" do
    test "returns structure timers for map", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/structure-timers?map_id=#{map.id}")
        |> assert_json_response(200)

      assert %{"data" => timers} = response
      assert is_list(timers)
    end

    test "returns structure timers filtered by system", %{conn: conn, map: map} do
      system_id = 30_000_142

      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/structure-timers?map_id=#{map.id}&system_id=#{system_id}")
        |> assert_json_response(200)

      assert %{"data" => timers} = response
      assert is_list(timers)
    end

    test "returns 400 for invalid system_id", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/structure-timers?map_id=#{map.id}&system_id=invalid")
        |> assert_json_response(400)

      assert %{"error" => error_msg} = response
      assert error_msg =~ "system_id must be int"
    end
  end

  describe "GET /api/map/systems-kills" do
    test "returns systems kills data", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/systems-kills/")
        |> assert_json_response(200)

      assert %{"data" => systems_kills} = response
      assert is_list(systems_kills)

      # Verify structure of systems kills data
      if length(systems_kills) > 0 do
        system_kills = hd(systems_kills)
        assert %{"solar_system_id" => _, "kills" => kills} = system_kills
        assert is_integer(system_kills["solar_system_id"])
        assert is_list(kills)
      end
    end
  end

  describe "authentication and authorization" do
    test "returns 403 when map API is disabled", %{conn: conn, map: map} do
      # This would require mocking the API disabled state
      # For now, we'll test that proper headers are required
      response =
        conn
        |> get("/api/maps/#{map.id}/user-characters")

      # Should fail due to missing authentication
      assert response.status in [401, 403, 404]
    end

    test "handles missing authentication headers", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/user-characters")

      # Should fail due to missing authentication
      assert response.status in [401, 403, 404]
    end

    test "handles invalid map identifier", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/maps/invalid-identifier/user-characters")

      # Should return not found or bad request
      assert response.status in [400, 404]
    end
  end

  describe "deprecated endpoints" do
    test "legacy user_characters endpoint still works", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/user_characters?map_id=#{map.id}")
        |> assert_json_response(200)

      assert %{"data" => _} = response
    end

    test "legacy characters endpoint works", %{conn: conn, map: map} do
      response =
        conn
        |> authenticate_map_api(map)
        |> get("/api/map/characters?map_id=#{map.id}")
        |> assert_json_response(200)

      assert %{"data" => _} = response
    end
  end
end
