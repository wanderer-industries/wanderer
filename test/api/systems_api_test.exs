defmodule WandererApp.SystemsApiTest do
  use WandererApp.ApiCase
  use WandererApp.Test.CrudTestScaffolding

  @moduletag :api

  # Enhanced CRUD operations using scaffolding patterns
  describe "Map Systems API - Enhanced CRUD patterns" do
    setup do
      map_data = create_test_map_with_auth()

      # Create some test systems for relationships
      system1 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142,
            name: "Jita"
          },
          map_data.owner
        )

      system2 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_144,
            name: "Perimeter"
          },
          map_data.owner
        )

      Map.merge(map_data, %{system1: system1, system2: system2})
      |> then(&{:ok, &1})
    end

    test "demonstrates comprehensive CRUD coverage patterns", context do
      # This test demonstrates the enhanced patterns we're implementing
      map_data = context

      # CREATE with comprehensive validation
      create_params = %{
        "solar_system_id" => 30_000_001,
        "temporary_name" => "Test System",
        "position_x" => 100,
        "position_y" => 200,
        "tag" => "test",
        "status" => 1,
        "description" => "Test system for CRUD demo"
      }

      # Test creation with full response validation
      response =
        context[:conn]
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [create_params])
        |> assert_success_response(200)

      assert response["data"]["systems"]["created"] == 1

      # READ with filtering and verification
      list_response =
        context[:conn]
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems")
        |> assert_success_response(200)

      systems = list_response["data"]["systems"]
      created_system = Enum.find(systems, &(&1["solar_system_id"] == 30_000_001))
      assert created_system
      assert created_system["name"] == "Test System"
      assert created_system["position_x"] == 100

      # UPDATE with partial data
      update_params = %{
        "position_x" => 300,
        "position_y" => 400,
        "tag" => "updated",
        "description" => "Updated test system"
      }

      # Note: Systems use bulk update via POST, not individual PUT
      update_system_params = Map.put(update_params, "solar_system_id", 30_000_001)

      update_response =
        context[:conn]
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [update_system_params])
        |> assert_success_response(200)

      assert update_response["data"]["systems"]["updated"] == 1

      # DELETE with verification
      context[:conn]
      |> authenticate_map(map_data.api_key)
      |> delete("/api/maps/#{map_data.map_slug}/systems/#{30_000_001}")
      |> assert_success_response(200)

      # Verify deletion
      context[:conn]
      |> authenticate_map(map_data.api_key)
      |> get("/api/maps/#{map_data.map_slug}/systems/#{30_000_001}")
      |> json_response!(404)
    end

    test "validation scenarios with edge cases", context do
      map_data = context

      # Test invalid system creation
      invalid_params = %{
        "solar_system_id" => nil,
        "temporary_name" => "",
        "position_x" => "invalid"
      }

      response =
        context[:conn]
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [invalid_params])
        |> assert_success_response(200)

      # Systems API handles invalid data gracefully
      assert response["data"]["systems"]["created"] == 0

      # Test non-existent system retrieval
      context[:conn]
      |> authenticate_map(map_data.api_key)
      |> get("/api/maps/#{map_data.map_slug}/systems/99999999")
      |> json_response!(404)
    end

    test "concurrent operations and bulk handling", context do
      map_data = context

      # Test bulk creation
      bulk_systems =
        for i <- 1..5 do
          %{
            "solar_system_id" => 30_000_000 + i,
            "temporary_name" => "Bulk System #{i}",
            "position_x" => i * 100,
            "position_y" => 200
          }
        end

      response =
        context[:conn]
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: bulk_systems)
        |> assert_success_response(200)

      assert response["data"]["systems"]["created"] == 5

      # Test bulk deletion
      system_ids = Enum.map(bulk_systems, & &1["solar_system_id"])

      context[:conn]
      |> authenticate_map(map_data.api_key)
      |> delete("/api/maps/#{map_data.map_slug}/systems", %{"system_ids" => system_ids})
      |> assert_success_response(200)

      # Verify all systems were deleted
      list_response =
        context[:conn]
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems")
        |> json_response!(200)

      remaining_systems = list_response["data"]["systems"]
      bulk_system_ids = MapSet.new(system_ids)

      assert Enum.all?(remaining_systems, fn sys ->
               not MapSet.member?(bulk_system_ids, sys["solar_system_id"])
             end)
    end
  end

  describe "Legacy Map Systems API CRUD operations" do
    setup do
      map_data = create_test_map_with_auth()
      {:ok, map_data: map_data}
    end

    test "GET /api/maps/:map_slug/systems - lists all systems in map", %{
      conn: conn,
      map_data: map_data
    } do
      # Create some systems
      system1 =
        create_map_system(
          %{
            map: map_data.map,
            # Jita
            solar_system_id: 30_000_142,
            name: "Jita",
            position_x: 100,
            position_y: 200
          },
          map_data.owner
        )

      system2 =
        create_map_system(
          %{
            map: map_data.map,
            # Perimeter
            solar_system_id: 30_000_144,
            name: "Perimeter",
            position_x: 300,
            position_y: 200
          },
          map_data.owner
        )

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems")
        |> assert_success_response(200)

      assert length(response["data"]["systems"]) == 2
      assert Enum.any?(response["data"]["systems"], &(&1["solar_system_id"] == 30_000_142))
      assert Enum.any?(response["data"]["systems"], &(&1["solar_system_id"] == 30_000_144))
    end

    test "POST /api/maps/:map_slug/systems - adds new system to map", %{
      conn: conn,
      map_data: map_data
    } do
      system_params = %{
        "solar_system_id" => 30_000_142,
        "temporary_name" => "Jita",
        "position_x" => 500,
        "position_y" => 300
      }

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])
        |> assert_success_response(200)

      assert response["data"]["systems"]["created"] == 1
      assert response["data"]["systems"]["updated"] == 0

      # Verify system was created by fetching it
      verify_response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems")
        |> json_response!(200)

      created_system =
        Enum.find(verify_response["data"]["systems"], &(&1["solar_system_id"] == 30_000_142))

      assert created_system
      assert created_system["name"] == "Jita"
      assert created_system["position_x"] == 500
      assert created_system["position_y"] == 300
    end

    test "POST /api/maps/:map_slug/systems - adds multiple systems", %{
      conn: conn,
      map_data: map_data
    } do
      systems_params = [
        %{
          "solar_system_id" => 30_000_142,
          "temporary_name" => "Jita",
          "position_x" => 100,
          "position_y" => 100
        },
        %{
          "solar_system_id" => 30_000_144,
          "temporary_name" => "Perimeter",
          "position_x" => 200,
          "position_y" => 100
        }
      ]

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: systems_params)
        |> assert_success_response(200)

      assert response["data"]["systems"]["created"] == 2
    end

    test "GET /api/maps/:map_slug/systems/:system_id - gets single system", %{
      conn: conn,
      map_data: map_data
    } do
      system =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142,
            temporary_name: "Jita"
          },
          map_data.owner
        )

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems/#{system.solar_system_id}")
        |> assert_success_response(200)

      assert response["data"]["solar_system_id"] == system.solar_system_id
      assert response["data"]["solar_system_id"] == 30_000_142
      assert response["data"]["name"] == "Jita"
    end

    test "DELETE /api/maps/:map_slug/systems/:system_id - removes system", %{
      conn: conn,
      map_data: map_data
    } do
      system =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142
          },
          map_data.owner
        )

      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> delete("/api/maps/#{map_data.map_slug}/systems/#{system.solar_system_id}")
        |> assert_success_response(200)

      assert response["data"]["deleted"] == true

      # Verify system is removed
      conn
      |> authenticate_map(map_data.api_key)
      |> get("/api/maps/#{map_data.map_slug}/systems/#{system.solar_system_id}")
      |> json_response!(404)
    end

    test "POST /api/maps/:map_slug/systems - validates required fields", %{
      conn: conn,
      map_data: map_data
    } do
      # Missing solar_system_id - API handles this gracefully and returns stats
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [%{"name" => "Test"}])
        |> assert_success_response(200)

      # Should return 0 created since no valid systems were provided
      assert response["data"]["systems"]["created"] == 0
    end

    test "POST /api/maps/:map_slug/systems - prevents duplicate systems", %{
      conn: conn,
      map_data: map_data
    } do
      # Add system first time
      system_params = %{
        "solar_system_id" => 30_000_142,
        "temporary_name" => "Jita",
        "position_x" => 100,
        "position_y" => 100
      }

      conn
      |> authenticate_map(map_data.api_key)
      |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])
      |> assert_success_response(200)

      # Try to add same system again - should update existing
      response2 =
        conn
        |> authenticate_map(map_data.api_key)
        |> post("/api/maps/#{map_data.map_slug}/systems", systems: [system_params])
        |> assert_success_response(200)

      assert response2["data"]["systems"]["updated"] == 1
      assert response2["data"]["systems"]["created"] == 0
    end
  end

  describe "System bulk operations" do
    setup do
      map_data = create_test_map_with_auth()
      {:ok, map_data: map_data}
    end

    test "DELETE /api/maps/:map_slug/systems - bulk delete with IDs", %{
      conn: conn,
      map_data: map_data
    } do
      # Create multiple systems
      system1 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_142}, map_data.owner)

      system2 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_144}, map_data.owner)

      system3 =
        create_map_system(%{map: map_data.map, solar_system_id: 30_000_145}, map_data.owner)

      # Delete two systems
      conn
      |> authenticate_map(map_data.api_key)
      |> delete("/api/maps/#{map_data.map_slug}/systems", %{
        "system_ids" => [system1.solar_system_id, system2.solar_system_id]
      })
      |> assert_success_response(200)

      # Verify only system3 remains
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems")
        |> json_response!(200)

      assert length(response["data"]["systems"]) == 1
      assert hd(response["data"]["systems"])["solar_system_id"] == system3.solar_system_id
    end
  end

  describe "System filtering and search" do
    setup do
      map_data = create_test_map_with_auth()

      # Create systems with different attributes
      _system1 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_142,
            temporary_name: "Jita",
            tag: "trade",
            status: 1
          },
          map_data.owner
        )

      _system2 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_144,
            temporary_name: "Perimeter",
            tag: "staging",
            status: 2
          },
          map_data.owner
        )

      _system3 =
        create_map_system(
          %{
            map: map_data.map,
            solar_system_id: 30_000_145,
            temporary_name: "Maurasi",
            tag: "trade",
            status: 1
          },
          map_data.owner
        )

      {:ok, map_data: map_data}
    end

    test "GET /api/maps/:map_slug/systems - filters by tag", %{conn: conn, map_data: map_data} do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems", %{"tag" => "trade"})
        |> json_response!(200)

      assert length(response["data"]["systems"]) == 2
      assert Enum.all?(response["data"]["systems"], &(&1["tag"] == "trade"))
    end

    test "GET /api/maps/:map_slug/systems - filters by status", %{conn: conn, map_data: map_data} do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems", %{"status" => "2"})
        |> json_response!(200)

      assert length(response["data"]["systems"]) == 1
      assert hd(response["data"]["systems"])["status"] == 2
    end

    test "GET /api/maps/:map_slug/systems - searches by name", %{conn: conn, map_data: map_data} do
      response =
        conn
        |> authenticate_map(map_data.api_key)
        |> get("/api/maps/#{map_data.map_slug}/systems", %{"search" => "Jita"})
        |> json_response!(200)

      assert length(response["data"]["systems"]) == 1
      assert hd(response["data"]["systems"])["name"] == "Jita"
    end
  end
end
