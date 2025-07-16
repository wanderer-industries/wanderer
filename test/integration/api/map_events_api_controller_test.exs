defmodule WandererAppWeb.MapEventsAPIControllerIntegrationTest do
  use WandererAppWeb.ApiCase, async: false

  import Mox

  describe "GET /api/maps/:map_identifier/events" do
    setup :setup_map_authentication

    test "returns empty events when MapEventRelay is not running", %{conn: conn, map: map} do
      # When MapEventRelay is not running, Process.whereis will return nil
      # and the controller should return empty list
      response =
        conn
        |> get("/api/maps/#{map.id}/events")
        |> assert_json_response(200)

      assert %{"data" => []} = response
    end

    test "returns error for invalid since parameter", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/events?since=invalid-datetime")
        |> assert_json_response(400)

      assert %{"error" => "Invalid 'since' parameter. Must be ISO8601 datetime."} = response
    end

    test "returns error for invalid limit parameter - too high", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/events?limit=150")
        |> assert_json_response(400)

      assert %{"error" => "Invalid 'limit' parameter. Must be between 1 and 100."} = response
    end

    test "returns error for invalid limit parameter - too low", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/events?limit=0")
        |> assert_json_response(400)

      assert %{"error" => "Invalid 'limit' parameter. Must be between 1 and 100."} = response
    end

    test "returns error for invalid limit parameter - non-numeric", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/events?limit=abc")
        |> assert_json_response(400)

      assert %{"error" => "Invalid 'limit' parameter. Must be between 1 and 100."} = response
    end

    test "accepts valid since parameter in ISO8601 format", %{conn: conn, map: map} do
      # This should not return a 400 error for valid datetime
      response =
        conn
        |> get("/api/maps/#{map.id}/events?since=2025-01-20T12:30:00Z")
        |> assert_json_response(200)

      assert %{"data" => events} = response
      assert is_list(events)
    end

    test "accepts valid limit parameter", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/events?limit=50")
        |> assert_json_response(200)

      assert %{"data" => events} = response
      assert is_list(events)
    end

    test "uses default limit when not provided", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.id}/events")
        |> assert_json_response(200)

      assert %{"data" => events} = response
      assert is_list(events)
    end

    test "works with map slug instead of UUID", %{conn: conn, map: map} do
      response =
        conn
        |> get("/api/maps/#{map.slug}/events")
        |> assert_json_response(200)

      assert %{"data" => events} = response
      assert is_list(events)
    end

    test "handles both string and integer limit parameters", %{conn: conn, map: map} do
      # String limit
      response1 =
        conn
        |> get("/api/maps/#{map.id}/events?limit=25")
        |> assert_json_response(200)

      assert %{"data" => events1} = response1
      assert is_list(events1)

      # The controller should handle both string and integer limit params
      # We can't easily test integer params via HTTP, but the controller has logic for both
    end
  end

  describe "authentication and authorization" do
    setup :setup_map_authentication

    test "returns 401 for missing API key", %{map: map} do
      response =
        build_conn()
        |> get("/api/maps/#{map.id}/events")
        |> assert_json_response(401)

      assert %{"error" => _} = response
    end

    test "returns authentication error for non-existent map with invalid API key" do
      # Without a valid API key, the authentication pipeline will reject first
      non_existent_map_id = Ecto.UUID.generate()

      response =
        build_conn()
        |> get("/api/maps/#{non_existent_map_id}/events")
        |> assert_json_response(401)

      assert %{"error" => _} = response
    end

    test "websocket events are enabled in test environment", %{conn: conn, map: map} do
      # This endpoint requires the :api_websocket_events pipeline
      # which includes the CheckWebsocketDisabled plug
      # In test env, websocket events should be enabled

      response =
        conn
        |> get("/api/maps/#{map.id}/events")
        |> assert_json_response(200)

      assert %{"data" => events} = response
      assert is_list(events)
    end
  end

  describe "parameter parsing" do
    setup :setup_map_authentication

    test "parses since parameter correctly", %{conn: conn, map: map} do
      valid_datetimes = [
        "2025-01-20T12:30:00Z",
        "2025-01-20T12:30:00.000Z",
        "2025-01-20T12:30:00+00:00"
      ]

      for datetime <- valid_datetimes do
        # Properly encode the datetime for URL
        encoded_datetime = URI.encode(datetime, &URI.char_unreserved?/1)

        response =
          conn
          |> get("/api/maps/#{map.id}/events?since=#{encoded_datetime}")
          |> assert_json_response(200)

        assert %{"data" => events} = response
        assert is_list(events)
      end
    end

    test "rejects invalid since parameter formats", %{conn: conn, map: map} do
      invalid_datetimes = [
        "2025-01-20",
        "invalid",
        "2025-13-40T25:70:70Z",
        ""
      ]

      for datetime <- invalid_datetimes do
        # Properly encode the datetime for URL (even invalid ones)
        encoded_datetime = URI.encode(datetime, &URI.char_unreserved?/1)

        response =
          conn
          |> get("/api/maps/#{map.id}/events?since=#{encoded_datetime}")
          |> assert_json_response(400)

        assert %{"error" => "Invalid 'since' parameter. Must be ISO8601 datetime."} = response
      end
    end

    @tag :skip
    test "validates limit parameter boundaries", %{conn: conn, map: map} do
      valid_limits = [1, 50, 100, "1", "50", "100"]

      for limit <- valid_limits do
        response =
          conn
          |> get("/api/maps/#{map.id}/events?limit=#{limit}")
          |> assert_json_response(200)

        assert %{"data" => events} = response
        assert is_list(events)
      end

      invalid_limits = [0, 101, 200, -1, "0", "101", "abc", ""]

      for limit <- invalid_limits do
        response =
          conn
          |> get("/api/maps/#{map.id}/events?limit=#{limit}")
          |> assert_json_response(400)

        assert %{"error" => "Invalid 'limit' parameter. Must be between 1 and 100."} = response
      end
    end
  end
end
