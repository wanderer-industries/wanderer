defmodule WandererAppWeb.MapConnectionAPIControllerSuccessTest do
  use WandererAppWeb.ConnCase, async: true

  import Mox
  import WandererAppWeb.Factory

  setup :verify_on_exit!

  describe "successful CRUD operations for map connections" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      # Start the map server for this test map
      {:ok, _pid} =
        DynamicSupervisor.start_child(
          {:via, PartitionSupervisor, {WandererApp.Map.DynamicSupervisors, self()}},
          {WandererApp.Map.ServerSupervisor, map_id: map.id}
        )

      # Create systems that connections can reference
      system1 =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          name: "Jita"
        })

      system2 =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_144,
          name: "Amarr"
        })

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

      %{
        conn: conn,
        user: user,
        character: character,
        map: map,
        system1: system1,
        system2: system2
      }
    end

    test "READ: successfully retrieves all connections for a map", %{
      conn: conn,
      map: map,
      system1: system1,
      system2: system2
    } do
      # Create some connections for the map
      connection1 =
        insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id,
          type: 0,
          ship_size_type: 2
        })

      connection2 =
        insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system2.solar_system_id,
          solar_system_target: system1.solar_system_id,
          type: 1,
          ship_size_type: 1
        })

      # Update the map cache with the connections we just created
      WandererApp.Map.add_connection(map.id, connection1)
      WandererApp.Map.add_connection(map.id, connection2)

      conn = get(conn, ~p"/api/maps/#{map.slug}/connections")

      assert %{
               "data" => returned_connections
             } = json_response(conn, 200)

      # At least one connection should be returned
      assert length(returned_connections) >= 1

      # Verify the connection has the expected structure and data
      first_conn = List.first(returned_connections)
      assert first_conn["solar_system_source"] != nil
      assert first_conn["solar_system_target"] != nil
      assert first_conn["type"] != nil
      assert first_conn["ship_size_type"] != nil
      # time_status will be default value since we can't set it during creation
      assert first_conn["time_status"] == 0
    end

    test "UPDATE: successfully updates connection properties", %{
      conn: conn,
      map: map,
      system1: system1,
      system2: system2
    } do
      connection =
        insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id,
          type: 0,
          ship_size_type: 0
        })

      # Update the map cache with the connection we just created
      WandererApp.Map.add_connection(map.id, connection)

      update_params = %{
        "mass_status" => 2
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/connections/#{connection.id}", update_params)

      response = json_response(conn, 200)

      assert %{
               "data" => updated_connection
             } = response

      assert updated_connection["mass_status"] == 2
      # Verify other fields remain unchanged
      assert updated_connection["ship_size_type"] == 0
      assert updated_connection["time_status"] == 0
    end

    test "DELETE: successfully deletes a connection", %{
      conn: conn,
      map: map,
      system1: system1,
      system2: system2
    } do
      connection =
        insert(:map_connection, %{
          map_id: map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id,
          type: 0,
          ship_size_type: 2
        })

      # Update the map cache with the connection we just created
      WandererApp.Map.add_connection(map.id, connection)

      conn = delete(conn, ~p"/api/maps/#{map.slug}/connections/#{connection.id}")

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
  end

  describe "error handling for connections" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})

      # Start the map server for this test map
      {:ok, _pid} =
        DynamicSupervisor.start_child(
          {:via, PartitionSupervisor, {WandererApp.Map.DynamicSupervisors, self()}},
          {WandererApp.Map.ServerSupervisor, map_id: map.id}
        )

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

    test "CREATE: fails with missing required parameters", %{conn: conn, map: map} do
      invalid_params = %{
        "type" => 0
        # Missing source and target system IDs
      }

      conn = post(conn, ~p"/api/maps/#{map.slug}/connections", invalid_params)

      # Should return an error response
      assert conn.status in [400, 422]
    end

    test "UPDATE: fails for non-existent connection", %{conn: conn, map: map} do
      non_existent_id = Ecto.UUID.generate()

      update_params = %{
        "ship_size_type" => "large",
        "time_status" => "critical"
      }

      conn = put(conn, ~p"/api/maps/#{map.slug}/connections/#{non_existent_id}", update_params)

      # Should return an error response
      assert conn.status in [404, 422, 500]
    end

    test "DELETE: handles non-existent connection gracefully", %{conn: conn, map: map} do
      non_existent_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/maps/#{map.slug}/connections/#{non_existent_id}")

      # Should handle gracefully - may be 404 or may succeed
      assert conn.status in [200, 204, 404]
    end

    test "READ: handles filtering with non-existent systems", %{conn: conn, map: map} do
      params = %{
        "solar_system_source" => "99999999",
        "solar_system_target" => "99999998"
      }

      conn = get(conn, ~p"/api/maps/#{map.slug}/connections", params)

      # Should return empty result or error
      case conn.status do
        200 ->
          response = json_response(conn, 200)
          # Should return empty data or null
          case response["data"] do
            nil -> :ok
            [] -> :ok
            %{} -> :ok
            _ -> flunk("Expected empty or null data for non-existent systems")
          end

        404 ->
          :ok

        _ ->
          assert conn.status in [200, 404]
      end
    end
  end
end
