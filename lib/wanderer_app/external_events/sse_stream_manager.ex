defmodule WandererApp.ExternalEvents.SseStreamManager do
  @moduledoc """
  Manages Server-Sent Events (SSE) connections for maps.

  This GenServer tracks active SSE connections, enforces connection limits,
  and broadcasts events to connected clients.

  Connection state is stored as:
  %{
    map_id => %{
      api_key => [%{pid: pid, event_filter: filter, connected_at: datetime}, ...]
    }
  }
  """

  use GenServer
  require Logger

  @cleanup_interval :timer.minutes(5)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Broadcasts an event to all SSE clients connected to a map.
  """
  def broadcast_event(map_id, event_json) do
    GenServer.cast(__MODULE__, {:broadcast_event, map_id, event_json})
  end

  @doc """
  Adds a new SSE client connection.
  Returns {:ok, ref} on success, {:error, reason} on failure.
  """
  def add_client(map_id, api_key, client_pid, event_filter \\ :all) do
    GenServer.call(__MODULE__, {:add_client, map_id, api_key, client_pid, event_filter})
  end

  @doc """
  Removes a client connection.
  """
  def remove_client(map_id, api_key, client_pid) do
    GenServer.cast(__MODULE__, {:remove_client, map_id, api_key, client_pid})
  end

  @doc """
  Gets connection stats for monitoring.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic cleanup of dead connections
    schedule_cleanup()

    # Read configuration once during initialization
    sse_config = Application.get_env(:wanderer_app, :sse, [])

    state = %{
      # map_id => %{api_key => [connection_info]}
      connections: %{},
      # pid => {map_id, api_key}
      monitors: %{},
      # Configuration
      enabled:
        WandererApp.Env.sse_enabled?()
        |> then(fn
          true -> true
          false -> false
        end),
      max_connections_total: Keyword.get(sse_config, :max_connections_total, 1000),
      max_connections_per_map: Keyword.get(sse_config, :max_connections_per_map, 50),
      max_connections_per_api_key: Keyword.get(sse_config, :max_connections_per_api_key, 10)
    }

    Logger.debug(fn -> "SSE Stream Manager started" end)
    {:ok, state}
  end

  @impl true
  def handle_call({:add_client, map_id, api_key, client_pid, event_filter}, _from, state) do
    # Check if feature is enabled
    unless state.enabled == true do
      {:reply, {:error, :sse_disabled}, state}
    else
      # Check connection limits
      case check_connection_limits(state, map_id, api_key, state.max_connections_total) do
        :ok ->
          # Monitor the client process
          ref = Process.monitor(client_pid)

          # Add connection to state
          connection_info = %{
            pid: client_pid,
            event_filter: event_filter,
            connected_at: DateTime.utc_now(),
            ref: ref
          }

          new_state = add_connection_to_state(state, map_id, api_key, connection_info)

          Logger.debug(
            "SSE client added: map=#{map_id}, api_key=#{String.slice(api_key, 0..7)}..., pid=#{inspect(client_pid)}"
          )

          {:reply, {:ok, ref}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    total_connections =
      state.connections
      |> Enum.flat_map(fn {_map_id, api_keys} ->
        Enum.flat_map(api_keys, fn {_api_key, connections} -> connections end)
      end)
      |> length()

    stats = %{
      total_connections: total_connections,
      maps_with_connections: map_size(state.connections),
      connections_by_map:
        state.connections
        |> Enum.map(fn {map_id, api_keys} ->
          count = api_keys |> Enum.flat_map(fn {_, conns} -> conns end) |> length()
          {map_id, count}
        end)
        |> Enum.into(%{})
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:broadcast_event, map_id, event_json}, state) do
    # Get all connections for this map
    connections = get_map_connections(state, map_id)

    # Send event to each connection that should receive it
    Enum.each(connections, fn connection_info ->
      if should_send_event?(event_json, connection_info.event_filter) do
        send_sse_event(connection_info.pid, event_json)
      end
    end)

    # Log ACL events at info level for debugging
    event_type = get_in(event_json, ["type"])

    if event_type in ["acl_member_added", "acl_member_removed", "acl_member_updated"] do
      Logger.debug(fn ->
        "Broadcast SSE event to #{length(connections)} clients for map #{map_id}: #{inspect(event_json)}"
      end)
    else
      Logger.debug("Broadcast SSE event to #{length(connections)} clients for map #{map_id}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove_client, map_id, api_key, client_pid}, state) do
    new_state = remove_connection_from_state(state, map_id, api_key, client_pid)

    Logger.debug(
      "SSE client removed: map=#{map_id}, api_key=#{String.slice(api_key, 0..7)}..., pid=#{inspect(client_pid)}"
    )

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Handle client process termination
    case Map.get(state.monitors, pid) do
      {map_id, api_key} ->
        new_state = remove_connection_from_state(state, map_id, api_key, pid)
        Logger.debug("SSE client process terminated: map=#{map_id}, pid=#{inspect(pid)}")
        {:noreply, new_state}

      nil ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:cleanup_connections, state) do
    new_state = cleanup_dead_connections(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("SSE Stream Manager received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private helper functions

  defp check_connection_limits(state, map_id, api_key, max_total) do
    # Check total server connections
    total_connections = count_total_connections(state)

    if total_connections >= max_total do
      {:error, :max_connections_reached}
    else
      # Check per-map and per-API-key limits from state
      map_connections = count_map_connections(state, map_id)
      key_connections = count_api_key_connections(state, map_id, api_key)

      cond do
        map_connections >= state.max_connections_per_map ->
          {:error, :map_connection_limit_reached}

        key_connections >= state.max_connections_per_api_key ->
          {:error, :api_key_connection_limit_reached}

        true ->
          :ok
      end
    end
  end

  defp count_total_connections(state) do
    state.connections
    |> Enum.flat_map(fn {_map_id, api_keys} ->
      Enum.flat_map(api_keys, fn {_api_key, connections} -> connections end)
    end)
    |> length()
  end

  defp count_map_connections(state, map_id) do
    case Map.get(state.connections, map_id) do
      nil ->
        0

      api_keys ->
        api_keys
        |> Enum.flat_map(fn {_api_key, connections} -> connections end)
        |> length()
    end
  end

  defp count_api_key_connections(state, map_id, api_key) do
    state.connections
    |> get_in([map_id, api_key])
    |> case do
      nil -> 0
      connections -> length(connections)
    end
  end

  defp add_connection_to_state(state, map_id, api_key, connection_info) do
    # Add to monitors
    monitors = Map.put(state.monitors, connection_info.pid, {map_id, api_key})

    # Add to connections
    connections =
      state.connections
      |> Map.put_new(map_id, %{})
      |> put_in(
        [map_id, api_key],
        get_in(state.connections, [map_id, api_key])
        |> case do
          nil -> [connection_info]
          existing -> [connection_info | existing]
        end
      )

    %{state | connections: connections, monitors: monitors}
  end

  defp remove_connection_from_state(state, map_id, api_key, client_pid) do
    # Remove from monitors
    monitors = Map.delete(state.monitors, client_pid)

    # Remove from connections
    connections =
      case get_in(state.connections, [map_id, api_key]) do
        nil ->
          state.connections

        existing_connections ->
          updated_connections = Enum.reject(existing_connections, &(&1.pid == client_pid))

          # Clean up empty structures
          if updated_connections == [] do
            api_keys = Map.delete(state.connections[map_id], api_key)

            if api_keys == %{} do
              Map.delete(state.connections, map_id)
            else
              Map.put(state.connections, map_id, api_keys)
            end
          else
            put_in(state.connections, [map_id, api_key], updated_connections)
          end
      end

    %{state | connections: connections, monitors: monitors}
  end

  defp get_map_connections(state, map_id) do
    case Map.get(state.connections, map_id) do
      nil ->
        []

      api_keys ->
        api_keys
        |> Enum.flat_map(fn {_api_key, connections} -> connections end)
    end
  end

  defp send_sse_event(client_pid, event_json) do
    Logger.debug(fn ->
      "SSE sending message to client #{inspect(client_pid)}: #{inspect(String.slice(inspect(event_json), 0, 200))}..."
    end)

    try do
      send(client_pid, {:sse_event, event_json})
      Logger.debug(fn -> "SSE message sent successfully to client #{inspect(client_pid)}" end)
    catch
      :error, :badarg ->
        Logger.debug(fn -> "SSE client process #{inspect(client_pid)} is dead, ignoring" end)
        # Process is dead, ignore
        :ok
    end
  end

  defp should_send_event?(_event_json, :all), do: true

  defp should_send_event?(event_json, event_filter) when is_list(event_filter) do
    # Extract event type from JSON
    case event_json do
      %{"type" => type} when is_binary(type) ->
        try do
          atom_type = String.to_existing_atom(type)
          atom_type in event_filter
        rescue
          ArgumentError -> false
        end

      %{"type" => type} when is_atom(type) ->
        type in event_filter

      _ ->
        false
    end
  end

  defp should_send_event?(_event_json, _filter), do: true

  defp cleanup_dead_connections(state) do
    # Remove connections for dead processes
    alive_connections =
      state.connections
      |> Enum.map(fn {map_id, api_keys} ->
        alive_api_keys =
          api_keys
          |> Enum.map(fn {api_key, connections} ->
            alive_conns = Enum.filter(connections, &Process.alive?(&1.pid))
            {api_key, alive_conns}
          end)
          |> Enum.reject(fn {_api_key, connections} -> connections == [] end)
          |> Enum.into(%{})

        {map_id, alive_api_keys}
      end)
      |> Enum.reject(fn {_map_id, api_keys} -> api_keys == %{} end)
      |> Enum.into(%{})

    # Update monitors to match alive connections
    alive_monitors =
      alive_connections
      |> Enum.flat_map(fn {map_id, api_keys} ->
        Enum.flat_map(api_keys, fn {api_key, connections} ->
          Enum.map(connections, fn conn -> {conn.pid, {map_id, api_key}} end)
        end)
      end)
      |> Enum.into(%{})

    %{state | connections: alive_connections, monitors: alive_monitors}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_connections, @cleanup_interval)
  end
end
