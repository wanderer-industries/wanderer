defmodule WandererApp.MapApiTest do
  use WandererApp.ApiCase

  @moduledoc """
  Tests for map-specific API endpoints using the new map server mock infrastructure.
  Note: Map management endpoints (CRUD) are handled by AshJsonApi at /api/v1/maps.
  These tests focus on map-specific operations that require map server state.
  """

  describe "GET /api/maps/:map_identifier/systems" do
    setup do
      map_data = create_test_map_with_auth()

      # Add systems to the map using the mock infrastructure
      system1 =
        add_system_to_mock(map_data, %{
          name: "System A",
          solar_system_id: 30_000_001,
          position_x: 100,
          position_y: 200
        })

      system2 =
        add_system_to_mock(map_data, %{
          name: "System B",
          solar_system_id: 30_000_002,
          position_x: 200,
          position_y: 300
        })

      {:ok, map_data: map_data, systems: [system1, system2]}
    end

    test "lists all systems in the map", %{conn: conn, map_data: map_data, systems: systems} do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map.slug}/systems")
        |> json_response(200)

      assert length(response["data"]["systems"]) == 2

      # Verify system data
      system_names = Enum.map(response["data"]["systems"], & &1["name"])
      assert "System A" in system_names
      assert "System B" in system_names
    end

    test "returns empty list for map with no systems", %{conn: conn} do
      map_data = create_test_map_with_auth()

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map.slug}/systems")
        |> json_response(200)

      assert response["data"]["systems"] == []
    end

    test "requires authentication", %{conn: conn, map_data: map_data} do
      conn
      |> get("/api/maps/#{map_data.map.slug}/systems")
      |> json_response(401)
    end
  end

  describe "GET /api/maps/:map_identifier/characters" do
    setup do
      map_data = create_test_map_with_auth()
      system = add_system_to_mock(map_data)

      # Create actual MapCharacterSettings record for character tracking
      # This is what the API actually reads from, not the mock cache
      {:ok, _settings} =
        WandererApp.Api.MapCharacterSettings
        |> Ash.Changeset.for_create(:create, %{
          map_id: map_data.map.id,
          character_id: map_data.owner.id,
          tracked: true,
          followed: false
        })
        |> WandererApp.Api.create()

      {:ok, map_data: map_data, system: system}
    end

    test "lists tracked characters in the map", %{conn: conn, map_data: map_data} do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/map/characters?map_id=#{map_data.map.id}")
        |> json_response(200)

      assert length(response["data"]) > 0

      character_setting = hd(response["data"])
      assert character_setting["character_id"] == map_data.owner.id
      assert character_setting["tracked"] == true

      # Check character data is included
      character = character_setting["character"]
      assert character["eve_id"] == map_data.owner.eve_id
      assert character["name"] == map_data.owner.name
    end
  end

  describe "POST /api/maps/:map_identifier/systems" do
    setup do
      map_data = create_test_map_with_auth()
      {:ok, map_data: map_data}
    end

    # Skipped: System creation has database sync issues
    # test "creates a new system in the map"

    test "validates required fields", %{conn: conn, map_data: map_data} do
      params = %{
        "systems" => [
          %{
            "temporary_name" => "Missing solar_system_id"
          }
        ]
      }

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map.slug}/systems", params)
        |> json_response(200)

      # Should return 0 created since invalid
      assert response["data"]["systems"]["created"] == 0
    end
  end

  # Skipped: System deletion has database sync issues
  # describe "DELETE /api/maps/:map_identifier/systems"

  describe "GET /api/maps/:map_identifier/activity" do
    setup do
      map_data = create_test_map_with_auth()
      {:ok, map_data: map_data}
    end

    test "returns character activity data", %{conn: conn, map_data: map_data} do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/map/character-activity?map_id=#{map_data.map.id}")
        |> json_response(200)

      assert Map.has_key?(response, "data")
    end
  end

  describe "GET /api/map/systems-kills" do
    setup do
      map_data = create_test_map_with_auth()
      _system = add_system_to_mock(map_data)
      {:ok, map_data: map_data}
    end

    test "returns kill data for systems in map", %{conn: conn, map_data: map_data} do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/map/systems-kills?map_id=#{map_data.map.id}")
        |> json_response(200)

      assert Map.has_key?(response, "data")
    end
  end
end
