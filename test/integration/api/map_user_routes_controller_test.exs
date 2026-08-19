defmodule WandererAppWeb.Api.MapUserRoutesControllerTest do
  use WandererAppWeb.ApiCase, async: false

  alias WandererAppWeb.Factory

  describe "GET /api/maps/:map_identifier/user-routes" do
    test "returns 400 when system_id is missing", %{conn: conn} do
      map = Factory.insert(:map)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/user-routes")

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns an empty route list for the map owner when no hubs are configured", %{
      conn: conn
    } do
      user = Factory.insert(:user)
      owner = Factory.insert(:character, %{user_id: user.id})
      map = Factory.insert(:map, %{owner_id: owner.id})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/user-routes?system_id=30000142")

      assert %{"data" => %{"routes" => [], "systems_static_data" => []}} =
               json_response(conn, 200)
    end

    test "reflects the map owner's configured hubs", %{conn: conn} do
      user = Factory.insert(:user)
      owner = Factory.insert(:character, %{user_id: user.id})
      map = Factory.insert(:map, %{owner_id: owner.id})

      {:ok, _} = WandererApp.MapUserSettingsRepo.update_hubs(map.id, user.id, ["30000142"])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/user-routes?system_id=30002187")

      assert %{"data" => %{"routes" => [route]}} = json_response(conn, 200)
      assert route["destination"] == 30_000_142
    end

    test "resolves hubs for the EVE-token-authenticated character, not the map owner",
         %{conn: conn} do
      owner_user = Factory.insert(:user)
      owner = Factory.insert(:character, %{user_id: owner_user.id})
      map = Factory.insert(:map, %{owner_id: owner.id})

      {:ok, _} =
        WandererApp.MapUserSettingsRepo.update_hubs(map.id, owner_user.id, ["30000142"])

      viewer_user = Factory.insert(:user)
      viewer = Factory.insert(:character, %{user_id: viewer_user.id, eve_id: "555"})

      acl = Factory.insert(:access_list, %{owner_id: owner.id})
      Factory.insert(:map_access_list, %{map_id: map.id, access_list_id: acl.id})

      Factory.insert(:access_list_member, %{
        access_list_id: acl.id,
        eve_character_id: "555",
        role: "viewer"
      })

      {:ok, _} =
        WandererApp.MapUserSettingsRepo.update_hubs(map.id, viewer_user.id, ["30002187"])

      Mox.stub(Test.EveSsoMock, :verify_token, fn _ ->
        {:ok, %{character_id: 555, character_name: viewer.name, scopes: ""}}
      end)

      exchange_conn =
        post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "tok"})

      assert %{"data" => %{"token" => scoped_token}} = json_response(exchange_conn, 200)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{scoped_token}")
        |> get(~p"/api/maps/#{map.slug}/user-routes?system_id=30000144")

      assert %{"data" => %{"routes" => [route]}} = json_response(conn, 200)
      assert route["destination"] == 30_002_187
    end
  end
end
