defmodule WandererAppWeb.AuthTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererAppWeb.Plugs.CheckMapApiKey
  alias WandererAppWeb.Plugs.CheckAclApiKey
  alias WandererAppWeb.BasicAuth
  alias WandererAppWeb.Factory

  describe "CheckMapApiKey plug" do
    setup do
      user = Factory.insert(:user)
      character = Factory.insert(:character, %{user_id: user.id})

      map =
        Factory.insert(:map, %{
          owner_id: character.id,
          public_api_key: "test_api_key_123"
        })

      %{user: user, character: character, map: map}
    end

    test "allows access with valid map API key via map_identifier path param", %{map: map} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_api_key_123")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_identifier" => map.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      refute result.halted
      assert result.assigns.map.id == map.id
      assert result.assigns.map_id == map.id
    end

    test "allows access with valid map API key via slug in map_identifier", %{map: map} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_api_key_123")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_identifier" => map.slug})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      refute result.halted
      assert result.assigns.map.id == map.id
    end

    test "allows access with valid map API key via legacy map_id param", %{map: map} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_api_key_123")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_id" => map.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      refute result.halted
      assert result.assigns.map.id == map.id
    end

    test "allows access with valid map API key via legacy slug param", %{map: map} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_api_key_123")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"slug" => map.slug})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      refute result.halted
      assert result.assigns.map.id == map.id
    end

    test "rejects request with missing authorization header", %{map: map} do
      conn =
        build_conn()
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_identifier" => map.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end

    test "rejects request with invalid authorization format", %{map: map} do
      conn =
        build_conn()
        # Not Bearer
        |> put_req_header("authorization", "Basic dGVzdDp0ZXN0")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_identifier" => map.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end

    test "rejects request with wrong API key", %{map: map} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer wrong_api_key")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_identifier" => map.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end

    test "rejects request with missing map identifier" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_api_key_123")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      assert result.halted
      assert result.status == 400
    end

    test "rejects request for non-existent map" do
      non_existent_id = "550e8400-e29b-41d4-a716-446655440000"

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_api_key_123")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_identifier" => non_existent_id})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      assert result.halted
      assert result.status == 404
    end

    test "rejects request for map without API key configured", %{map: map} do
      # Update map to have no API key using the proper action
      {:ok, map_without_key} = Ash.update(map, %{public_api_key: nil}, action: :update_api_key)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_api_key_123")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"map_identifier" => map_without_key.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckMapApiKey.call(conn, CheckMapApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end
  end

  describe "CheckAclApiKey plug" do
    setup do
      user = Factory.insert(:user)
      character = Factory.insert(:character, %{user_id: user.id})

      acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          api_key: "test_acl_key_456"
        })

      %{user: user, character: character, acl: acl}
    end

    test "allows access with valid ACL API key via id param", %{acl: acl} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_acl_key_456")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"id" => acl.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      refute result.halted
    end

    test "allows access with valid ACL API key via acl_id param", %{acl: acl} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_acl_key_456")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"acl_id" => acl.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      refute result.halted
    end

    test "rejects request with missing authorization header", %{acl: acl} do
      conn =
        build_conn()
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"id" => acl.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end

    test "rejects request with invalid authorization format", %{acl: acl} do
      conn =
        build_conn()
        # Not Bearer
        |> put_req_header("authorization", "Basic dGVzdDp0ZXN0")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"id" => acl.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end

    test "rejects request with wrong API key", %{acl: acl} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer wrong_acl_key")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"id" => acl.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end

    test "rejects request with missing ACL ID" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_acl_key_456")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      assert result.halted
      assert result.status == 400
    end

    test "rejects request for non-existent ACL" do
      non_existent_id = "550e8400-e29b-41d4-a716-446655440000"

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_acl_key_456")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"id" => non_existent_id})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      assert result.halted
      assert result.status == 404
    end

    test "rejects request for ACL without API key configured", %{acl: acl} do
      # Update ACL to have no API key
      {:ok, acl_without_key} = Ash.update(acl, %{api_key: nil})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer test_acl_key_456")
        |> put_private(:phoenix_router, WandererAppWeb.Router)
        |> Map.put(:params, %{"id" => acl_without_key.id})
        |> Plug.Conn.fetch_query_params()

      result = CheckAclApiKey.call(conn, CheckAclApiKey.init([]))

      assert result.halted
      assert result.status == 401
    end
  end

  describe "BasicAuth" do
    test "function exists and can be called" do
      # Basic smoke test - the function exists and doesn't crash
      conn = build_conn() |> Plug.Conn.fetch_query_params()
      result = BasicAuth.admin_basic_auth(conn, [])

      # Should return a conn (either original or modified by Plug.BasicAuth)
      assert %Plug.Conn{} = result
    end
  end
end
