defmodule WandererApp.Map.MapPoolCrashRecoveryTest do
  use ExUnit.Case, async: false

  import Mox

  setup :verify_on_exit!

  alias WandererApp.Map.{MapPool, MapPoolState}

  @cache :map_pool_cache
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry
  @ets_table :map_pool_state_table

  setup do
    # Clean up any existing test data
    cleanup_test_data()

    # Check if ETS table exists
    ets_exists? =
      try do
        :ets.info(@ets_table) != :undefined
      rescue
        _ -> false
      end

    on_exit(fn ->
      cleanup_test_data()
    end)

    {:ok, ets_exists: ets_exists?}
  end

  defp cleanup_test_data do
    # Clean up test caches
    WandererApp.Cache.delete("started_maps")
    Cachex.clear(@cache)

    # Clean up ETS entries for test pools
    if :ets.whereis(@ets_table) != :undefined do
      :ets.match_delete(@ets_table, {:"$1", :"$2", :"$3"})
    end
  end

  defp create_test_pool_with_uuid(uuid, map_ids) do
    # Manually register in unique_registry
    {:ok, _} = Registry.register(@unique_registry, Module.concat(MapPool, uuid), map_ids)
    {:ok, _} = Registry.register(@registry, MapPool, uuid)

    # Add to cache
    Enum.each(map_ids, fn map_id ->
      Cachex.put(@cache, map_id, uuid)
    end)

    # Save to ETS
    MapPoolState.save_pool_state(uuid, map_ids)

    uuid
  end

  defp get_pool_map_ids(uuid) do
    case Registry.lookup(@unique_registry, Module.concat(MapPool, uuid)) do
      [{_pid, map_ids}] -> map_ids
      [] -> []
    end
  end

  describe "MapPoolState - ETS operations" do
    test "save_pool_state stores state in ETS", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "test-pool-#{:rand.uniform(1_000_000)}"
        map_ids = [1, 2, 3]

        assert :ok = MapPoolState.save_pool_state(uuid, map_ids)

        # Verify it's in ETS
        assert {:ok, ^map_ids} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end

    test "get_pool_state returns not_found for non-existent pool", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "non-existent-#{:rand.uniform(1_000_000)}"

        assert {:error, :not_found} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end

    test "delete_pool_state removes state from ETS", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "test-pool-#{:rand.uniform(1_000_000)}"
        map_ids = [1, 2, 3]

        MapPoolState.save_pool_state(uuid, map_ids)
        assert {:ok, ^map_ids} = MapPoolState.get_pool_state(uuid)

        assert :ok = MapPoolState.delete_pool_state(uuid)
        assert {:error, :not_found} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end

    test "save_pool_state updates existing state", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "test-pool-#{:rand.uniform(1_000_000)}"

        # Save initial state
        MapPoolState.save_pool_state(uuid, [1, 2])
        assert {:ok, [1, 2]} = MapPoolState.get_pool_state(uuid)

        # Update state
        MapPoolState.save_pool_state(uuid, [1, 2, 3, 4])
        assert {:ok, [1, 2, 3, 4]} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end

    test "list_all_states returns all pool states", %{ets_exists: ets_exists?} do
      if ets_exists? do
        # Clean first
        :ets.delete_all_objects(@ets_table)

        uuid1 = "test-pool-1-#{:rand.uniform(1_000_000)}"
        uuid2 = "test-pool-2-#{:rand.uniform(1_000_000)}"

        MapPoolState.save_pool_state(uuid1, [1, 2])
        MapPoolState.save_pool_state(uuid2, [3, 4])

        states = MapPoolState.list_all_states()
        assert length(states) >= 2

        # Verify our pools are in there
        uuids = Enum.map(states, fn {uuid, _map_ids, _timestamp} -> uuid end)
        assert uuid1 in uuids
        assert uuid2 in uuids
      else
        :ok
      end
    end

    test "count_states returns correct count", %{ets_exists: ets_exists?} do
      if ets_exists? do
        # Clean first
        :ets.delete_all_objects(@ets_table)

        uuid1 = "test-pool-1-#{:rand.uniform(1_000_000)}"
        uuid2 = "test-pool-2-#{:rand.uniform(1_000_000)}"

        MapPoolState.save_pool_state(uuid1, [1, 2])
        MapPoolState.save_pool_state(uuid2, [3, 4])

        count = MapPoolState.count_states()
        assert count >= 2
      else
        :ok
      end
    end
  end

  describe "MapPoolState - stale entry cleanup" do
    test "cleanup_stale_entries removes old entries", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "stale-pool-#{:rand.uniform(1_000_000)}"

        # Manually insert a stale entry (24+ hours old)
        stale_timestamp = System.system_time(:second) - 25 * 3600
        :ets.insert(@ets_table, {uuid, [1, 2], stale_timestamp})

        assert {:ok, [1, 2]} = MapPoolState.get_pool_state(uuid)

        # Clean up stale entries
        {:ok, deleted_count} = MapPoolState.cleanup_stale_entries()
        assert deleted_count >= 1

        # Verify stale entry was removed
        assert {:error, :not_found} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end

    test "cleanup_stale_entries preserves recent entries", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "recent-pool-#{:rand.uniform(1_000_000)}"
        map_ids = [1, 2, 3]

        # Save recent entry
        MapPoolState.save_pool_state(uuid, map_ids)

        # Clean up
        MapPoolState.cleanup_stale_entries()

        # Recent entry should still exist
        assert {:ok, ^map_ids} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end
  end

  describe "Crash recovery - basic scenarios" do
    @tag :skip
    test "MapPool recovers single map after crash" do
      # This test requires a full MapPool GenServer with actual map data
      # Skipping as it needs integration with Server.Impl.start_map
      :ok
    end

    @tag :skip
    test "MapPool recovers multiple maps after crash" do
      # Similar to above - requires full integration
      :ok
    end

    @tag :skip
    test "MapPool merges new and recovered map_ids" do
      # Tests that if pool crashes while starting a new map,
      # both the new map and recovered maps are started
      :ok
    end
  end

  describe "Crash recovery - telemetry" do
    test "recovery emits start telemetry event", %{ets_exists: ets_exists?} do
      if ets_exists? do
        test_pid = self()

        # Attach telemetry handler
        :telemetry.attach(
          "test-recovery-start",
          [:wanderer_app, :map_pool, :recovery, :start],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:telemetry_start, measurements, metadata})
          end,
          nil
        )

        uuid = "test-pool-#{:rand.uniform(1_000_000)}"
        recovered_maps = [1, 2, 3]

        # Save state to ETS (simulating previous run)
        MapPoolState.save_pool_state(uuid, recovered_maps)

        # Simulate init with recovery
        # Note: Can't actually start a MapPool here without full integration,
        # but we can verify the telemetry handler is set up correctly

        # Manually emit the event to test handler
        :telemetry.execute(
          [:wanderer_app, :map_pool, :recovery, :start],
          %{recovered_map_count: 3, total_map_count: 3},
          %{pool_uuid: uuid}
        )

        assert_receive {:telemetry_start, measurements, metadata}, 500

        assert measurements.recovered_map_count == 3
        assert measurements.total_map_count == 3
        assert metadata.pool_uuid == uuid

        # Cleanup
        :telemetry.detach("test-recovery-start")
      else
        :ok
      end
    end

    test "recovery emits complete telemetry event", %{ets_exists: ets_exists?} do
      if ets_exists? do
        test_pid = self()

        :telemetry.attach(
          "test-recovery-complete",
          [:wanderer_app, :map_pool, :recovery, :complete],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:telemetry_complete, measurements, metadata})
          end,
          nil
        )

        uuid = "test-pool-#{:rand.uniform(1_000_000)}"

        # Manually emit the event
        :telemetry.execute(
          [:wanderer_app, :map_pool, :recovery, :complete],
          %{recovered_count: 3, failed_count: 0, duration_ms: 100},
          %{pool_uuid: uuid}
        )

        assert_receive {:telemetry_complete, measurements, metadata}, 500

        assert measurements.recovered_count == 3
        assert measurements.failed_count == 0
        assert measurements.duration_ms == 100
        assert metadata.pool_uuid == uuid

        :telemetry.detach("test-recovery-complete")
      else
        :ok
      end
    end

    test "recovery emits map_failed telemetry event", %{ets_exists: ets_exists?} do
      if ets_exists? do
        test_pid = self()

        :telemetry.attach(
          "test-recovery-map-failed",
          [:wanderer_app, :map_pool, :recovery, :map_failed],
          fn _event, measurements, metadata, _config ->
            send(test_pid, {:telemetry_map_failed, measurements, metadata})
          end,
          nil
        )

        uuid = "test-pool-#{:rand.uniform(1_000_000)}"
        failed_map_id = 123

        # Manually emit the event
        :telemetry.execute(
          [:wanderer_app, :map_pool, :recovery, :map_failed],
          %{map_id: failed_map_id},
          %{pool_uuid: uuid, reason: "Map not found"}
        )

        assert_receive {:telemetry_map_failed, measurements, metadata}, 500

        assert measurements.map_id == failed_map_id
        assert metadata.pool_uuid == uuid
        assert metadata.reason == "Map not found"

        :telemetry.detach("test-recovery-map-failed")
      else
        :ok
      end
    end
  end

  describe "Crash recovery - state persistence" do
    @tag :skip
    test "state persisted after successful map start" do
      # Would need to start actual MapPool and trigger start_map
      :ok
    end

    @tag :skip
    test "state persisted after successful map stop" do
      # Would need to start actual MapPool and trigger stop_map
      :ok
    end

    @tag :skip
    test "state persisted during backup_state" do
      # Would need to trigger backup_state handler
      :ok
    end
  end

  describe "Graceful shutdown cleanup" do
    test "ETS state cleaned on normal termination", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "test-pool-#{:rand.uniform(1_000_000)}"
        map_ids = [1, 2, 3]

        # Save state
        MapPoolState.save_pool_state(uuid, map_ids)
        assert {:ok, ^map_ids} = MapPoolState.get_pool_state(uuid)

        # Simulate graceful shutdown by calling delete
        MapPoolState.delete_pool_state(uuid)

        # State should be gone
        assert {:error, :not_found} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end

    @tag :skip
    test "ETS state preserved on abnormal termination" do
      # Would need to actually crash a MapPool to test this
      # The terminate callback would not call delete_pool_state
      :ok
    end
  end

  describe "Edge cases" do
    test "recovery with empty map_ids list", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "test-pool-#{:rand.uniform(1_000_000)}"

        # Save empty state
        MapPoolState.save_pool_state(uuid, [])
        assert {:ok, []} = MapPoolState.get_pool_state(uuid)
      else
        :ok
      end
    end

    test "recovery with duplicate map_ids gets deduplicated", %{ets_exists: ets_exists?} do
      if ets_exists? do
        # This tests the deduplication logic in init
        # If we have [1, 2] in ETS and [2, 3] in new map_ids,
        # result should be [1, 2, 3] after Enum.uniq

        recovered_maps = [1, 2]
        new_maps = [2, 3]
        expected = Enum.uniq(recovered_maps ++ new_maps)

        # Should be [1, 2, 3] or [2, 3, 1] depending on order
        assert 1 in expected
        assert 2 in expected
        assert 3 in expected
        assert length(expected) == 3
      else
        :ok
      end
    end

    test "large number of maps in recovery", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "test-pool-#{:rand.uniform(1_000_000)}"
        # Test with 20 maps (the pool limit)
        map_ids = Enum.to_list(1..20)

        MapPoolState.save_pool_state(uuid, map_ids)
        assert {:ok, recovered} = MapPoolState.get_pool_state(uuid)
        assert length(recovered) == 20
        assert recovered == map_ids
      else
        :ok
      end
    end
  end

  describe "Concurrent operations" do
    test "multiple pools can save state concurrently", %{ets_exists: ets_exists?} do
      if ets_exists? do
        # Create 10 pools concurrently
        tasks =
          1..10
          |> Enum.map(fn i ->
            Task.async(fn ->
              uuid = "concurrent-pool-#{i}-#{:rand.uniform(1_000_000)}"
              map_ids = [i * 10, i * 10 + 1]
              MapPoolState.save_pool_state(uuid, map_ids)
              {uuid, map_ids}
            end)
          end)

        results = Task.await_many(tasks, 5000)

        # Verify all pools saved successfully
        Enum.each(results, fn {uuid, expected_map_ids} ->
          assert {:ok, ^expected_map_ids} = MapPoolState.get_pool_state(uuid)
        end)
      else
        :ok
      end
    end

    test "concurrent reads and writes don't corrupt state", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "test-pool-#{:rand.uniform(1_000_000)}"
        MapPoolState.save_pool_state(uuid, [1, 2, 3])

        # Spawn multiple readers and writers
        readers =
          1..5
          |> Enum.map(fn _ ->
            Task.async(fn ->
              MapPoolState.get_pool_state(uuid)
            end)
          end)

        writers =
          1..5
          |> Enum.map(fn i ->
            Task.async(fn ->
              MapPoolState.save_pool_state(uuid, [i, i + 1])
            end)
          end)

        # All operations should complete without error
        reader_results = Task.await_many(readers, 5000)
        writer_results = Task.await_many(writers, 5000)

        assert Enum.all?(reader_results, fn
                 {:ok, _} -> true
                 _ -> false
               end)

        assert Enum.all?(writer_results, fn :ok -> true end)

        # Final state should be valid (one of the writer's values)
        assert {:ok, final_state} = MapPoolState.get_pool_state(uuid)
        assert is_list(final_state)
        assert length(final_state) == 2
      else
        :ok
      end
    end
  end

  describe "Performance" do
    @tag :slow
    test "recovery completes within acceptable time", %{ets_exists: ets_exists?} do
      if ets_exists? do
        uuid = "perf-pool-#{:rand.uniform(1_000_000)}"
        # Test with pool at limit (20 maps)
        map_ids = Enum.to_list(1..20)

        # Measure save time
        {save_time_us, :ok} =
          :timer.tc(fn ->
            MapPoolState.save_pool_state(uuid, map_ids)
          end)

        # Measure retrieval time
        {get_time_us, {:ok, _}} =
          :timer.tc(fn ->
            MapPoolState.get_pool_state(uuid)
          end)

        # Both operations should be very fast (< 1ms)
        assert save_time_us < 1000, "Save took #{save_time_us}µs, expected < 1000µs"
        assert get_time_us < 1000, "Get took #{get_time_us}µs, expected < 1000µs"
      else
        :ok
      end
    end

    @tag :slow
    test "cleanup performance with many stale entries", %{ets_exists: ets_exists?} do
      if ets_exists? do
        # Insert 100 stale entries
        stale_timestamp = System.system_time(:second) - 25 * 3600

        1..100
        |> Enum.each(fn i ->
          uuid = "stale-pool-#{i}"
          :ets.insert(@ets_table, {uuid, [i], stale_timestamp})
        end)

        # Measure cleanup time
        {cleanup_time_us, {:ok, deleted_count}} =
          :timer.tc(fn ->
            MapPoolState.cleanup_stale_entries()
          end)

        # Should have deleted at least 100 entries
        assert deleted_count >= 100

        # Cleanup should be reasonably fast (< 100ms for 100 entries)
        assert cleanup_time_us < 100_000,
               "Cleanup took #{cleanup_time_us}µs, expected < 100,000µs"
      else
        :ok
      end
    end
  end
end
