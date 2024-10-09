defmodule WandererApp.User.ActivityTracker do
  @moduledoc false
  require Logger

  def track_map_event(
        event_type,
        metadata
      ),
      do: WandererApp.Map.Audit.track_map_event(event_type, metadata)

  def track_acl_event(
        event_type,
        metadata
      ),
      do: WandererApp.Map.Audit.track_acl_event(event_type, metadata)
end
