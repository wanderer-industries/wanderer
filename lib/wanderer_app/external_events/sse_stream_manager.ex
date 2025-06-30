defmodule WandererApp.ExternalEvents.SseStreamManager do
  @moduledoc """
  Manages Server-Sent Events (SSE) connections for maps.
  
  This is a minimal stub implementation to prevent crashes while we test SSE functionality.
  """
  
  require Logger
  
  @doc """
  Broadcasts an event to all SSE clients connected to a map.
  
  This is a stub implementation that just logs the event.
  """
  def broadcast_event(map_id, _event_json) do
    Logger.debug("SseStreamManager.broadcast_event called for map #{map_id}")
    # Stub: just log for now, don't actually broadcast
    :ok
  end
  
  @doc """
  Adds a new SSE client connection.
  
  This is a stub implementation that returns success.
  """
  def add_client(map_id, client_pid, _event_filter) do
    Logger.debug("SseStreamManager.add_client called for map #{map_id}, pid #{inspect(client_pid)}")
    # Stub: just return success
    {:ok, self()}
  end
  
  @doc """
  Removes a client connection.
  
  This is a stub implementation that returns success.
  """
  def remove_client(map_id, client_pid) do
    Logger.debug("SseStreamManager.remove_client called for map #{map_id}, pid #{inspect(client_pid)}")
    # Stub: just return success
    :ok
  end
end