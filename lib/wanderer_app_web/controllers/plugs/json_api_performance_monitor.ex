defmodule WandererAppWeb.Plugs.JsonApiPerformanceMonitor do
  @moduledoc """
  Plug for monitoring JSON:API v1 endpoint performance.

  This plug emits telemetry events for:
  - Request/response timing
  - Payload sizes
  - Authentication metrics
  - Error tracking
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip monitoring for non-JSON:API endpoints
    if json_api_request?(conn) do
      start_time = System.monotonic_time(:millisecond)

      # Extract request metadata
      request_metadata = extract_request_metadata(conn)

      # Emit request start event
      :telemetry.execute(
        [:wanderer_app, :json_api, :request],
        %{
          count: 1,
          duration: 0,
          payload_size: get_request_payload_size(conn)
        },
        request_metadata
      )

      # Register callback to emit response event
      conn
      |> register_before_send(fn conn ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Extract response metadata
        response_metadata = extract_response_metadata(conn, request_metadata)

        # Emit response event
        :telemetry.execute(
          [:wanderer_app, :json_api, :response],
          %{
            count: 1,
            payload_size: get_response_payload_size(conn)
          },
          response_metadata
        )

        # Emit error event if error status
        if conn.status >= 400 do
          :telemetry.execute(
            [:wanderer_app, :json_api, :error],
            %{count: 1},
            Map.put(response_metadata, :error_type, get_error_type(conn.status))
          )
        end

        conn
      end)
    else
      conn
    end
  end

  defp json_api_request?(conn) do
    String.starts_with?(conn.request_path, "/api/v1/")
  end

  defp extract_request_metadata(conn) do
    %{
      resource: extract_resource_from_path(conn.request_path),
      action: extract_action_from_method_and_path(conn.method, conn.request_path),
      method: conn.method
    }
  end

  defp extract_response_metadata(conn, request_metadata) do
    Map.put(request_metadata, :status_code, conn.status)
  end

  defp extract_resource_from_path(path) do
    case String.split(path, "/") do
      ["", "api", "v1", resource | _] -> resource
      _ -> "unknown"
    end
  end

  defp extract_action_from_method_and_path(method, path) do
    # Basic action mapping based on HTTP method and path structure
    path_parts = String.split(path, "/")

    case {method, length(path_parts)} do
      # /api/v1/characters
      {"GET", 4} -> "index"
      # /api/v1/characters/1
      {"GET", 5} -> "show"
      # /api/v1/characters
      {"POST", 4} -> "create"
      # /api/v1/characters/1
      {"PATCH", 5} -> "update"
      # /api/v1/characters/1
      {"PUT", 5} -> "update"
      # /api/v1/characters/1
      {"DELETE", 5} -> "destroy"
      _ -> "unknown"
    end
  end

  defp get_request_payload_size(conn) do
    case get_req_header(conn, "content-length") do
      [size_str] ->
        case Integer.parse(size_str) do
          {size, ""} -> size
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp get_response_payload_size(conn) do
    case get_resp_header(conn, "content-length") do
      [size_str] ->
        case Integer.parse(size_str) do
          {size, ""} -> size
          _ -> 0
        end

      _ ->
        # Estimate from response body if content-length not set
        case conn.resp_body do
          body when is_binary(body) -> byte_size(body)
          _ -> 0
        end
    end
  end

  defp get_error_type(status_code) do
    case status_code do
      400 -> "bad_request"
      401 -> "unauthorized"
      403 -> "forbidden"
      404 -> "not_found"
      422 -> "unprocessable_entity"
      500 -> "internal_server_error"
      _ -> "unknown"
    end
  end
end
