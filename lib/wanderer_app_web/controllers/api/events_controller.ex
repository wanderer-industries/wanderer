defmodule WandererAppWeb.Api.EventsController do
  @moduledoc """
  Controller for Server-Sent Events (SSE) streaming.
  
  Provides real-time event streaming for map updates to external clients.
  """
  
  use WandererAppWeb, :controller
  
  alias WandererApp.ExternalEvents.{SseConnectionTracker, EventFilter, MapEventRelay}
  alias WandererApp.Api.Map, as: ApiMap
  alias WandererAppWeb.SSE
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
    
    # Validate API key and get map
    case validate_api_key(conn, map_identifier) do
      {:ok, map, api_key} ->
        # Check connection limits
        case SseConnectionTracker.check_limits(map.id, api_key) do
          :ok ->
            establish_sse_connection(conn, map.id, api_key, params)
            
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
        end
        
      {:error, status, message} ->
        conn
        |> put_status(status)
        |> json(%{error: message})
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
    conn = SSE.send_headers(conn)
    
    # Track the connection
    :ok = SseConnectionTracker.track_connection(map_id, api_key, self())
    
    # Send initial connection event
    conn = SSE.send_event(conn, %{
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
  end
  
  defp send_backfill_events(conn, map_id, last_event_id, event_filter) do
    case MapEventRelay.get_events_since_ulid(map_id, last_event_id) do
      {:ok, events} ->
        # Filter and send each event
        Enum.reduce(events, conn, fn event_json, acc_conn ->
          event = Jason.decode!(event_json)
          
          if EventFilter.matches?(event["type"], event_filter) do
            SSE.send_event(acc_conn, event)
          else
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
        event = Jason.decode!(event_json)
        
        conn = 
          if EventFilter.matches?(event["type"], event_filter) do
            SSE.send_event(conn, event)
          else
            conn
          end
        
        # Continue streaming
        stream_events(conn, map_id, api_key, event_filter)
        
      :keepalive ->
        # Send keepalive
        conn = SSE.send_keepalive(conn)
        
        # Continue streaming
        stream_events(conn, map_id, api_key, event_filter)
        
      _ ->
        # Unknown message, continue
        stream_events(conn, map_id, api_key, event_filter)
        
    after
      30_000 ->
        # Send keepalive every 30 seconds
        conn = SSE.send_keepalive(conn)
        stream_events(conn, map_id, api_key, event_filter)
    end
  rescue
    _ ->
      # Connection closed, cleanup
      Logger.info("SSE connection closed for map #{map_id}")
      SseConnectionTracker.remove_connection(map_id, api_key, self())
      conn
  end
  
  defp validate_api_key(conn, map_identifier) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, map} <- resolve_map(map_identifier),
         true <- is_binary(map.public_api_key) && 
                 Crypto.secure_compare(map.public_api_key, token)
    do
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
end