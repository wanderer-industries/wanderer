defmodule WandererApp.SecurityAudit.AsyncProcessor do
  @moduledoc """
  GenServer for asynchronous batch processing of security audit events.

  This server buffers audit events in memory and periodically flushes them
  to the database in batches for improved performance.
  """

  use GenServer
  require Logger

  alias WandererApp.SecurityAudit

  @default_batch_size 100
  # 5 seconds
  @default_flush_interval 5_000
  @max_buffer_size 1_000

  defstruct [
    :batch_size,
    :flush_interval,
    :buffer,
    :timer_ref,
    :stats
  ]

  # Client API

  @doc """
  Start the async processor.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Log an event asynchronously.
  """
  def log_event(audit_entry) do
    GenServer.cast(__MODULE__, {:log_event, audit_entry})
  end

  @doc """
  Force a flush of the buffer.
  """
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Get current processor statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    config = Application.get_env(:wanderer_app, WandererApp.SecurityAudit, [])

    batch_size = Keyword.get(opts, :batch_size, config[:batch_size] || @default_batch_size)

    flush_interval =
      Keyword.get(opts, :flush_interval, config[:flush_interval] || @default_flush_interval)

    state = %__MODULE__{
      batch_size: batch_size,
      flush_interval: flush_interval,
      buffer: [],
      timer_ref: nil,
      stats: %{
        events_processed: 0,
        batches_flushed: 0,
        errors: 0,
        last_flush: nil
      }
    }

    # Schedule first flush
    state = schedule_flush(state)

    {:ok, state}
  end

  @impl true
  def handle_cast({:log_event, audit_entry}, state) do
    # Add to buffer
    buffer = [audit_entry | state.buffer]
    buf_len = length(buffer)

    # Update stats
    stats = Map.update!(state.stats, :events_processed, &(&1 + 1))

    # Check if we need to flush
    cond do
      buf_len >= state.batch_size ->
        # Flush immediately if batch size reached
        {:noreply, do_flush(%{state | buffer: buffer, stats: stats})}

      buf_len >= @max_buffer_size ->
        # Force flush if max buffer size reached
        Logger.warning("Security audit buffer overflow, forcing flush",
          buffer_size: buf_len,
          max_size: @max_buffer_size
        )

        {:noreply, do_flush(%{state | buffer: buffer, stats: stats})}

      true ->
        # Just add to buffer
        {:noreply, %{state | buffer: buffer, stats: stats}}
    end
  end

  @impl true
  def handle_call(:flush, _from, state) do
    new_state = do_flush(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = Map.put(state.stats, :current_buffer_size, length(state.buffer))
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:flush_timer, state) do
    state =
      if length(state.buffer) > 0 do
        do_flush(state)
      else
        state
      end

    # Schedule next flush
    state = schedule_flush(state)

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Flush any remaining events on shutdown
    if length(state.buffer) > 0 do
      do_flush(state)
    end

    :ok
  end

  # Private functions

  defp schedule_flush(state) do
    # Cancel existing timer if any
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    # Schedule new timer
    timer_ref = Process.send_after(self(), :flush_timer, state.flush_interval)

    %{state | timer_ref: timer_ref}
  end

  defp do_flush(state) when length(state.buffer) == 0 do
    state
  end

  defp do_flush(state) do
    # Take events to flush (reverse to maintain order)
    events = Enum.reverse(state.buffer)

    # Attempt to store events
    case bulk_store_events(events) do
      {:ok, count} ->
        Logger.debug("Flushed #{count} security audit events")

        # Update stats
        stats =
          state.stats
          |> Map.update!(:batches_flushed, &(&1 + 1))
          |> Map.put(:last_flush, DateTime.utc_now())

        # Clear buffer
        %{state | buffer: [], stats: stats}

      {:partial, success_count, failed_events} ->
        failed_count = length(failed_events)

        Logger.warning(
          "Partial flush: stored #{success_count}, failed #{failed_count} audit events",
          success_count: success_count,
          failed_count: failed_count,
          buffer_size: length(state.buffer)
        )

        # Emit telemetry for monitoring
        :telemetry.execute(
          [:wanderer_app, :security_audit, :async_flush_partial],
          %{success_count: success_count, failed_count: failed_count},
          %{}
        )

        # Update stats - count partial flush as both success and error
        stats =
          state.stats
          |> Map.update!(:batches_flushed, &(&1 + 1))
          |> Map.update!(:errors, &(&1 + 1))
          |> Map.put(:last_flush, DateTime.utc_now())

        # Extract just the events from failed_events tuples
        failed_only = Enum.map(failed_events, fn {event, _reason} -> event end)

        remaining_buffer = Enum.reject(state.buffer, fn ev -> ev in failed_only end)

        # Re-buffer failed events at the front, preserving newest-first ordering
        # Reverse failed_only since flush reversed the buffer to oldest-first
        new_buffer = Enum.reverse(failed_only) ++ remaining_buffer
        buffer = handle_buffer_overflow(new_buffer, @max_buffer_size)

        %{state | buffer: buffer, stats: stats}

      {:error, failed_events} ->
        failed_count = length(failed_events)

        Logger.error("Failed to flush all #{failed_count} security audit events",
          failed_count: failed_count,
          buffer_size: length(state.buffer)
        )

        # Emit telemetry for monitoring
        :telemetry.execute(
          [:wanderer_app, :security_audit, :async_flush_failure],
          %{count: 1, event_count: failed_count},
          %{}
        )

        # Update error stats
        stats = Map.update!(state.stats, :errors, &(&1 + 1))

        # Extract just the events from failed_events tuples
        failed_only = Enum.map(failed_events, fn {event, _reason} -> event end)

        # Since ALL events failed, the new buffer should only contain the failed events
        # Reverse to maintain newest-first ordering (flush reversed to oldest-first)
        buffer = handle_buffer_overflow(Enum.reverse(failed_only), @max_buffer_size)

        %{state | buffer: buffer, stats: stats}
    end
  end

  defp bulk_store_events(events) do
    # Process events in smaller chunks if necessary
    events
    # Ash bulk operations work better with smaller chunks
    |> Enum.chunk_every(50)
    |> Enum.reduce({0, []}, fn chunk, {total_success, all_failed} ->
      case store_event_chunk(chunk) do
        {:ok, chunk_count} ->
          {total_success + chunk_count, all_failed}

        {:partial, chunk_count, failed_events} ->
          {total_success + chunk_count, all_failed ++ failed_events}

        {:error, failed_events} ->
          {total_success, all_failed ++ failed_events}
      end
    end)
    |> then(fn {success_count, failed_events_list} ->
      # Derive the final return shape based on results
      cond do
        failed_events_list == [] ->
          {:ok, success_count}

        success_count == 0 ->
          {:error, failed_events_list}

        true ->
          {:partial, success_count, failed_events_list}
      end
    end)
  end

  defp handle_buffer_overflow(buffer, max_size) when length(buffer) > max_size do
    dropped = length(buffer) - max_size

    Logger.warning(
      "Dropping #{dropped} oldest audit events due to buffer overflow",
      buffer_size: length(buffer),
      max_size: max_size
    )

    # Emit telemetry for dropped events
    :telemetry.execute(
      [:wanderer_app, :security_audit, :events_dropped],
      %{count: dropped},
      %{}
    )

    # Keep the newest events (take from the front since buffer is newest-first)
    Enum.take(buffer, max_size)
  end

  defp handle_buffer_overflow(buffer, _max_size), do: buffer

  defp store_event_chunk(events) do
    # Process each event and partition results
    {successes, failures} =
      events
      |> Enum.map(fn event ->
        case SecurityAudit.do_store_audit_entry(event) do
          :ok ->
            {:ok, event}

          {:error, reason} ->
            Logger.error("Failed to store individual audit event",
              error: inspect(reason),
              event_type: Map.get(event, :event_type),
              user_id: Map.get(event, :user_id)
            )

            {:error, {event, reason}}
        end
      end)
      |> Enum.split_with(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    successful_count = length(successes)
    failed_count = length(failures)

    # Extract failed events with reasons
    failed_events = Enum.map(failures, fn {:error, event_reason} -> event_reason end)

    # Log if some events failed (telemetry will be emitted at flush level)
    if failed_count > 0 do
      Logger.debug("Chunk processing: #{failed_count} of #{length(events)} events failed")
    end

    # Return richer result shape
    cond do
      successful_count == 0 ->
        {:error, failed_events}

      failed_count > 0 ->
        {:partial, successful_count, failed_events}

      true ->
        {:ok, successful_count}
    end
  end
end
