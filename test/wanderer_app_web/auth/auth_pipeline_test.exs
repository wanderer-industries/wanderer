defmodule WandererAppWeb.Auth.AuthPipelineTest do
  use WandererAppWeb.ConnCase

  @moduletag :ash

  alias WandererAppWeb.Auth.AuthPipeline
  alias WandererApp.Api

  import WandererApp.Factory

  describe "AuthPipeline" do
    test "authenticates with map API key", %{conn: conn} do
      user = create_user()
      character = create_character(%{user_id: user.id}, user)
      map = create_map(%{owner_id: character.id}, character)

      {:ok, map} =
        Ash.update(map, %{public_api_key: "test-api-key"},
          actor: character,
          action: :update_api_key
        )

      conn =
        conn
        |> assign(:map, map)
        |> put_req_header("authorization", "Bearer test-api-key")
        |> AuthPipeline.call(AuthPipeline.init(strategies: [:map_api_key]))

      assert conn.assigns.authenticated_by == :map_api_key
      assert conn.assigns.map_id == map.id
      refute conn.halted
    end

    test "fails with invalid map API key", %{conn: conn} do
      user = create_user()
      character = create_character(%{user_id: user.id}, user)
      map = create_map(%{owner_id: character.id}, character)

      {:ok, map} =
        Ash.update(map, %{public_api_key: "test-api-key"},
          actor: character,
          action: :update_api_key
        )

      conn =
        conn
        |> assign(:map, map)
        |> put_req_header("authorization", "Bearer wrong-key")
        |> AuthPipeline.call(AuthPipeline.init(strategies: [:map_api_key]))

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Authentication required"
    end

    test "skips authentication when not required", %{conn: conn} do
      conn =
        conn
        |> AuthPipeline.call(
          AuthPipeline.init(
            strategies: [:map_api_key],
            required: false
          )
        )

      refute conn.halted
      refute Map.has_key?(conn.assigns, :authenticated_by)
    end

    test "tries multiple strategies in order", %{conn: conn} do
      user = create_user()
      character = create_character(%{user_id: user.id}, user)
      map = create_map(%{owner_id: character.id}, character)

      {:ok, map} =
        Ash.update(map, %{public_api_key: "test-api-key"},
          actor: character,
          action: :update_api_key
        )

      # First strategy will skip (no ACL), second should succeed
      conn =
        conn
        |> assign(:map, map)
        |> put_req_header("authorization", "Bearer test-api-key")
        |> fetch_query_params()
        |> AuthPipeline.call(AuthPipeline.init(strategies: [:acl_key, :map_api_key]))

      assert conn.assigns.authenticated_by == :map_api_key
      refute conn.halted
    end

    test "respects feature flags", %{conn: conn} do
      # Temporarily set feature flag
      original = Application.get_env(:wanderer_app, :public_api_disabled)
      Application.put_env(:wanderer_app, :public_api_disabled, true)

      conn =
        conn
        |> AuthPipeline.call(
          AuthPipeline.init(
            strategies: [],
            feature_flag: :public_api_disabled
          )
        )

      assert conn.halted
      assert conn.status == 403
      assert json_response(conn, 403)["error"] == "This feature is disabled"

      # Restore original value
      Application.put_env(:wanderer_app, :public_api_disabled, original)
    end

    test "assigns auth data with custom key", %{conn: conn} do
      user = create_user()
      character = create_character(%{user_id: user.id}, user)
      map = create_map(%{owner_id: character.id}, character)

      {:ok, map} =
        Ash.update(map, %{public_api_key: "test-api-key"},
          actor: character,
          action: :update_api_key
        )

      conn =
        conn
        |> assign(:map, map)
        |> put_req_header("authorization", "Bearer test-api-key")
        |> AuthPipeline.call(
          AuthPipeline.init(
            strategies: [:map_api_key],
            assign_as: :auth_context
          )
        )

      assert conn.assigns.auth_context.type == :map_api_key
      assert conn.assigns.auth_context.map_id == map.id
      refute conn.halted
    end
  end
end
