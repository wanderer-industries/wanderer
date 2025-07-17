defmodule WandererApp.Kills.StorageTest do
  use ExUnit.Case
  alias WandererApp.Kills.{Storage, CacheKeys}

  setup do
    # Start cache if not already started
    case WandererApp.Cache.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Clear cache before each test
    WandererApp.Cache.delete_all()
    :ok
  end

  describe "kill count race condition handling" do
    test "incremental updates are skipped when recent websocket update exists" do
      system_id = 30_000_142

      # Simulate websocket update
      assert :ok = Storage.store_kill_count(system_id, 100)

      # Immediately try incremental update (within 5 seconds)
      assert :ok = Storage.update_kill_count(system_id, 5, :timer.minutes(5))

      # Count should still be 100, not 105
      assert {:ok, 100} = Storage.get_kill_count(system_id)
    end

    test "incremental updates work after websocket update timeout" do
      system_id = 30_000_143

      # Simulate websocket update
      assert :ok = Storage.store_kill_count(system_id, 100)

      # Manually update metadata to simulate old timestamp
      metadata_key = CacheKeys.kill_count_metadata(system_id)
      # 10 seconds ago
      old_timestamp = System.system_time(:millisecond) - 10_000

      WandererApp.Cache.insert(
        metadata_key,
        %{
          "source" => "websocket",
          "timestamp" => old_timestamp,
          "absolute_count" => 100
        },
        ttl: :timer.minutes(5)
      )

      # Try incremental update (after timeout)
      assert :ok = Storage.update_kill_count(system_id, 5, :timer.minutes(5))

      # Count should now be 105
      assert {:ok, 105} = Storage.get_kill_count(system_id)
    end

    test "incremental updates work when no metadata exists" do
      system_id = 30_000_144

      # Set initial count without metadata (simulating old data)
      key = CacheKeys.system_kill_count(system_id)
      WandererApp.Cache.insert(key, 50, ttl: :timer.minutes(5))

      # Try incremental update
      assert :ok = Storage.update_kill_count(system_id, 5, :timer.minutes(5))

      # Count should be 55
      assert {:ok, 55} = Storage.get_kill_count(system_id)
    end

    test "reconcile_kill_count fixes discrepancies" do
      system_id = 30_000_145

      # Set up mismatched count and list
      count_key = CacheKeys.system_kill_count(system_id)
      list_key = CacheKeys.system_kill_list(system_id)

      # Count says 100, but list only has 50
      WandererApp.Cache.insert(count_key, 100, ttl: :timer.minutes(5))
      WandererApp.Cache.insert(list_key, Enum.to_list(1..50), ttl: :timer.minutes(5))

      # Reconcile
      assert :ok = Storage.reconcile_kill_count(system_id)

      # Count should now match list length
      assert {:ok, 50} = Storage.get_kill_count(system_id)
    end
  end

  describe "store_killmails/3" do
    test "stores individual killmails and updates system list" do
      system_id = 30_000_146

      killmails = [
        %{"killmail_id" => 123, "kill_time" => "2024-01-01T12:00:00Z"},
        %{"killmail_id" => 124, "kill_time" => "2024-01-01T12:01:00Z"}
      ]

      assert :ok = Storage.store_killmails(system_id, killmails, :timer.minutes(5))

      # Check individual killmails are stored
      assert {:ok, %{"killmail_id" => 123}} = Storage.get_killmail(123)
      assert {:ok, %{"killmail_id" => 124}} = Storage.get_killmail(124)

      # Check system list is updated
      list_key = CacheKeys.system_kill_list(system_id)
      assert [123, 124] = WandererApp.Cache.get(list_key)
    end

    test "handles missing killmail_id gracefully" do
      system_id = 30_000_147

      killmails = [
        # Missing killmail_id
        %{"kill_time" => "2024-01-01T12:00:00Z"},
        %{"killmail_id" => 125, "kill_time" => "2024-01-01T12:01:00Z"}
      ]

      # Should still store the valid killmail
      assert :ok = Storage.store_killmails(system_id, killmails, :timer.minutes(5))

      # Only the valid killmail is stored
      assert {:ok, %{"killmail_id" => 125}} = Storage.get_killmail(125)

      # System list only contains valid ID
      list_key = CacheKeys.system_kill_list(system_id)
      assert [125] = WandererApp.Cache.get(list_key)
    end
  end
end
