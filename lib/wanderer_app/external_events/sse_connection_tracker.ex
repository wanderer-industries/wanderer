defmodule WandererApp.ExternalEvents.SseConnectionTracker do
  @moduledoc """
  Tracks and enforces connection limits for SSE connections.

  Maintains counts of active connections per map and per API key to prevent
  resource exhaustion. Uses ETS for efficient concurrent access.
  """

  use GenServer
  require Logger

  @table_name :sse_connection_tracker
  @cleanup_interval :timer.minutes(5)

  @doc """
  Starts the SSE connection tracker.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Checks if a new connection would exceed limits.

  Returns :ok if connection is allowed, or {:error, reason} if limits exceeded.
  """
  @spec check_limits(String.t(), String.t()) :: :ok | {:error, atom()}
  def check_limits(map_id, api_key) do
    if is_binary(map_id) and map_id != "" and is_binary(api_key) and api_key != "" do
      GenServer.call(__MODULE__, {:check_limits, map_id, api_key})
    else
      {:error, :invalid_parameters}
    end
  end

  @doc """
  Tracks a new SSE connection.

  Should be called after check_limits returns :ok.
  """
  @spec track_connection(String.t(), String.t(), pid()) :: :ok
  def track_connection(map_id, api_key, pid) do
    GenServer.call(__MODULE__, {:track_connection, map_id, api_key, pid})
  end

  @doc """
  Removes a tracked connection.

  Called when a connection is closed.
  """
  @spec remove_connection(String.t(), String.t(), pid()) :: :ok
  def remove_connection(map_id, api_key, pid) do
    GenServer.call(__MODULE__, {:remove_connection, map_id, api_key, pid})
  end

  @doc """
  Gets current connection statistics.
  """
  @spec get_stats() :: %{maps: map(), api_keys: map(), total_connections: non_neg_integer()}
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer callbacks

  @impl true
  def init([]) do
    # Create ETS table for connection tracking
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("SSE Connection Tracker started")

    {:ok, %{}}
  end

  @impl true
  def handle_call({:check_limits, map_id, api_key}, _from, state) do
    map_count = count_connections_for_map(map_id)
    key_count = count_connections_for_api_key(api_key)

    result =
      cond do
        map_count >= max_connections_per_map() ->
          Logger.warning(
            "SSE connection limit exceeded for map #{map_id}: #{map_count}/#{max_connections_per_map()}"
          )

          {:error, :map_connection_limit_exceeded}

        key_count >= max_connections_per_api_key() ->
          Logger.warning(
            "SSE connection limit exceeded for API key: #{key_count}/#{max_connections_per_api_key()}"
          )

          {:error, :api_key_connection_limit_exceeded}

        true ->
          :ok
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:track_connection, map_id, api_key, pid}, _from, state) do
    # Monitor the connection process
    monitor_ref = Process.monitor(pid)

    # Store connection info
    :ets.insert(@table_name, {{pid, monitor_ref}, %{map_id: map_id, api_key: api_key}})

    Logger.debug(
      "Tracked SSE connection for map #{map_id}, API key #{String.slice(api_key, 0..7)}..."
    )

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:remove_connection, _map_id, _api_key, pid}, _from, state) do
    # Find and remove the connection
    case :ets.match(@table_name, {{pid, :"$1"}, :_}) do
      [[monitor_ref]] ->
        Process.demonitor(monitor_ref, [:flush])
        :ets.delete(@table_name, {pid, monitor_ref})

      _ ->
        :ok
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    # Aggregate statistics from ETS
    stats =
      :ets.foldl(
        fn {{_pid, _ref}, %{map_id: map_id, api_key: api_key}}, acc ->
          acc
          |> update_in([:maps, map_id], &((&1 || 0) + 1))
          |> update_in([:api_keys, api_key], &((&1 || 0) + 1))
          |> update_in([:total_connections], &(&1 + 1))
        end,
        %{maps: %{}, api_keys: %{}, total_connections: 0},
        @table_name
      )

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, state) do
    # Remove connection when process dies
    :ets.delete(@table_name, {pid, monitor_ref})
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up any orphaned entries (shouldn't happen normally)
    cleanup_dead_connections()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp count_connections_for_map(map_id) do
    :ets.select_count(@table_name, [
      {{:_, %{map_id: :"$1", api_key: :_}}, [{:==, :"$1", map_id}], [true]}
    ])
  end

  defp count_connections_for_api_key(api_key) do
    :ets.select_count(@table_name, [
      {{:_, %{map_id: :_, api_key: :"$1"}}, [{:==, :"$1", api_key}], [true]}
    ])
  end

  defp cleanup_dead_connections do
    :ets.foldl(
      fn {{pid, ref}, _data}, acc ->
        if not Process.alive?(pid) do
          :ets.delete(@table_name, {pid, ref})
          acc + 1
        else
          acc
        end
      end,
      0,
      @table_name
    )
    |> case do
      0 ->
        :ok

      count ->
        Logger.info("Cleaned up #{count} dead SSE connections")
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp max_connections_per_map do
    Application.get_env(:wanderer_app, :sse, [])
    |> Keyword.get(:max_connections_per_map, 50)
  end

  defp max_connections_per_api_key do
    Application.get_env(:wanderer_app, :sse, [])
    |> Keyword.get(:max_connections_per_api_key, 10)
  end
end