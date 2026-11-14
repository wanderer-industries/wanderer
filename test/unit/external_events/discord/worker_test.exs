defmodule WandererApp.ExternalEvents.Discord.WorkerTest do
  use WandererApp.DataCase, async: false

  import WandererApp.ExternalEvents.Discord.TestHelpers

  alias WandererApp.Api.MapDiscordNotification
  alias WandererApp.ExternalEvents.Discord.{HttpStub, Worker, WorkerSupervisor}
  alias WandererAppWeb.Factory

  setup do
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

    map = Factory.insert(:map, %{})

    {:ok, notification} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/tok"
      })

    %{map: map, notification: notification}
  end

  defp message, do: %{"embeds" => [%{"title" => "test"}]}

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

  test "honors numeric retry_after in Discord's JSON rate-limit response", %{
    map: map,
    notification: n
  } do
    HttpStub.set_responses([{:ok, 429, [], ~s({"retry_after":20.0,"global":false})}])
    WorkerSupervisor.deliver(map.id, n.id, [message()])

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
      end)

    assert reloaded.last_error =~ "429"
    assert reloaded.last_error =~ "20000ms"
    assert length(HttpStub.requests()) == 1
  end

  for {scope, headers, body} <- [
        {"global header", [{"X-RateLimit-Global", "true"}], ~s({"retry_after":0.6})},
        {"scope header", [{"X-RateLimit-Scope", "global"}], ~s({"retry_after":0.6})},
        {"JSON flag", [], ~s({"retry_after":0.6,"global":true})},
        {"both flags", [{"x-ratelimit-global", "true"}, {"x-ratelimit-scope", "global"}],
         ~s({"retry_after":0.6,"global":true})}
      ] do
    @tag :review_batch
    test "delays another map's actual worker for a known global cooldown from #{scope}", %{
      map: map,
      notification: n
    } do
      other = Factory.insert(:map, %{})

      {:ok, other_n} =
        MapDiscordNotification.create(%{
          map_id: other.id,
          webhook_url: "https://discord.com/api/webhooks/456/other"
        })

      parent = self()

      probe = fn url, _ ->
        send(parent, {:network, url, System.monotonic_time(:millisecond)})
        {:ok, 204, []}
      end

      HttpStub.set_responses([
        fn _, _ ->
          send(parent, {:limited_at, System.monotonic_time(:millisecond)})
          {:ok, 429, [{"retry-after", "0.6"} | unquote(headers)], unquote(body)}
        end,
        probe,
        probe
      ])

      WorkerSupervisor.deliver(map.id, n.id, [message()])
      assert_receive {:limited_at, limited_at}, 1_000

      await_condition(fn ->
        if is_integer(sync(map.id).retry_at), do: {:ok, :limited}, else: :retry
      end)

      WorkerSupervisor.deliver(other.id, other_n.id, [message()])
      sync(other.id)
      sync(other.id)
      refute_receive {:network, _, _}, 100
      assert_receive {:network, "https://discord.com/api/webhooks/456/other", posted_at}, 1_000
      assert posted_at - limited_at >= 600
      assert length(wait_for_requests(3)) == 3
    end
  end

  @tag :review_batch
  test "shares a long global cooldown across map workers without sending early", %{
    map: map,
    notification: n
  } do
    other = Factory.insert(:map, %{})

    {:ok, other_n} =
      MapDiscordNotification.create(%{
        map_id: other.id,
        webhook_url: "https://discord.com/api/webhooks/456/other"
      })

    HttpStub.set_responses([
      {:ok, 429,
       [{"retry-after", "20"}, {"x-ratelimit-global", "true"}, {"x-ratelimit-scope", "global"}],
       ~s({"retry_after":20.0,"global":true})}
    ])

    WorkerSupervisor.deliver(map.id, n.id, [message()])

    await_condition(fn ->
      if is_integer(sync(map.id).retry_at), do: {:ok, :limited}, else: :retry
    end)

    WorkerSupervisor.deliver(other.id, other_n.id, [message()])
    sync(other.id)
    sync(other.id)
    Process.sleep(100)
    assert length(HttpStub.requests()) == 1
  end

  @tag :review_batch
  test "keeps a webhook-only cooldown local to its map", %{map: map, notification: n} do
    HttpStub.set_responses([
      {:ok, 429, [{"retry-after", "20"}, {"x-ratelimit-scope", "shared"}],
       ~s({"retry_after":20.0,"global":false})}
    ])

    WorkerSupervisor.deliver(map.id, n.id, [message()])

    await_condition(fn ->
      if is_integer(sync(map.id).retry_at), do: {:ok, :limited}, else: :retry
    end)

    other = Factory.insert(:map, %{})

    {:ok, other_n} =
      MapDiscordNotification.create(%{
        map_id: other.id,
        webhook_url: "https://discord.com/api/webhooks/456/other"
      })

    WorkerSupervisor.deliver(other.id, other_n.id, [message()])
    assert length(wait_for_requests(2)) == 2
  end

  @tag :review_batch
  test "retries a linked request task crash once without crashing the worker", %{
    map: map,
    notification: n
  } do
    HttpStub.set_responses([fn _, _ -> Process.exit(self(), :kill) end, {:ok, 204, []}])
    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)
    [{pid, _}] = Registry.lookup(WorkerSupervisor.registry(), map.id)

    await_condition(fn ->
      if reload(map.id).last_delivery_at, do: {:ok, :delivered}, else: :retry
    end)

    assert Process.alive?(pid)
    assert length(HttpStub.requests()) == 2
    assert reload(map.id).consecutive_failures == 0
  end

  @tag :review_batch
  test "stop_worker removes a busy worker rather than leaving it alive", %{
    map: map,
    notification: n
  } do
    parent = self()

    HttpStub.set_responses([
      fn _, _ ->
        send(parent, {:pending_request, self()})

        receive do
          :release ->
            send(parent, :late_effect)
            {:ok, 204, []}
        end
      end
    ])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    assert_receive {:pending_request, task}, 1_000
    task_ref = Process.monitor(task)

    on_exit(fn -> if Process.alive?(task), do: Process.exit(task, :kill) end)

    [{pid, _}] = Registry.lookup(WorkerSupervisor.registry(), map.id)
    # Model a blocked DB call: unlike suspension this also blocks system
    # messages, so GenServer.stop alone times out without killing the worker.
    Task.start(fn ->
      try do
        :sys.replace_state(pid, fn state ->
          send(parent, :worker_blocked)

          receive do
            :release -> state
          end
        end)
      catch
        # The deliberately blocked callback cannot reply before forced stop.
        :exit, _ -> :ok
      end
    end)

    assert_receive :worker_blocked
    on_exit(fn -> send(pid, :release) end)
    assert :ok = WorkerSupervisor.stop_worker(map.id)
    refute Process.alive?(pid)
    assert_receive {:DOWN, ^task_ref, :process, ^task, _}, 1_000
    send(task, :release)
    refute_receive :late_effect

    assert [] ==
             DynamicSupervisor.which_children(
               WandererApp.ExternalEvents.Discord.DynamicSupervisor
             )
  end

  test "does not resume queued delivery for a soft-deleted map", %{map: map, notification: n} do
    {:ok, _} = WandererApp.Api.Map.mark_as_deleted(map)
    WorkerSupervisor.deliver(map.id, n.id, [message()])
    sync(map.id)
    sync(map.id)
    assert HttpStub.requests() == []
    assert reload(map.id).last_delivery_at == nil
  end

  test "stops retrying when the global webhook switch turns off", %{map: map, notification: n} do
    HttpStub.set_responses([{:ok, 429, [{"retry-after", "0.05"}]}])
    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)
    original = Application.get_env(:wanderer_app, :external_events, [])

    Application.put_env(
      :wanderer_app,
      :external_events,
      Keyword.put(original, :webhooks_enabled, false)
    )

    await_condition(fn ->
      if sync(map.id).current == nil, do: {:ok, :idle}, else: :retry
    end)

    assert length(HttpStub.requests()) == 1
    assert reload(map.id).last_delivery_at == nil
    assert reload(map.id).consecutive_failures == 0
  end

  test "redacts credential-bearing transport errors and exceptions", %{map: map, notification: n} do
    secret = "synthetic-webhook-token"
    url = "https://discord.com/api/webhooks/123/#{secret}"
    {:ok, _} = MapDiscordNotification.update(n, %{webhook_url: url})

    for response <- [
          {:error, %RuntimeError{message: "request failed for #{url}"}},
          fn _, _ -> raise "request failed for #{url}" end
        ] do
      HttpStub.set_responses(
        List.duplicate({:ok, 429, [{"retry-after", "0.05"}]}, 4) ++ [response]
      )

      previous = reload(map.id).consecutive_failures

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          WorkerSupervisor.deliver(map.id, n.id, [message()])

          await_condition(fn ->
            rec = reload(map.id)
            if rec.consecutive_failures > previous, do: {:ok, rec}, else: :retry
          end)
        end)

      refute log =~ secret
      refute reload(map.id).last_error =~ secret
      assert reload(map.id).last_error =~ "connection error"
    end
  end

  test "destroy cancels the in-flight HTTP task and queued deliveries", %{
    map: map,
    notification: n
  } do
    parent = self()

    HttpStub.set_responses([
      fn _, _ ->
        send(parent, {:http_started, self()})

        receive do
          :release -> {:ok, 204, []}
        end
      end
    ])

    WorkerSupervisor.deliver(map.id, n.id, [message(), message()])
    assert_receive {:http_started, task}, 1_000
    on_exit(fn -> send(task, :release) end)
    ref = Process.monitor(task)

    assert :ok = MapDiscordNotification.destroy(n)
    assert_receive {:DOWN, ^ref, :process, ^task, _}, 1_000
    assert length(HttpStub.requests()) == 1
  end

  test "honors a long 429 cooldown for the next queued event", %{map: map, notification: n} do
    HttpStub.set_responses([{:ok, 429, [{"retry-after", "20"}]}])
    WorkerSupervisor.deliver(map.id, n.id, [message()])

    await_condition(fn ->
      rec = reload(map.id)
      if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
    end)

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    sync(map.id)
    Process.sleep(100)
    assert length(HttpStub.requests()) == 1
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
    # Two syncs, not a sleep: the first flushes the deliver cast, the second the
    # `:attempt` message that cast sends to itself. After both, the worker has
    # decided whether to post.
    sync(map.id)
    sync(map.id)

    assert HttpStub.requests() == []
  end

  test "drops the event when the notification was disabled while queued", %{
    map: map,
    notification: n
  } do
    {:ok, _} = MapDiscordNotification.update(n, %{enabled?: false})

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    sync(map.id)
    sync(map.id)

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

  test "a 429 with retry-after above the budget does not retry and records a failure", %{
    map: map,
    notification: n
  } do
    # Above @retry_after_give_up_ms: retrying this early ignores what Discord
    # asked for, so it must not be sent — the event is recorded as failed
    # instead of burning an attempt on an early request.
    HttpStub.set_responses([{:ok, 429, [{"retry-after", "20"}]}])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
      end)

    # One request only — no early retry against the instructed wait.
    assert length(HttpStub.requests()) == 1
    assert reloaded.enabled? == true
    assert reloaded.last_error =~ "429"
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

  # A payload that will not encode cannot become encodable by retrying, so this
  # must be classified permanent like a 4xx — otherwise it burns all 5 attempts
  # and surfaces in the settings tab as a "connection error".
  test "does not retry an encode failure, but counts it", %{map: map, notification: n} do
    HttpStub.set_responses([{:error, {:encode_failed, :bad_term}}])

    WorkerSupervisor.deliver(map.id, n.id, [message()])
    wait_for_requests(1)

    reloaded =
      await_condition(fn ->
        rec = reload(map.id)
        if rec.consecutive_failures == 1, do: {:ok, rec}, else: :retry
      end)

    assert length(HttpStub.requests()) == 1
    assert reloaded.enabled? == true
    assert reloaded.last_error =~ "invalid payload"
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
