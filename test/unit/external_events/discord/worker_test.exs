defmodule WandererApp.ExternalEvents.Discord.WorkerTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.MapDiscordNotification
  alias WandererApp.ExternalEvents.Discord.{HttpStub, Worker, WorkerSupervisor}
  alias WandererAppWeb.Factory

  setup do
    HttpStub.start()
    HttpStub.reset()

    start_supervised!(WorkerSupervisor)

    map = Factory.insert(:map, %{})

    {:ok, notification} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/tok"
      })

    %{map: map, notification: notification}
  end

  defp message, do: %{"embeds" => [%{"title" => "test"}]}

  defp wait_for_requests(count, timeout \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait(count, deadline)
  end

  defp do_wait(count, deadline) do
    if length(HttpStub.requests()) >= count do
      HttpStub.requests()
    else
      if System.monotonic_time(:millisecond) > deadline do
        flunk("expected #{count} requests, got #{length(HttpStub.requests())}")
      else
        Process.sleep(25)
        do_wait(count, deadline)
      end
    end
  end

  # Blocks until the worker has drained its mailbox up to this point. Cheaper
  # and far less flaky than sleeping, now that every attempt is scheduled.
  defp sync(map_id) do
    case Registry.lookup(WorkerSupervisor.registry(), map_id) do
      [{pid, _}] -> :sys.get_state(pid)
      [] -> :no_worker
    end
  end

  defp await_condition(fun, timeout \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await_condition(fun, deadline)
  end

  defp do_await_condition(fun, deadline) do
    case fun.() do
      {:ok, value} ->
        value

      :retry ->
        if System.monotonic_time(:millisecond) > deadline do
          flunk("condition not met before deadline")
        else
          Process.sleep(25)
          do_await_condition(fun, deadline)
        end
    end
  end

  defp reload(map_id) do
    {:ok, rec} = MapDiscordNotification.by_map(map_id)
    rec
  end

  test "delivers a message to the configured url", %{map: map, notification: n} do
    WorkerSupervisor.deliver(map.id, n.id, [message()])

    assert [{url, body}] = wait_for_requests(1)
    assert url == "https://discord.com/api/webhooks/123/tok"
    assert %{"embeds" => _} = body
  end

  test "records success on the notification", %{map: map, notification: n} do
    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.last_delivery_at, do: {:ok, rec}, else: :retry
      end)

    assert reloaded.consecutive_failures == 0
  end

  test "reloads the notification, so a replaced url is not used", %{map: map, notification: n} do
    # Change the URL after capturing the (now stale) struct the caller holds.
    {:ok, _} =
      MapDiscordNotification.update(n, %{
        webhook_url: "https://discord.com/api/webhooks/999/newtok"
      })

    WorkerSupervisor.deliver(map.id, n.id, [message()])

    assert [{url, _body}] = wait_for_requests(1)
    assert url == "https://discord.com/api/webhooks/999/newtok"
  end

  test "drops the event when the notification was deleted while queued", %{
    map: map,
    notification: n
  } do
    Ash.destroy!(n)

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    Process.sleep(300)

    assert HttpStub.requests() == []
  end

  test "drops the event when the notification was disabled while queued", %{
    map: map,
    notification: n
  } do
    {:ok, _} = MapDiscordNotification.update(n, %{enabled?: false})

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    Process.sleep(300)

    assert HttpStub.requests() == []
  end

  test "sends multi-chunk events in order", %{map: map, notification: n} do
    msgs = [
      %{"embeds" => [%{"title" => "one"}]},
      %{"embeds" => [%{"title" => "two"}]},
      %{"embeds" => [%{"title" => "three"}]}
    ]

    WorkerSupervisor.deliver(map.id, n.id, msgs)
    requests = wait_for_requests(3)

    titles =
      Enum.map(requests, fn {_url, body} ->
        body["embeds"] |> hd() |> Map.get("title")
      end)

    assert titles == ["one", "two", "three"]
  end

  test "retries after a 429 honoring retry_after", %{map: map, notification: n} do
    HttpStub.set_responses([
      {:ok, 429, [{"retry-after", "0.05"}]},
      {:ok, 204, []}
    ])

    WorkerSupervisor.deliver(map.id, n.id, [message()])

    assert length(wait_for_requests(2)) == 2
  end

  test "does not block its mailbox while waiting to retry", %{map: map, notification: n} do
    # A long retry-after must not stop the worker answering new casts: if the
    # send path slept, this :sys.get_state would time out.
    HttpStub.set_responses([{:ok, 429, [{"retry-after", "2"}]}, {:ok, 204, []}])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    assert %{} = sync(map.id)
  end

  test "drops the oldest event when the queue is full", %{map: map, notification: n} do
    # Hold the worker on a long retry so nothing drains while we overfill.
    HttpStub.set_responses([{:ok, 429, [{"retry-after", "5"}]}])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    for i <- 1..120 do
      WorkerSupervisor.deliver(map.id, n.id, [%{"embeds" => [%{"title" => "q#{i}"}]}])
    end

    state = sync(map.id)

    assert state.queue_len == 100
    # Oldest were dropped, so the newest enqueued event survived.
    assert state.queue |> :queue.to_list() |> List.last() |> elem(1) ==
             [%{"embeds" => [%{"title" => "q120"}]}]
  end

  test "does not retry a 403, but counts it as a failure", %{map: map, notification: n} do
    HttpStub.set_responses([{:ok, 403, []}])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
      end)

    # One request only — 403 is permanent, no retry.
    assert length(HttpStub.requests()) == 1
    # But it does NOT disable on its own; the 10-failure threshold governs.
    assert reloaded.enabled? == true
    assert reloaded.last_error =~ "403"
  end

  test "a 401 increments failures without disabling", %{map: map, notification: n} do
    HttpStub.set_responses([{:ok, 401, []}])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
      end)

    assert reloaded.enabled? == true
  end

  test "disables the notification on 404", %{map: map, notification: n} do
    HttpStub.set_responses([{:ok, 404, []}])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.enabled? == false, do: {:ok, rec}, else: :retry
      end)

    assert reloaded.last_error =~ "404"
  end

  test "disables after 10 consecutive failed events", %{map: map, notification: n} do
    HttpStub.set_responses(for _ <- 1..10, do: {:ok, 403, []})

    for _ <- 1..10 do
      WorkerSupervisor.deliver(map.id, n.id, [message()])
    end

    reloaded =
      await_condition(
        fn ->
          rec = reload(map.id)
          if rec.consecutive_failures >= 10, do: {:ok, rec}, else: :retry
        end,
        5_000
      )

    assert reloaded.enabled? == false
  end

  test "a later failing chunk is not masked by an earlier success", %{map: map, notification: n} do
    HttpStub.set_responses([
      {:ok, 204, []},
      {:ok, 500, []},
      {:ok, 500, []},
      {:ok, 500, []},
      {:ok, 500, []},
      {:ok, 500, []}
    ])

    WorkerSupervisor.deliver(map.id, n.id, [message(), message()])

    reloaded =
      await_condition(
        fn ->
          rec = reload(map.id)
          if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
        end,
        20_000
      )

    assert reloaded.last_error != nil
    # Per-event semantics: the successful first chunk must not stamp a delivery.
    assert reloaded.last_delivery_at == nil
  end

  test "stop_worker terminates a running worker", %{map: map, notification: n} do
    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    assert [{pid, _}] = Registry.lookup(WorkerSupervisor.registry(), map.id)
    ref = Process.monitor(pid)

    assert :ok = WorkerSupervisor.stop_worker(map.id)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

    # Registry cleans up its entry asynchronously when the owner dies, so the
    # :DOWN can arrive before the key is released. Poll rather than sleep.
    await_condition(fn ->
      case Registry.lookup(WorkerSupervisor.registry(), map.id) do
        [] -> {:ok, []}
        _ -> :retry
      end
    end)
  end

  test "stop_worker is a no-op when no worker is running", %{map: map} do
    assert :ok = WorkerSupervisor.stop_worker(map.id)
  end

  test "deliver returns an error instead of raising when the supervisor is down", %{
    map: map,
    notification: n
  } do
    # The kill-switch case: application.ex only starts WorkerSupervisor when
    # webhooks are enabled, so the registry may not exist at all. deliver/3 and
    # stop_worker/1 must be equally tolerant — a dispatcher call must not crash
    # just because the feature is off.
    stop_supervised!(WorkerSupervisor)
    refute Process.whereis(WorkerSupervisor.registry())

    assert {:error, :not_running} = WorkerSupervisor.deliver(map.id, n.id, [message()])
    assert :ok = WorkerSupervisor.stop_worker(map.id)
    assert HttpStub.requests() == []
  end

  test "shuts down when idle", %{map: map} do
    # Tiny idle timeout so this exercises the real shutdown path in ms.
    pid =
      start_supervised!(
        {Worker, map_id: map.id, registry: WorkerSupervisor.registry(), idle_timeout: 50},
        restart: :temporary
      )

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
  end

  test "gives up on an event whose deadline has passed, without sending", %{
    map: map,
    notification: n
  } do
    # A negative deadline is already expired when the first attempt runs, so
    # the event is abandoned before any request goes out.
    pid =
      start_supervised!(
        {Worker, map_id: map.id, registry: WorkerSupervisor.registry(), event_deadline_ms: -1},
        restart: :temporary
      )

    Worker.enqueue(pid, n.id, [message()])

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
      end)

    assert HttpStub.requests() == []
    assert reloaded.last_error =~ "deadline"
    assert reloaded.last_delivery_at == nil
  end
end
