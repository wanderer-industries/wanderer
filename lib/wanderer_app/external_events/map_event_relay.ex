defmodule WandererApp.ExternalEvents.MapEventRelay do
  @moduledoc """
  GenServer that handles delivery of external events to SSE and webhook clients.

  This system is completely separate from internal Phoenix PubSub and does NOT
  modify any existing event flows. It only handles external client delivery.

  Responsibilities:
  - Store events in ETS ring buffer for backfill
  - Broadcast to SSE clients
  - Dispatch to webhook endpoints
  - Provide event history for reconnecting clients

  Events are stored in an ETS table per map with ULID ordering for backfill support.
  Events older than 10 minutes are automatically cleaned up.
  """

  use GenServer

  alias WandererApp.ExternalEvents.Event
  alias WandererApp.ExternalEvents.WebhookDispatcher

  require Logger

  @cleanup_interval :timer.minutes(2)
  @event_retention_minutes 10

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieves events since a given timestamp for backfill.
  """
  @spec get_events_since(String.t(), DateTime.t(), pos_integer()) :: [map()]
  def get_events_since(map_id, since_datetime, limit \\ 100) do
    GenServer.call(__MODULE__, {:get_events_since, map_id, since_datetime, limit})
  end

  @doc """
  Retrieves events since a given ULID for SSE backfill.
  """
  @spec get_events_since_ulid(String.t(), String.t(), pos_integer()) ::
          {:ok, [map()]} | {:error, term()}
  def get_events_since_ulid(map_id, since_ulid, limit \\ 1_000) do
    GenServer.call(__MODULE__, {:get_events_since_ulid, map_id, since_ulid, limit})
  end

  @impl true
  def init(_opts) do
    # Create ETS table for event storage
    # Using ordered_set for ULID sorting, public for read access
    ets_table =
      :ets.new(:external_events, [
        :ordered_set,
        :public,
        :named_table,
        {:read_concurrency, true}
      ])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.debug(fn -> "MapEventRelay started for external events" end)

    {:ok,
     %{
       ets_table: ets_table,
       event_count: 0
     }}
  end

  @impl true
  def handle_cast({:deliver_event, %Event{} = event}, state) do
    Logger.debug(fn ->
      "MapEventRelay received :deliver_event (cast) for map #{event.map_id}, type: #{event.type}"
    end)

    new_state = deliver_single_event(event, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:deliver_event, %Event{} = event}, _from, state) do
    # Log ACL events at info level for debugging
    if event.type in [:acl_member_added, :acl_member_removed, :acl_member_updated] do
      Logger.debug(fn ->
        "MapEventRelay received :deliver_event (call) for map #{event.map_id}, type: #{event.type}"
      end)
    else
      Logger.debug(fn ->
        "MapEventRelay received :deliver_event (call) for map #{event.map_id}, type: #{event.type}"
      end)
    end

    new_state = deliver_single_event(event, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_events_since, map_id, since_datetime, limit}, _from, state) do
    events = get_events_from_ets(map_id, since_datetime, limit, state.ets_table)
    {:reply, events, state}
  end

  @impl true
  def handle_call({:get_events_since_ulid, map_id, since_ulid}, from, state) do
    handle_call({:get_events_since_ulid, map_id, since_ulid, 1_000}, from, state)
  end

  @impl true
  def handle_call({:get_events_since_ulid, map_id, since_ulid, limit}, _from, state) do
    # Get all events for this map and filter by ULID
    case validate_ulid(since_ulid) do
      :ok ->
        try do
          # Events are stored as {event_id, map_id, json_data}
          # Filter by map_id and event_id (ULID) > since_ulid
          events =
            :ets.select(state.ets_table, [
              {{:"$1", :"$2", :"$3"}, [{:andalso, {:>, :"$1", since_ulid}, {:==, :"$2", map_id}}],
               [:"$3"]}
            ])
            |> Enum.take(limit)

          {:reply, {:ok, events}, state}
        rescue
          error in [ArgumentError] ->
            {:reply, {:error, {:ets_error, error}}, state}
        end

      {:error, :invalid_ulid} ->
        {:reply, {:error, :invalid_ulid}, state}
    end
  end

  @impl true
  def handle_info(:cleanup_events, state) do
    cleanup_old_events(state.ets_table)
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("MapEventRelay received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp deliver_single_event(%Event{} = event, state) do
    Logger.debug(fn ->
      "MapEventRelay.deliver_single_event processing event for map #{event.map_id}, type: #{event.type}"
    end)

    # Emit telemetry
    :telemetry.execute(
      [:wanderer_app, :external_events, :relay, :received],
      %{count: 1},
      %{map_id: event.map_id, event_type: event.type}
    )

    # 1. Store in ETS for backfill
    store_event(event, state.ets_table)

    # 2. Convert event to JSON for delivery methods
    event_json = Event.to_json(event)

    Logger.debug(fn ->
      "MapEventRelay converted event to JSON: #{inspect(String.slice(inspect(event_json), 0, 200))}..."
    end)

    # 3. Send to webhook subscriptions via WebhookDispatcher
    WebhookDispatcher.dispatch_event(event.map_id, event)

    # 4. Broadcast to SSE clients
    Logger.debug(fn -> "MapEventRelay broadcasting to SSE clients for map #{event.map_id}" end)
    WandererApp.ExternalEvents.SseStreamManager.broadcast_event(event.map_id, event_json)

    # Emit delivered telemetry
    :telemetry.execute(
      [:wanderer_app, :external_events, :relay, :delivered],
      %{count: 1},
      %{map_id: event.map_id, event_type: event.type}
    )

    %{state | event_count: state.event_count + 1}
  end

  defp store_event(%Event{} = event, ets_table) do
    # Store with ULID as key for ordering
    # Value includes map_id for efficient filtering
    :ets.insert(ets_table, {event.id, event.map_id, Event.to_json(event)})
  end

  defp get_events_from_ets(map_id, since_datetime, limit, ets_table) do
    # Convert datetime to ULID for comparison
    # If no since_datetime, retrieve all events for the map
    if since_datetime do
      since_ulid = datetime_to_ulid(since_datetime)

      # Get all events since the ULID, filtered by map_id
      :ets.select(ets_table, [
        {{:"$1", :"$2", :"$3"}, [{:andalso, {:>=, :"$1", since_ulid}, {:==, :"$2", map_id}}],
         [:"$3"]}
      ])
      |> Enum.take(limit)
    else
      # Get all events for the map_id
      :ets.select(ets_table, [
        {{:"$1", :"$2", :"$3"}, [{:==, :"$2", map_id}], [:"$3"]}
      ])
      |> Enum.take(limit)
    end
  end

  defp validate_ulid(ulid) when is_binary(ulid) do
    # ULID format validation: 26 characters, [0-9A-Z] excluding I, L, O, U
    case byte_size(ulid) do
      26 ->
        if ulid =~ ~r/^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$/ do
          :ok
        else
          {:error, :invalid_ulid}
        end

      _ ->
        {:error, :invalid_ulid}
    end
  end

  defp validate_ulid(_), do: {:error, :invalid_ulid}

  defp cleanup_old_events(ets_table) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@event_retention_minutes, :minute)
    cutoff_ulid = datetime_to_ulid(cutoff_time)

    # Delete events older than cutoff
    :ets.select_delete(ets_table, [
      {{:"$1", :_, :_}, [{:<, :"$1", cutoff_ulid}], [true]}
    ])
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_events, @cleanup_interval)
  end

  # Convert DateTime to ULID timestamp for comparison
  defp datetime_to_ulid(datetime) do
    timestamp = DateTime.to_unix(datetime, :millisecond)
    # Create a ULID with the timestamp (rest will be zeros for comparison)
    Ecto.ULID.generate(timestamp)
  end
end
