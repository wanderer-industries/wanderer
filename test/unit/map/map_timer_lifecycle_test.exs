defmodule WandererApp.Map.MapTimerLifecycleTest do
  use ExUnit.Case, async: false

  alias WandererApp.Map.Server.AclsImpl
  alias WandererApp.Map.Server.Impl

  setup do
    map_id = "test_map_#{System.unique_integer([:positive])}"

    on_exit(fn ->
      WandererApp.Cache.delete("map_#{map_id}:timer_gen")
      WandererApp.Cache.delete("map_#{map_id}:started")
      Cachex.del(:map_cache, map_id)
    end)

    {:ok, map_id: map_id}
  end

  describe "per-map timer loops" do
    test "a loop from a previous map start is not rescheduled", %{map_id: map_id} do
      WandererApp.Cache.insert("map_#{map_id}:timer_gen", make_ref())
      stale_gen = make_ref()

      assert :ok = Impl.handle_event({:update_presence, map_id, stale_gen})

      refute_receive {:update_presence, ^map_id, _}, 6_000
    end

    test "a loop of a stopped map is not rescheduled", %{map_id: map_id} do
      timer_gen = make_ref()
      WandererApp.Cache.insert("map_#{map_id}:timer_gen", timer_gen)

      # stop_map/1 deletes the generation
      WandererApp.Cache.delete("map_#{map_id}:timer_gen")

      for event <- [:update_characters, :update_presence, :reconcile_tracking] do
        assert :ok = Impl.handle_event({event, map_id, timer_gen})
      end

      refute_receive {_event, ^map_id, _}, 1_500
      assert {:error, :not_found} = WandererApp.Map.get_map(map_id)
    end

    test "the current loop keeps rescheduling", %{map_id: map_id} do
      timer_gen = make_ref()
      WandererApp.Cache.insert("map_#{map_id}:timer_gen", timer_gen)

      Impl.handle_event({:update_presence, map_id, timer_gen})

      assert_receive {:update_presence, ^map_id, ^timer_gen}, 6_000
    end
  end

  describe "ACL fan-out" do
    test "does not create map cache entries for maps that are not running",
         %{map_id: map_id} do
      assert :ok = AclsImpl.handle_acl_updated(map_id, "acl_id")
      assert :ok = AclsImpl.handle_acl_deleted(map_id, "acl_id")

      assert {:error, :not_found} = WandererApp.Map.get_map(map_id)
    end
  end
end
