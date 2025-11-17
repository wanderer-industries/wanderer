defmodule WandererAppWeb.Api.V1.MapPingsV1Test do
  use WandererAppWeb.ApiCase

  alias WandererApp.Api.{Map, MapPing}

  describe "POST /api/v1/map_pings (create)" do
    setup :setup_map_authentication_without_server

    test "creates ping with valid data", %{conn: conn, map: map, character: character} do
      # Get a system from the map
      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      ping_params = %{
        data: %{
          type: "map_pings",
          attributes: %{
            # map_id removed - auto-injected from token
            system_id: map_system.id,
            type: "rally_point",
            message: "Rally here!",
            expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_pings", ping_params)

      response = json_response(conn, 201)
      assert response["data"]["type"] == "map_pings"
      assert response["data"]["attributes"]["type"] == "rally_point"
      assert response["data"]["attributes"]["message"] == "Rally here!"
      assert response["data"]["attributes"]["acknowledged"] == false
      refute is_nil(response["data"]["attributes"]["expires_at"])
    end

    test "creates ping with minimal data (no message, no expiration)", %{
      conn: conn,
      map: map,
      character: character
    } do
      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      ping_params = %{
        data: %{
          type: "map_pings",
          attributes: %{
            # map_id removed - auto-injected from token
            system_id: map_system.id,
            type: "info"
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_pings", ping_params)

      response = json_response(conn, 201)
      assert response["data"]["attributes"]["type"] == "info"
      assert is_nil(response["data"]["attributes"]["message"])
      assert is_nil(response["data"]["attributes"]["expires_at"])
    end

    test "validates ping type", %{conn: conn, map: map, character: character} do
      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      ping_params = %{
        data: %{
          type: "map_pings",
          attributes: %{
            # map_id removed - auto-injected from token
            system_id: map_system.id,
            type: "invalid_type"
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_pings", ping_params)

      response = json_response(conn, 400)
      assert response["errors"]
    end

    test "requires authentication", %{map: map, character: character} do
      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      conn = build_conn()

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_pings", %{
          data: %{
            type: "map_pings",
            attributes: %{
              # map_id removed - auth required
              system_id: map_system.id,
              type: "info"
            }
          }
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/map_pings (index)" do
    setup :setup_map_authentication_without_server

    setup context do
      map = context[:map]
      # Use the character from context (the map owner with proper user linkage)
      character = context[:character]

      # Create test pings
      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      ping1 =
        create_ping(%{
          map_id: map.id,
          system_id: map_system.id,
          character_id: character.id,
          type: :rally_point
        })

      ping2 =
        create_ping(%{
          map_id: map.id,
          system_id: map_system.id,
          character_id: character.id,
          type: :danger
        })

      # Create ping on different map
      other_map = WandererAppWeb.Factory.insert(:map)
      other_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: other_map.id})
      other_character = WandererAppWeb.Factory.insert(:character)

      other_ping =
        create_ping(%{
          map_id: other_map.id,
          system_id: other_system.id,
          character_id: other_character.id,
          type: :info
        })

      {:ok, %{map_system: map_system, ping1: ping1, ping2: ping2, other_ping: other_ping}}
    end

    test "lists pings for user's accessible maps", %{
      conn: conn,
      map: map,
      ping1: ping1,
      ping2: ping2,
      other_ping: other_ping
    } do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_pings")

      response = json_response(conn, 200)
      ping_ids = Enum.map(response["data"], & &1["id"])

      # Should include pings from user's map
      assert ping1.id in ping_ids
      assert ping2.id in ping_ids

      # Should NOT include pings from other maps
      refute other_ping.id in ping_ids
    end

    test "supports filtering by map_id", %{conn: conn, map: map, ping1: ping1, ping2: ping2} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_pings")

      response = json_response(conn, 200)
      assert length(response["data"]) == 2

      ping_ids = Enum.map(response["data"], & &1["id"])
      assert ping1.id in ping_ids
      assert ping2.id in ping_ids
    end

    test "supports filtering by type", %{conn: conn, map: map, ping1: ping1} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_pings?filter[type]=rally_point")

      response = json_response(conn, 200)
      assert length(response["data"]) >= 1

      ping_ids = Enum.map(response["data"], & &1["id"])
      assert ping1.id in ping_ids
    end

    test "supports includes for map and system", %{conn: conn, map: map} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_pings?include=map,system")

      response = json_response(conn, 200)
      assert response["included"]

      # Verify included resources (character not available as it's not exposed via JSON:API)
      included_types =
        Enum.map(response["included"], & &1["type"]) |> Enum.uniq() |> Enum.reject(&is_nil/1)

      assert "maps" in included_types
      assert "map_systems" in included_types
    end
  end

  describe "GET /api/v1/map_pings/:id (show)" do
    setup :setup_map_authentication_without_server

    setup context do
      map = context[:map]

      # Create a character for the ping
      character = WandererAppWeb.Factory.insert(:character)

      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      ping =
        create_ping(%{
          map_id: map.id,
          system_id: map_system.id,
          character_id: character.id,
          type: :rally_point,
          message: "Test ping"
        })

      {:ok, %{ping: ping}}
    end

    test "returns single ping", %{conn: conn, map: map, ping: ping} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_pings/#{ping.id}")

      response = json_response(conn, 200)
      assert response["data"]["type"] == "map_pings"
      assert response["data"]["id"] == ping.id
      assert response["data"]["attributes"]["type"] == "rally_point"
      assert response["data"]["attributes"]["message"] == "Test ping"
    end

    test "returns 404 for non-existent ping", %{conn: conn, map: map} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_pings/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/map_pings/:id/acknowledge" do
    setup :setup_map_authentication_without_server

    setup context do
      map = context[:map]
      # Use the character from context (the map owner with proper user linkage)
      character = context[:character]

      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      ping =
        create_ping(%{
          map_id: map.id,
          system_id: map_system.id,
          character_id: character.id
        })

      {:ok, %{ping: ping}}
    end

    test "acknowledges ping", %{conn: conn, map: map, ping: ping} do
      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> patch("/api/v1/map_pings/#{ping.id}/acknowledge", %{data: %{}})

      response = json_response(conn, 200)
      assert response["data"]["attributes"]["acknowledged"] == true
    end

    test "acknowledging already acknowledged ping is idempotent", %{
      conn: conn,
      map: map,
      ping: ping
    } do
      # Acknowledge first time
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> patch("/api/v1/map_pings/#{ping.id}/acknowledge", %{data: %{}})

      # Acknowledge again
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> patch("/api/v1/map_pings/#{ping.id}/acknowledge", %{data: %{}})

      response = json_response(conn, 200)
      assert response["data"]["attributes"]["acknowledged"] == true
    end
  end

  describe "DELETE /api/v1/map_pings/:id (destroy)" do
    setup :setup_map_authentication_without_server

    setup context do
      map = context[:map]
      # Use the character from context (the map owner with proper user linkage)
      character = context[:character]

      map_system = WandererAppWeb.Factory.insert(:map_system, %{map_id: map.id})

      ping =
        create_ping(%{
          map_id: map.id,
          system_id: map_system.id,
          character_id: character.id
        })

      {:ok, %{ping: ping}}
    end

    test "deletes ping", %{conn: conn, map: map, ping: ping} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/v1/map_pings/#{ping.id}")

      # AshJsonApi returns 200 with the deleted resource (not 204 No Content)
      response = json_response(conn, 200)
      assert response["data"]["id"] == ping.id

      # Verify deleted - create new conn with auth
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_pings/#{ping.id}")

      assert json_response(conn, 404)
    end
  end

  # Helper function to create pings for testing
  defp create_ping(%{map_id: map_id} = attrs) do
    default_attrs = %{
      type: :info
    }

    # Remove map_id from attrs as it's injected from context
    # Note: Use Elixir.Map to avoid conflict with WandererApp.Api.Map alias
    # Merge order: defaults first, then attrs override
    attrs =
      default_attrs
      |> Elixir.Map.merge(attrs)
      |> Elixir.Map.delete(:map_id)

    # Load map to provide context for InjectMapFromActor
    {:ok, map} = Ash.get(Map, map_id)

    # Create ping with map in context
    case Ash.create(MapPing, attrs, action: :new, context: %{map: map}) do
      {:ok, ping} -> ping
      {:error, reason} -> raise "Failed to create ping: #{inspect(reason)}"
    end
  end
end
