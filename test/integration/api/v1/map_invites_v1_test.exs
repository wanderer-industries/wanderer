defmodule WandererAppWeb.Api.V1.MapInvitesV1Test do
  use WandererAppWeb.ApiCase

  alias WandererApp.Api.MapInvite

  describe "POST /api/v1/map_invites (create)" do
    setup :setup_map_authentication_without_server

    test "creates invite with auto-generated code", %{conn: conn, map: map} do
      user = WandererAppWeb.Factory.insert(:user)

      invite_params = %{
        data: %{
          type: "map_invites",
          attributes: %{
            # map_id removed - auto-injected from token
            max_uses: 5,
            expires_at:
              DateTime.utc_now() |> DateTime.add(7 * 24 * 3600, :second) |> DateTime.to_iso8601()
          }
        }
      }

      # Create invite via API
      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_invites", invite_params)

      # Should return 201 Created
      response = json_response(conn, 201)

      assert response["data"]["type"] == "map_invites"
      assert response["data"]["attributes"]["code"]
      assert String.length(response["data"]["attributes"]["code"]) > 10
      assert response["data"]["attributes"]["max_uses"] == 5
      assert response["data"]["attributes"]["use_count"] == 0
    end

    test "creates invite with email restriction", %{conn: conn, map: map} do
      invite_params = %{
        data: %{
          type: "map_invites",
          attributes: %{
            # map_id removed - auto-injected from token
            email: "test@example.com",
            max_uses: 1
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_invites", invite_params)

      response = json_response(conn, 201)
      assert response["data"]["attributes"]["email"] == "test@example.com"
    end

    test "sets default max_uses to 1", %{conn: conn, map: map} do
      invite_params = %{
        data: %{
          type: "map_invites",
          attributes:
            %{
              # map_id removed - auto-injected from token
            }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_invites", invite_params)

      response = json_response(conn, 201)
      assert response["data"]["attributes"]["max_uses"] == 1
      assert response["data"]["attributes"]["use_count"] == 0
    end
  end

  describe "GET /api/v1/map_invites (index)" do
    setup :setup_map_authentication_without_server

    test "lists invites for accessible maps", %{conn: conn, map: map} do
      # Create some invites for this map
      invite1 = create_invite(%{map_id: map.id})
      invite2 = create_invite(%{map_id: map.id})

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_invites")

      response = json_response(conn, 200)

      # Should return at least the invites we created
      invite_ids = Enum.map(response["data"], & &1["id"])
      assert invite1.id in invite_ids
      assert invite2.id in invite_ids
    end

    test "supports filtering by map_id", %{conn: conn, map: map} do
      map2 = WandererAppWeb.Factory.insert(:map)

      invite1 = create_invite(%{map_id: map.id})
      invite2 = create_invite(%{map_id: map2.id})

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_invites?filter[map_id]=#{map.id}")

      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == invite1.id
    end
  end

  describe "GET /api/v1/map_invites/:id (show)" do
    setup :setup_map_authentication_without_server

    test "returns specific invite", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id})

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_invites/#{invite.id}")

      response = json_response(conn, 200)
      assert response["data"]["id"] == invite.id
      assert response["data"]["attributes"]["code"] == invite.code
    end

    test "returns 404 for non-existent invite", %{conn: conn} do
      fake_id = Ash.UUID.generate()

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_invites/#{fake_id}")

      assert json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/map_invites/:id/revoke (revoke)" do
    setup :setup_map_authentication_without_server

    test "revokes an invite", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id, code: "revoke-me"})

      refute invite.revoked_at

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> patch("/api/v1/map_invites/#{invite.id}/revoke", %{data: %{}})

      response = json_response(conn, 200)
      assert response["data"]["attributes"]["revoked_at"]

      # Verify in database
      {:ok, updated_invite} = Ash.get(MapInvite, invite.id)
      assert updated_invite.revoked_at
    end

    test "revoked invite shows revoked_at timestamp", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id})

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> patch("/api/v1/map_invites/#{invite.id}/revoke", %{data: %{}})

      response = json_response(conn, 200)
      revoked_at = response["data"]["attributes"]["revoked_at"]

      assert revoked_at
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(revoked_at)
    end
  end

  describe "DELETE /api/v1/map_invites/:id (destroy)" do
    setup :setup_map_authentication_without_server

    test "deletes an invite", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id})

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/v1/map_invites/#{invite.id}")

      # AshJsonApi returns 200 with the deleted resource (valid per JSON:API spec)
      response = json_response(conn, 200)
      assert response["data"]["id"] == invite.id

      # Verify it's deleted
      assert {:error, _} = Ash.get(MapInvite, invite.id)
    end

    test "returns 404 for already deleted invite", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id})

      # Delete it
      :ok = Ash.destroy(invite)

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> delete("/api/v1/map_invites/#{invite.id}")

      assert json_response(conn, 404)
    end
  end

  describe "Invite code generation" do
    setup :setup_map_authentication_without_server

    test "generates unique codes for each invite", %{conn: conn, map: map} do
      codes =
        for _ <- 1..5 do
          invite_params = %{
            data: %{
              type: "map_invites",
              attributes: %{map_id: map.id}
            }
          }

          response =
            conn
            |> put_req_header("content-type", "application/vnd.api+json")
            |> put_req_header("accept", "application/vnd.api+json")
            |> post("/api/v1/map_invites", invite_params)
            |> json_response(201)

          response["data"]["attributes"]["code"]
        end

      # All codes should be unique
      assert length(Enum.uniq(codes)) == 5

      # All codes should be non-empty strings
      assert Enum.all?(codes, &(is_binary(&1) and String.length(&1) > 0))
    end
  end

  describe "Invite expiration" do
    setup :setup_map_authentication_without_server

    test "accepts expires_at timestamp", %{conn: conn, map: map} do
      future_time = DateTime.utc_now() |> DateTime.add(3600, :second)

      invite_params = %{
        data: %{
          type: "map_invites",
          attributes: %{
            map_id: map.id,
            expires_at: DateTime.to_iso8601(future_time)
          }
        }
      }

      response =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_invites", invite_params)
        |> json_response(201)

      assert response["data"]["attributes"]["expires_at"]
    end

    test "invite without expiration has null expires_at", %{conn: conn, map: map} do
      invite_params = %{
        data: %{
          type: "map_invites",
          attributes: %{map_id: map.id}
        }
      }

      response =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> put_req_header("accept", "application/vnd.api+json")
        |> post("/api/v1/map_invites", invite_params)
        |> json_response(201)

      assert response["data"]["attributes"]["expires_at"] == nil
    end
  end

  describe "JSON:API compliance" do
    setup :setup_map_authentication_without_server

    test "returns correct content-type header", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id})

      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_invites/#{invite.id}")

      assert Enum.any?(conn.resp_headers, fn {key, value} ->
               key == "content-type" and String.contains?(value, "application/vnd.api+json")
             end)
    end

    test "includes type in response", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id})

      response =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_invites/#{invite.id}")
        |> json_response(200)

      assert response["data"]["type"] == "map_invites"
    end

    test "includes id in response", %{conn: conn, map: map} do
      invite = create_invite(%{map_id: map.id})

      response =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/v1/map_invites/#{invite.id}")
        |> json_response(200)

      assert response["data"]["id"] == invite.id
    end
  end

  # Helper function to create invites directly using v1 create action
  defp create_invite(attrs) do
    default_attrs = %{
      max_uses: 1
    }

    # Don't include code in default attrs - it's auto-generated
    attrs = Map.merge(default_attrs, attrs) |> Map.delete(:code)

    # Use the create action which accepts v1 fields
    case Ash.create(MapInvite, attrs, action: :create) do
      {:ok, invite} -> invite
      {:error, reason} -> raise "Failed to create invite: #{inspect(reason)}"
    end
  end
end
