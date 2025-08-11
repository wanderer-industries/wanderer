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

    # Update stats
    stats = Map.update!(state.stats, :events_processed, &(&1 + 1))

    # Check if we need to flush
    cond do
      length(buffer) >= state.batch_size ->
        # Flush immediately if batch size reached
        {:noreply, do_flush(%{state | buffer: buffer, stats: stats})}

      length(buffer) >= @max_buffer_size ->
        # Force flush if max buffer size reached
        Logger.warning("Security audit buffer overflow, forcing flush",
          buffer_size: length(buffer),
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

      {:error, reason} ->
        Logger.error("Failed to flush security audit events",
          reason: inspect(reason),
          event_count: length(events)
        )

        # Update error stats
        stats = Map.update!(state.stats, :errors, &(&1 + 1))

        # Implement backoff - keep events in buffer but don't grow indefinitely
        buffer =
          if length(state.buffer) > @max_buffer_size do
            Logger.warning("Dropping oldest audit events due to repeated flush failures")
            Enum.take(state.buffer, @max_buffer_size)
          else
            state.buffer
          end

        %{state | buffer: buffer, stats: stats}
    end
  end

  defp bulk_store_events(events) do
    # Process events in smaller chunks if necessary
    events
    # Ash bulk operations work better with smaller chunks
    |> Enum.chunk_every(50)
    |> Enum.reduce_while({:ok, 0}, fn chunk, {:ok, count} ->
      case store_event_chunk(chunk) do
        {:ok, chunk_count} ->
          {:cont, {:ok, count + chunk_count}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp store_event_chunk(events) do
    # Transform events to Ash attributes
    records =
      Enum.map(events, fn event ->
        SecurityAudit.do_store_audit_entry(event)
      end)

    # Count successful stores
    successful =
      Enum.count(records, fn
        :ok -> true
        _ -> false
      end)

    {:ok, successful}
  rescue
    error ->
      {:error, error}
  end
end
