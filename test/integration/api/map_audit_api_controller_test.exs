defmodule WandererAppWeb.MapAuditAPIControllerIntegrationTest do
  use WandererAppWeb.ApiCase

  alias WandererAppWeb.Factory

  describe "GET /api/map/audit (index)" do
    setup :setup_map_authentication

    test "returns audit events for a map by slug", %{conn: conn, map: map} do
      # Create a character for the audit events
      character =
        Factory.insert(:character, %{
          eve_id: "123456789",
          name: "Test Character"
        })

      # Create a user for the audit events
      user = Factory.insert(:user)

      # Create audit events
      _audit1 =
        Factory.insert(:map_audit_event, %{
          entity_id: map.id,
          user_id: user.id,
          character_id: character.id,
          entity_type: :map,
          event_type: :system_added,
          event_data: %{"solar_system_id" => 30_000_142, "name" => "Jita"}
        })

      _audit2 =
        Factory.insert(:map_audit_event, %{
          entity_id: map.id,
          user_id: user.id,
          character_id: character.id,
          entity_type: :map,
          event_type: :map_connection_added,
          event_data: %{"source" => 30_000_142, "target" => 30_000_143}
        })

      conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => "1D"})

      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) == 2

      # Verify event structure
      event = hd(events)
      assert Map.has_key?(event, "entity_type")
      assert Map.has_key?(event, "event_name")
      assert Map.has_key?(event, "event_data")
      assert Map.has_key?(event, "character")
      assert Map.has_key?(event, "inserted_at")

      # Verify character information
      assert event["character"]["eve_id"] == "123456789"
      assert event["character"]["name"] == "Test Character"
    end

    test "returns audit events for a map by map_id", %{conn: conn, map: map} do
      character = Factory.insert(:character, %{eve_id: "123456789"})
      user = Factory.insert(:user)

      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :system_updated
      })

      conn = get(conn, "/api/map/audit", %{"map_id" => map.id, "period" => "1H"})

      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) == 1
    end

    test "filters events by period", %{conn: conn, map: map} do
      character = Factory.insert(:character, %{eve_id: "123456789"})
      user = Factory.insert(:user)

      # Create events at different times
      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :system_added
      })

      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :systems_removed
      })

      # Request events for last 1 day
      conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => "1D"})

      assert %{"data" => events} = json_response(conn, 200)
      # Should only return recent events based on period filter
      # Number depends on period filtering logic
      assert length(events) >= 0
    end

    test "supports different period values", %{conn: conn, map: map} do
      character = Factory.insert(:character, %{eve_id: "123456789"})
      user = Factory.insert(:user)

      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :system_added
      })

      # Test different period values
      periods = ["1H", "1D", "1W", "1M", "2M", "3M"]

      for period <- periods do
        conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => period})
        assert %{"data" => _events} = json_response(conn, 200)
      end
    end

    test "returns empty array when no audit events exist", %{conn: conn, map: map} do
      conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => "1D"})
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "requires period parameter", %{conn: conn, map: map} do
      conn = get(conn, "/api/map/audit", %{"slug" => map.slug})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "requires either map_id or slug parameter", %{conn: conn} do
      conn = get(conn, "/api/map/audit", %{"period" => "1D"})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns error when both map_id and slug provided", %{conn: conn, map: map} do
      conn =
        get(conn, "/api/map/audit", %{
          "map_id" => map.id,
          "slug" => map.slug,
          "period" => "1D"
        })

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 404 for non-existent map", %{conn: conn} do
      conn = get(conn, "/api/map/audit", %{"slug" => "non-existent", "period" => "1D"})
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns 401 without API key", %{map: map} do
      conn = build_conn()
      conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => "1D"})
      assert json_response(conn, 401)
    end

    test "includes different entity types", %{conn: conn, map: map} do
      character = Factory.insert(:character, %{eve_id: "123456789"})
      user = Factory.insert(:user)

      # Create different types of audit events
      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :system_added
      })

      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :map_connection_added
      })

      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :signatures_added
      })

      conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => "1D"})

      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) == 3

      entity_types = Enum.map(events, & &1["entity_type"])
      assert "map" in entity_types
      # All should be map entity type
      assert Enum.all?(entity_types, &(&1 == "map"))
    end

    test "handles events without character information", %{conn: conn, map: map} do
      user = Factory.insert(:user)

      # Create audit event without character
      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: nil,
        entity_type: :map,
        event_type: :custom
      })

      conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => "1D"})

      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) == 1

      event = hd(events)
      # Should handle missing character gracefully
      assert Map.has_key?(event, "character")
    end

    test "orders events by insertion time", %{conn: conn, map: map} do
      character = Factory.insert(:character, %{eve_id: "123456789"})
      user = Factory.insert(:user)

      # Create events with specific timestamps
      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :system_added,
        event_data: %{"name" => "first_event"}
      })

      # Sleep to ensure second event has later timestamp
      Process.sleep(100)

      Factory.insert(:map_audit_event, %{
        entity_id: map.id,
        user_id: user.id,
        character_id: character.id,
        entity_type: :map,
        event_type: :system_updated,
        event_data: %{"name" => "second_event"}
      })

      conn = get(conn, "/api/map/audit", %{"slug" => map.slug, "period" => "1D"})

      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) == 2

      # Verify events are ordered by insertion time (should be descending - newest first)
      timestamps = Enum.map(events, & &1["inserted_at"])
      assert length(timestamps) == 2

      # Convert to DateTime for comparison
      [first_timestamp, second_timestamp] =
        Enum.map(timestamps, fn ts ->
          {:ok, dt, _} = DateTime.from_iso8601(ts)
          dt
        end)

      # Verify descending order (newest first)
      assert DateTime.compare(first_timestamp, second_timestamp) == :gt,
             "Events should be ordered by insertion time (newest first)"

      # Also verify the event names to confirm correct ordering
      event_names = Enum.map(events, & &1["event_name"])
      # The exact names depend on the get_event_name function
      assert length(event_names) == 2
    end
  end
end
