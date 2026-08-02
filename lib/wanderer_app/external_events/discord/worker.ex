defmodule WandererApp.ExternalEvents.Discord.Worker do
  @moduledoc """
  Serializes Discord delivery for one map.

  Discord rate-limits a webhook to roughly 5 requests/second and answers 429
  with a `retry-after`. Everything for a map funnels through this process so
  concurrent kill batches cannot interleave and burst.

  ## Asynchronous: never blocks on the network

  Each request and each retry is scheduled with `Process.send_after/3` and
  handled in `handle_info`, so the process returns to its mailbox between
  attempts. This is deliberate: a worker that sleeps inside `handle_cast`
  cannot process incoming casts, which would make the 100-item queue bound
  meaningless — events would pile up unbounded in the mailbox instead of being
  dropped by the cap. (The existing `WebhookDispatcher` sleeps inside its retry
  loop at `webhook_dispatcher.ex:355,376`; it is not the model here.)

  The HTTP request itself runs in a monitored `Task` for the same reason: a
  synchronous call would block the process for up to the client's 15s receive
  timeout, and a queue bound the mailbox routes around is not a bound at all.

  The database calls are the deliberate exception, and the guarantee is
  specifically "never blocks on the *network*", not "never blocks". The
  notification reload in `attempt/1` is synchronous because it must be ordered
  before the send — the whole point is that no request goes out against a stale
  record, which an async reload could not guarantee. The status write shares
  that call's result. Under Ecto pool exhaustion (prod `queue_target` 5s) these
  can block, which is the same mailbox-accumulation failure mode via the DB
  rather than the socket; it is bounded by the pool timeout and accepted here.

  ## Ids, not records

  The queue holds `{notification_id, messages}`. The notification is reloaded
  from the database immediately before every send, so a webhook URL the user
  has replaced or deleted is never used, and a stale `consecutive_failures`
  snapshot cannot corrupt the counter.

  If the reload finds the notification deleted, or finds `enabled?` false, the
  queued event is dropped silently: no request, and no status write. There is
  nothing meaningful to record against a row the user removed, and writing a
  failure onto a row they deliberately disabled would be misleading.

  ## Per-event status

  Delivery status is tracked per *event*, not per request: a multi-chunk event
  is only a success once every chunk lands, and an early successful chunk never
  clears an error recorded by a later one.

  ## Limits

  An event gets at most 5 attempts per chunk and is subject to a ~60s deadline.
  The deadline is checked before dispatching an attempt, not while a request is
  in flight, so an event can overrun by up to one request duration (worst case
  ~75s with the client's 15s timeout). It is a bound on *starting* new work, not
  a hard wall-clock cap; nothing downstream depends on the exact figure.
  """

  use GenServer, restart: :transient

  require Logger

  alias WandererApp.Api.MapDiscordNotification
  alias WandererApp.ExternalEvents.Discord.HttpClient

  @idle_timeout :timer.seconds(60)
  @max_queue 100
  @max_attempts 5
  @event_deadline_ms 60_000
  @max_retry_after_ms 10_000
  @min_retry_after_ms 50

  def start_link(opts) do
    map_id = Keyword.fetch!(opts, :map_id)
    registry = Keyword.fetch!(opts, :registry)
    GenServer.start_link(__MODULE__, opts, name: {:via, Registry, {registry, map_id}})
  end

  @doc "Queues one event's messages for delivery, by notification id."
  def enqueue(pid, notification_id, messages) do
    GenServer.cast(pid, {:enqueue, notification_id, messages})
  end

  @impl true
  def init(opts) do
    # Both timeouts are overridable so tests can exercise idle shutdown and
    # deadline expiry without waiting a real minute. Production always uses the
    # module defaults.
    idle_timeout = Keyword.get(opts, :idle_timeout, @idle_timeout)

    {:ok,
     %{
       map_id: Keyword.fetch!(opts, :map_id),
       idle_timeout: idle_timeout,
       event_deadline_ms: Keyword.get(opts, :event_deadline_ms, @event_deadline_ms),
       queue: :queue.new(),
       queue_len: 0,
       # nil when idle, otherwise the event currently being delivered
       current: nil
     }, idle_timeout}
  end

  @impl true
  def handle_cast({:enqueue, notification_id, messages}, state) do
    state =
      state
      |> push({notification_id, messages})
      |> maybe_start_next()

    {:noreply, state, state.idle_timeout}
  end

  @impl true
  def handle_info(:attempt, %{current: nil} = state) do
    state = maybe_start_next(state)
    {:noreply, state, state.idle_timeout}
  end

  def handle_info(:attempt, state) do
    state = attempt(state)
    {:noreply, state, state.idle_timeout}
  end

  # Reply from the in-flight request task.
  def handle_info({ref, result}, %{current: %{task_ref: ref}} = state) when is_reference(ref) do
    # Demonitor first: the task is about to send its :DOWN, and we do not want
    # to treat normal completion as a crash.
    Process.demonitor(ref, [:flush])
    state = handle_post_result(state, result)
    {:noreply, state, state.idle_timeout}
  end

  # The request task crashed. Treat it as a transient failure and retry, rather
  # than losing the event: async_nolink means this does not take the worker down.
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{current: %{task_ref: ref}} = state)
      when is_reference(ref) do
    state = put_current(state, %{state.current | task_ref: nil})

    state =
      schedule_retry(
        state,
        backoff_ms(state.current.attempt),
        "request crashed: #{inspect(reason)}"
      )

    {:noreply, state, state.idle_timeout}
  end

  # A late reply or DOWN from a task we already gave up on — ignore it.
  def handle_info({ref, _result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, state, state.idle_timeout}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) when is_reference(ref) do
    {:noreply, state, state.idle_timeout}
  end

  def handle_info(:timeout, %{queue_len: 0, current: nil} = state) do
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state), do: {:noreply, state, state.idle_timeout}

  def handle_info(msg, state) do
    Logger.debug("[Discord.Worker] unexpected message: #{inspect(msg)}")
    {:noreply, state, state.idle_timeout}
  end

  # -- queue ----------------------------------------------------------------

  defp push(%{queue_len: len} = state, item) when len >= @max_queue do
    # Drop the oldest: a feed 100 messages behind has already failed its
    # purpose, and unbounded growth risks the VM. queue_len is unchanged
    # because one item leaves as one enters.
    {{:value, _dropped}, q} = :queue.out(state.queue)
    Logger.warning("[Discord.Worker] queue full for map #{state.map_id}, dropping oldest event")
    %{state | queue: :queue.in(item, q)}
  end

  defp push(state, item) do
    %{state | queue: :queue.in(item, state.queue), queue_len: state.queue_len + 1}
  end

  defp maybe_start_next(%{current: current} = state) when not is_nil(current), do: state

  defp maybe_start_next(state) do
    case :queue.out(state.queue) do
      {:empty, _} ->
        state

      {{:value, {notification_id, messages}}, rest} ->
        current = %{
          notification_id: notification_id,
          pending: messages,
          attempt: 1,
          task_ref: nil,
          # Most recently loaded record, reused for the status write so
          # finishing an event does not re-query what we just read.
          notification: nil,
          deadline: System.monotonic_time(:millisecond) + state.event_deadline_ms
        }

        send(self(), :attempt)
        %{state | queue: rest, queue_len: state.queue_len - 1, current: current}
    end
  end

  # -- one attempt ----------------------------------------------------------

  defp attempt(%{current: %{pending: []}} = state), do: finish(state, :ok)

  defp attempt(%{current: current} = state) do
    cond do
      System.monotonic_time(:millisecond) > current.deadline ->
        finish(state, {:error, "delivery deadline exceeded", :count})

      current.attempt > @max_attempts ->
        finish(state, {:error, "gave up after #{@max_attempts} attempts", :count})

      true ->
        # Reload every time: the URL may have been replaced or the config
        # deleted since this event was queued. This reload is the one that
        # matters — nothing is sent against a stale record.
        case MapDiscordNotification.by_id(current.notification_id) do
          {:ok, notification} ->
            state = put_current(state, %{current | notification: notification})

            if notification.enabled? do
              do_post(state, notification)
            else
              # Disabled while queued — drop the event silently, no status write.
              drop_current(state)
            end

          _ ->
            Logger.debug("[Discord.Worker] notification gone, dropping queued event")
            drop_current(state)
        end
    end
  end

  # Runs the request in a monitored Task so the worker never blocks on the
  # socket. The HTTP client can take up to its 15s receive timeout; blocking
  # here would let casts pile up in the mailbox and silently defeat the
  # bounded state queue — the same defect as sleeping, just harder to see.
  defp do_post(%{current: current} = state, notification) do
    [message | _rest] = current.pending
    url = notification.webhook_url

    task =
      Task.Supervisor.async_nolink(
        WandererApp.ExternalEvents.Discord.TaskSupervisor,
        fn -> HttpClient.post(url, message) end
      )

    put_current(state, %{current | task_ref: task.ref})
  end

  defp handle_post_result(state, result) do
    current = state.current
    [_sent | rest] = current.pending

    case result do
      {:ok, status, _headers} when status in 200..299 ->
        # Chunk delivered: move on with a fresh attempt budget, same deadline.
        state = put_current(state, %{current | pending: rest, attempt: 1, task_ref: nil})

        if rest == [] do
          finish(state, :ok)
        else
          send(self(), :attempt)
          state
        end

      {:ok, 429, headers} ->
        state = put_current(state, %{current | task_ref: nil})
        schedule_retry(state, retry_after_ms(headers), "Discord returned 429 (rate limited)")

      {:ok, 404, _headers} ->
        # The only status that disables immediately: the webhook was deleted
        # upstream and will never recover.
        finish(state, {:error, "Discord returned 404 — webhook was deleted", :disable})

      {:ok, status, _headers} when status in 400..499 ->
        # 401/403 and any other 4xx are permanent for this event but do NOT
        # disable on their own — they feed the 10-consecutive-failure
        # threshold, so a single transient 403 cannot kill a map's feed.
        finish(state, {:error, "Discord returned #{status}", :count})

      {:ok, status, _headers} ->
        state = put_current(state, %{current | task_ref: nil})
        schedule_retry(state, backoff_ms(current.attempt), "Discord returned #{status}")

      {:error, reason} ->
        state = put_current(state, %{current | task_ref: nil})
        schedule_retry(state, backoff_ms(current.attempt), "request failed: #{inspect(reason)}")
    end
  end

  # Schedules the next attempt instead of sleeping, so the mailbox keeps moving.
  defp schedule_retry(%{current: current} = state, delay_ms, reason) do
    next_attempt = current.attempt + 1

    if next_attempt > @max_attempts do
      finish(state, {:error, reason, :count})
    else
      Process.send_after(self(), :attempt, delay_ms)
      put_current(state, %{current | attempt: next_attempt})
    end
  end

  defp put_current(state, current), do: %{state | current: current}

  defp drop_current(state) do
    state |> put_current(nil) |> maybe_start_next()
  end

  # -- event completion -----------------------------------------------------

  # Reuses the record `attempt/1` loaded moments ago rather than re-querying.
  # The reload that matters for correctness is the one *before the send*; this
  # is only the status write, and `record_failure` re-reads the counter inside
  # the resource action anyway, so a slightly stale copy here cannot corrupt it.
  # Falls back to a query when no record was loaded (e.g. the deadline expired
  # before the first attempt).
  defp finish(%{current: current} = state, outcome) do
    case current.notification do
      nil -> record_outcome(current.notification_id, outcome)
      notification -> apply_outcome(notification, outcome)
    end

    drop_current(state)
  end

  defp record_outcome(notification_id, outcome) do
    case MapDiscordNotification.by_id(notification_id) do
      {:ok, notification} -> apply_outcome(notification, outcome)
      _ -> :ok
    end
  end

  defp apply_outcome(notification, :ok) do
    case MapDiscordNotification.record_success(notification) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("[Discord] record_success failed: #{inspect(reason)}")
    end
  end

  defp apply_outcome(notification, {:error, reason, :disable}) do
    case MapDiscordNotification.disable(notification, to_string(reason)) do
      {:ok, _} -> :ok
      {:error, err} -> Logger.warning("[Discord] disable failed: #{inspect(err)}")
    end
  end

  defp apply_outcome(notification, {:error, reason, :count}) do
    # record_failure disables at @max_consecutive_failures on the resource side.
    case MapDiscordNotification.record_failure(notification, to_string(reason)) do
      {:ok, _} -> :ok
      {:error, err} -> Logger.warning("[Discord] record_failure failed: #{inspect(err)}")
    end
  end

  # -- timing helpers -------------------------------------------------------

  defp retry_after_ms(headers) do
    headers
    |> Enum.find_value(fn {k, v} ->
      if String.downcase(k) == "retry-after", do: v
    end)
    |> parse_retry_after()
  end

  defp parse_retry_after(nil), do: 1_000

  defp parse_retry_after(value) do
    # Clamped to @max_retry_after_ms. Tradeoff, stated explicitly: if Discord
    # asks for a wait longer than 10s we retry sooner than requested and burn
    # an attempt, so a heavily rate-limited event can exhaust its 5 attempts
    # and be recorded as a failure rather than waiting the full window. We
    # accept that to keep the worker's queue moving — a 60s honored wait would
    # stall every other event for this map behind one rate-limited chunk, and
    # the event deadline would likely kill it anyway.
    case Float.parse(to_string(value)) do
      {seconds, _} ->
        seconds
        |> Kernel.*(1000)
        |> round()
        |> min(@max_retry_after_ms)
        |> max(@min_retry_after_ms)

      :error ->
        1_000
    end
  end

  defp backoff_ms(attempt), do: min(1_000 * :math.pow(2, attempt - 1), 8_000) |> round()
end
