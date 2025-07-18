defmodule WandererAppWeb.MapDuplicationAPIControllerSuccessTest do
  use WandererAppWeb.ConnCase, async: true

  import Mox
  import WandererAppWeb.Factory
  import Ash.Query

  setup :verify_on_exit!

  describe "successful map duplication operations" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      source_map =
        insert(:map, %{
          owner_id: character.id,
          name: "Original Test Map",
          description: "A detailed exploration map with systems and connections"
        })

      # Create some systems and connections for the source map
      system1 =
        insert(:map_system, %{
          map_id: source_map.id,
          solar_system_id: 30_000_142,
          name: "Jita",
          position_x: 100,
          position_y: 200,
          status: 1
        })

      system2 =
        insert(:map_system, %{
          map_id: source_map.id,
          solar_system_id: 30_000_144,
          name: "Amarr",
          position_x: 300,
          position_y: 400,
          status: 0
        })

      _connection =
        insert(:map_connection, %{
          map_id: source_map.id,
          solar_system_source: system1.solar_system_id,
          solar_system_target: system2.solar_system_id,
          type: 1
        })

      # Create some signatures
      _signature =
        insert(:map_system_signature, %{
          system_id: system1.id,
          eve_id: "ABC-123",
          name: "Test Wormhole",
          type: "wormhole"
        })

      conn =
        build_conn()
        |> put_req_header(
          "authorization",
          "Bearer #{source_map.public_api_key || "test-api-key"}"
        )
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> assign(:map, source_map)

      %{
        conn: conn,
        user: user,
        character: character,
        source_map: source_map,
        system1: system1,
        system2: system2
      }
    end

    test "successfully duplicates a map with all systems and connections", %{
      conn: conn,
      source_map: source_map
    } do
      duplication_params = %{
        "name" => "Duplicated Map",
        "description" => "A perfect copy of the original exploration map",
        "copy_acls" => true,
        "copy_user_settings" => true,
        "copy_signatures" => false
      }

      conn = post(conn, ~p"/api/maps/#{source_map.slug}/duplicate", duplication_params)

      assert %{
               "data" => %{
                 "id" => new_id,
                 "name" => "Duplicated Map",
                 "description" => "A perfect copy of the original exploration map"
               }
             } = json_response(conn, 201)

      assert new_id != source_map.id

      # Verify the duplicated map exists
      duplicated_map = WandererApp.Api.Map.by_id!(new_id)
      assert duplicated_map.name == "Duplicated Map"
    end

    test "successfully duplicates with minimal parameters using defaults", %{
      conn: conn,
      source_map: source_map
    } do
      minimal_params = %{
        "name" => "Simple Copy"
      }

      conn = post(conn, ~p"/api/maps/#{source_map.id}/duplicate", minimal_params)

      assert %{
               "data" => %{
                 "id" => new_id,
                 "name" => "Simple Copy"
               }
             } = json_response(conn, 201)

      assert new_id != source_map.id

      # Verify the duplicated map exists
      duplicated_map = WandererApp.Api.Map.by_id!(new_id)
      assert duplicated_map.name == "Simple Copy"
    end

    test "successfully duplicates using map slug instead of ID", %{
      conn: conn,
      source_map: source_map
    } do
      params = %{
        "name" => "Slug-based Copy",
        "description" => "Duplicated using slug identifier"
      }

      conn = post(conn, ~p"/api/maps/#{source_map.slug}/duplicate", params)

      assert %{
               "data" => %{
                 "id" => new_id,
                 "name" => "Slug-based Copy",
                 "description" => "Duplicated using slug identifier"
               }
             } = json_response(conn, 201)

      assert new_id != source_map.id
    end

    test "successfully duplicates with selective copying options", %{
      conn: conn,
      source_map: source_map
    } do
      duplication_params = %{
        "name" => "Selective Copy",
        "copy_acls" => false,
        "copy_user_settings" => false,
        "copy_signatures" => true
      }

      conn = post(conn, ~p"/api/maps/#{source_map.slug}/duplicate", duplication_params)

      assert %{
               "data" => %{
                 "id" => new_id,
                 "name" => "Selective Copy"
               }
             } = json_response(conn, 201)

      assert new_id != source_map.id
    end

    test "duplicated map contains copied systems", %{conn: conn, source_map: source_map} do
      duplication_params = %{
        "name" => "System Copy Test",
        "copy_signatures" => false
      }

      conn = post(conn, ~p"/api/maps/#{source_map.slug}/duplicate", duplication_params)

      assert %{
               "data" => %{
                 "id" => new_map_id
               }
             } = json_response(conn, 201)

      # Check that the new map has systems
      {:ok, new_systems} =
        WandererApp.Api.MapSystem
        |> Ash.Query.filter(map_id == ^new_map_id)
        |> Ash.read()

      assert length(new_systems) >= 2

      # Find the copied Jita system
      jita_system = Enum.find(new_systems, &(&1.name == "Jita"))
      assert jita_system != nil
      assert jita_system.solar_system_id == 30_000_142
      assert jita_system.position_x == 100
      assert jita_system.status == 1

      # Find the copied Amarr system
      amarr_system = Enum.find(new_systems, &(&1.name == "Amarr"))
      assert amarr_system != nil
      assert amarr_system.solar_system_id == 30_000_144
      assert amarr_system.position_x == 300.0
      assert amarr_system.status == 0
    end

    test "duplicated map contains copied connections", %{conn: conn, source_map: source_map} do
      duplication_params = %{
        "name" => "Connection Copy Test"
      }

      conn = post(conn, ~p"/api/maps/#{source_map.slug}/duplicate", duplication_params)

      assert %{
               "data" => %{
                 "id" => new_map_id
               }
             } = json_response(conn, 201)

      # Check that the new map has connections
      {:ok, new_connections} =
        WandererApp.Api.MapConnection
        |> Ash.Query.filter(map_id == ^new_map_id)
        |> Ash.read()

      assert length(new_connections) >= 1

      # Find the copied stargate connection
      stargate_connection = Enum.find(new_connections, &(&1.type == 1))
      assert stargate_connection != nil
      assert stargate_connection.solar_system_source == 30_000_142
      assert stargate_connection.solar_system_target == 30_000_144
    end
  end

  describe "error handling for map duplication" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-api-key")
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, character)
        |> assign(:current_user, user)

      %{conn: conn, user: user, character: character, map: map}
    end

    test "fails with missing required name parameter", %{
      conn: conn,
      user: user,
      character: character
    } do
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      invalid_params = %{
        "description" => "Missing name field"
      }

      authenticated_conn =
        conn
        |> put_req_header("authorization", "Bearer #{source_map.public_api_key}")
        |> assign(:map, source_map)

      conn = post(authenticated_conn, ~p"/api/maps/#{source_map.id}/duplicate", invalid_params)

      assert %{
               "error" => error_message
             } = json_response(conn, 400)

      assert String.contains?(error_message, "Name is required")
    end

    test "fails when source map does not exist", %{conn: conn} do
      non_existent_id = Ecto.UUID.generate()

      params = %{
        "name" => "Copy of Non-existent Map"
      }

      conn = post(conn, ~p"/api/maps/#{non_existent_id}/duplicate", params)

      assert json_response(conn, 404)
    end

    test "fails when source map slug does not exist", %{conn: conn} do
      non_existent_slug = "non-existent-map-slug"

      params = %{
        "name" => "Copy of Non-existent Map"
      }

      conn = post(conn, ~p"/api/maps/#{non_existent_slug}/duplicate", params)

      assert json_response(conn, 404)
    end

    test "fails with invalid boolean parameters", %{conn: conn, user: user, character: character} do
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      invalid_params = %{
        "name" => "Invalid Boolean Test",
        "copy_acls" => "not-a-boolean",
        "copy_user_settings" => "invalid",
        "copy_signatures" => "wrong"
      }

      authenticated_conn =
        conn
        |> put_req_header("authorization", "Bearer #{source_map.public_api_key}")
        |> assign(:map, source_map)

      conn = post(authenticated_conn, ~p"/api/maps/#{source_map.id}/duplicate", invalid_params)

      # Should return an error response for invalid boolean values
      assert conn.status in [400, 422]
    end

    test "handles very long map names", %{conn: conn, user: user, character: character} do
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      # Very long name
      long_name = String.duplicate("a", 300)

      params = %{
        "name" => long_name
      }

      authenticated_conn =
        conn
        |> put_req_header("authorization", "Bearer #{source_map.public_api_key}")
        |> assign(:map, source_map)

      conn = post(authenticated_conn, ~p"/api/maps/#{source_map.id}/duplicate", params)

      # Should return an error response for name too long
      assert conn.status in [400, 422]
    end
  end

  describe "authorization for map duplication" do
    test "fails when user is not authenticated" do
      source_map = insert(:map, %{})

      params = %{
        "name" => "Unauthorized Copy"
      }

      conn = build_conn()
      conn = post(conn, ~p"/api/maps/#{source_map.id}/duplicate", params)

      # Should require authentication
      assert conn.status in [401, 403]
    end

    test "succeeds when user has access to source map" do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      params = %{
        "name" => "Authorized Copy"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{source_map.public_api_key}")
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> assign(:map, source_map)
        |> post(~p"/api/maps/#{source_map.slug}/duplicate", params)

      assert %{
               "data" => %{
                 "name" => "Authorized Copy"
               }
             } = json_response(conn, 201)
    end
  end
end
