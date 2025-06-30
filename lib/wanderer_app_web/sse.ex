defmodule WandererAppWeb.SSE do
  @moduledoc """
  Server-Sent Events helper functions for establishing and managing SSE connections.

  Provides utilities for:
  - Setting up SSE response headers
  - Formatting events according to SSE specification
  - Sending events and keepalive messages
  - Handling connection errors gracefully
  """

  import Plug.Conn

  @doc """
  Sets up SSE-specific response headers and begins a chunked response.

  Returns a conn ready for streaming SSE data.
  """
  def send_headers(conn) do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-headers", "authorization")
    # Disable Nginx buffering
    |> put_resp_header("x-accel-buffering", "no")
    |> send_chunked(200)
  end

  @doc """
  Formats an event according to the SSE specification.

  Handles different event formats and includes the event ID for client-side reconnection support.
  """
  def format_event(event) do
    case event do
      %{"id" => id, "event" => type, "data" => data} ->
        # JSON map with string keys
        [
          "id: #{id}\n",
          "event: #{type}\n",
          "data: #{Jason.encode!(data)}\n\n"
        ]
        
      %{id: id, event: type, data: data} ->
        # Atom keys
        [
          "id: #{id}\n",
          "event: #{type}\n",
          "data: #{Jason.encode!(data)}\n\n"
        ]
      
      %{"id" => id, "type" => type} = full_event ->
        # Event from relay (string keys)
        [
          "id: #{id}\n",
          "event: #{type}\n",
          "data: #{Jason.encode!(full_event)}\n\n"
        ]
        
      %{id: id, type: type} = full_event ->
        # Event from relay (atom keys)
        [
          "id: #{id}\n",
          "event: #{type}\n",
          "data: #{Jason.encode!(full_event)}\n\n"
        ]
          
      _ ->
        # Fallback - just send as data
        ["data: #{Jason.encode!(event)}\n\n"]
    end
    |> IO.iodata_to_binary()
  end

  @doc """
  Sends an event to the SSE connection.

  Returns the conn on success.
  """
  def send_event(conn, event) do
    case chunk(conn, format_event(event)) do
      {:ok, conn} -> conn
      {:error, _reason} -> conn
    end
  end

  @doc """
  Sends a keepalive comment to maintain the connection.

  SSE clients ignore lines starting with ':'.
  """
  def send_keepalive(conn) do
    case chunk(conn, ": keepalive\n\n") do
      {:ok, conn} -> conn
      {:error, _reason} -> conn
    end
  end

  @doc """
  Sends a retry hint to the client for reconnection delay.

  Time is in milliseconds.
  """
  def send_retry(conn, time_ms) do
    case chunk(conn, "retry: #{time_ms}\n\n") do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end
end