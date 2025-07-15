defmodule WandererApp.SecurityAuditTest do
  @moduledoc """
  Tests for the security audit logging system.
  """

  use WandererAppWeb.ConnCase, async: true

  alias WandererApp.SecurityAudit
  alias WandererApp.Api.UserActivity

  import WandererAppWeb.Factory

  describe "security audit logging" do
    test "logs authentication success events" do
      user = insert(:user)

      request_details = %{
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0 Test Browser",
        auth_method: "session",
        session_id: "test_session_123"
      }

      assert :ok = SecurityAudit.log_auth_event(:auth_success, user.id, request_details)

      # Verify the event was stored
      events = SecurityAudit.get_user_audit_events(user.id)
      assert length(events) > 0

      event = hd(events)
      assert event.event_type == :auth_success
      assert event.user_id == user.id
      assert event.entity_type == :security_event

      # Verify event data
      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["ip_address"] == "192.168.1.100"
      assert event_data["user_agent"] == "Mozilla/5.0 Test Browser"
      assert event_data["auth_method"] == "session"
    end

    test "logs authentication failure events" do
      request_details = %{
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0 Test Browser",
        auth_method: "bearer_token",
        failure_reason: "Invalid token"
      }

      assert :ok = SecurityAudit.log_auth_event(:auth_failure, nil, request_details)

      # Verify the event was stored
      events = SecurityAudit.get_events_by_type(:auth_failure)
      assert length(events) > 0

      event = hd(events)
      assert event.event_type == :auth_failure
      assert event.user_id == nil
      assert event.entity_type == :security_event

      # Verify event data
      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["failure_reason"] == "Invalid token"
    end

    test "logs data access events" do
      user = insert(:user)
      map = insert(:map)

      request_details = %{
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0 Test Browser",
        session_id: "test_session_123"
      }

      assert :ok = SecurityAudit.log_data_access("map", map.id, user.id, "read", request_details)

      # Verify the event was stored
      events = SecurityAudit.get_user_audit_events(user.id)
      assert length(events) > 0

      event = hd(events)
      assert event.event_type == :data_access
      assert event.user_id == user.id
      assert event.entity_type == :security_event

      # Verify event data
      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["resource_type"] == "map"
      assert event_data["resource_id"] == map.id
      assert event_data["action"] == "read"
    end

    test "logs permission denied events" do
      user = insert(:user)
      map = insert(:map)

      request_details = %{
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0 Test Browser",
        session_id: "test_session_123"
      }

      assert :ok =
               SecurityAudit.log_permission_denied(
                 "map",
                 map.id,
                 user.id,
                 "write",
                 request_details
               )

      # Verify the event was stored
      events = SecurityAudit.get_user_audit_events(user.id)
      assert length(events) > 0

      event = hd(events)
      assert event.event_type == :permission_denied
      assert event.user_id == user.id
      assert event.entity_type == :security_event

      # Verify event data
      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["resource_type"] == "map"
      assert event_data["resource_id"] == map.id
      assert event_data["attempted_action"] == "write"
    end

    test "logs admin actions" do
      user = insert(:user)

      request_details = %{
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0 Test Browser",
        session_id: "test_session_123"
      }

      assert :ok = SecurityAudit.log_admin_action("delete_user", user.id, "user", request_details)

      # Verify the event was stored
      events = SecurityAudit.get_user_audit_events(user.id)
      assert length(events) > 0

      event = hd(events)
      assert event.event_type == :admin_action
      assert event.user_id == user.id
      assert event.entity_type == :security_event

      # Verify event data
      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["action"] == "delete_user"
      assert event_data["target_resource"] == "user"
    end

    test "logs bulk operations" do
      user = insert(:user)

      request_details = %{
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0 Test Browser",
        session_id: "test_session_123"
      }

      assert :ok = SecurityAudit.log_bulk_operation("export_data", 1000, user.id, request_details)

      # Verify the event was stored
      events = SecurityAudit.get_user_audit_events(user.id)
      assert length(events) > 0

      event = hd(events)
      assert event.event_type == :bulk_operation
      assert event.user_id == user.id
      assert event.entity_type == :security_event

      # Verify event data
      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["operation_type"] == "export_data"
      assert event_data["record_count"] == 1000
    end
  end

  describe "security event queries" do
    test "gets events by type" do
      user = insert(:user)

      # Create multiple events of different types
      SecurityAudit.log_auth_event(:auth_success, user.id, %{ip_address: "192.168.1.100"})
      SecurityAudit.log_auth_event(:auth_failure, user.id, %{ip_address: "192.168.1.100"})

      SecurityAudit.log_data_access("map", "test_map", user.id, "read", %{
        ip_address: "192.168.1.100"
      })

      # Get only auth_success events
      success_events = SecurityAudit.get_events_by_type(:auth_success)
      assert length(success_events) > 0
      assert Enum.all?(success_events, fn event -> event.event_type == :auth_success end)

      # Get only auth_failure events
      failure_events = SecurityAudit.get_events_by_type(:auth_failure)
      assert length(failure_events) > 0
      assert Enum.all?(failure_events, fn event -> event.event_type == :auth_failure end)
    end

    test "gets events in date range" do
      user = insert(:user)

      # Create an event
      SecurityAudit.log_auth_event(:auth_success, user.id, %{ip_address: "192.168.1.100"})

      # Get events from last hour
      now = DateTime.utc_now()
      one_hour_ago = DateTime.add(now, -3600, :second)

      events = SecurityAudit.get_events_in_range(one_hour_ago, now)
      assert length(events) > 0

      # Get events from far in the past (should be empty)
      one_day_ago = DateTime.add(now, -86400, :second)
      two_days_ago = DateTime.add(now, -172_800, :second)

      old_events = SecurityAudit.get_events_in_range(two_days_ago, one_day_ago)
      assert Enum.empty?(old_events)
    end
  end

  describe "sensitive data sanitization" do
    test "sanitizes sensitive configuration values" do
      user = insert(:user)

      # Test with sensitive data
      SecurityAudit.log_config_change("api_key", "secret_key_123", "new_secret_key_456", user.id)

      events = SecurityAudit.get_user_audit_events(user.id)
      event = hd(events)

      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["old_value"] == "[REDACTED]"
      assert event_data["new_value"] == "[REDACTED]"
    end

    test "does not sanitize non-sensitive data" do
      user = insert(:user)

      # Test with non-sensitive data
      SecurityAudit.log_config_change("map_name", "Old Map Name", "New Map Name", user.id)

      events = SecurityAudit.get_user_audit_events(user.id)
      event = hd(events)

      {:ok, event_data} = Jason.decode(event.event_data)
      assert event_data["old_value"] == "Old Map Name"
      assert event_data["new_value"] == "New Map Name"
    end
  end
end
