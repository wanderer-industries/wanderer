defmodule WandererAppWeb.Plugs.SecurityAudit do
  @moduledoc """
  Plug for automatic security audit logging of HTTP requests.

  This plug automatically logs security-relevant HTTP requests and responses,
  including authentication attempts, authorization failures, and data access patterns.
  """

  import Plug.Conn

  alias WandererApp.SecurityAudit

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)

    conn
    |> assign(:audit_start_time, start_time)
    |> assign(:audit_request_details, extract_request_details(conn))
    |> register_before_send(&log_response/1)
  end

  defp log_response(conn) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - conn.assigns[:audit_start_time]

    request_details = conn.assigns[:audit_request_details]
    user_id = get_user_id(conn)

    # Log different types of events based on request and response
    case conn.status do
      401 ->
        # Authentication failure
        SecurityAudit.log_auth_event(:auth_failure, user_id, request_details)

      403 ->
        # Authorization failure
        SecurityAudit.log_permission_denied(
          get_resource_type(conn),
          get_resource_id(conn),
          user_id,
          conn.method,
          request_details
        )

      status when status >= 200 and status < 300 ->
        # Successful request - log data access for sensitive endpoints
        if sensitive_endpoint?(conn) do
          SecurityAudit.log_data_access(
            get_resource_type(conn),
            get_resource_id(conn),
            user_id,
            conn.method,
            request_details
          )
        end

        # Log admin actions
        if admin_endpoint?(conn) do
          SecurityAudit.log_admin_action(
            "#{conn.method} #{conn.request_path}",
            user_id,
            get_resource_type(conn),
            request_details
          )
        end

      _ ->
        # Other status codes - log as general events
        :ok
    end

    # Emit telemetry for request monitoring
    :telemetry.execute(
      [:wanderer_app, :http_request, :security_audit],
      %{duration: duration, count: 1},
      %{
        method: conn.method,
        path: conn.request_path,
        status: conn.status,
        user_id: user_id,
        ip_address: request_details[:ip_address]
      }
    )

    conn
  end

  defp extract_request_details(conn) do
    %{
      ip_address: get_peer_ip(conn),
      user_agent: get_user_agent(conn),
      referer: get_referer(conn),
      session_id: get_session_id(conn),
      request_path: conn.request_path,
      query_params: conn.query_params,
      method: conn.method
    }
  end

  defp get_peer_ip(conn) do
    # Handle various proxy headers
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_for] ->
        # Take the first IP from the forwarded-for header
        forwarded_for
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [real_ip] ->
            real_ip

          [] ->
            case conn.remote_ip do
              {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
              _ -> "unknown"
            end
        end
    end
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent] -> user_agent
      [] -> "unknown"
    end
  end

  defp get_referer(conn) do
    case get_req_header(conn, "referer") do
      [referer] -> referer
      [] -> nil
    end
  end

  defp get_session_id(conn) do
    case get_session(conn, :session_id) do
      nil ->
        # Generate a request ID if no session
        conn.assigns[:request_id] || "unknown"

      session_id ->
        session_id
    end
  end

  defp get_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> user_id
      _ -> nil
    end
  end

  defp get_resource_type(conn) do
    # Extract resource type from path
    case conn.path_info do
      ["api", resource_type | _] -> resource_type
      [resource_type | _] -> resource_type
      _ -> "unknown"
    end
  end

  defp get_resource_id(conn) do
    # Extract resource ID from path params
    case conn.path_params do
      %{"id" => id} -> id
      _ -> nil
    end
  end

  defp sensitive_endpoint?(conn) do
    # Define which endpoints are considered sensitive
    sensitive_paths = [
      ~r/^\/api\/characters/,
      ~r/^\/api\/maps/,
      ~r/^\/api\/users/,
      ~r/^\/api\/acls/,
      ~r/^\/auth/,
      ~r/^\/admin/
    ]

    Enum.any?(sensitive_paths, fn pattern ->
      Regex.match?(pattern, conn.request_path)
    end)
  end

  defp admin_endpoint?(conn) do
    # Define which endpoints are admin-only
    admin_paths = [
      ~r/^\/admin/,
      ~r/^\/api\/.*\/admin/,
      ~r/^\/api\/system/
    ]

    Enum.any?(admin_paths, fn pattern ->
      Regex.match?(pattern, conn.request_path)
    end)
  end
end
