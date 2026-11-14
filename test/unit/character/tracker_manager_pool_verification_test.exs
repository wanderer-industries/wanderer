defmodule WandererApp.Character.TrackerManagerPoolVerificationTest do
  use ExUnit.Case, async: false

  alias WandererApp.Character.TrackerManager.Impl
  alias WandererApp.Character.TrackerPoolDynamicSupervisor

  setup do
    # Tracker pool supervision tree is not started in the test env
    if Process.whereis(WandererApp.Character.TrackerPoolSupervisor) == nil do
      start_supervised!(WandererApp.Character.TrackerPoolSupervisor)
    end

    {:ok, original_active} = WandererApp.Cache.lookup("tracked_characters", [])

    lost_id = "test_lost_char_#{System.unique_integer([:positive])}"
    pooled_id = "test_pooled_char_#{System.unique_integer([:positive])}"

    WandererApp.Cache.insert("tracked_characters", [lost_id, pooled_id | original_active])

    on_exit(fn ->
      WandererApp.Cache.insert("tracked_characters", original_active)
      Enum.each([lost_id, pooled_id], &Cachex.del(:tracked_characters, &1))
    end)

    {:ok, lost_id: lost_id, pooled_id: pooled_id}
  end

  test "re-tracks a character missing from all pools on the second consecutive check",
       %{lost_id: lost_id, pooled_id: pooled_id} do
    {:ok, _pid} = TrackerPoolDynamicSupervisor.start_tracking(pooled_id)
    assert MapSet.member?(TrackerPoolDynamicSupervisor.tracked_ids(), pooled_id)

    state = Impl.new(%{characters: [], opts: []})

    # First check only records the character as missing
    state = Impl.handle_info(:verify_tracker_pools, state)
    assert MapSet.member?(state.missing_from_pools, lost_id)
    refute MapSet.member?(state.missing_from_pools, pooled_id)
    refute MapSet.member?(TrackerPoolDynamicSupervisor.tracked_ids(), lost_id)

    # Second check re-tracks it
    state = Impl.handle_info(:verify_tracker_pools, state)

    wait_until(fn -> MapSet.member?(TrackerPoolDynamicSupervisor.tracked_ids(), lost_id) end)
    refute MapSet.member?(state.missing_from_pools, lost_id)

    # Once pooled, it is no longer reported missing
    state = Impl.handle_info(:verify_tracker_pools, state)
    refute MapSet.member?(state.missing_from_pools, lost_id)
  end

  test "a character that reappears in a pool before the second check is not re-tracked",
       %{lost_id: lost_id} do
    state = Impl.new(%{characters: [], opts: []})

    state = Impl.handle_info(:verify_tracker_pools, state)
    assert MapSet.member?(state.missing_from_pools, lost_id)

    # e.g. an in-flight {:add_tracked_id, _} cast landed in the meantime
    {:ok, _pid} = TrackerPoolDynamicSupervisor.start_tracking(lost_id)

    state = Impl.handle_info(:verify_tracker_pools, state)
    refute MapSet.member?(state.missing_from_pools, lost_id)

    pools_holding_id =
      :tracker_pool_registry
      |> Registry.lookup(WandererApp.Character.TrackerPool)
      |> Enum.count(fn {_pid, uuid} ->
        [{_, ids}] =
          Registry.lookup(
            :unique_tracker_pool_registry,
            Module.concat(WandererApp.Character.TrackerPool, uuid)
          )

        lost_id in ids
      end)

    assert pools_holding_id == 1
  end

  defp wait_until(fun, attempts \\ 50) do
    cond do
      fun.() ->
        :ok

      attempts > 0 ->
        Process.sleep(20)
        wait_until(fun, attempts - 1)

      true ->
        flunk("condition not met in time")
    end
  end
end
