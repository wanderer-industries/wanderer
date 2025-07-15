defmodule WandererApp.MapDuplicationTest do
  use WandererAppWeb.ConnCase, async: true

  alias WandererApp.ExternalEvents.Event

  # Factory not needed for this test

  describe "map duplication" do
    test "rally point events are supported in external events system" do
      supported_types = Event.supported_event_types()

      assert :rally_point_added in supported_types
      assert :rally_point_removed in supported_types
    end

    test "rally point event types validate correctly" do
      assert Event.valid_event_type?(:rally_point_added)
      assert Event.valid_event_type?(:rally_point_removed)
      refute Event.valid_event_type?(:invalid_rally_event)
    end
  end
end
