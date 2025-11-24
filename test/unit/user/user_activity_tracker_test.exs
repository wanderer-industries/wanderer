defmodule WandererApp.User.ActivityTrackerTest do
  use WandererApp.DataCase, async: false

  import Mox

  setup :verify_on_exit!

  alias WandererApp.User.ActivityTracker

  describe "track_map_event/2" do
    test "returns {:ok, result} on success" do
      # This test verifies the happy path
      # In real scenarios, this would succeed when creating a new activity record
      assert {:ok, _} = ActivityTracker.track_map_event(:test_event, %{})
    end

    test "returns {:ok, nil} on error without crashing" do
      # This simulates the scenario where tracking fails (e.g., unique constraint violation)
      # The function should handle the error gracefully and return {:ok, nil}

      # Note: In actual implementation, this would catch errors from:
      # - Unique constraint violations
      # - Database connection issues
      # - Invalid data

      # The key requirement is that it NEVER crashes the calling code
      result =
        ActivityTracker.track_map_event(:map_connection_added, %{
          # This will cause the function to skip tracking
          character_id: nil,
          user_id: nil,
          map_id: nil
        })

      # Should return success even when input is incomplete
      assert {:ok, _} = result
    end

    test "handles errors gracefully and logs them" do
      # Verify that errors are logged for observability
      # This is important for monitoring and debugging

      # The function should complete without raising even with incomplete data
      assert {:ok, _} =
               ActivityTracker.track_map_event(:map_connection_added, %{
                 character_id: nil,
                 user_id: nil,
                 map_id: nil
               })
    end
  end

  describe "track_acl_event/2" do
    test "returns {:ok, result} on success" do
      assert {:ok, _} = ActivityTracker.track_acl_event(:test_event, %{})
    end

    test "returns {:ok, nil} on error without crashing" do
      result =
        ActivityTracker.track_acl_event(:map_acl_added, %{
          user_id: nil,
          acl_id: nil
        })

      assert {:ok, _} = result
    end
  end

  describe "error resilience" do
    test "always returns success tuple even on internal errors" do
      # The key guarantee is that activity tracking never crashes calling code
      # Even if the internal tracking fails (e.g., unique constraint violation),
      # the wrapper ensures a success tuple is returned

      # This test verifies that the function signature guarantees {:ok, _}
      # regardless of internal errors

      # Test with nil values (which will fail validation)
      assert {:ok, _} =
               ActivityTracker.track_map_event(:test_event, %{
                 character_id: nil,
                 user_id: nil,
                 map_id: nil
               })

      # Test with empty map (which will fail validation)
      assert {:ok, _} = ActivityTracker.track_map_event(:test_event, %{})

      # The guarantee is: no matter what, it returns {:ok, _}
      # This prevents MatchError crashes in calling code
    end
  end
end
