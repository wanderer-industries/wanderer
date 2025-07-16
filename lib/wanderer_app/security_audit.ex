defmodule WandererApp.SecurityAudit do
  @moduledoc """
  Comprehensive security audit logging system.

  This module provides centralized logging for security-related events including:
  - Authentication events (login, logout, failures)
  - Authorization events (permission denied, privilege escalation)
  - Data access events (sensitive queries, bulk exports)
  - Configuration changes and admin actions
  """

  require Logger
  require Ash.Query

  alias WandererApp.Api.{User, Character, Map, UserActivity}

  @doc """
  Log a security event with structured data.

  ## Examples

      iex> WandererApp.SecurityAudit.log_event(:auth_success, user_id, %{
      ...>   ip_address: "192.168.1.100",
      ...>   user_agent: "Mozilla/5.0...",
      ...>   auth_method: "session"
      ...> })
      :ok
  """
  def log_event(event_type, user_id, details \\ %{}) do
    audit_entry = %{
      event_type: event_type,
      user_id: user_id,
      timestamp: DateTime.utc_now(),
      details: details,
      severity: determine_severity(event_type),
      session_id: details[:session_id],
      ip_address: details[:ip_address],
      user_agent: details[:user_agent]
    }

    # Store in database
    store_audit_entry(audit_entry)

    # Send to telemetry for monitoring
    emit_telemetry_event(audit_entry)

    # Log to application logs
    log_to_application_log(audit_entry)

    # Check for security alerts
    check_security_alerts(audit_entry)

    :ok
  end

  @doc """
  Log authentication events.
  """
  def log_auth_event(event_type, user_id, request_details) do
    # Start with the basic required fields
    details = %{
      ip_address: request_details[:ip_address],
      user_agent: request_details[:user_agent],
      auth_method: request_details[:auth_method],
      session_id: request_details[:session_id]
    }

    # Merge any additional fields from request_details
    details = Elixir.Map.merge(details, request_details)

    log_event(event_type, user_id, details)
  end

  @doc """
  Log data access events.
  """
  def log_data_access(resource_type, resource_id, user_id, action, request_details \\ %{}) do
    details = %{
      resource_type: resource_type,
      resource_id: resource_id,
      action: action,
      ip_address: request_details[:ip_address],
      user_agent: request_details[:user_agent],
      session_id: request_details[:session_id]
    }

    log_event(:data_access, user_id, details)
  end

  @doc """
  Log permission denied events.
  """
  def log_permission_denied(
        resource_type,
        resource_id,
        user_id,
        attempted_action,
        request_details \\ %{}
      ) do
    details = %{
      resource_type: resource_type,
      resource_id: resource_id,
      attempted_action: attempted_action,
      ip_address: request_details[:ip_address],
      user_agent: request_details[:user_agent],
      session_id: request_details[:session_id]
    }

    log_event(:permission_denied, user_id, details)
  end

  @doc """
  Log admin actions.
  """
  def log_admin_action(action, user_id, target_resource, request_details \\ %{}) do
    details = %{
      action: action,
      target_resource: target_resource,
      ip_address: request_details[:ip_address],
      user_agent: request_details[:user_agent],
      session_id: request_details[:session_id]
    }

    log_event(:admin_action, user_id, details)
  end

  @doc """
  Log configuration changes.
  """
  def log_config_change(config_key, old_value, new_value, user_id, request_details \\ %{}) do
    details = %{
      config_key: config_key,
      old_value: sanitize_sensitive_data(old_value),
      new_value: sanitize_sensitive_data(new_value),
      ip_address: request_details[:ip_address],
      user_agent: request_details[:user_agent],
      session_id: request_details[:session_id]
    }

    log_event(:config_change, user_id, details)
  end

  @doc """
  Log bulk data operations.
  """
  def log_bulk_operation(operation_type, record_count, user_id, request_details \\ %{}) do
    details = %{
      operation_type: operation_type,
      record_count: record_count,
      ip_address: request_details[:ip_address],
      user_agent: request_details[:user_agent],
      session_id: request_details[:session_id]
    }

    log_event(:bulk_operation, user_id, details)
  end

  @doc """
  Get audit events for a specific user.
  """
  def get_user_audit_events(user_id, limit \\ 100) do
    UserActivity
    |> Ash.Query.filter(user_id: user_id)
    |> Ash.Query.filter(entity_type: :security_event)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end

  @doc """
  Get recent security events.
  """
  def get_recent_events(limit \\ 50) do
    UserActivity
    |> Ash.Query.filter(entity_type: :security_event)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end

  @doc """
  Get security events by type.
  """
  def get_events_by_type(event_type, limit \\ 50) do
    UserActivity
    |> Ash.Query.filter(entity_type: :security_event)
    |> Ash.Query.filter(event_type: event_type)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end

  @doc """
  Get security events within a time range.
  """
  def get_events_in_range(from_datetime, to_datetime, limit \\ 100) do
    UserActivity
    |> Ash.Query.filter(entity_type: :security_event)
    |> Ash.Query.filter(inserted_at: [greater_than_or_equal: from_datetime])
    |> Ash.Query.filter(inserted_at: [less_than_or_equal: to_datetime])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end

  @doc """
  Check for suspicious patterns in user activity.
  """
  def analyze_user_behavior(user_id, time_window \\ 3600) do
    # This would analyze patterns like:
    # - Multiple failed login attempts
    # - Unusual access patterns
    # - Privilege escalation attempts
    # - Geographic anomalies

    %{
      risk_score: :low,
      suspicious_patterns: [],
      recommendations: []
    }
  end

  # Private functions

  defp store_audit_entry(audit_entry) do
    # Store in the existing UserActivity system
    try do
      # Ensure event_type is properly converted to atom if it's a string
      event_type =
        case audit_entry.event_type do
          atom when is_atom(atom) -> atom
          string when is_binary(string) -> String.to_existing_atom(string)
          # Default fallback
          _ -> :security_alert
        end

      Ash.create!(UserActivity, %{
        user_id: audit_entry.user_id,
        character_id: nil,
        entity_id: audit_entry.session_id || "unknown",
        entity_type: :security_event,
        event_type: event_type,
        event_data: Jason.encode!(audit_entry.details)
      })
    rescue
      error ->
        Logger.error("Failed to store security audit entry: #{inspect(error)}")

        # Fallback to ETS for development/testing
        case :ets.info(:security_audit_log) do
          :undefined ->
            :ets.new(:security_audit_log, [:set, :public, :named_table])

          _ ->
            :ok
        end

        # Store with timestamp as key to maintain order
        key = {audit_entry.timestamp, System.unique_integer([:positive])}
        :ets.insert(:security_audit_log, {key, audit_entry})

        # Keep only last 1000 entries in memory
        maintain_audit_log_size()
    end
  end

  defp maintain_audit_log_size do
    case :ets.info(:security_audit_log, :size) do
      size when size > 1000 ->
        # Remove oldest entries
        first_key = :ets.first(:security_audit_log)

        if first_key != :"$end_of_table" do
          :ets.delete(:security_audit_log, first_key)
        end

      _ ->
        :ok
    end
  end

  defp emit_telemetry_event(audit_entry) do
    :telemetry.execute(
      [:wanderer_app, :security_audit],
      %{count: 1},
      %{
        event_type: audit_entry.event_type,
        severity: audit_entry.severity,
        user_id: audit_entry.user_id
      }
    )
  end

  defp log_to_application_log(audit_entry) do
    log_level =
      case audit_entry.severity do
        :critical -> :error
        :high -> :warning
        :medium -> :info
        :low -> :debug
      end

    Logger.log(log_level, "Security audit: #{audit_entry.event_type}",
      user_id: audit_entry.user_id,
      timestamp: audit_entry.timestamp,
      details: audit_entry.details
    )
  end

  defp check_security_alerts(audit_entry) do
    case audit_entry.event_type do
      :auth_failure ->
        check_failed_login_attempts(audit_entry)

      :permission_denied ->
        check_privilege_escalation_attempts(audit_entry)

      :bulk_operation ->
        check_bulk_data_access(audit_entry)

      _ ->
        :ok
    end
  end

  defp check_failed_login_attempts(audit_entry) do
    # Check for multiple failed attempts from same IP
    # This is a placeholder - in production, you'd query the audit log
    :ok
  end

  defp check_privilege_escalation_attempts(audit_entry) do
    # Check for repeated permission denied events
    # This is a placeholder - in production, you'd query the audit log
    :ok
  end

  defp check_bulk_data_access(audit_entry) do
    # Check for unusual bulk data access patterns
    # This is a placeholder - in production, you'd query the audit log
    :ok
  end

  defp determine_severity(event_type) do
    case event_type do
      :auth_failure -> :medium
      :permission_denied -> :high
      :privilege_escalation -> :critical
      :config_change -> :high
      :admin_action -> :medium
      :bulk_operation -> :medium
      :data_access -> :low
      :auth_success -> :low
      _ -> :medium
    end
  end

  defp sanitize_sensitive_data(value) when is_binary(value) do
    # Sanitize sensitive data like passwords, tokens, etc.
    cond do
      String.contains?(value, "password") -> "[REDACTED]"
      String.contains?(value, "token") -> "[REDACTED]"
      String.contains?(value, "secret") -> "[REDACTED]"
      String.length(value) > 100 -> String.slice(value, 0, 100) <> "..."
      true -> value
    end
  end

  defp sanitize_sensitive_data(value), do: value
end
