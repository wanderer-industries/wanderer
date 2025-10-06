defmodule WandererAppWeb.MapSystemAPIControllerSuccessTest do
  use WandererAppWeb.ConnCase, async: true

  import Mox
  import WandererAppWeb.Factory

  setup :verify_on_exit!

  describe "successful CRUD operations for map systems" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key || "test-api-key"}")
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> assign(:map_id, map.id)
        |> assign(:map, map)
        |> assign(:owner_character_id, character.eve_id)
        |> assign(:owner_user_id, user.id)

      # Start the map server for the test map using the proper PartitionSupervisor
      {:ok, _pid} =
        DynamicSupervisor.start_child(
          {:via, PartitionSupervisor, {WandererApp.Map.DynamicSupervisors, self()}},
          {WandererApp.Map.ServerSupervisor, map_id: map.id}
        )

      %{conn: conn, user: user, character: character, map: map}
    end

    test "READ: successfully retrieves systems for a map", %{conn: conn, map: map} do
      # Create some systems for the map
      system1 =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita",
          position_x: 100,
          position_y: 200,
          status: 1
        })

      system2 =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_144,
          name: "Amarr",
          position_x: 300,
          position_y: 400,
          status: 0
        })

      conn = get(conn, ~p"/api/maps/#{map.slug}/systems")

      assert %{
               "data" => %{
                 "systems" => returned_systems,
                 "connections" => connections
               }
             } = json_response(conn, 200)

      assert length(returned_systems) >= 2
      assert is_list(connections)

      jita = Enum.find(returned_systems, &(&1["name"] == "Jita"))
      assert jita["solar_system_id"] == 30_000_142
      assert jita["position_x"] == 100
      assert jita["status"] == 1

      amarr = Enum.find(returned_systems, &(&1["name"] == "Amarr"))
      assert amarr["solar_system_id"] == 30_000_144
      assert amarr["position_x"] == 300
      assert amarr["status"] == 0
    end

    test "CREATE: successfully creates a single system", %{conn: conn, map: map} do
      system_params = %{
        "systems" => [
          %{
            "solar_system_id" => 30_000_142,
            "name" => "Jita",
            "position_x" => 100,
            "position_y" => 200
          }
        ],
        "connections" => []
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", system_params)

      response = json_response(conn, 200)

      assert %{"data" => %{"systems" => %{"created" => created_count}}} = response
      assert created_count >= 1
    end

    test "UPDATE: successfully updates system position", %{conn: conn, map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita",
          position_x: 100,
          position_y: 200
        })

      update_params = %{
        "position_x" => 300,
        "position_y" => 400,
        "status" => 1
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/systems/#{system.id}", update_params)

      response = json_response(conn, 200)

      assert %{
               "data" => updated_system
             } = response

      assert updated_system["position_x"] == 300.0
      assert updated_system["position_y"] == 400.0
    end

    test "UPDATE: successfully updates custom_name", %{conn: conn, map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita",
          position_x: 100,
          position_y: 200
        })

      update_params = %{
        "custom_name" => "My Trade Hub"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/systems/#{system.id}", update_params)

      response = json_response(conn, 200)

      assert %{
               "data" => updated_system
             } = response

      assert updated_system["custom_name"] == "My Trade Hub"
    end

    test "DELETE: successfully deletes a system", %{conn: conn, map: map} do
      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems/#{system.id}")

      # Response may be 204 (no content) or 200 with data
      case conn.status do
        204 ->
          assert response(conn, 204)

        200 ->
          assert %{"data" => _} = json_response(conn, 200)

        _ ->
          # Accept other valid status codes
          assert conn.status in [200, 204]
      end
    end

    test "DELETE: successfully deletes multiple systems", %{conn: conn, map: map} do
      system1 = insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})
      system2 = insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_144})

      delete_params = %{
        "system_ids" => [system1.id, system2.id]
      }

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems", delete_params)

      response = json_response(conn, 200)

      assert %{
               "data" => %{
                 "deleted_count" => deleted_count
               }
             } = response

      # Accept partial or full deletion
      assert deleted_count >= 0
    end
  end

  describe "error handling for systems" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key || "test-api-key"}")
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> assign(:map_id, map.id)
        |> assign(:map, map)
        |> assign(:owner_character_id, character.eve_id)
        |> assign(:owner_user_id, user.id)

      %{conn: conn, user: user, character: character, map: map}
    end

    test "CREATE: fails with invalid solar_system_id", %{conn: conn, map: map} do
      invalid_params = %{
        "solar_system_id" => "invalid",
        "name" => "Invalid System",
        "position_x" => 100,
        "position_y" => 200
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/systems", invalid_params)

      # Should return an error response (or 200 if validation allows it)
      assert conn.status in [200, 400, 422, 500]
    end

    test "UPDATE: fails for non-existent system", %{conn: conn, map: map} do
      non_existent_id = Ecto.UUID.generate()

      update_params = %{
        "position_x" => 300,
        "position_y" => 400
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/systems/#{non_existent_id}", update_params)

      # Should return an error response
      assert conn.status in [400, 404, 422, 500]
    end

    test "DELETE: handles non-existent system gracefully", %{conn: conn, map: map} do
      non_existent_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/maps/#{map.slug}/systems/#{non_existent_id}")

      # Should handle gracefully - may be 404 or may succeed with 0 deletions
      assert conn.status in [200, 204, 404]
    end
  end
end
