defmodule WandererAppWeb.Api.EventsController do
  @moduledoc """
  Controller for Server-Sent Events (SSE) streaming.
  
  Provides real-time event streaming for map updates to external clients.
  """
  
  use WandererAppWeb, :controller
  
  alias WandererApp.ExternalEvents.{SseStreamManager, EventFilter, MapEventRelay}
  alias WandererApp.Api.Map, as: ApiMap
  alias Plug.Crypto
  
  require Logger
  
  @doc """
  Establishes an SSE connection for streaming map events.
  
  Query parameters:
  - events: Comma-separated list of event types to filter (optional)
  - last_event_id: ULID of last received event for backfill (optional)
  """
  def stream(conn, %{"map_identifier" => map_identifier} = params) do
    Logger.info("SSE stream requested for map #{map_identifier}")
    
    # Check if SSE is enabled
    unless WandererApp.Env.sse_enabled?() do
      conn
      |> put_status(:service_unavailable)
      |> put_resp_content_type("text/plain")
      |> send_resp(503, "Server-Sent Events are disabled on this server")
    else
    
    # Validate API key and get map
    case validate_api_key(conn, map_identifier) do
      {:ok, map, api_key} ->
        establish_sse_connection(conn, map.id, api_key, params)
        
      {:error, status, message} ->
        conn
        |> put_status(status)
        |> json(%{error: message})
    end
    end
  end
  
  defp establish_sse_connection(conn, map_id, api_key, params) do
    # Parse event filter if provided
    event_filter = 
      case Map.get(params, "events") do
        nil -> :all
        events -> EventFilter.parse(events)
      end
    
    # Send SSE headers
    conn = send_headers(conn)
    
    # Track the connection
    case SseStreamManager.add_client(map_id, api_key, self(), event_filter) do
      {:ok, _} ->
        # Send initial connection event
        conn = send_event(conn, %{
          id: Ulid.generate(),
          event: "connected",
          data: %{
            map_id: map_id,
            server_time: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
        
        # Handle backfill if last_event_id is provided
        conn = 
          case Map.get(params, "last_event_id") do
            nil -> 
              conn
              
            last_event_id ->
              send_backfill_events(conn, map_id, last_event_id, event_filter)
          end
        
        # Subscribe to map events
        Phoenix.PubSub.subscribe(WandererApp.PubSub, "external_events:map:#{map_id}")
        
        # Start streaming loop
        stream_events(conn, map_id, api_key, event_filter)
        
      {:error, :map_limit_exceeded} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Too many connections to this map",
          code: "MAP_CONNECTION_LIMIT"
        })
        
      {:error, :api_key_limit_exceeded} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Too many connections for this API key",
          code: "API_KEY_CONNECTION_LIMIT"
        })
        
      {:error, reason} ->
        Logger.error("Failed to add SSE client: #{inspect(reason)}")
        conn
        |> put_status(:internal_server_error)
        |> send_resp(500, "Internal server error")
    end
  end
  
  defp send_backfill_events(conn, map_id, last_event_id, event_filter) do
    case MapEventRelay.get_events_since_ulid(map_id, last_event_id) do
      {:ok, events} ->
        # Filter and send each event
        Enum.reduce(events, conn, fn event_json, acc_conn ->
          case Jason.decode(event_json) do
            {:ok, event} ->
              if EventFilter.matches?(event["type"], event_filter) do
                send_event(acc_conn, event)
              else
                acc_conn
              end
              
            {:error, reason} ->
              Logger.error("Failed to decode event during backfill: #{inspect(reason)}")
              acc_conn
          end
        end)
        
      {:error, reason} ->
        Logger.error("Failed to backfill events: #{inspect(reason)}")
        conn
    end
  end
  
  defp stream_events(conn, map_id, api_key, event_filter) do
    receive do
      {:external_event, event_json} ->
        # Parse and check if event matches filter
        conn = 
          case Jason.decode(event_json) do
            {:ok, event} ->
              if EventFilter.matches?(event["type"], event_filter) do
                send_event(conn, event)
              else
                conn
              end
              
            {:error, reason} ->
              Logger.error("Failed to decode event in stream: #{inspect(reason)}")
              conn
          end
        
        # Continue streaming
        stream_events(conn, map_id, api_key, event_filter)
        
      :keepalive ->
        # Send keepalive
        conn = send_keepalive(conn)
        
        # Continue streaming
        stream_events(conn, map_id, api_key, event_filter)
        
      _ ->
        # Unknown message, continue
        stream_events(conn, map_id, api_key, event_filter)
        
    after
      30_000 ->
        # Send keepalive every 30 seconds
        conn = send_keepalive(conn)
        stream_events(conn, map_id, api_key, event_filter)
    end
  rescue
    _error in [Plug.Conn.WrapperError, DBConnection.ConnectionError] ->
      # Connection closed, cleanup
      Logger.info("SSE connection closed for map #{map_id}")
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
        {:error, :unauthorized, "Missing or invalid 'Bearer' token"}

      {:error, :not_found} ->
        Logger.warning("Map not found: #{map_identifier}")
        {:error, :not_found, "Map not found"}

      false ->
        Logger.warning("Unauthorized: invalid token for map #{map_identifier}")
        {:error, :unauthorized, "Unauthorized (invalid token for map)"}

      error ->
        Logger.error("Unexpected error validating API key: #{inspect(error)}")
        {:error, :internal_server_error, "Unexpected error"}
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
  
  defp send_event(conn, event) when is_map(event) do
    sse_data = format_sse_event(event)
    
    case chunk(conn, sse_data) do
      {:ok, conn} ->
        conn
        
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
        
      {:error, reason} ->
        Logger.error("Failed to send SSE keepalive: #{inspect(reason)}")
        # Return the connection as-is since we can't recover from chunk errors
        # The error will be caught by the stream_events rescue clause
        conn
    end
  end
  
  defp format_sse_event(event) do
    data = []
    
    # Add event type if present
    data = 
      case Map.get(event, :event) do
        nil -> data
        event_type -> ["event: #{event_type}\n" | data]
      end
    
    # Add ID if present
    data = 
      case Map.get(event, :id) do
        nil -> data
        id -> ["id: #{id}\n" | data]
      end
    
    # Add data (required)
    data = 
      case Map.get(event, :data) do
        nil -> 
          ["data: \n" | data]
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