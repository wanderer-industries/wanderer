defmodule WandererAppWeb.Api.PermissionGatingTest do
  @moduledoc """
  Covers two review findings on wanderer-industries/wanderer#648:

    1. `WandererApp.Map.EveTokenAuth.exchange/2` computes a permission mask
       but it never reached the signed token or anything downstream, so any
       eve-token (viewer included) authenticated as if it were the map owner.
       `WandererAppWeb.Plugs.RequirePermission` now gates write endpoints on
       that mask.
    2. `WandererAppWeb.Plugs.CheckMapApiKey.call_with_eve_token/2` never
       checked the token's map against the map the request was actually
       addressed to, so a token minted for map A authenticated requests to
       map B.
  """

  use WandererAppWeb.ApiCase, async: false

  alias WandererAppWeb.Factory

  defp mint_eve_token(conn, map, character) do
    Mox.stub(Test.EveSsoMock, :verify_token, fn _ ->
      {:ok,
       %{
         character_id: String.to_integer(character.eve_id),
         character_name: character.name,
         scopes: ""
       }}
    end)

    exchange_conn =
      post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "tok"})

    assert %{"data" => %{"token" => token}} = json_response(exchange_conn, 200)
    token
  end

  describe "permission-mask enforcement on write endpoints" do
    setup %{conn: conn} do
      owner_user = Factory.insert(:user)
      owner = Factory.insert(:character, %{user_id: owner_user.id})
      map = Factory.insert(:map, %{owner_id: owner.id})

      acl = Factory.insert(:access_list, %{owner_id: owner.id})
      Factory.insert(:map_access_list, %{map_id: map.id, access_list_id: acl.id})

      %{conn: conn, map: map, owner: owner, acl: acl}
    end

    test "a viewer-role eve-token cannot batch-delete systems", %{
      conn: conn,
      map: map,
      acl: acl
    } do
      viewer_user = Factory.insert(:user)
      viewer = Factory.insert(:character, %{user_id: viewer_user.id})

      Factory.insert(:access_list_member, %{
        access_list_id: acl.id,
        eve_character_id: viewer.eve_id,
        role: "viewer"
      })

      token = mint_eve_token(conn, map, viewer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/maps/#{map.slug}/systems", %{})

      assert %{"error" => _} = json_response(conn, 403)
    end

    test "an admin-role eve-token can create a system", %{conn: conn, map: map, acl: acl} do
      admin_user = Factory.insert(:user)
      admin = Factory.insert(:character, %{user_id: admin_user.id})

      Factory.insert(:access_list_member, %{
        access_list_id: acl.id,
        eve_character_id: admin.eve_id,
        role: "admin"
      })

      token = mint_eve_token(conn, map, admin)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/maps/#{map.slug}/systems", %{"solar_system_id" => 30_000_142})

      assert %{"data" => _} = json_response(conn, 200)
    end

    test "the map owner's eve-token can create a system (owner-gets-admin, no ACL entry needed)",
         %{conn: conn, map: map, owner: owner} do
      token = mint_eve_token(conn, map, owner)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/maps/#{map.slug}/systems", %{"solar_system_id" => 30_000_144})

      assert %{"data" => _} = json_response(conn, 200)
    end

    test "the static map key still passes through unaffected", %{conn: conn, map: map} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> post(~p"/api/maps/#{map.slug}/systems", %{"solar_system_id" => 30_002_187})

      assert %{"data" => _} = json_response(conn, 200)
    end
  end

  describe "eve-token map-id scoping" do
    setup %{conn: conn} do
      owner_user = Factory.insert(:user)
      owner = Factory.insert(:character, %{user_id: owner_user.id})
      map = Factory.insert(:map, %{owner_id: owner.id})
      own_system = Factory.insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

      other_map = Factory.insert(:map)

      token = mint_eve_token(conn, map, owner)
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      %{conn: conn, map: map, own_system: own_system, other_map: other_map}
    end

    test "own map (by slug) -> 200", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.slug}/systems")
      assert %{"data" => _} = json_response(conn, 200)
    end

    test "own map (by id) -> 200", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/maps/#{map.id}/systems")
      assert %{"data" => _} = json_response(conn, 200)
    end

    test "another map's slug -> 404, not the token's own map data", %{
      conn: conn,
      other_map: other_map
    } do
      conn = get(conn, ~p"/api/maps/#{other_map.slug}/systems")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "another map's id -> 404", %{conn: conn, other_map: other_map} do
      conn = get(conn, ~p"/api/maps/#{other_map.id}/systems")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "a nonexistent map identifier -> 404, not 500", %{conn: conn} do
      conn = get(conn, ~p"/api/maps/does-not-exist/systems")
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "own map id upper-cased still resolves to the same map (not a raw string mismatch)",
         %{conn: conn, map: map} do
      # Unlike a naive raw-string comparison, both sides of the mismatch guard
      # go through ApiMap.by_id/get_map_by_slug (Ecto.UUID.cast) before being
      # compared, so this is case-normalized the same way every other UUID
      # lookup in the app already is - not a bypass, since it can only ever
      # resolve to the exact same map, never a different one.
      conn = get(conn, ~p"/api/maps/#{String.upcase(map.id)}/systems")
      assert %{"data" => _} = json_response(conn, 200)
    end
  end
end
