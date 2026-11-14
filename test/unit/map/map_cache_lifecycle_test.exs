defmodule WandererApp.Map.MapCacheLifecycleTest do
  use ExUnit.Case, async: false

  alias WandererApp.Character.TrackingUtils

  setup do
    map_id = "test_map_#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Cachex.del(:map_cache, map_id)
      Cachex.del(:map_pool_cache, map_id)
    end)

    {:ok, map_id: map_id}
  end

  describe ":map_cache" do
    test "entries do not expire while the map is running", %{map_id: map_id} do
      WandererApp.Map.update_map(map_id, %{map_id: map_id, systems: %{}, characters: []})
      WandererApp.Map.update_map(map_id, %{characters: ["char_1"]})

      assert {:ok, nil} = Cachex.ttl(:map_cache, map_id)

      assert %{map_id: ^map_id, systems: %{}, characters: ["char_1"]} =
               WandererApp.Map.get_map!(map_id)
    end

    test "delete_map/1 removes the entry", %{map_id: map_id} do
      WandererApp.Map.update_map(map_id, %{map_id: map_id})

      WandererApp.Map.delete_map(map_id)

      assert {:error, :not_found} = WandererApp.Map.get_map(map_id)
    end
  end

  describe ":map_pool_cache" do
    test "entries do not expire", %{map_id: map_id} do
      Cachex.put(:map_pool_cache, map_id, "pool_uuid")

      assert {:ok, nil} = Cachex.ttl(:map_pool_cache, map_id)
    end
  end

  describe ":map_state_cache" do
    test "entries do not expire", %{map_id: map_id} do
      Cachex.put(:map_state_cache, map_id, %{map_id: map_id})
      on_exit(fn -> WandererApp.Map.delete_map_state(map_id) end)

      assert {:ok, nil} = Cachex.ttl(:map_state_cache, map_id)
    end
  end

  describe ":tracked_characters" do
    setup do
      # Tracker pool registries are not started in the test env
      ensure_registry(:unique_tracker_pool_registry, :unique)
      ensure_registry(:tracker_pool_registry, :duplicate)

      tracked_id = "test_char_#{System.unique_integer([:positive])}"
      on_exit(fn -> Cachex.del(:tracked_characters, tracked_id) end)
      {:ok, tracked_id: tracked_id}
    end

    test "entries do not expire", %{tracked_id: tracked_id} do
      Cachex.put(:tracked_characters, tracked_id, "pool_uuid")

      assert {:ok, nil} = Cachex.ttl(:tracked_characters, tracked_id)
    end

    test "stop_tracking/1 finds the pool by scanning the registry on cache miss",
         %{tracked_id: tracked_id} do
      uuid = "test_pool_#{System.unique_integer([:positive])}"

      {:ok, _} =
        Registry.register(
          :unique_tracker_pool_registry,
          Module.concat(WandererApp.Character.TrackerPool, uuid),
          [tracked_id]
        )

      {:ok, _} =
        Registry.register(:tracker_pool_registry, WandererApp.Character.TrackerPool, uuid)

      assert {:ok, nil} = Cachex.get(:tracked_characters, tracked_id)

      WandererApp.Character.TrackerPoolDynamicSupervisor.stop_tracking(tracked_id)

      assert_receive {:"$gen_cast", {:remove_tracked_id, ^tracked_id}}
    end

    test "stop_tracking/1 is a no-op for an unknown tracked_id", %{tracked_id: tracked_id} do
      assert :ok = WandererApp.Character.TrackerPoolDynamicSupervisor.stop_tracking(tracked_id)
    end
  end

  describe "TrackingUtils.filter_characters_with_tracking_permission/2" do
    test "returns an empty list when the map is nil" do
      assert [] == TrackingUtils.filter_characters_with_tracking_permission([], nil)
    end
  end

  defp ensure_registry(name, keys) do
    if Process.whereis(name) == nil do
      start_supervised!({Registry, keys: keys, name: name}, id: name)
    end
  end
end
