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

  alias WandererApp.Api.UserActivity

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
    # store_audit_entry(audit_entry)

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
    details = Map.merge(details, request_details)

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
  Track map-related events (compatibility with Map.Audit).
  """
  def track_map_event(
        event_type,
        %{character_id: character_id, user_id: user_id, map_id: map_id} = metadata
      )
      when not is_nil(character_id) and not is_nil(user_id) and not is_nil(map_id) do
    # Sanitize and prepare metadata
    sanitized_metadata =
      metadata
      |> Map.drop([:character_id, :user_id, :map_id])
      |> sanitize_metadata()

    attrs = %{
      character_id: character_id,
      user_id: user_id,
      entity_type: :map,
      entity_id: map_id,
      event_type: normalize_event_type(event_type),
      event_data: Jason.encode!(sanitized_metadata)
    }

    case UserActivity.new(attrs) do
      {:ok, activity} ->
        {:ok, activity}

      {:error, error} ->
        Logger.error("Failed to track map event",
          error: inspect(error),
          event_type: event_type,
          map_id: map_id
        )

        {:error, error}
    end
  end

  def track_map_event(_event_type, _metadata), do: {:ok, nil}

  @doc """
  Track ACL-related events (compatibility with Map.Audit).
  """
  def track_acl_event(
        event_type,
        %{user_id: user_id, acl_id: acl_id} = metadata
      )
      when not is_nil(user_id) and not is_nil(acl_id) do
    # Sanitize and prepare metadata
    sanitized_metadata =
      metadata
      |> Map.drop([:user_id, :acl_id])
      |> sanitize_metadata()

    attrs = %{
      user_id: user_id,
      entity_type: :access_list,
      entity_id: acl_id,
      event_type: normalize_event_type(event_type),
      event_data: Jason.encode!(sanitized_metadata)
    }

    case UserActivity.new(attrs) do
      {:ok, activity} ->
        {:ok, activity}

      {:error, error} ->
        Logger.error("Failed to track ACL event",
          error: inspect(error),
          event_type: event_type,
          acl_id: acl_id
        )

        {:error, error}
    end
  end

  def track_acl_event(_event_type, _metadata), do: {:ok, nil}

  @doc """
  Get activity query for maps (compatibility with Map.Audit).
  """
  def get_map_activity_query(map_id, period, activity \\ "all") do
    {from, to} = get_period(period)

    query =
      UserActivity
      |> Ash.Query.filter(
        and: [
          [entity_id: map_id],
          [inserted_at: [greater_than_or_equal: from]],
          [inserted_at: [less_than_or_equal: to]]
        ]
      )

    query =
      case activity do
        "all" ->
          query

        activity ->
          query
          |> Ash.Query.filter(event_type: normalize_event_type(activity))
      end

    query
    |> Ash.Query.sort(inserted_at: :desc)
  end

  defp get_period("1H") do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -1 * 3600, :second)
    {start_date, now}
  end

  defp get_period("1D") do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -24 * 3600, :second)
    {start_date, now}
  end

  defp get_period("1W") do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -24 * 3600 * 7, :second)
    {start_date, now}
  end

  defp get_period("1M") do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -24 * 3600 * 31, :second)
    {start_date, now}
  end

  defp get_period("2M") do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -24 * 3600 * 31 * 2, :second)
    {start_date, now}
  end

  defp get_period("3M") do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -24 * 3600 * 31 * 3, :second)
    {start_date, now}
  end

  defp get_period(_), do: get_period("1H")

  @doc """
  Check for suspicious patterns in user activity.
  """
  def analyze_user_behavior(user_id, time_window \\ 3600) do
    now = DateTime.utc_now()
    from_time = DateTime.add(now, -time_window, :second)

    # Get recent activities
    activities =
      UserActivity
      |> Ash.Query.filter(user_id: user_id)
      |> Ash.Query.filter(entity_type: :security_event)
      |> Ash.Query.filter(inserted_at: [greater_than_or_equal: from_time])
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    # Analyze patterns
    patterns = analyze_patterns(activities)
    risk_score = calculate_risk_score(patterns)
    recommendations = generate_recommendations(patterns, risk_score)

    %{
      risk_score: risk_score,
      suspicious_patterns: patterns,
      recommendations: recommendations,
      activities_analyzed: length(activities),
      time_window_seconds: time_window
    }
  end

  defp analyze_patterns(activities) do
    patterns = []

    # Count by event type
    event_counts = Enum.frequencies_by(activities, & &1.event_type)

    # Check for multiple auth failures
    auth_failures = Map.get(event_counts, :auth_failure, 0)

    patterns =
      if auth_failures >= 3 do
        [{:multiple_auth_failures, auth_failures} | patterns]
      else
        patterns
      end

    # Check for permission denied spikes
    permission_denied = Map.get(event_counts, :permission_denied, 0)

    patterns =
      if permission_denied >= 5 do
        [{:excessive_permission_denials, permission_denied} | patterns]
      else
        patterns
      end

    # Check for rapid activity (more than 100 events in time window)
    patterns =
      if length(activities) > 100 do
        [{:high_activity_volume, length(activities)} | patterns]
      else
        patterns
      end

    # Check for geographic anomalies by analyzing unique IPs
    unique_ips =
      activities
      |> Enum.map(fn activity ->
        case Jason.decode(activity.event_data || "{}") do
          {:ok, data} -> data["ip_address"]
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    patterns =
      if unique_ips > 5 do
        [{:multiple_ip_addresses, unique_ips} | patterns]
      else
        patterns
      end

    patterns
  end

  defp calculate_risk_score(patterns) do
    score =
      Enum.reduce(patterns, 0, fn
        {:multiple_auth_failures, count}, acc -> acc + count * 2
        {:excessive_permission_denials, count}, acc -> acc + count * 1.5
        {:high_activity_volume, _}, acc -> acc + 5
        {:multiple_ip_addresses, count}, acc -> acc + count * 3
        _, acc -> acc
      end)

    cond do
      score >= 20 -> :critical
      score >= 10 -> :high
      score >= 5 -> :medium
      true -> :low
    end
  end

  defp generate_recommendations(patterns, risk_score) do
    base_recommendations =
      case risk_score do
        :critical -> ["Immediate review required", "Consider blocking user temporarily"]
        :high -> ["Monitor user activity closely", "Review recent actions"]
        :medium -> ["Keep user under observation"]
        :low -> []
      end

    pattern_recommendations =
      Enum.flat_map(patterns, fn
        {:multiple_auth_failures, _} ->
          ["Reset user password", "Enable MFA"]

        {:excessive_permission_denials, _} ->
          ["Review user permissions", "Check for compromised account"]

        {:high_activity_volume, _} ->
          ["Check for automated activity", "Review API usage"]

        {:multiple_ip_addresses, _} ->
          ["Verify user location changes", "Check for account sharing"]

        _ ->
          []
      end)

    Enum.uniq(base_recommendations ++ pattern_recommendations)
  end

  # Private functions

  defp store_audit_entry(audit_entry) do
    # Handle async processing if enabled
    # if async_enabled?() do
    #   WandererApp.SecurityAudit.AsyncProcessor.log_event(audit_entry)
    # else
    #   do_store_audit_entry(audit_entry)
    # end
  end

  @doc false
  def do_store_audit_entry(audit_entry) do
    # Ensure event_type is properly formatted
    event_type = normalize_event_type(audit_entry.event_type)

    attrs = %{
      user_id: audit_entry.user_id,
      character_id: nil,
      entity_id: hash_identifier(audit_entry.session_id),
      entity_type: :security_event,
      event_type: event_type,
      event_data: encode_event_data(audit_entry)
    }

    case UserActivity.new(attrs) do
      {:ok, _activity} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to store security audit entry",
          error: inspect(error),
          event_type: event_type,
          user_id: audit_entry.user_id
        )

        # Emit telemetry for monitoring
        :telemetry.execute(
          [:wanderer_app, :security_audit, :storage_error],
          %{count: 1},
          %{event_type: event_type, error: error}
        )

        # Don't block the request, but track the failure
        {:error, :storage_failed}
    end
  end

  defp hash_identifier(identifier) when is_binary(identifier) do
    secret_salt =
      Application.get_env(:wanderer_app, :secret_key_base) ||
        raise "SECRET_KEY_BASE not configured"

    :crypto.hash(:sha256, secret_salt <> identifier)
    |> Base.encode16(case: :lower)
  end

  defp hash_identifier(nil), do: generate_entity_id()

  defp normalize_event_type(event_type) when is_atom(event_type), do: event_type

  defp normalize_event_type(event_type) when is_binary(event_type) do
    try do
      String.to_existing_atom(event_type)
    rescue
      ArgumentError -> :security_alert
    end
  end

  defp normalize_event_type(_), do: :security_alert

  defp encode_event_data(audit_entry) do
    sanitized_details = sanitize_for_json(audit_entry.details)

    data =
      Map.merge(sanitized_details, %{
        timestamp: convert_datetime(audit_entry.timestamp),
        severity: to_string(audit_entry.severity),
        ip_address: audit_entry.ip_address,
        user_agent: audit_entry.user_agent
      })

    case Jason.encode(data) do
      {:ok, json} -> json
      {:error, _} -> Jason.encode!(%{error: "Failed to encode audit data"})
    end
  end

  defp sanitize_for_json(data) when is_map(data) do
    data
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      sanitized_key = to_string(key)

      # Skip sensitive fields
      if sanitized_key in ~w(password secret token private_key api_key) do
        acc
      else
        Map.put(acc, sanitized_key, sanitize_value(value))
      end
    end)
  end

  defp sanitize_for_json(data), do: sanitize_value(data)

  defp sanitize_metadata(metadata) do
    # List of sensitive keys to remove from metadata
    sensitive_keys = [:password, :token, :secret, :api_key, :private_key, :auth_token]

    metadata
    |> Map.drop(sensitive_keys)
    |> Enum.map(fn {k, v} ->
      # Ensure keys are strings or atoms
      key = if is_binary(k), do: k, else: to_string(k)
      {key, sanitize_value(v)}
    end)
    |> Enum.into(%{})
  end

  defp sanitize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp sanitize_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp sanitize_value(%Date{} = date), do: Date.to_iso8601(date)
  defp sanitize_value(%Time{} = time), do: Time.to_iso8601(time)

  defp sanitize_value(atom) when is_atom(atom) and not is_nil(atom) and not is_boolean(atom),
    do: to_string(atom)

  defp sanitize_value(list) when is_list(list), do: Enum.map(list, &sanitize_value/1)
  defp sanitize_value(map) when is_map(map), do: sanitize_for_json(map)
  defp sanitize_value(value), do: value

  defp convert_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp convert_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp convert_datetime(value), do: value

  defp generate_entity_id do
    "audit_#{DateTime.utc_now() |> DateTime.to_unix(:microsecond)}_#{System.unique_integer([:positive])}"
  end

  defp async_enabled? do
    Application.get_env(:wanderer_app, __MODULE__, [])
    |> Keyword.get(:async, false)
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

      :security_alert ->
        # Already a security alert, don't double-check
        :ok

      _ ->
        :ok
    end
  end

  defp check_failed_login_attempts(audit_entry) do
    config = threat_detection_config()

    if config[:enabled] do
      ip_address = audit_entry.ip_address || "unknown"
      cache_key = "auth_failures:#{ip_address}"
      window = config[:window_seconds] || 300
      max_attempts = config[:max_failed_attempts] || 5

      # Increment counter in Cachex with TTL
      count =
        case Cachex.incr(:wanderer_app_cache, cache_key) do
          {:ok, count} ->
            # Set TTL on first increment
            if count == 1 do
              Cachex.expire(:wanderer_app_cache, cache_key, :timer.seconds(window))
            end

            count

          {:error, :no_key} ->
            # Key doesn't exist, initialize it with TTL
            case Cachex.put(:wanderer_app_cache, cache_key, 1, ttl: :timer.seconds(window)) do
              {:ok, _} ->
                1

              {:error, error} ->
                Logger.error("Failed to initialize auth failure counter",
                  error: inspect(error),
                  cache_key: cache_key
                )

                1
            end

          {:error, error} ->
            # Other errors - log and return safe default
            Logger.error("Failed to increment auth failure counter",
              error: inspect(error),
              cache_key: cache_key
            )

            1
        end

      if count >= max_attempts do
        Logger.warning("Potential brute force attack detected",
          ip_address: ip_address,
          attempts: count,
          user_id: audit_entry.user_id
        )

        # Emit security alert
        :telemetry.execute(
          [:wanderer_app, :security_audit, :threat_detected],
          %{count: 1},
          %{threat_type: :brute_force, ip_address: ip_address}
        )

        # Log a security alert event
        log_event(:security_alert, audit_entry.user_id, %{
          threat_type: "brute_force",
          ip_address: ip_address,
          failed_attempts: count,
          window_seconds: window
        })
      end
    end

    :ok
  end

  defp check_privilege_escalation_attempts(audit_entry) do
    config = threat_detection_config()

    if config[:enabled] && audit_entry.user_id do
      cache_key = "privilege_escalation:#{audit_entry.user_id}"
      window = config[:window_seconds] || 300
      max_denials = config[:max_permission_denials] || 10

      count =
        case Cachex.incr(:wanderer_app_cache, cache_key) do
          {:ok, count} ->
            if count == 1 do
              Cachex.expire(:wanderer_app_cache, cache_key, :timer.seconds(window))
            end

            count

          {:error, :no_key} ->
            # Key doesn't exist, initialize it with TTL
            case Cachex.put(:wanderer_app_cache, cache_key, 1, ttl: :timer.seconds(window)) do
              {:ok, _} ->
                1

              {:error, error} ->
                Logger.error("Failed to initialize privilege escalation counter",
                  error: inspect(error),
                  cache_key: cache_key
                )

                1
            end

          {:error, error} ->
            # Other errors - log and return safe default
            Logger.error("Failed to increment privilege escalation counter",
              error: inspect(error),
              cache_key: cache_key
            )

            1
        end

      if count >= max_denials do
        Logger.warning("Potential privilege escalation attempt detected",
          user_id: audit_entry.user_id,
          denials: count,
          resource_type: audit_entry.details[:resource_type]
        )

        :telemetry.execute(
          [:wanderer_app, :security_audit, :threat_detected],
          %{count: 1},
          %{threat_type: :privilege_escalation, user_id: audit_entry.user_id}
        )
      end
    end

    :ok
  end

  defp check_bulk_data_access(audit_entry) do
    config = threat_detection_config()

    if config[:enabled] && audit_entry.user_id do
      record_count = audit_entry.details[:record_count] || 0
      threshold = config[:bulk_operation_threshold] || 10000

      if record_count > threshold do
        Logger.warning("Large bulk operation detected",
          user_id: audit_entry.user_id,
          operation_type: audit_entry.details[:operation_type],
          record_count: record_count
        )

        :telemetry.execute(
          [:wanderer_app, :security_audit, :bulk_operation],
          %{record_count: record_count},
          %{user_id: audit_entry.user_id, operation_type: audit_entry.details[:operation_type]}
        )
      end
    end

    :ok
  end

  defp threat_detection_config do
    Application.get_env(:wanderer_app, __MODULE__, [])
    |> Keyword.get(:threat_detection, %{})
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
    # Patterns to detect sensitive data
    sensitive_patterns = [
      ~r/password/i,
      ~r/token/i,
      ~r/secret/i,
      ~r/api[_-]?key/i,
      ~r/private[_-]?key/i,
      ~r/access[_-]?key/i,
      ~r/auth/i,
      ~r/bearer\s+[a-zA-Z0-9\-_]+/i,
      # Long hex strings (potential tokens)
      ~r/[a-f0-9]{32,}/i
    ]

    # Check if value contains sensitive patterns
    is_sensitive = Enum.any?(sensitive_patterns, &Regex.match?(&1, value))

    cond do
      is_sensitive -> "[REDACTED]"
      String.length(value) > 200 -> String.slice(value, 0, 200) <> "..."
      true -> value
    end
  end

  defp sanitize_sensitive_data(value) when is_map(value) do
    # Recursively sanitize map values
    Map.new(value, fn {k, v} ->
      key_str = to_string(k)

      if Regex.match?(~r/password|token|secret|key|auth/i, key_str) do
        {k, "[REDACTED]"}
      else
        {k, sanitize_sensitive_data(v)}
      end
    end)
  end

  defp sanitize_sensitive_data(value) when is_list(value) do
    Enum.map(value, &sanitize_sensitive_data/1)
  end

  defp sanitize_sensitive_data(value), do: value
end
