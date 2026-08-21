defmodule WandererAppWeb.Api.MapUserRoutesControllerTest do
  use WandererAppWeb.ApiCase, async: false

  alias WandererAppWeb.Factory

  describe "GET /api/maps/:map_identifier/user-routes" do
    setup do
      # Routes.find/5 ultimately calls WandererApp.Esi.get_routes_custom/3, which
      # otherwise POSTs to an unconfigured/live external routing service in test
      # env. Stub it so the destination-based assertions below are backed by a
      # deterministic response instead of network availability.
      Mox.stub(WandererApp.Esi.Mock, :get_routes_custom, fn hubs, origin, _params ->
        {:ok,
         Enum.map(hubs, fn hub ->
           %{"origin" => origin, "destination" => hub, "systems" => [], "success" => true}
         end)}
      end)

      :ok
    end

    test "returns 400 when system_id is missing", %{conn: conn} do
      map = Factory.insert(:map)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/user-routes")

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 (not 500) when system_id is not an integer", %{conn: conn} do
      map = Factory.insert(:map)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/user-routes?system_id=abc")

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when avoid contains a non-integer", %{conn: conn} do
      map = Factory.insert(:map)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/user-routes?system_id=30000142&avoid=30000001,not-a-number")

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "avoid param is parsed to integers and forwarded to the routing service", %{conn: conn} do
      user = Factory.insert(:user)
      owner = Factory.insert(:character, %{user_id: user.id})
      map = Factory.insert(:map, %{owner_id: owner.id})

      {:ok, _} = WandererApp.MapUserSettingsRepo.update_hubs(map.id, user.id, ["30000142"])

      test_pid = self()

      Mox.stub(WandererApp.Esi.Mock, :get_routes_custom, fn hubs, origin, params ->
        send(test_pid, {:avoid_param, params.avoid})

        {:ok,
         Enum.map(hubs, fn hub ->
           %{"origin" => origin, "destination" => hub, "systems" => [], "success" => true}
         end)}
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(
          ~p"/api/maps/#{map.slug}/user-routes?system_id=30002187&avoid=30000001,30000002"
        )

      assert %{"data" => %{"routes" => [_route]}} = json_response(conn, 200)
      assert_received {:avoid_param, avoid}
      assert 30_000_001 in avoid
      assert 30_000_002 in avoid
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
