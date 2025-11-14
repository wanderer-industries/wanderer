defmodule WandererApp.User.ActivityTracker do
  @moduledoc """
  Activity tracking wrapper that ensures audit logging never crashes application logic.

  Activity tracking is best-effort and errors are logged but not propagated to callers.
  This prevents race conditions (e.g., duplicate activity records) from affecting
  critical business operations like character tracking or connection management.
  """
  require Logger

  @doc """
  Track a map-related event. Always returns `{:ok, result}` even on error.

  Errors (such as unique constraint violations from concurrent operations)
  are logged but do not propagate to prevent crashing critical application logic.
  """
  def track_map_event(event_type, metadata) do
    case WandererApp.Map.Audit.track_map_event(event_type, metadata) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        Logger.warning("Failed to track map event (non-critical)",
          event_type: event_type,
          map_id: metadata[:map_id],
          error: inspect(error),
          reason: :best_effort_tracking
        )

        # Return success to prevent crashes - activity tracking is best-effort
        {:ok, nil}
    end
  end

  @doc """
  Track an ACL-related event. Always returns `{:ok, result}` even on error.

  Errors are logged but do not propagate to prevent crashing critical application logic.
  """
  def track_acl_event(event_type, metadata) do
    case WandererApp.Map.Audit.track_acl_event(event_type, metadata) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        Logger.warning("Failed to track ACL event (non-critical)",
          event_type: event_type,
          acl_id: metadata[:acl_id],
          error: inspect(error),
          reason: :best_effort_tracking
        )

        # Return success to prevent crashes - activity tracking is best-effort
        {:ok, nil}
    end
  end
end
