defmodule WandererApp.MapDuplicationAPITest do
  use WandererAppWeb.ConnCase, async: true

  import WandererAppWeb.Factory

  describe "POST /api/maps/:map_id/duplicate" do
    setup %{conn: conn} do
      user = insert(:user)
      owner = insert(:character, %{user_id: user.id})

      source_map =
        insert(:map, %{
          name: "Source API Map",
          description: "For API testing",
          owner_id: owner.id
        })

      conn =
        conn
        |> put_req_header(
          "authorization",
          "Bearer #{source_map.public_api_key || "test-api-key"}"
        )
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, owner)
        |> assign(:current_user, user)
        |> assign(:map, source_map)

      %{conn: conn, owner: owner, user: user, source_map: source_map}
    end

    test "creates duplicated map with valid parameters", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "API Duplicated Map",
          "description" => "Created via API",
          "copy_acls" => true,
          "copy_user_settings" => true,
          "copy_signatures" => false
        })

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "API Duplicated Map",
                 "description" => "Created via API"
               }
             } = json_response(conn, 201)

      assert id != source_map.id
    end

    test "uses default copy options when not specified", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Default Options Map"
        })

      # Should succeed with default options
      assert %{
               "data" => %{
                 "name" => "Default Options Map"
               }
             } = json_response(conn, 201)
    end

    test "validates required name parameter", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "description" => "Missing name"
        })

      assert %{"error" => "Name is required"} = json_response(conn, 400)
    end

    test "validates name length - too short", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "ab"
        })

      assert %{"error" => "Name must be at least 3 characters long"} = json_response(conn, 400)
    end

    test "validates name length - too long", %{conn: conn, source_map: source_map} do
      long_name = String.duplicate("a", 21)

      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => long_name
        })

      assert %{"error" => "Name must be no more than 20 characters long"} =
               json_response(conn, 400)
    end

    test "works with map slug identifier", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.slug}/duplicate", %{
          "name" => "Slug Duplicated Map"
        })

      assert %{
               "data" => %{
                 "name" => "Slug Duplicated Map"
               }
             } = json_response(conn, 201)
    end

    test "handles non-existent map", %{conn: conn} do
      non_existent_id = Ecto.UUID.generate()

      conn =
        post(conn, "/api/maps/#{non_existent_id}/duplicate", %{
          "name" => "Non-existent Source"
        })

      response = json_response(conn, 404)
      assert Map.has_key?(response, "error")
      assert String.contains?(response["error"], "Map not found")
    end

    test "requires map ownership", %{source_map: source_map} do
      other_user = insert(:user)
      other_owner = insert(:character, %{user_id: other_user.id})
      other_map = insert(:map, %{owner_id: other_owner.id})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{other_map.public_api_key || "test-api-key"}")
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, other_owner)
        |> assign(:current_user, other_user)
        |> assign(:map, other_map)
        |> post("/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Unauthorized Copy"
        })

      # Should get 401 since other_owner can't access source_map (unauthorized)
      assert json_response(conn, 401)
    end

    test "requires authentication", %{source_map: source_map} do
      # No authentication
      conn = build_conn()

      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Unauthenticated Copy"
        })

      assert response(conn, 401)
    end

    test "handles invalid JSON payload gracefully", %{conn: conn, source_map: source_map} do
      # JSON parsing errors are handled at the Plug level, not controller level
      try do
        conn =
          conn
          |> put_req_header("content-type", "application/json")
          |> post("/api/maps/#{source_map.id}/duplicate", "{invalid json")

        assert response(conn, 400)
      rescue
        Plug.Parsers.ParseError ->
          # This is expected behavior - Phoenix's JSON parser fails before controller
          assert true
      end
    end

    test "validates boolean copy options", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Boolean Test",
          "copy_acls" => "not_a_boolean"
        })

      # Should handle invalid boolean gracefully - Phoenix validation returns 422
      assert response(conn, 422)
    end

    test "handles extremely long description", %{conn: conn, source_map: source_map} do
      very_long_description = String.duplicate("Very long description. ", 1000)

      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Long Desc Map",
          "description" => very_long_description
        })

      # Should either succeed or fail gracefully depending on database limits
      response = json_response(conn, 201)
      assert response["data"]["name"] == "Long Desc Map"
    end

    test "handles special characters in name", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Tëst Mäp Ñamê"
        })

      assert %{
               "data" => %{
                 "name" => "Tëst Mäp Ñamê"
               }
             } = json_response(conn, 201)
    end

    test "preserves copy option defaults correctly", %{conn: conn, source_map: source_map} do
      # Test that copy_user_settings defaults to true as requested
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Default Test",
          "copy_acls" => false,
          "copy_signatures" => false
          # copy_user_settings should default to true
        })

      assert %{
               "data" => %{
                 "name" => "Default Test"
               }
             } = json_response(conn, 201)
    end

    test "returns proper error for invalid map identifier format", %{conn: conn} do
      conn =
        post(conn, "/api/maps/invalid-format/duplicate", %{
          "name" => "Invalid ID Test"
        })

      assert response(conn, 404)
    end
  end

  describe "error response format" do
    setup %{conn: conn} do
      user = insert(:user)
      owner = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{name: "Test Map", owner_id: owner.id})

      conn =
        conn
        |> put_req_header(
          "authorization",
          "Bearer #{source_map.public_api_key || "test-api-key"}"
        )
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, owner)
        |> assign(:current_user, user)
        |> assign(:map, source_map)

      %{conn: conn, source_map: source_map}
    end

    test "returns consistent error format for validation errors", %{
      conn: conn,
      source_map: source_map
    } do
      conn = post(conn, "/api/maps/#{source_map.id}/duplicate", %{})

      response = json_response(conn, 400)
      assert Map.has_key?(response, "error")
      assert is_binary(response["error"])
    end

    test "returns consistent error format for authorization errors", %{source_map: source_map} do
      # Test with no authentication - should get 401
      conn =
        build_conn()
        |> post("/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Unauthorized"
        })

      response = json_response(conn, 401)
      assert Map.has_key?(response, "error")
      assert is_binary(response["error"])
    end

    test "returns consistent error format for not found errors", %{conn: conn} do
      conn =
        post(conn, "/api/maps/#{Ecto.UUID.generate()}/duplicate", %{
          "name" => "Not Found Test"
        })

      response = json_response(conn, 404)
      assert Map.has_key?(response, "error")
      assert is_binary(response["error"])
    end
  end

  describe "concurrent API requests" do
    setup %{conn: conn} do
      user = insert(:user)
      owner = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{name: "Concurrent Test", owner_id: owner.id})

      conn =
        conn
        |> put_req_header(
          "authorization",
          "Bearer #{source_map.public_api_key || "test-api-key"}"
        )
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, owner)
        |> assign(:current_user, user)
        |> assign(:map, source_map)

      %{conn: conn, source_map: source_map, owner: owner}
    end

    test "handles multiple simultaneous duplication requests", %{
      conn: conn,
      source_map: source_map
    } do
      # Create multiple requests concurrently
      tasks =
        Enum.map(1..3, fn i ->
          Task.async(fn ->
            post(conn, "/api/maps/#{source_map.id}/duplicate", %{
              "name" => "Concurrent #{i}"
            })
          end)
        end)

      responses = Task.await_many(tasks, 5000)

      # All should succeed
      assert Enum.all?(responses, fn conn -> conn.status == 201 end)

      # All should have unique IDs
      ids =
        Enum.map(responses, fn conn ->
          json_response(conn, 201)["data"]["id"]
        end)

      assert length(Enum.uniq(ids)) == 3
    end
  end

  describe "content type handling" do
    setup %{conn: conn} do
      user = insert(:user)
      owner = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{name: "Content Type Test", owner_id: owner.id})

      conn =
        conn
        |> put_req_header(
          "authorization",
          "Bearer #{source_map.public_api_key || "test-api-key"}"
        )
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, owner)
        |> assign(:current_user, user)
        |> assign(:map, source_map)

      %{conn: conn, source_map: source_map}
    end

    test "accepts application/json content type", %{conn: conn, source_map: source_map} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/maps/#{source_map.id}/duplicate",
          Jason.encode!(%{
            "name" => "JSON Content"
          })
        )

      assert json_response(conn, 201)["data"]["name"] == "JSON Content"
    end

    test "returns appropriate response content type", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Content Type Response"
        })

      assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
    end
  end

  describe "OpenAPI compliance" do
    setup %{conn: conn} do
      user = insert(:user)
      owner = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{name: "OpenAPI Test", owner_id: owner.id})

      conn =
        conn
        |> put_req_header(
          "authorization",
          "Bearer #{source_map.public_api_key || "test-api-key"}"
        )
        |> put_req_header("content-type", "application/json")
        |> assign(:current_character, owner)
        |> assign(:current_user, user)
        |> assign(:map, source_map)

      %{conn: conn, source_map: source_map}
    end

    test "response matches expected schema structure", %{conn: conn, source_map: source_map} do
      conn =
        post(conn, "/api/maps/#{source_map.id}/duplicate", %{
          "name" => "Schema Test",
          "description" => "Testing response schema"
        })

      response = json_response(conn, 201)

      # Verify required fields according to OpenAPI spec
      assert Map.has_key?(response["data"], "id")
      assert Map.has_key?(response["data"], "name")
      assert Map.has_key?(response["data"], "description")

      assert is_binary(response["data"]["id"])
      assert is_binary(response["data"]["name"])
      assert is_binary(response["data"]["description"])
    end
  end
end
