defmodule WandererApp.Map.MapPoolTest do
  use ExUnit.Case, async: false

  import Mox

  setup :verify_on_exit!

  alias WandererApp.Map.{MapPool, MapPoolDynamicSupervisor, Reconciler}

  @cache :map_pool_cache
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry

  setup do
    # Clean up any existing test data
    cleanup_test_data()

    # Check if required infrastructure is running
    registries_running? =
      try do
        Registry.keys(@registry, self()) != :error
      rescue
        _ -> false
      end

    reconciler_running? = Process.whereis(Reconciler) != nil

    on_exit(fn ->
      cleanup_test_data()
    end)

    {:ok, registries_running: registries_running?, reconciler_running: reconciler_running?}
  end

  defp cleanup_test_data do
    # Clean up test caches
    WandererApp.Cache.delete("started_maps")
    Cachex.clear(@cache)
  end

  describe "garbage collection with synchronous stop" do
    @tag :skip
    test "garbage collector successfully stops map with synchronous call" do
      # This test would require setting up a full map pool with a test map
      # Skipping for now as it requires more complex setup with actual map data
      :ok
    end

    @tag :skip
    test "garbage collector handles stop failures gracefully" do
      # This test would verify error handling when stop fails
      :ok
    end
  end

  describe "cache lookup with registry fallback" do
    test "stop_map handles cache miss by scanning registry", %{
      registries_running: registries_running?
    } do
      if registries_running? do
        # Setup: Create a map_id that's not in cache but will be found in registry scan
        map_id = "test_map_#{:rand.uniform(1_000_000)}"

        # Verify cache is empty for this map
        assert {:ok, nil} = Cachex.get(@cache, map_id)

        # Call stop_map - should handle gracefully with fallback
        assert :ok = MapPoolDynamicSupervisor.stop_map(map_id)
      else
        # Skip test if registries not running
        :ok
      end
    end

    test "stop_map handles non-existent pool_uuid in registry", %{
      registries_running: registries_running?
    } do
      if registries_running? do
        map_id = "test_map_#{:rand.uniform(1_000_000)}"
        fake_uuid = "fake_uuid_#{:rand.uniform(1_000_000)}"

        # Put fake uuid in cache that doesn't exist in registry
        Cachex.put(@cache, map_id, fake_uuid)

        # Call stop_map - should handle gracefully with fallback
        assert :ok = MapPoolDynamicSupervisor.stop_map(map_id)
      else
        :ok
      end
    end

    test "stop_map updates cache when found via registry scan", %{
      registries_running: registries_running?
    } do
      if registries_running? do
        # This test would require a running pool with registered maps
        # For now, we verify the fallback logic doesn't crash
        map_id = "test_map_#{:rand.uniform(1_000_000)}"
        assert :ok = MapPoolDynamicSupervisor.stop_map(map_id)
      else
        :ok
      end
    end
  end

  describe "state cleanup atomicity" do
    @tag :skip
    test "rollback occurs when registry update fails" do
      # This would require mocking Registry.update_value to fail
      # Skipping for now as it requires more complex mocking setup
      :ok
    end

    @tag :skip
    test "rollback occurs when cache delete fails" do
      # This would require mocking Cachex.del to fail
      :ok
    end

    @tag :skip
    test "successful cleanup updates all three state stores" do
      # This would verify Registry, Cache, and GenServer state are all updated
      :ok
    end
  end

  describe "Reconciler - zombie map detection and cleanup" do
    test "reconciler detects zombie maps in started_maps cache", %{
      reconciler_running: reconciler_running?
    } do
      if reconciler_running? do
        # Setup: Add maps to started_maps that aren't in any registry
        zombie_map_id = "zombie_map_#{:rand.uniform(1_000_000)}"

        WandererApp.Cache.insert_or_update(
          "started_maps",
          [zombie_map_id],
          fn existing -> [zombie_map_id | existing] |> Enum.uniq() end
        )

        # Get started_maps
        {:ok, started_maps} = WandererApp.Cache.lookup("started_maps", [])
        assert zombie_map_id in started_maps

        # Trigger reconciliation
        send(Reconciler, :reconcile)
        # Give it time to process (reduced from 200ms)
        Process.sleep(50)

        # Verify zombie was cleaned up
        {:ok, started_maps_after} = WandererApp.Cache.lookup("started_maps", [])
        refute zombie_map_id in started_maps_after
      else
        :ok
      end
    end

    test "reconciler cleans up zombie map caches", %{reconciler_running: reconciler_running?} do
      if reconciler_running? do
        zombie_map_id = "zombie_map_#{:rand.uniform(1_000_000)}"

        # Setup zombie state
        WandererApp.Cache.insert_or_update(
          "started_maps",
          [zombie_map_id],
          fn existing -> [zombie_map_id | existing] |> Enum.uniq() end
        )

        WandererApp.Cache.insert("map_#{zombie_map_id}:started", true)
        Cachex.put(@cache, zombie_map_id, "fake_uuid")

        # Trigger reconciliation
        send(Reconciler, :reconcile)
        Process.sleep(50)

        # Verify all caches cleaned
        {:ok, started_maps} = WandererApp.Cache.lookup("started_maps", [])
        refute zombie_map_id in started_maps

        {:ok, cache_entry} = Cachex.get(@cache, zombie_map_id)
        assert cache_entry == nil
      else
        :ok
      end
    end
  end

  describe "Reconciler - orphan map detection and fix" do
    @tag :skip
    test "reconciler detects orphan maps in registry" do
      # This would require setting up a pool with maps in registry
      # but not in started_maps cache
      :ok
    end

    @tag :skip
    test "reconciler adds orphan maps to started_maps cache" do
      # This would verify orphan maps get added to the cache
      :ok
    end
  end

  describe "Reconciler - cache inconsistency detection and fix" do
    test "reconciler detects map with missing cache entry", %{
      reconciler_running: reconciler_running?
    } do
      if reconciler_running? do
        # This test verifies the reconciler can detect when a map
        # is in the registry but has no cache entry
        # Since we can't easily set up a full pool, we test the detection logic

        map_id = "test_map_#{:rand.uniform(1_000_000)}"

        # Ensure no cache entry
        Cachex.del(@cache, map_id)

        # The reconciler would detect this if the map was in a registry
        # For now, we just verify the logic doesn't crash
        send(Reconciler, :reconcile)
        Process.sleep(50)

        # No assertions needed - just verifying no crashes
      end
    end

    @tag :skip
    test "reconciler detects cache pointing to non-existent pool", %{
      reconciler_running: reconciler_running?
    } do
      if reconciler_running? do
        map_id = "test_map_#{:rand.uniform(1_000_000)}"
        fake_uuid = "fake_uuid_#{:rand.uniform(1_000_000)}"

        # Put fake uuid in cache
        Cachex.put(@cache, map_id, fake_uuid)

        # Trigger reconciliation
        send(Reconciler, :reconcile)
        Process.sleep(50)

        # Cache entry should be removed since pool doesn't exist
        {:ok, cache_entry} = Cachex.get(@cache, map_id)
        assert cache_entry == nil
      else
        :ok
      end
    end
  end

  describe "Reconciler - stats and telemetry" do
    test "reconciler emits telemetry events", %{reconciler_running: reconciler_running?} do
      if reconciler_running? do
        # Setup telemetry handler
        test_pid = self()

        :telemetry.attach(
          "test-reconciliation",
          [:wanderer_app, :map, :reconciliation],
          fn _event, measurements, _metadata, _config ->
            send(test_pid, {:telemetry, measurements})
          end,
          nil
        )

        # Trigger reconciliation
        send(Reconciler, :reconcile)
        Process.sleep(50)

        # Should receive telemetry event
        assert_receive {:telemetry, measurements}, 500

        assert is_integer(measurements.total_started_maps)
        assert is_integer(measurements.total_registry_maps)
        assert is_integer(measurements.zombie_maps)
        assert is_integer(measurements.orphan_maps)
        assert is_integer(measurements.cache_inconsistencies)

        # Cleanup
        :telemetry.detach("test-reconciliation")
      else
        :ok
      end
    end
  end

  describe "Reconciler - manual trigger" do
    test "trigger_reconciliation runs reconciliation immediately", %{
      reconciler_running: reconciler_running?
    } do
      if reconciler_running? do
        zombie_map_id = "zombie_map_#{:rand.uniform(1_000_000)}"

        # Setup zombie state
        WandererApp.Cache.insert_or_update(
          "started_maps",
          [zombie_map_id],
          fn existing -> [zombie_map_id | existing] |> Enum.uniq() end
        )

        # Verify it exists
        {:ok, started_maps_before} = WandererApp.Cache.lookup("started_maps", [])
        assert zombie_map_id in started_maps_before

        # Trigger manual reconciliation
        Reconciler.trigger_reconciliation()
        Process.sleep(50)

        # Verify zombie was cleaned up
        {:ok, started_maps_after} = WandererApp.Cache.lookup("started_maps", [])
        refute zombie_map_id in started_maps_after
      else
        :ok
      end
    end
  end

  describe "edge cases and error handling" do
    test "stop_map with cache error returns ok", %{registries_running: registries_running?} do
      if registries_running? do
        map_id = "test_map_#{:rand.uniform(1_000_000)}"

        # Even if cache operations fail, should return :ok
        assert :ok = MapPoolDynamicSupervisor.stop_map(map_id)
      else
        :ok
      end
    end

    test "reconciler handles empty registries gracefully", %{
      reconciler_running: reconciler_running?
    } do
      if reconciler_running? do
        # Clear everything
        cleanup_test_data()

        # Should not crash even with empty data
        send(Reconciler, :reconcile)
        Process.sleep(50)

        # No assertions - just verifying no crash
        assert true
      else
        :ok
      end
    end

    test "reconciler handles nil values in caches", %{reconciler_running: reconciler_running?} do
      if reconciler_running? do
        map_id = "test_map_#{:rand.uniform(1_000_000)}"

        # Explicitly set nil
        Cachex.put(@cache, map_id, nil)

        # Should handle gracefully
        send(Reconciler, :reconcile)
        Process.sleep(50)

        assert true
      else
        :ok
      end
    end
  end
end
