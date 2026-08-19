defmodule WandererAppWeb.Api.EveAuthControllerTest do
  use WandererAppWeb.ApiCase, async: false

  alias WandererAppWeb.Factory

  describe "POST /api/maps/:map_identifier/auth/eve-token" do
    test "exchanges a valid EVE SSO token for a scoped token when the character owns the map",
         %{conn: conn} do
      user = Factory.insert(:user)
      character = Factory.insert(:character, %{user_id: user.id, eve_id: "123456"})
      map = Factory.insert(:map, %{owner_id: character.id})

      Mox.stub(Test.EveSsoMock, :verify_token, fn "valid-token" ->
        {:ok, %{character_id: 123_456, character_name: character.name, scopes: ""}}
      end)

      conn =
        post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "valid-token"})

      assert %{
               "data" => %{
                 "token" => token,
                 "token_type" => "Bearer",
                 "map_id" => map_id,
                 "permissions" => permissions
               }
             } = json_response(conn, 200)

      assert is_binary(token)
      assert map_id == map.id
      assert permissions["admin_map"] == true
    end

    test "returns 422 when the character has never logged into Wanderer", %{conn: conn} do
      map = Factory.insert(:map)

      Mox.stub(Test.EveSsoMock, :verify_token, fn _ ->
        {:ok, %{character_id: 999_999_999, character_name: "Unknown", scopes: ""}}
      end)

      conn = post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "tok"})
      assert %{"error" => _} = json_response(conn, 422)
    end

    test "returns 401 when the EVE SSO token is invalid", %{conn: conn} do
      map = Factory.insert(:map)

      Mox.stub(Test.EveSsoMock, :verify_token, fn _ -> {:error, :invalid_token} end)

      conn = post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "bad"})
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 403 when the tracked character has no ACL access to the map", %{conn: conn} do
      map = Factory.insert(:map)
      other_user = Factory.insert(:user)
      character = Factory.insert(:character, %{user_id: other_user.id, eve_id: "42"})

      Mox.stub(Test.EveSsoMock, :verify_token, fn _ ->
        {:ok, %{character_id: 42, character_name: character.name, scopes: ""}}
      end)

      conn = post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "tok"})
      assert %{"error" => _} = json_response(conn, 403)
    end

    test "returns 404 for an unknown map", %{conn: conn} do
      conn =
        post(conn, ~p"/api/maps/does-not-exist/auth/eve-token", %{"eve_token" => "tok"})

      assert %{"error" => _} = json_response(conn, 404)
    end

    test "the minted token authenticates subsequent map API requests", %{conn: conn} do
      user = Factory.insert(:user)
      character = Factory.insert(:character, %{user_id: user.id, eve_id: "777"})
      map = Factory.insert(:map, %{owner_id: character.id})

      Mox.stub(Test.EveSsoMock, :verify_token, fn _ ->
        {:ok, %{character_id: 777, character_name: character.name, scopes: ""}}
      end)

      exchange_conn =
        post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "tok"})

      assert %{"data" => %{"token" => scoped_token}} = json_response(exchange_conn, 200)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{scoped_token}")
        |> get(~p"/api/map/systems?slug=#{map.slug}")

      assert %{"data" => %{"connections" => [], "systems" => []}} = json_response(conn, 200)
    end
  end
end
