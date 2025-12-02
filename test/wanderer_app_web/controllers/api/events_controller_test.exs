defmodule WandererAppWeb.Api.EventsControllerTest do
  use WandererAppWeb.ConnCase, async: false

  import WandererAppWeb.Factory

  # Enable SSE globally for these tests
  setup do
    # Store original value
    original_sse_config = Application.get_env(:wanderer_app, :sse, [])

    # Enable SSE for tests
    Application.put_env(:wanderer_app, :sse, Keyword.put(original_sse_config, :enabled, true))

    on_exit(fn ->
      # Restore original value
      Application.put_env(:wanderer_app, :sse, original_sse_config)
    end)

    :ok
  end

  describe "GET /api/maps/:map_identifier/events/stream - SSE access control" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      # Create map (factory sets public_api_key)
      map = insert(:map, %{owner_id: character.id})

      # Create an active subscription for the map to allow SSE
      create_active_subscription_for_map(map.id)

      # Enable SSE for the map
      {:ok, map} = Ash.update(map, %{sse_enabled: true})

      %{map: map, character: character}
    end

    # Note: Most error scenarios are difficult to test in isolation because:
    # 1. 401/404 errors are handled by CheckMapApiKey plug (before controller)
    # 2. 402/503 errors pass access control and require SseStreamManager to be running
    # We test the 403 error which demonstrates the JSON error format works correctly.

    test "returns 403 JSON error with code when SSE disabled for map", %{conn: conn, map: map} do
      # Disable SSE for this map
      {:ok, updated_map} = Ash.update(map, %{sse_enabled: false})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{updated_map.public_api_key}")
        |> get("/api/maps/#{updated_map.slug}/events/stream")

      # Verify JSON error response with structured format (Task 5 requirement)
      response = json_response(conn, 403)
      assert response["error"] =~ "disabled for this map"
      assert response["code"] == "SSE_DISABLED_FOR_MAP"
      assert response["status"] == 403
    end
  end
end
