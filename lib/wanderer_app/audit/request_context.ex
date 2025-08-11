defmodule WandererApp.Audit.RequestContext do
  @moduledoc """
  Provides utilities for extracting request context information
  for audit logging purposes.
  """

  require Logger

  @doc """
  Extract the client's IP address from the connection.

  Simply returns the remote_ip from the connection.
  """
  def get_ip_address(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  rescue
    error ->
      Logger.warning("Failed to get IP address: #{inspect(error)}",
        error: error,
        stacktrace: __STACKTRACE__
      )

      "unknown"
  end

  @doc """
  Extract the user agent from the request headers.
  """
  def get_user_agent(conn) do
    get_header(conn, "user-agent") || "unknown"
  end

  @doc """
  Extract or generate a session ID for the request.
  """
  def get_session_id(conn) do
    # Try to get from session
    session_id = get_session(conn, :session_id)

    # Fall back to request ID
    session_id || get_request_id(conn)
  end

  @doc """
  Extract or generate a request ID for correlation.
  """
  def get_request_id(conn) do
    # Try standard request ID headers
    get_header(conn, "x-request-id") ||
      get_header(conn, "x-correlation-id") ||
      Logger.metadata()[:request_id] ||
      generate_request_id()
  end

  @doc """
  Build a complete request metadata map for audit logging.
  """
  def build_request_metadata(conn) do
    %{
      ip_address: get_ip_address(conn),
      user_agent: get_user_agent(conn),
      session_id: get_session_id(conn),
      request_id: get_request_id(conn),
      request_path: conn.request_path,
      method: conn.method |> to_string() |> String.upcase(),
      host: conn.host,
      port: conn.port,
      scheme: conn.scheme |> to_string()
    }
  end

  @doc """
  Extract user information from the connection.

  Returns a map with user_id and any additional user context.
  """
  def get_user_info(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} = user ->
        %{
          user_id: user_id,
          username: Map.get(user, :username),
          email: Map.get(user, :email)
        }

      nil ->
        %{user_id: nil}
    end
  end

  @doc """
  Build a minimal request details map for audit events.

  This is used by existing audit calls that expect specific fields.
  """
  def build_request_details(conn) do
    metadata = build_request_metadata(conn)

    %{
      ip_address: metadata.ip_address,
      user_agent: metadata.user_agent,
      session_id: metadata.session_id,
      request_path: metadata.request_path,
      method: metadata.method
    }
  end

  @doc """
  Set request context in the process dictionary for async logging.
  """
  def set_request_context(conn) do
    context = %{
      metadata: build_request_metadata(conn),
      user_info: get_user_info(conn),
      timestamp: DateTime.utc_now()
    }

    Process.put(:audit_request_context, context)
    conn
  end

  @doc """
  Get request context from the process dictionary.
  """
  def get_request_context do
    Process.get(:audit_request_context)
  end

  # Private functions

  defp get_header(conn, header) do
    case Plug.Conn.get_req_header(conn, header) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp get_session(conn, key) do
    conn
    |> Plug.Conn.get_session(key)
  rescue
    _ -> nil
  end

  defp generate_request_id do
    "req_#{:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)}"
  end
end
