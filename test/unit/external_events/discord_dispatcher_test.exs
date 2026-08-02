defmodule WandererApp.ExternalEvents.DiscordDispatcherTest do
  # `async: false` is mandatory: `HttpStub` keeps its state in a single named
  # Agent, and this file also mutates application env.
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.MapDiscordNotification
  alias WandererApp.ExternalEvents.{DiscordDispatcher, Event}
  alias WandererApp.ExternalEvents.Discord.{EmbedFormatter, HttpStub, WorkerSupervisor}
  alias WandererAppWeb.Factory

  # A real wormhole system id (J-space) and a real known-space id (Jita).
  @wh_system 31_000_005
  @ks_system 30_000_142

  setup do
    # `wh_only` filtering resolves the system class through
    # `CachedInfo.get_system_static_info/1`, which falls back to the
    # `map_solar_systems` table. That table is static import data and is NOT
    # populated by `mix test` on a clean database, so seed the cache directly —
    # the same approach `WandererApp.MapTestHelpers` uses.
    seed_static_info()

    # `config/test.exs:35` sets `external_events: [webhooks_enabled: false]`, and
    # the dispatcher checks `Env.webhooks_enabled?/0` at call time. Without this
    # override EVERY delivery assertion below would pass while sending nothing.
    original = Application.get_env(:wanderer_app, :external_events, [])

    Application.put_env(
      :wanderer_app,
      :external_events,
      Keyword.put(original, :webhooks_enabled, true)
    )

    on_exit(fn -> Application.put_env(:wanderer_app, :external_events, original) end)

    HttpStub.start()
    HttpStub.reset()
    start_supervised!(WorkerSupervisor)
    start_supervised!(DiscordDispatcher)

    map = Factory.insert(:map, %{})

    {:ok, notification} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/tok"
      })

    DiscordDispatcher.invalidate_cache(map.id)

    %{map: map, notification: notification}
  end

  # C3 for the J-space id, high-sec (class 0) for Jita, matching the shape
  # `MapTestHelpers.default_test_systems/0` stores.
  #
  # `:system_static_info_cache` is a GLOBAL Cachex table, not sandboxed per test,
  # so these entries must be removed again: `CommonAPIControllerTest` inserts its
  # own Jita row and reads it back through this same cache, and a partial entry
  # left behind here makes it fail on a missing `region_id`.
  defp seed_static_info do
    Cachex.put(:system_static_info_cache, @wh_system, %{
      solar_system_id: @wh_system,
      solar_system_name: "J115405",
      system_class: 3
    })

    Cachex.put(:system_static_info_cache, @ks_system, %{
      solar_system_id: @ks_system,
      solar_system_name: "Jita",
      system_class: 0
    })

    on_exit(fn ->
      Cachex.del(:system_static_info_cache, @wh_system)
      Cachex.del(:system_static_info_cache, @ks_system)
    end)

    :ok
  end

  defp disable_gate do
    original = Application.get_env(:wanderer_app, :external_events, [])

    Application.put_env(
      :wanderer_app,
      :external_events,
      Keyword.put(original, :webhooks_enabled, false)
    )

    on_exit(fn -> Application.put_env(:wanderer_app, :external_events, original) end)
  end

  defp kill_event(payload), do: %Event{map_id: nil, type: :map_kill, payload: payload}

  # Dispatch is a cast and delivery is a second async hop, so tests synchronize
  # rather than guess: drain the dispatcher's mailbox, then the worker's.
  defp settle(map_id) do
    :sys.get_state(DiscordDispatcher)

    case Registry.lookup(WorkerSupervisor.registry(), map_id) do
      [{pid, _}] -> :sys.get_state(pid)
      [] -> :no_worker
    end
  end

  # Asserting "nothing was delivered" needs more than `settle/1`: the HTTP call
  # itself runs in a `Task.Supervisor.async_nolink` task, so a request can still
  # be in flight when the worker's mailbox is drained. Wait until the worker is
  # genuinely idle (no queued event, none in progress) before asserting, or the
  # assertion passes for the wrong reason. Mutating the seeded system class
  # confirms this: without the wait, marking Jita as wormhole space still leaves
  # "skips non-wormhole systems" green.
  defp refute_delivery(map_id, timeout \\ 2_000) do
    settle(map_id)
    await_worker_idle(map_id, System.monotonic_time(:millisecond) + timeout)
    assert HttpStub.requests() == []
  end

  defp await_worker_idle(map_id, deadline) do
    case Registry.lookup(WorkerSupervisor.registry(), map_id) do
      [] ->
        :no_worker

      [{pid, _}] ->
        state = :sys.get_state(pid)

        cond do
          state.current == nil and state.queue_len == 0 -> :idle
          System.monotonic_time(:millisecond) >= deadline -> :timeout
          true -> await_worker_idle(map_id, deadline)
        end
    end
  end

  defp wait_for_requests(count, timeout \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait(count, deadline)
  end

  defp do_wait(count, deadline) do
    cond do
      length(HttpStub.requests()) >= count ->
        HttpStub.requests()

      System.monotonic_time(:millisecond) > deadline ->
        flunk("expected #{count} requests, got #{length(HttpStub.requests())}")

      true ->
        Process.sleep(25)
        do_wait(count, deadline)
    end
  end

  test "sends nothing when the global webhook gate is off", %{map: map} do
    # Covers the gate itself rather than assuming it. This is the failure mode
    # that would otherwise make every test in this file green but meaningless.
    disable_gate()

    event = kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system}))

    DiscordDispatcher.dispatch_event(map.id, event)

    refute_delivery(map.id)
  end

  test "delivers a wormhole kill", %{map: map} do
    event = kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system}))

    DiscordDispatcher.dispatch_event(map.id, event)
    settle(map.id)

    assert length(wait_for_requests(1)) == 1
  end

  test "ignores kill_count events", %{map: map} do
    event = kill_event(Factory.build(:kill_count_event, %{solar_system_id: @wh_system}))

    DiscordDispatcher.dispatch_event(map.id, event)

    refute_delivery(map.id)
  end

  test "skips non-wormhole systems when wh_only is set", %{map: map} do
    event = kill_event(Factory.build(:kill_event, %{solar_system_id: @ks_system}))

    DiscordDispatcher.dispatch_event(map.id, event)

    refute_delivery(map.id)
  end

  test "delivers known-space kills when wh_only is off", %{map: map, notification: n} do
    {:ok, _} = MapDiscordNotification.update(n, %{wh_only: false})
    DiscordDispatcher.invalidate_cache(map.id)

    event = kill_event(Factory.build(:kill_event, %{solar_system_id: @ks_system}))

    DiscordDispatcher.dispatch_event(map.id, event)
    settle(map.id)

    assert length(wait_for_requests(1)) == 1
  end

  test "skips excluded systems", %{map: map, notification: n} do
    {:ok, _} = MapDiscordNotification.update(n, %{excluded_systems: [@wh_system]})
    DiscordDispatcher.invalidate_cache(map.id)

    event = kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system}))

    DiscordDispatcher.dispatch_event(map.id, event)

    refute_delivery(map.id)
  end

  test "skips when disabled", %{map: map, notification: n} do
    {:ok, _} = MapDiscordNotification.update(n, %{enabled?: false})
    DiscordDispatcher.invalidate_cache(map.id)

    event = kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system}))

    DiscordDispatcher.dispatch_event(map.id, event)

    refute_delivery(map.id)
  end

  test "no-ops for a map with no configuration" do
    other_map = Factory.insert(:map, %{})
    event = kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system}))

    DiscordDispatcher.dispatch_event(other_map.id, event)

    refute_delivery(other_map.id)
  end

  test "deduplicates a replayed killmail", %{map: map} do
    kill = Factory.build(:killmail, %{solar_system_id: @wh_system, killmail_id: 777_777})
    payload = Factory.build(:kill_event, %{solar_system_id: @wh_system, killmails: [kill]})

    DiscordDispatcher.dispatch_event(map.id, kill_event(payload))
    settle(map.id)
    wait_for_requests(1)

    DiscordDispatcher.dispatch_event(map.id, kill_event(payload))
    settle(map.id)

    assert length(HttpStub.requests()) == 1
  end

  test "delivers only the new kills in a partially-replayed batch", %{map: map} do
    old = Factory.build(:killmail, %{solar_system_id: @wh_system, killmail_id: 111})
    new = Factory.build(:killmail, %{solar_system_id: @wh_system, killmail_id: 222})

    DiscordDispatcher.dispatch_event(
      map.id,
      kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system, killmails: [old]}))
    )

    settle(map.id)
    wait_for_requests(1)

    DiscordDispatcher.dispatch_event(
      map.id,
      kill_event(
        Factory.build(:kill_event, %{solar_system_id: @wh_system, killmails: [old, new]})
      )
    )

    settle(map.id)

    assert [{_, _}, {_, second_body}] = wait_for_requests(2)
    assert length(second_body["embeds"]) == 1
  end

  test "ignores non-kill event types", %{map: map} do
    event = %Event{map_id: map.id, type: :add_system, payload: %{}}

    DiscordDispatcher.dispatch_event(map.id, event)

    refute_delivery(map.id)
  end

  # Guards the carry-forward constraint: WorkerSupervisor.deliver/3 answers
  # {:error, :not_running} when the worker tree is down. The dispatcher must
  # neither crash nor treat that as delivered, and — since nothing was enqueued
  # — must release the dedup marks so the kill can still be sent later.
  test "survives the worker tree being down and does not burn the dedup mark", %{map: map} do
    kill = Factory.build(:killmail, %{solar_system_id: @wh_system, killmail_id: 999_111})
    payload = Factory.build(:kill_event, %{solar_system_id: @wh_system, killmails: [kill]})

    :ok = stop_supervised(WorkerSupervisor)

    DiscordDispatcher.dispatch_event(map.id, kill_event(payload))
    :sys.get_state(DiscordDispatcher)

    assert HttpStub.requests() == []
    assert Process.alive?(Process.whereis(DiscordDispatcher))

    start_supervised!(WorkerSupervisor)

    DiscordDispatcher.dispatch_event(map.id, kill_event(payload))
    settle(map.id)

    assert length(wait_for_requests(1)) == 1
  end

  # Pins the dedup key as PER-MAP. Deleting `map_id` from `dedup_key/2` makes
  # every other test still pass, while the second map would silently stop
  # receiving any kill the first one already reported.
  test "dedup is per-map: two maps both receive the same killmail", %{map: map_a} do
    map_b = Factory.insert(:map, %{})
    url_b = "https://discord.com/api/webhooks/456/tok-b"

    {:ok, _} = MapDiscordNotification.create(%{map_id: map_b.id, webhook_url: url_b})
    DiscordDispatcher.invalidate_cache(map_b.id)

    kill = Factory.build(:killmail, %{solar_system_id: @wh_system, killmail_id: 555_555})
    payload = Factory.build(:kill_event, %{solar_system_id: @wh_system, killmails: [kill]})

    DiscordDispatcher.dispatch_event(map_a.id, kill_event(payload))
    settle(map_a.id)
    wait_for_requests(1)

    DiscordDispatcher.dispatch_event(map_b.id, kill_event(payload))
    settle(map_b.id)

    requests = wait_for_requests(2)
    assert length(requests) == 2

    # Distinct webhook URLs prove both maps were served, not one map twice.
    urls = requests |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    assert urls == Enum.sort(["https://discord.com/api/webhooks/123/tok", url_b])
  end

  # Kills past the formatter's per-event cap are never rendered into a message,
  # so they must not be marked attempted — otherwise they are burned for the
  # full dedup TTL without ever being sent.
  test "does not burn kills dropped by the formatter's per-event cap", %{map: map} do
    cap = EmbedFormatter.max_kills_per_event()

    kills =
      for i <- 1..(cap + 5) do
        Factory.build(:killmail, %{solar_system_id: @wh_system, killmail_id: 600_000 + i})
      end

    overflow = Enum.drop(kills, cap)
    assert length(overflow) == 5

    DiscordDispatcher.dispatch_event(
      map.id,
      kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system, killmails: kills}))
    )

    settle(map.id)
    first_batch = wait_for_requests(1)

    # The overflow kills arrive again on their own: they were never formatted,
    # so they are still eligible and must be delivered now.
    DiscordDispatcher.dispatch_event(
      map.id,
      kill_event(Factory.build(:kill_event, %{solar_system_id: @wh_system, killmails: overflow}))
    )

    settle(map.id)

    later = wait_for_requests(length(first_batch) + 1)
    [{_url, body} | _] = Enum.drop(later, length(first_batch))
    assert length(body["embeds"]) == 5
  end

  test "send_test_message reports the global gate being off", %{map: map} do
    disable_gate()

    assert {:error, :notifications_disabled} = DiscordDispatcher.send_test_message(map.id)
    assert HttpStub.requests() == []
  end

  test "send_test_message goes through the worker", %{map: map} do
    assert :ok = DiscordDispatcher.send_test_message(map.id)

    assert [{_url, body}] = wait_for_requests(1)
    assert body["content"] =~ "test message"
  end

  test "send_test_message reports an unconfigured map" do
    other_map = Factory.insert(:map, %{})

    assert {:error, :not_configured} = DiscordDispatcher.send_test_message(other_map.id)
  end
end
