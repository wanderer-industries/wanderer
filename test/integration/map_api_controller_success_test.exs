defmodule WandererAppWeb.MapAPIControllerSuccessTest do
  use WandererAppWeb.ConnCase, async: true

  import Mox
  import WandererAppWeb.Factory

  describe "map duplication API operations" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      # Create a map with test data
      source_map =
        insert(:map, %{
          owner_id: character.id,
          name: "Source Map",
          description: "Original map for duplication testing"
        })

      # Set up the connection with proper authentication for map API
      conn =
        build_conn()
        |> put_req_header(
          "authorization",
          "Bearer #{source_map.public_api_key || "test-api-key"}"
        )
        |> assign(:current_character, character)
        |> assign(:current_user, user)

      %{conn: conn, user: user, character: character, source_map: source_map}
    end

    test "DUPLICATE: successfully duplicates a map with all options", %{
      conn: conn,
      source_map: source_map
    } do
      duplication_params = %{
        "name" => "Duplicated Map",
        "description" => "A copy of the original map",
        "copy_acls" => true,
        "copy_user_settings" => true,
        "copy_signatures" => false
      }

      conn = post(conn, ~p"/api/maps/#{source_map.id}/duplicate", duplication_params)

      assert %{
               "data" => %{
                 "id" => _new_id,
                 "name" => "Duplicated Map",
                 "description" => "A copy of the original map"
               }
             } = json_response(conn, 201)
    end

    test "DUPLICATE: successfully duplicates using map slug", %{
      conn: conn,
      source_map: source_map
    } do
      duplication_params = %{
        "name" => "Slug Duplicated Map"
      }

      conn = post(conn, ~p"/api/maps/#{source_map.slug}/duplicate", duplication_params)

      assert %{
               "data" => %{
                 "id" => _new_id,
                 "name" => "Slug Duplicated Map"
               }
             } = json_response(conn, 201)
    end

    test "DUPLICATE: uses default parameters when not specified", %{
      conn: conn,
      source_map: source_map
    } do
      minimal_params = %{
        "name" => "Minimal Copy"
      }

      conn = post(conn, ~p"/api/maps/#{source_map.id}/duplicate", minimal_params)

      assert %{
               "data" => %{
                 "name" => "Minimal Copy"
               }
             } = json_response(conn, 201)
    end

    test "DUPLICATE: handles selective copying options", %{conn: conn, source_map: source_map} do
      selective_params = %{
        "name" => "Selective Copy",
        "copy_acls" => false,
        "copy_user_settings" => false,
        "copy_signatures" => true
      }

      conn = post(conn, ~p"/api/maps/#{source_map.id}/duplicate", selective_params)

      assert %{
               "data" => %{
                 "name" => "Selective Copy"
               }
             } = json_response(conn, 201)
    end
  end

  describe "error handling for map duplication" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-api-key")
        |> assign(:current_character, character)
        |> assign(:current_user, user)

      %{conn: conn, user: user, character: character}
    end

    test "DUPLICATE: fails with missing required name parameter", %{conn: _conn} do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      invalid_params = %{
        "description" => "Missing required name field"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-api-key")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> post(~p"/api/maps/#{source_map.id}/duplicate", invalid_params)

      assert %{
               "error" => error
             } = json_response(conn, 400)

      assert error == "Name is required"
    end

    test "DUPLICATE: returns 404 for non-existent source map", %{conn: _conn} do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      non_existent_id = Ecto.UUID.generate()

      params = %{
        "name" => "Copy of Non-existent Map"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-api-key")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> post(~p"/api/maps/#{non_existent_id}/duplicate", params)

      assert json_response(conn, 404)
    end

    test "DUPLICATE: fails with invalid boolean parameters", %{conn: _conn} do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      invalid_params = %{
        "name" => "Invalid Boolean Test",
        "copy_acls" => "not-a-boolean",
        "copy_user_settings" => "invalid",
        "copy_signatures" => "wrong"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-api-key")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> post(~p"/api/maps/#{source_map.id}/duplicate", invalid_params)

      assert conn.status in [400, 422]
    end

    test "DUPLICATE: handles very long map names", %{conn: _conn} do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      # Very long name
      long_name = String.duplicate("a", 300)

      params = %{
        "name" => long_name
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-api-key")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> post(~p"/api/maps/#{source_map.id}/duplicate", params)

      assert conn.status in [400, 422]
    end
  end

  describe "authentication and authorization" do
    test "DUPLICATE: fails when user is not authenticated" do
      source_map = insert(:map, %{})

      params = %{
        "name" => "Unauthorized Copy"
      }

      conn = build_conn()
      conn = post(conn, ~p"/api/maps/#{source_map.id}/duplicate", params)

      # Should require authentication
      assert conn.status in [401, 403]
    end

    test "DUPLICATE: succeeds when user has proper API key" do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      source_map = insert(:map, %{owner_id: character.id, public_api_key: "test-api-key"})

      params = %{
        "name" => "Authorized Copy"
      }

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test-api-key")
        |> assign(:current_character, character)
        |> assign(:current_user, user)
        |> post(~p"/api/maps/#{source_map.id}/duplicate", params)

      assert %{
               "data" => %{
                 "name" => "Authorized Copy"
               }
             } = json_response(conn, 201)
    end
  end
end
