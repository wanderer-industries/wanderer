defmodule WandererApp.Contract.Api.JsonApiEventsContractTest do
  @moduledoc """
  Contract tests for JSON:API formatted SSE events.

  Validates that the SSE events endpoint properly formats events
  according to JSON:API specification when format=jsonapi is requested.
  """

  use WandererAppWeb.ApiCase, async: false

  import WandererApp.Support.ContractHelpers.ApiContractHelpers

  alias WandererApp.ExternalEvents.JsonApiFormatter
  alias WandererApp.ExternalEvents.Event

  @moduletag :contract

  describe "SSE Events JSON:API Contract" do
    test "validates JSON:API event formatting structure" do
      # Test various event types to ensure they format correctly
      event_types = [
        %{"type" => "connected", "payload" => %{"server_time" => "2024-01-01T00:00:00Z"}},
        %{
          "type" => "add_system",
          "payload" => %{"system_id" => "sys123", "name" => "Test System"}
        },
        %{
          "type" => "character_added",
          "payload" => %{"character_id" => "char123", "name" => "Test Character"}
        },
        %{
          "type" => "acl_member_added",
          "payload" => %{"member_id" => "mem123", "role" => "admin"}
        }
      ]

      Enum.each(event_types, fn event_data ->
        test_event =
          Map.merge(event_data, %{
            "id" => "01HZ123ABC",
            "map_id" => "map123",
            "timestamp" => "2024-01-01T00:00:00Z"
          })

        # Format to JSON:API
        formatted_event = JsonApiFormatter.format_legacy_event(test_event)

        # Validate JSON:API structure
        validate_jsonapi_contract(formatted_event)

        # Validate required top-level fields
        assert Map.has_key?(formatted_event, "data"),
               "Missing 'data' field for #{event_data["type"]}"

        assert Map.has_key?(formatted_event, "meta"),
               "Missing 'meta' field for #{event_data["type"]}"

        assert Map.has_key?(formatted_event, "links"),
               "Missing 'links' field for #{event_data["type"]}"

        # Validate data structure
        data = formatted_event["data"]
        assert Map.has_key?(data, "type"), "Missing 'type' in data for #{event_data["type"]}"
        assert Map.has_key?(data, "id"), "Missing 'id' in data for #{event_data["type"]}"

        # Validate meta structure
        meta = formatted_event["meta"]
        assert Map.has_key?(meta, "event_type"), "Missing 'event_type' in meta"
        assert Map.has_key?(meta, "event_action"), "Missing 'event_action' in meta"
        assert Map.has_key?(meta, "timestamp"), "Missing 'timestamp' in meta"
        assert Map.has_key?(meta, "map_id"), "Missing 'map_id' in meta"
        assert Map.has_key?(meta, "event_id"), "Missing 'event_id' in meta"

        # Validate links structure
        links = formatted_event["links"]
        assert Map.has_key?(links, "related"), "Missing 'related' link"
        assert Map.has_key?(links, "self"), "Missing 'self' link"

        assert String.contains?(links["related"], "maps/#{test_event["map_id"]}"),
               "Invalid related link"

        assert String.contains?(links["self"], "events/stream"), "Invalid self link"
      end)
    end

    test "validates event action mappings" do
      test_cases = [
        {"add_system", "created"},
        {"deleted_system", "deleted"},
        {"system_renamed", "updated"},
        {"connection_added", "created"},
        {"connection_removed", "deleted"},
        {"character_updated", "updated"},
        {"connected", "connected"}
      ]

      Enum.each(test_cases, fn {event_type, expected_action} ->
        test_event = %{
          "id" => "01HZ123ABC",
          "type" => event_type,
          "map_id" => "map123",
          "timestamp" => "2024-01-01T00:00:00Z",
          "payload" => %{}
        }

        formatted_event = JsonApiFormatter.format_legacy_event(test_event)
        actual_action = formatted_event["meta"]["event_action"]

        assert actual_action == expected_action,
               "Expected action '#{expected_action}' for event type '#{event_type}', got '#{actual_action}'"
      end)
    end

    test "validates resource type mappings" do
      test_cases = [
        # Generic fallback
        {"add_system", "events"},
        {"connected", "connection_status"},
        {"signature_added", "events"},
        {"character_added", "events"}
      ]

      Enum.each(test_cases, fn {event_type, expected_resource_type} ->
        test_event = %{
          "id" => "01HZ123ABC",
          "type" => event_type,
          "map_id" => "map123",
          "timestamp" => "2024-01-01T00:00:00Z",
          "payload" => %{}
        }

        formatted_event = JsonApiFormatter.format_legacy_event(test_event)
        actual_resource_type = formatted_event["data"]["type"]

        assert actual_resource_type == expected_resource_type,
               "Expected resource type '#{expected_resource_type}' for event type '#{event_type}', got '#{actual_resource_type}'"
      end)
    end

    test "validates event data preservation" do
      original_payload = %{
        "system_id" => "sys123",
        "name" => "Test System",
        "x" => 100,
        "y" => 200,
        "custom_field" => "custom_value"
      }

      test_event = %{
        "id" => "01HZ123ABC",
        "type" => "add_system",
        "map_id" => "map123",
        "timestamp" => "2024-01-01T00:00:00Z",
        "payload" => original_payload
      }

      formatted_event = JsonApiFormatter.format_legacy_event(test_event)

      # Verify original data is preserved in attributes
      attributes = formatted_event["data"]["attributes"]

      Enum.each(original_payload, fn {key, value} ->
        assert Map.has_key?(attributes, key) or Map.has_key?(attributes, String.to_atom(key)),
               "Missing payload field '#{key}' in formatted attributes"
      end)
    end

    test "validates relationship structure" do
      test_event = %{
        "id" => "01HZ123ABC",
        "type" => "add_system",
        "map_id" => "map123",
        "timestamp" => "2024-01-01T00:00:00Z",
        "payload" => %{"system_id" => "sys123"}
      }

      formatted_event = JsonApiFormatter.format_legacy_event(test_event)

      # All events should have a map relationship
      relationships = formatted_event["data"]["relationships"]
      assert Map.has_key?(relationships, "map"), "Missing map relationship"

      map_relationship = relationships["map"]
      assert Map.has_key?(map_relationship, "data"), "Missing data in map relationship"

      map_data = map_relationship["data"]
      assert map_data["type"] == "maps", "Invalid map relationship type"
      assert map_data["id"] == "map123", "Invalid map relationship id"
    end

    test "validates timestamp formatting" do
      test_event = %{
        "id" => "01HZ123ABC",
        "type" => "connected",
        "map_id" => "map123",
        "timestamp" => "2024-01-01T00:00:00Z",
        "payload" => %{}
      }

      formatted_event = JsonApiFormatter.format_legacy_event(test_event)

      # Validate timestamp is preserved in meta
      assert formatted_event["meta"]["timestamp"] == "2024-01-01T00:00:00Z"

      # Validate timestamp format (ISO 8601)
      timestamp = formatted_event["meta"]["timestamp"]

      assert Regex.match?(~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, timestamp),
             "Invalid timestamp format: #{timestamp}"
    end

    test "validates error handling for malformed events" do
      # Test with minimal event data
      minimal_event = %{
        "type" => "unknown_event",
        "map_id" => "map123"
      }

      # Should not crash and should provide fallback values
      formatted_event = JsonApiFormatter.format_legacy_event(minimal_event)

      # Should have required JSON:API structure
      assert Map.has_key?(formatted_event, "data")
      assert Map.has_key?(formatted_event, "meta")
      assert Map.has_key?(formatted_event, "links")

      # Should use fallback values
      assert formatted_event["data"]["type"] == "events"
      assert formatted_event["meta"]["event_action"] == "unknown"
    end
  end

  describe "SSE Endpoint Format Parameter Contract" do
    setup do
      scenario = create_authenticated_scenario()
      %{scenario: scenario}
    end

    # Skip until we have a running server for integration testing
    @tag :skip
    test "validates format parameter acceptance", %{scenario: scenario} do
      conn = build_authenticated_conn(scenario.auth_token)

      # Test legacy format (default)
      response_legacy = get(conn, "/api/events/stream/#{scenario.map.id}")
      assert response_legacy.status in [200, 202], "Legacy format should be accepted"

      # Test JSON:API format
      response_jsonapi = get(conn, "/api/events/stream/#{scenario.map.id}?format=jsonapi")
      assert response_jsonapi.status in [200, 202], "JSON:API format should be accepted"

      # Test invalid format
      response_invalid = get(conn, "/api/events/stream/#{scenario.map.id}?format=invalid")
      # Should default to legacy format
      assert response_invalid.status in [200, 202], "Invalid format should default to legacy"
    end
  end
end
