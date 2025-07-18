defmodule WandererApp.ExternalEvents.RallyPointEventsTest do
  use WandererApp.DataCase

  alias WandererApp.ExternalEvents
  alias WandererApp.ExternalEvents.Event
  alias WandererApp.Map.Server.PingsImpl

  import Mox

  # Mock the external events system for testing
  setup :verify_on_exit!

  describe "external events configuration" do
    test "rally point event types are supported" do
      supported_types = Event.supported_event_types()

      assert :rally_point_added in supported_types
      assert :rally_point_removed in supported_types
    end

    test "rally point events validate correctly" do
      assert Event.valid_event_type?(:rally_point_added)
      assert Event.valid_event_type?(:rally_point_removed)
      refute Event.valid_event_type?(:invalid_rally_event)
    end

    test "rally point events can be created" do
      payload = %{
        rally_point_id: "test-rally-id",
        solar_system_id: "31000123",
        character_name: "Test Character",
        message: "Rally here!"
      }

      event = Event.new("test-map-id", :rally_point_added, payload)

      assert event.type == :rally_point_added
      assert event.map_id == "test-map-id"
      assert event.payload == payload
      assert %DateTime{} = event.timestamp
      assert is_binary(event.id)
    end
  end

  describe "rally point event broadcasting" do
    test "rally point added event payload structure" do
      test_payload = %{
        rally_point_id: "ping-123",
        solar_system_id: "31000199",
        system_id: "system-uuid",
        character_id: "char-uuid",
        character_name: "Test Character",
        character_eve_id: 12345,
        system_name: "J123456",
        message: "Fleet rally here",
        created_at: ~U[2024-01-01 12:00:00Z]
      }

      event = Event.new("map-123", :rally_point_added, test_payload)
      json_event = Event.to_json(event)

      assert json_event["type"] == "rally_point_added"
      assert json_event["map_id"] == "map-123"

      payload = json_event["payload"]
      assert payload["rally_point_id"] == "ping-123"
      assert payload["solar_system_id"] == "31000199"
      assert payload["character_name"] == "Test Character"
      assert payload["message"] == "Fleet rally here"
    end

    test "rally point removed event payload structure" do
      test_payload = %{
        solar_system_id: "31000199",
        system_id: "system-uuid",
        character_id: "char-uuid",
        character_name: "Test Character",
        character_eve_id: 12345,
        system_name: "J123456"
      }

      event = Event.new("map-123", :rally_point_removed, test_payload)
      json_event = Event.to_json(event)

      assert json_event["type"] == "rally_point_removed"
      assert json_event["map_id"] == "map-123"

      payload = json_event["payload"]
      assert payload["solar_system_id"] == "31000199"
      assert payload["character_name"] == "Test Character"
      assert payload["system_name"] == "J123456"
      # Rally point removed doesn't include rally_point_id or message
      refute Map.has_key?(payload, "rally_point_id")
      refute Map.has_key?(payload, "message")
    end
  end
end
