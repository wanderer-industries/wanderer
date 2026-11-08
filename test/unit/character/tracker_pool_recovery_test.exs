defmodule WandererApp.Character.TrackerPoolRecoveryTest do
  use ExUnit.Case, async: false

  alias WandererApp.Character.TrackerPool

  @cache :tracked_characters
  @unique_registry :unique_tracker_pool_registry

  setup do
    # Tracker pool registries are not started in the test env
    ensure_registry(@unique_registry, :unique)
    ensure_registry(:tracker_pool_registry, :duplicate)

    uuid = "test_pool_#{System.unique_integer([:positive])}"
    ids = for n <- 1..3, do: "test_char_#{n}_#{System.unique_integer([:positive])}"

    {:ok, original_active} = WandererApp.Cache.lookup("tracked_characters", [])
    WandererApp.Cache.insert("tracked_characters", ids ++ original_active)

    on_exit(fn ->
      WandererApp.Cache.insert("tracked_characters", original_active)
      Enum.each(ids, &Cachex.del(@cache, &1))
    end)

    {:ok, uuid: uuid, ids: ids}
  end

  test "restarted pool keeps its uuid and recovers characters added after start",
       %{uuid: uuid, ids: [first | added] = ids} do
    pid = start_pool(uuid, [first])

    Enum.each(added, &GenServer.cast(pid, {:add_tracked_id, &1}))
    assert_tracked(uuid, ids)

    new_pid = crash_and_wait_for_restart(pid, uuid)

    assert new_pid != pid
    assert_tracked(uuid, ids)
    assert Enum.all?(ids, &(Cachex.get(@cache, &1) == {:ok, uuid}))
  end

  test "characters stopped while the pool was down are not recovered",
       %{uuid: uuid, ids: [first, kept, stopped]} do
    pid = start_pool(uuid, [first])
    Enum.each([kept, stopped], &GenServer.cast(pid, {:add_tracked_id, &1}))
    assert_tracked(uuid, [first, kept, stopped])

    # TrackerManager already forgot `stopped`, but its remove cast never reached the pool
    WandererApp.Cache.insert_or_update("tracked_characters", [], &List.delete(&1, stopped))

    crash_and_wait_for_restart(pid, uuid)

    assert_tracked(uuid, [first, kept])
    assert {:ok, nil} = Cachex.get(@cache, stopped)
  end

  test "graceful stop removes cache entries", %{uuid: uuid, ids: [first | added] = ids} do
    pid = start_pool(uuid, [first])
    Enum.each(added, &GenServer.cast(pid, {:add_tracked_id, &1}))
    assert_tracked(uuid, ids)

    :ok = GenServer.stop(pid, :normal)

    assert Enum.all?(ids, &(Cachex.get(@cache, &1) == {:ok, nil}))
  end

  defp start_pool(uuid, tracked_ids) do
    start_supervised!(%{
      id: uuid,
      start: {TrackerPool, :start_link, [{uuid, tracked_ids}]},
      restart: :transient
    })
  end

  defp crash_and_wait_for_restart(pid, uuid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    wait_until(fn ->
      case Registry.lookup(@unique_registry, Module.concat(TrackerPool, uuid)) do
        [{new_pid, _}] when new_pid != pid -> new_pid
        _ -> nil
      end
    end)
  end

  defp assert_tracked(uuid, expected_ids) do
    wait_until(fn ->
      with [{pid, registered}] <-
             Registry.lookup(@unique_registry, Module.concat(TrackerPool, uuid)),
           %{characters: characters} <- :sys.get_state(pid),
           true <- Enum.sort(registered) == Enum.sort(expected_ids),
           true <- Enum.sort(characters) == Enum.sort(expected_ids) do
        true
      else
        _ -> nil
      end
    end)
  end

  defp wait_until(fun, attempts \\ 50) do
    case fun.() do
      nil when attempts > 0 ->
        Process.sleep(20)
        wait_until(fun, attempts - 1)

      nil ->
        flunk("condition not met in time")

      result ->
        result
    end
  end

  defp ensure_registry(name, keys) do
    if Process.whereis(name) == nil do
      start_supervised!({Registry, keys: keys, name: name}, id: name)
    end
  end
end
