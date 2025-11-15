defmodule WandererAppWeb.Api.EventsController do
  @moduledoc """
  Controller for Server-Sent Events (SSE) streaming.

  Provides real-time event streaming for map updates to external clients.

  ## Error Handling

  All error responses use structured JSON format for consistency with the API:

      {
        "error": "Human-readable error message",
        "code": "MACHINE_READABLE_CODE",
        "status": 403
      }

  ## Error Codes

  - `SSE_GLOBALLY_DISABLED` - SSE disabled in server configuration
  - `SSE_DISABLED_FOR_MAP` - SSE disabled for this specific map
  - `SUBSCRIPTION_REQUIRED` - Active subscription required (Enterprise mode)
  - `MAP_NOT_FOUND` - Requested map does not exist
  - `UNAUTHORIZED` - Invalid or missing API key
  - `MAP_CONNECTION_LIMIT` - Too many concurrent connections to this map
  - `API_KEY_CONNECTION_LIMIT` - Too many connections for this API key
  - `INTERNAL_SERVER_ERROR` - Unexpected server error

  ## Access Control

  SSE connections require:
  1. Valid API key (Bearer token)
  2. SSE enabled globally (server config)
  3. SSE enabled for the specific map
  4. Active subscription (Enterprise mode only)

  See `WandererApp.ExternalEvents.SseAccessControl` for details.
  """

  use WandererAppWeb, :controller

  alias WandererApp.ExternalEvents.{
    SseStreamManager,
    EventFilter,
    MapEventRelay,
    JsonApiFormatter
  }

  alias WandererApp.Api.Map, as: ApiMap
  alias Plug.Crypto

  require Logger

  @doc """
  Establishes an SSE connection for streaming map events.

  Query parameters:
  - events: Comma-separated list of event types to filter (optional)
  - last_event_id: ULID of last received event for backfill (optional)
  - format: Event format - "legacy" (default) or "jsonapi" for JSON:API compliance
  """
  def stream(conn, %{"map_identifier" => map_identifier} = params) do
    case validate_api_key(conn, map_identifier) do
      {:ok, map, api_key} ->
        case WandererApp.ExternalEvents.SseAccessControl.sse_allowed?(map.id) do
          :ok ->
            establish_sse_connection(conn, map.id, api_key, params)

          {:error, :sse_globally_disabled} ->
            send_sse_error(
              conn,
              503,
              "Server-Sent Events are disabled on this server",
              "SSE_GLOBALLY_DISABLED"
            )

          {:error, :sse_disabled_for_map} ->
            send_sse_error(
              conn,
              403,
              "Server-Sent Events are disabled for this map",
              "SSE_DISABLED_FOR_MAP"
            )

          {:error, :subscription_required} ->
            send_sse_error(
              conn,
              402,
              "Active subscription required for Server-Sent Events",
              "SUBSCRIPTION_REQUIRED"
            )

          {:error, _reason} ->
            send_sse_error(
              conn,
              403,
              "Server-Sent Events not available",
              "SSE_NOT_AVAILABLE"
            )
        end

      {:error, status, message} ->
        # Map validation errors to appropriate codes
        code =
          case status do
            401 -> "UNAUTHORIZED"
            404 -> "MAP_NOT_FOUND"
            _ -> "SSE_ERROR"
          end

        send_sse_error(conn, status, message, code)
    end
  end

  defp establish_sse_connection(conn, map_id, api_key, params) do
    # Parse event filter if provided
    event_filter = EventFilter.parse(Map.get(params, "events"))

    # Parse format parameter
    event_format = Map.get(params, "format", "legacy")

    # Log full SSE subscription details
    Logger.debug(fn ->
      "SSE client subscription - map: #{map_id}, api_key: #{String.slice(api_key, 0..7)}..., events_param: #{inspect(Map.get(params, "events"))}, parsed_filter: #{inspect(event_filter)}, all_params: #{inspect(params)}"
    end)

    # Send SSE headers
    conn = send_headers(conn)

    # Track the connection
    Logger.debug(fn ->
      "SSE registering client with SseStreamManager: pid=#{inspect(self())}, map_id=#{map_id}"
    end)

    case SseStreamManager.add_client(map_id, api_key, self(), event_filter) do
      {:ok, _} ->
        Logger.debug(fn -> "SSE client registered successfully with SseStreamManager" end)
        # Send initial connection event
        conn =
          send_event(
            conn,
            %{
              id: Ecto.ULID.generate(),
              event: "connected",
              data: %{
                map_id: map_id,
                server_time: DateTime.utc_now() |> DateTime.to_iso8601()
              }
            },
            event_format
          )

        # Handle backfill if last_event_id is provided
        conn =
          case Map.get(params, "last_event_id") do
            nil ->
              conn

            last_event_id ->
              send_backfill_events(conn, map_id, last_event_id, event_filter, event_format)
          end

        # Subscribe to map events
        Phoenix.PubSub.subscribe(WandererApp.PubSub, "external_events:map:#{map_id}")

        # Start streaming loop
        stream_events(conn, map_id, api_key, event_filter, event_format)

      {:error, :map_limit_exceeded} ->
        send_sse_error(
          conn,
          429,
          "Too many connections to this map",
          "MAP_CONNECTION_LIMIT"
        )

      {:error, :api_key_limit_exceeded} ->
        send_sse_error(
          conn,
          429,
          "Too many connections for this API key",
          "API_KEY_CONNECTION_LIMIT"
        )

      {:error, reason} ->
        Logger.error("Failed to add SSE client: #{inspect(reason)}")
        send_sse_error(conn, 500, "Internal server error", "INTERNAL_SERVER_ERROR")
    end
  end

  defp send_backfill_events(conn, map_id, last_event_id, event_filter, event_format) do
    case MapEventRelay.get_events_since_ulid(map_id, last_event_id) do
      {:ok, events} ->
        # Filter and send each event
        Enum.reduce(events, conn, fn event_data, acc_conn ->
          # Handle both JSON strings and already decoded events
          event =
            case event_data do
              binary when is_binary(binary) ->
                case Jason.decode(binary) do
                  {:ok, decoded} ->
                    decoded

                  {:error, reason} ->
                    Logger.error("Failed to decode event during backfill: #{inspect(reason)}")
                    nil
                end

              map when is_map(map) ->
                map

              _ ->
                nil
            end

          if event && EventFilter.matches?(event["type"], event_filter) do
            # Log ACL events filtering for debugging
            if event["type"] in ["acl_member_added", "acl_member_removed", "acl_member_updated"] do
              Logger.debug(fn ->
                "EventFilter.matches? - event_type: #{event["type"]}, filter: #{inspect(event_filter)}, result: true (backfill)"
              end)
            end

            send_event(acc_conn, event, event_format)
          else
            # Log ACL events filtering for debugging
            if event &&
                 event["type"] in ["acl_member_added", "acl_member_removed", "acl_member_updated"] do
              Logger.debug(fn ->
                "EventFilter.matches? - event_type: #{event["type"]}, filter: #{inspect(event_filter)}, result: false (backfill)"
              end)
            end

            acc_conn
          end
        end)

      {:error, reason} ->
        Logger.error("Failed to backfill events: #{inspect(reason)}")
        conn
    end
  end

  defp stream_events(conn, map_id, api_key, event_filter, event_format) do
    receive do
      {:sse_event, event_json} ->
        Logger.debug(fn ->
          "SSE received sse_event message: #{inspect(String.slice(inspect(event_json), 0, 200))}..."
        end)

        # Parse and check if event matches filter
        # Handle both JSON strings and already decoded events
        event =
          case event_json do
            binary when is_binary(binary) ->
              case Jason.decode(binary) do
                {:ok, decoded} ->
                  decoded

                {:error, reason} ->
                  Logger.error("Failed to decode event in stream: #{inspect(reason)}")
                  nil
              end

            map when is_map(map) ->
              map

            _ ->
              nil
          end

        conn =
          if event do
            event_type = event["type"]
            Logger.debug(fn -> "SSE decoded event: type=#{event_type}, checking filter..." end)

            if EventFilter.matches?(event_type, event_filter) do
              # Log ACL events filtering for debugging
              if event_type in ["acl_member_added", "acl_member_removed", "acl_member_updated"] do
                Logger.debug(fn ->
                  "EventFilter.matches? - event_type: #{event_type}, filter: #{inspect(event_filter)}, result: true (streaming)"
                end)
              end

              Logger.debug(fn -> "SSE event matches filter, sending to client: #{event_type}" end)
              send_event(conn, event, event_format)
            else
              # Log ACL events filtering for debugging
              if event_type in ["acl_member_added", "acl_member_removed", "acl_member_updated"] do
                Logger.debug(fn ->
                  "EventFilter.matches? - event_type: #{event_type}, filter: #{inspect(event_filter)}, result: false (streaming)"
                end)
              end

              Logger.debug(fn ->
                "SSE event filtered out: #{event_type} not in #{inspect(event_filter)}"
              end)

              conn
            end
          else
            Logger.error("SSE could not parse event: #{inspect(event_json)}")
            conn
          end

        # Continue streaming
        stream_events(conn, map_id, api_key, event_filter, event_format)

      :keepalive ->
        Logger.debug(fn -> "SSE received keepalive message" end)
        # Send keepalive
        conn = send_keepalive(conn)
        # Continue streaming
        stream_events(conn, map_id, api_key, event_filter, event_format)

      other ->
        Logger.debug(fn -> "SSE received unknown message: #{inspect(other)}" end)
        # Unknown message, continue
        stream_events(conn, map_id, api_key, event_filter, event_format)
    after
      30_000 ->
        Logger.debug(fn -> "SSE timeout after 30s, sending keepalive" end)
        # Send keepalive every 30 seconds
        conn = send_keepalive(conn)
        stream_events(conn, map_id, api_key, event_filter, event_format)
    end
  rescue
    _error in [Plug.Conn.WrapperError, DBConnection.ConnectionError] ->
      # Connection closed, cleanup
      Logger.debug(fn -> "SSE connection closed for map #{map_id}" end)
      SseStreamManager.remove_client(map_id, api_key, self())
      conn

    error ->
      # Log unexpected errors before cleanup
      Logger.error("Unexpected error in SSE stream: #{inspect(error)}")
      SseStreamManager.remove_client(map_id, api_key, self())
      reraise error, __STACKTRACE__
  end

  defp validate_api_key(conn, map_identifier) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, map} <- resolve_map(map_identifier),
         true <-
           is_binary(map.public_api_key) &&
             Crypto.secure_compare(map.public_api_key, token) do
      {:ok, map, token}
    else
      [] ->
        Logger.warning("Missing or invalid 'Bearer' token")
        {:error, 401, "Missing or invalid 'Bearer' token"}

      {:error, :not_found} ->
        Logger.warning("Map not found: #{map_identifier}")
        {:error, 404, "Map not found"}

      false ->
        Logger.warning("Unauthorized: invalid token for map #{map_identifier}")
        {:error, 401, "Unauthorized (invalid token for map)"}

      error ->
        Logger.error("Unexpected error validating API key: #{inspect(error)}")
        {:error, 500, "Unexpected error"}
    end
  end

  defp resolve_map(identifier) do
    case ApiMap.by_id(identifier) do
      {:ok, map} ->
        {:ok, map}

      _ ->
        case ApiMap.get_map_by_slug(identifier) do
          {:ok, map} ->
            {:ok, map}

          _ ->
            {:error, :not_found}
        end
    end
  end

  # Sends a structured JSON error response for SSE connection failures.
  #
  # Returns consistent JSON format matching the rest of the API:
  # - error: Human-readable error message
  # - code: Machine-readable error code for programmatic handling
  # - status: HTTP status code
  #
  # This maintains API consistency and makes it easier for clients to
  # handle errors programmatically.
  defp send_sse_error(conn, status, message, code) do
    conn
    |> put_status(status)
    |> json(%{
      error: message,
      code: code,
      status: status
    })
  end

  # SSE helper functions

  defp send_headers(conn) do
    conn
    |> put_resp_content_type("text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-headers", "Cache-Control")
    |> send_chunked(200)
  end

  defp send_event(conn, event, event_format) when is_map(event) do
    event_type = Map.get(event, "type", Map.get(event, :type, "unknown"))
    event_id = Map.get(event, "id", Map.get(event, :id, "unknown"))

    Logger.debug(fn ->
      "SSE sending event: type=#{event_type}, id=#{event_id}, format=#{event_format}"
    end)

    # Format the event based on the requested format
    formatted_event =
      case event_format do
        "jsonapi" -> JsonApiFormatter.format_legacy_event(event)
        _ -> event
      end

    sse_data = format_sse_event(formatted_event)
    Logger.debug(fn -> "SSE formatted data: #{inspect(String.slice(sse_data, 0, 200))}..." end)

    case chunk(conn, sse_data) do
      {:ok, conn} ->
        Logger.debug(fn -> "SSE event sent successfully: type=#{event_type}" end)
        conn

      {:error, :enotconn} ->
        Logger.debug(fn -> "SSE client disconnected while sending event" end)
        # Client disconnected, raise error to exit the stream loop
        raise Plug.Conn.WrapperError, conn: conn, kind: :error, reason: :enotconn, stack: []

      {:error, reason} ->
        Logger.error("Failed to send SSE event: #{inspect(reason)}")
        # Return the connection as-is since we can't recover from chunk errors
        # The error will be caught by the stream_events rescue clause
        conn
    end
  end

  defp send_keepalive(conn) do
    case chunk(conn, ": keepalive\n\n") do
      {:ok, conn} ->
        conn

      {:error, :enotconn} ->
        # Client disconnected, raise error to exit the stream loop
        raise Plug.Conn.WrapperError, conn: conn, kind: :error, reason: :enotconn, stack: []

      {:error, reason} ->
        Logger.error("Failed to send SSE keepalive: #{inspect(reason)}")
        # Return the connection as-is since we can't recover from chunk errors
        # The error will be caught by the stream_events rescue clause
        conn
    end
  end

  defp format_sse_event(event) do
    data = []

    # Add event type if present (check both string and atom keys)
    data =
      case Map.get(event, "type") || Map.get(event, :event) do
        nil -> data
        event_type -> ["event: #{event_type}\n" | data]
      end

    # Add ID if present (check both string and atom keys)
    data =
      case Map.get(event, "id") || Map.get(event, :id) do
        nil -> data
        id -> ["id: #{id}\n" | data]
      end

    # Add data (required) - use the entire event as data if no specific :data key
    data =
      case Map.get(event, :data) do
        nil ->
          # Use the entire event as JSON data
          json_data = Jason.encode!(event)
          ["data: #{json_data}\n" | data]

        event_data when is_binary(event_data) ->
          ["data: #{event_data}\n" | data]

        event_data ->
          json_data = Jason.encode!(event_data)
          ["data: #{json_data}\n" | data]
      end

    # Reverse to get correct order and add final newline
    data
    |> Enum.reverse()
    |> Enum.join("")
    |> Kernel.<>("\n")
  end
end
