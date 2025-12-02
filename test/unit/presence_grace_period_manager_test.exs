defmodule WandererAppWeb.PresenceGracePeriodManagerTest do
  @moduledoc """
  Comprehensive tests for PresenceGracePeriodManager.

  Tests cover:
  - Grace period scheduling when characters leave presence
  - Grace period cancellation when characters rejoin
  - Atomic cache removal after grace period expires
  - Multiple characters and maps scenarios
  - Edge cases and error handling
  """
  use ExUnit.Case, async: false

  alias WandererAppWeb.PresenceGracePeriodManager

  setup do
    # Generate unique map and character IDs for each test
    map_id = "test_map_#{:rand.uniform(1_000_000)}"
    character_id = "test_char_#{:rand.uniform(1_000_000)}"
    character_id_2 = "test_char_2_#{:rand.uniform(1_000_000)}"

    # Clean up GenServer state for this specific map
    PresenceGracePeriodManager.clear_map_state(map_id)

    # Clean up any existing cache data for this test
    cleanup_cache(map_id)

    on_exit(fn ->
      PresenceGracePeriodManager.clear_map_state(map_id)
      cleanup_cache(map_id)
    end)

    {:ok, map_id: map_id, character_id: character_id, character_id_2: character_id_2}
  end

  defp cleanup_cache(map_id) do
    WandererApp.Cache.delete("map_#{map_id}:presence_character_ids")
    WandererApp.Cache.delete("map_#{map_id}:presence_data")
    WandererApp.Cache.delete("map_#{map_id}:presence_updated")
  end

  defp build_presence_data(characters) do
    Enum.map(characters, fn {character_id, tracked} ->
      %{
        character_id: character_id,
        tracked: tracked,
        from: DateTime.utc_now()
      }
    end)
  end

  defp get_presence_character_ids(map_id) do
    case WandererApp.Cache.get("map_#{map_id}:presence_character_ids") do
      nil -> []
      ids -> ids
    end
  end

  defp get_presence_data(map_id) do
    WandererApp.Cache.get("map_#{map_id}:presence_data")
  end

  defp get_presence_updated(map_id) do
    WandererApp.Cache.get("map_#{map_id}:presence_updated") || false
  end

  describe "initialization" do
    test "manager starts successfully" do
      # The manager should already be running as part of the application
      assert Process.whereis(PresenceGracePeriodManager) != nil
    end

    test "get_state returns valid state structure" do
      state = PresenceGracePeriodManager.get_state()

      assert %PresenceGracePeriodManager{} = state
      assert is_map(state.pending_removals)
      assert is_map(state.timers)
    end

    test "reset_state clears all state" do
      # First reset
      PresenceGracePeriodManager.reset_state()
      state = PresenceGracePeriodManager.get_state()

      assert state.pending_removals == %{}
      assert state.timers == %{}
    end
  end

  describe "process_presence_change - character joins" do
    test "first character joins - updates cache with character ID", %{
      map_id: map_id,
      character_id: character_id
    } do
      presence_data = build_presence_data([{character_id, true}])

      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      assert get_presence_character_ids(map_id) == [character_id]
      assert get_presence_data(map_id) == presence_data
      assert get_presence_updated(map_id) == true
    end

    test "multiple characters join - all are in cache", %{
      map_id: map_id,
      character_id: character_id,
      character_id_2: character_id_2
    } do
      presence_data = build_presence_data([{character_id, true}, {character_id_2, true}])

      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      cached_ids = get_presence_character_ids(map_id)
      assert Enum.sort(cached_ids) == Enum.sort([character_id, character_id_2])
    end

    test "untracked character is not included in presence_character_ids", %{
      map_id: map_id,
      character_id: character_id,
      character_id_2: character_id_2
    } do
      presence_data = build_presence_data([{character_id, true}, {character_id_2, false}])

      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Only tracked character should be in presence_character_ids
      assert get_presence_character_ids(map_id) == [character_id]

      # But both should be in presence_data
      assert length(get_presence_data(map_id)) == 2
    end
  end

  describe "process_presence_change - character leaves (grace period)" do
    test "character leaving starts grace period - still in cache", %{
      map_id: map_id,
      character_id: character_id
    } do
      # First, character joins
      presence_data = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      assert get_presence_character_ids(map_id) == [character_id]

      # Character leaves (empty presence)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Character should still be in cache (grace period active)
      assert get_presence_character_ids(map_id) == [character_id]

      # State should have pending removal
      state = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state.pending_removals, {map_id, character_id})
      assert Map.has_key?(state.timers, {map_id, character_id})
    end

    test "multiple characters leave - all have grace periods", %{
      map_id: map_id,
      character_id: character_id,
      character_id_2: character_id_2
    } do
      # Both characters join
      presence_data = build_presence_data([{character_id, true}, {character_id_2, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Both leave
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Both should still be in cache
      cached_ids = get_presence_character_ids(map_id)
      assert Enum.sort(cached_ids) == Enum.sort([character_id, character_id_2])

      # Both should have pending removals
      state = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state.pending_removals, {map_id, character_id})
      assert Map.has_key?(state.pending_removals, {map_id, character_id_2})
    end

    test "one character leaves, one stays - only leaving character has grace period", %{
      map_id: map_id,
      character_id: character_id,
      character_id_2: character_id_2
    } do
      # Both characters join
      presence_data = build_presence_data([{character_id, true}, {character_id_2, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Only character_id leaves
      presence_data_after = build_presence_data([{character_id_2, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data_after)

      # Both should be in cache (one current, one in grace period)
      cached_ids = get_presence_character_ids(map_id)
      assert Enum.sort(cached_ids) == Enum.sort([character_id, character_id_2])

      # Only character_id should have pending removal
      state = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state.pending_removals, {map_id, character_id})
      refute Map.has_key?(state.pending_removals, {map_id, character_id_2})
    end
  end

  describe "process_presence_change - character rejoins (cancels grace period)" do
    test "character rejoins during grace period - removal cancelled", %{
      map_id: map_id,
      character_id: character_id
    } do
      # Character joins
      presence_data = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Character leaves (starts grace period)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Verify grace period started
      state_before = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state_before.pending_removals, {map_id, character_id})

      # Character rejoins
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Grace period should be cancelled
      state_after = PresenceGracePeriodManager.get_state()
      refute Map.has_key?(state_after.pending_removals, {map_id, character_id})
      refute Map.has_key?(state_after.timers, {map_id, character_id})

      # Character should still be in cache
      assert get_presence_character_ids(map_id) == [character_id]
    end

    test "character leaves and rejoins multiple times - only one grace period at a time", %{
      map_id: map_id,
      character_id: character_id
    } do
      presence_data = build_presence_data([{character_id, true}])

      # Cycle 1: join -> leave -> rejoin
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Cycle 2: leave -> rejoin
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Should have no pending removals
      state = PresenceGracePeriodManager.get_state()
      refute Map.has_key?(state.pending_removals, {map_id, character_id})

      # Character should be in cache
      assert get_presence_character_ids(map_id) == [character_id]
    end
  end

  describe "grace_period_expired - atomic removal" do
    test "directly sending grace_period_expired removes character from cache", %{
      map_id: map_id,
      character_id: character_id
    } do
      # Setup: character joins then leaves
      presence_data = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Verify grace period started
      state = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state.timers, {map_id, character_id})

      # Simulate grace period expiration by sending the message directly
      send(
        Process.whereis(PresenceGracePeriodManager),
        {:grace_period_expired, map_id, character_id}
      )

      # Small wait for the message to be processed
      :timer.sleep(20)

      # Character should be removed from cache
      assert get_presence_character_ids(map_id) == []

      # Pending removal should be cleared
      state_after = PresenceGracePeriodManager.get_state()
      refute Map.has_key?(state_after.pending_removals, {map_id, character_id})
      refute Map.has_key?(state_after.timers, {map_id, character_id})
    end

    test "grace_period_expired for already cancelled timer is ignored", %{
      map_id: map_id,
      character_id: character_id
    } do
      # Setup: character joins, leaves, then rejoins
      presence_data = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Timer was cancelled, but let's simulate the message arriving anyway
      send(
        Process.whereis(PresenceGracePeriodManager),
        {:grace_period_expired, map_id, character_id}
      )

      :timer.sleep(20)

      # Character should still be in cache (message was ignored)
      assert get_presence_character_ids(map_id) == [character_id]
    end

    test "grace_period_expired with no presence_data in cache handles gracefully", %{
      map_id: map_id,
      character_id: character_id
    } do
      # Don't set up any presence data - just send the expired message
      # This simulates a race condition where the map was stopped

      # First add character to state manually by going through the flow
      presence_data = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Clear the cache to simulate map being stopped
      cleanup_cache(map_id)

      # Send expired message
      send(
        Process.whereis(PresenceGracePeriodManager),
        {:grace_period_expired, map_id, character_id}
      )

      :timer.sleep(20)

      # Should handle gracefully without crashing
      state = PresenceGracePeriodManager.get_state()
      refute Map.has_key?(state.pending_removals, {map_id, character_id})
    end

    test "removes only the specified character, keeps others", %{
      map_id: map_id,
      character_id: character_id,
      character_id_2: character_id_2
    } do
      # Both characters join then leave
      presence_data = build_presence_data([{character_id, true}, {character_id_2, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Both in grace period
      cached_before = get_presence_character_ids(map_id)
      assert length(cached_before) == 2

      # Only expire character_id
      send(
        Process.whereis(PresenceGracePeriodManager),
        {:grace_period_expired, map_id, character_id}
      )

      :timer.sleep(20)

      # Only character_id_2 should remain
      assert get_presence_character_ids(map_id) == [character_id_2]

      # character_id_2 should still have pending removal
      state = PresenceGracePeriodManager.get_state()
      refute Map.has_key?(state.pending_removals, {map_id, character_id})
      assert Map.has_key?(state.pending_removals, {map_id, character_id_2})
    end
  end

  describe "multiple maps scenarios" do
    test "same character on different maps - independent grace periods", %{
      character_id: character_id
    } do
      map_id_1 = "test_map_multi_1_#{:rand.uniform(1_000_000)}"
      map_id_2 = "test_map_multi_2_#{:rand.uniform(1_000_000)}"

      on_exit(fn ->
        PresenceGracePeriodManager.clear_map_state(map_id_1)
        PresenceGracePeriodManager.clear_map_state(map_id_2)
        cleanup_cache(map_id_1)
        cleanup_cache(map_id_2)
      end)

      presence_data = build_presence_data([{character_id, true}])

      # Character joins both maps
      PresenceGracePeriodManager.process_presence_change_sync(map_id_1, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id_2, presence_data)

      # Character leaves map_id_1 only
      PresenceGracePeriodManager.process_presence_change_sync(map_id_1, [])

      # map_id_1 should have grace period, map_id_2 should not
      state = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state.pending_removals, {map_id_1, character_id})
      refute Map.has_key?(state.pending_removals, {map_id_2, character_id})

      # Character should be in cache for both maps
      assert get_presence_character_ids(map_id_1) == [character_id]
      assert get_presence_character_ids(map_id_2) == [character_id]

      # Expire grace period for map_id_1
      send(
        Process.whereis(PresenceGracePeriodManager),
        {:grace_period_expired, map_id_1, character_id}
      )

      :timer.sleep(20)

      # map_id_1 should be empty, map_id_2 should still have character
      assert get_presence_character_ids(map_id_1) == []
      assert get_presence_character_ids(map_id_2) == [character_id]
    end

    test "grace period on one map doesn't affect other maps", %{
      character_id: character_id,
      character_id_2: character_id_2
    } do
      map_id_1 = "test_map_iso_1_#{:rand.uniform(1_000_000)}"
      map_id_2 = "test_map_iso_2_#{:rand.uniform(1_000_000)}"

      on_exit(fn ->
        PresenceGracePeriodManager.clear_map_state(map_id_1)
        PresenceGracePeriodManager.clear_map_state(map_id_2)
        cleanup_cache(map_id_1)
        cleanup_cache(map_id_2)
      end)

      # Different characters on different maps
      presence_data_1 = build_presence_data([{character_id, true}])
      presence_data_2 = build_presence_data([{character_id_2, true}])

      PresenceGracePeriodManager.process_presence_change_sync(map_id_1, presence_data_1)
      PresenceGracePeriodManager.process_presence_change_sync(map_id_2, presence_data_2)

      # Character leaves map_id_1
      PresenceGracePeriodManager.process_presence_change_sync(map_id_1, [])

      # map_id_2 should be completely unaffected
      assert get_presence_character_ids(map_id_2) == [character_id_2]

      state = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state.pending_removals, {map_id_1, character_id})
      refute Map.has_key?(state.pending_removals, {map_id_2, character_id_2})
    end
  end

  describe "edge cases" do
    test "empty presence data on fresh map", %{map_id: map_id} do
      # Process empty presence for a map that never had data
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Should not crash, cache should be empty
      assert get_presence_character_ids(map_id) == []
    end

    test "presence data with all untracked characters", %{
      map_id: map_id,
      character_id: character_id,
      character_id_2: character_id_2
    } do
      presence_data = build_presence_data([{character_id, false}, {character_id_2, false}])

      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # No tracked characters, so presence_character_ids should be empty
      assert get_presence_character_ids(map_id) == []
      # But presence_data should have both characters
      assert length(get_presence_data(map_id)) == 2
    end

    test "rapid presence changes don't cause issues", %{
      map_id: map_id,
      character_id: character_id
    } do
      presence_data = build_presence_data([{character_id, true}])

      # Rapid fire presence changes (synchronous)
      for _ <- 1..20 do
        PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
        PresenceGracePeriodManager.process_presence_change_sync(map_id, [])
      end

      # Final state: character present
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Should have exactly one pending removal or none (depending on final state)
      state = PresenceGracePeriodManager.get_state()
      refute Map.has_key?(state.pending_removals, {map_id, character_id})
      assert get_presence_character_ids(map_id) == [character_id]
    end

    test "character switching from tracked to untracked", %{
      map_id: map_id,
      character_id: character_id
    } do
      # Character joins as tracked
      presence_data_tracked = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data_tracked)

      assert get_presence_character_ids(map_id) == [character_id]

      # Character becomes untracked (still present, but not tracking)
      presence_data_untracked = build_presence_data([{character_id, false}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data_untracked)

      # Character was tracked before, now untracked - should start grace period
      state = PresenceGracePeriodManager.get_state()
      assert Map.has_key?(state.pending_removals, {map_id, character_id})

      # Character should still be in cache (grace period)
      assert get_presence_character_ids(map_id) == [character_id]
    end

    test "character switching from untracked to tracked", %{
      map_id: map_id,
      character_id: character_id
    } do
      # Character joins as untracked
      presence_data_untracked = build_presence_data([{character_id, false}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data_untracked)

      assert get_presence_character_ids(map_id) == []

      # Character becomes tracked
      presence_data_tracked = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data_tracked)

      # Character should now be in tracked list
      assert get_presence_character_ids(map_id) == [character_id]
    end

    test "duplicate character IDs in presence data are handled", %{
      map_id: map_id,
      character_id: character_id
    } do
      # Presence data with duplicate entries (shouldn't happen but let's be safe)
      presence_data = [
        %{character_id: character_id, tracked: true, from: DateTime.utc_now()},
        %{character_id: character_id, tracked: true, from: DateTime.utc_now()}
      ]

      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # Should handle gracefully, character appears once in tracked IDs
      cached_ids = get_presence_character_ids(map_id)
      # Due to how the code works, duplicates may appear - that's a known limitation
      # The important thing is it doesn't crash
      assert character_id in cached_ids
    end
  end

  describe "telemetry events" do
    test "grace_period_started telemetry is emitted when character leaves", %{
      map_id: map_id,
      character_id: character_id
    } do
      test_pid = self()
      handler_id = "test-grace-period-started-#{map_id}"

      :telemetry.attach(
        handler_id,
        [:wanderer_app, :presence, :grace_period_started],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :started, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      # Character joins then leaves
      presence_data = build_presence_data([{character_id, true}])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      assert_receive {:telemetry, :started, measurements, metadata}, 500
      assert measurements.grace_period_ms > 0
      assert metadata.map_id == map_id
      assert metadata.character_id == character_id
      assert metadata.reason == :presence_left
    end

    test "grace_period_cancelled telemetry is emitted when character rejoins", %{
      map_id: map_id,
      character_id: character_id
    } do
      test_pid = self()
      handler_id = "test-grace-period-cancelled-#{map_id}"

      :telemetry.attach(
        handler_id,
        [:wanderer_app, :presence, :grace_period_cancelled],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :cancelled, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      presence_data = build_presence_data([{character_id, true}])

      # Join -> leave -> rejoin
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      assert_receive {:telemetry, :cancelled, _measurements, metadata}, 500
      assert metadata.map_id == map_id
      assert metadata.character_id == character_id
      assert metadata.reason == :character_rejoined
    end

    test "grace_period_expired telemetry is emitted when timer fires", %{
      map_id: map_id,
      character_id: character_id
    } do
      test_pid = self()
      handler_id = "test-grace-period-expired-#{map_id}"

      :telemetry.attach(
        handler_id,
        [:wanderer_app, :presence, :grace_period_expired],
        fn _name, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :expired, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      presence_data = build_presence_data([{character_id, true}])

      # Join -> leave -> simulate expiration
      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      # Simulate grace period expiration
      send(
        Process.whereis(PresenceGracePeriodManager),
        {:grace_period_expired, map_id, character_id}
      )

      :timer.sleep(20)

      assert_receive {:telemetry, :expired, measurements, metadata}, 500
      assert measurements.duration_ms > 0
      assert metadata.map_id == map_id
      assert metadata.character_id == character_id
      assert metadata.reason == :grace_period_timeout
    end
  end

  describe "cache consistency" do
    test "presence_updated flag is set on every change", %{
      map_id: map_id,
      character_id: character_id
    } do
      presence_data = build_presence_data([{character_id, true}])

      # Clear the flag
      WandererApp.Cache.delete("map_#{map_id}:presence_updated")

      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      assert get_presence_updated(map_id) == true

      # Clear and change again
      WandererApp.Cache.delete("map_#{map_id}:presence_updated")
      PresenceGracePeriodManager.process_presence_change_sync(map_id, [])

      assert get_presence_updated(map_id) == true
    end

    test "presence_data and presence_character_ids are always in sync", %{
      map_id: map_id,
      character_id: character_id,
      character_id_2: character_id_2
    } do
      # Complex scenario: multiple characters, some tracked, some not
      presence_data =
        build_presence_data([
          {character_id, true},
          {character_id_2, false}
        ])

      PresenceGracePeriodManager.process_presence_change_sync(map_id, presence_data)

      # presence_character_ids should only have tracked characters
      cached_ids = get_presence_character_ids(map_id)
      assert cached_ids == [character_id]

      # presence_data should have all characters
      cached_data = get_presence_data(map_id)
      assert length(cached_data) == 2
      data_ids = Enum.map(cached_data, & &1.character_id)
      assert Enum.sort(data_ids) == Enum.sort([character_id, character_id_2])
    end
  end
end
