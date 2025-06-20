defmodule WandererApp.Kills.StorageTest do
  use ExUnit.Case
  alias WandererApp.Kills.Storage

  setup do
    # Clear cache before each test
    WandererApp.Cache.delete_all()
    :ok
  end

  describe "kill count race condition handling" do
    test "incremental updates are skipped when recent websocket update exists" do
      system_id = 30000142
      
      # Simulate websocket update
      assert :ok = Storage.store_kill_count(system_id, 100)
      
      # Immediately try incremental update (within 5 seconds)
      assert :ok = Storage.update_kill_count(system_id, 5, :timer.minutes(5))
      
      # Count should still be 100, not 105
      assert {:ok, 100} = Storage.get_kill_count(system_id)
    end

    test "incremental updates work after websocket update timeout" do
      system_id = 30000143
      
      # Simulate websocket update
      assert :ok = Storage.store_kill_count(system_id, 100)
      
      # Manually update metadata to simulate old timestamp
      metadata_key = "zkb:kills:metadata:#{system_id}"
      old_timestamp = System.system_time(:millisecond) - 10_000  # 10 seconds ago
      WandererApp.Cache.insert(metadata_key, %{
        "source" => "websocket",
        "timestamp" => old_timestamp,
        "absolute_count" => 100
      }, ttl: :timer.minutes(5))
      
      # Try incremental update (after timeout)
      assert :ok = Storage.update_kill_count(system_id, 5, :timer.minutes(5))
      
      # Count should now be 105
      assert {:ok, 105} = Storage.get_kill_count(system_id)
    end

    test "incremental updates work when no metadata exists" do
      system_id = 30000144
      
      # Set initial count without metadata (simulating old data)
      key = "zkb:kills:#{system_id}"
      WandererApp.Cache.insert(key, 50, ttl: :timer.minutes(5))
      
      # Try incremental update
      assert :ok = Storage.update_kill_count(system_id, 5, :timer.minutes(5))
      
      # Count should be 55
      assert {:ok, 55} = Storage.get_kill_count(system_id)
    end

    test "reconcile_kill_count fixes discrepancies" do
      system_id = 30000145
      
      # Set up mismatched count and list
      count_key = "zkb:kills:#{system_id}"
      list_key = "zkb:kills:list:#{system_id}"
      
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
      system_id = 30000146
      killmails = [
        %{"killmail_id" => 123, "kill_time" => "2024-01-01T12:00:00Z"},
        %{"killmail_id" => 124, "kill_time" => "2024-01-01T12:01:00Z"}
      ]
      
      assert :ok = Storage.store_killmails(system_id, killmails, :timer.minutes(5))
      
      # Check individual killmails are stored
      assert {:ok, %{"killmail_id" => 123}} = Storage.get_killmail(123)
      assert {:ok, %{"killmail_id" => 124}} = Storage.get_killmail(124)
      
      # Check system list is updated (order might vary)
      list_key = "zkb:kills:list:#{system_id}"
      list = WandererApp.Cache.get(list_key)
      assert Enum.sort(list) == [123, 124]
    end

    test "handles missing killmail_id gracefully" do
      system_id = 30000147
      killmails = [
        %{"kill_time" => "2024-01-01T12:00:00Z"},  # Missing killmail_id
        %{"killmail_id" => 125, "kill_time" => "2024-01-01T12:01:00Z"}
      ]
      
      # Should return an error when a killmail has no ID
      assert {:error, :missing_killmail_id} = Storage.store_killmails(system_id, killmails, :timer.minutes(5))
      
      # The valid killmail is still stored (function processes all before returning error)
      assert {:ok, %{"killmail_id" => 125}} = Storage.get_killmail(125)
      
      # System list contains only the valid ID
      list_key = "zkb:kills:list:#{system_id}"
      assert [125] = WandererApp.Cache.get(list_key)
    end
  end
end