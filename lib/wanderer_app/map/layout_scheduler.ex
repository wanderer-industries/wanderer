defmodule WandererApp.Map.LayoutScheduler do
  @moduledoc false

  use GenServer

  require Logger

  alias WandererApp.Map.Server.{ConnectionsImpl, Impl, SystemsImpl}

  @debounce_ms 200
  @retry_ms 1_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def schedule(map_id, opts \\ []) when is_binary(map_id) do
    GenServer.cast(__MODULE__, {:schedule, map_id, normalize_request(opts)})
  catch
    :exit, _reason -> :ok
  end

  def enqueue(map_id, opts) when is_binary(map_id) do
    GenServer.call(__MODULE__, {:enqueue, map_id, normalize_request(opts)})
  catch
    :exit, reason -> {:error, reason}
  end

  def schedule_and_wait(map_id, opts) when is_binary(map_id) do
    GenServer.call(__MODULE__, {:schedule_and_wait, map_id, normalize_request(opts)}, :infinity)
  catch
    :exit, reason -> {:error, reason}
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:schedule, map_id, request}, state) do
    entry =
      state
      |> Map.get(map_id, new_entry(map_id))
      |> merge_request(request)

    if entry.monitor do
      {:noreply, Map.put(state, map_id, %{entry | dirty: true})}
    else
      {:noreply, Map.put(state, map_id, schedule_timer(entry))}
    end
  end

  @impl true
  def handle_call({:enqueue, map_id, request}, _from, state) do
    entry =
      state
      |> Map.get(map_id, new_entry(map_id))
      |> merge_request(request)

    entry =
      if entry.monitor do
        %{entry | dirty: true}
      else
        schedule_timer(entry)
      end

    {:reply, :ok, Map.put(state, map_id, entry)}
  end

  def handle_call({:schedule_and_wait, map_id, request}, from, state) do
    entry =
      state
      |> Map.get(map_id, new_entry(map_id))
      |> merge_request(request)
      |> Map.update!(:pending_waiters, &[from | &1])

    entry =
      if entry.monitor do
        %{entry | dirty: true}
      else
        schedule_timer(entry)
      end

    {:noreply, Map.put(state, map_id, entry)}
  end

  @impl true
  def handle_info({:run, map_id, timer_token}, state) do
    case Map.get(state, map_id) do
      %{timer_token: ^timer_token, monitor: nil} = entry ->
        if layout_enabled?(map_id) do
          start_layout(map_id, entry, state)
        else
          case commit_without_layout(map_id, entry) do
            :ok ->
              reply_waiters(entry.pending_waiters, :ok)
              {:noreply, Map.delete(state, map_id)}

            {:error, reason} ->
              Logger.warning("Pending map additions commit failed: #{inspect(reason)}")
              {:noreply, Map.put(state, map_id, schedule_timer(entry, @retry_ms))}
          end
        end

      _stale_or_missing ->
        {:noreply, state}
    end
  end

  def handle_info({:layout_finished, map_id, result}, state) do
    case Map.get(state, map_id) do
      %{monitor: monitor} = entry when not is_nil(monitor) ->
        Process.demonitor(monitor, [:flush])

        if entry.dirty or has_pending_request?(entry) do
          entry =
            entry
            |> requeue_running_request()
            |> clear_running()
            |> Map.update!(:pending_waiters, &(entry.running_waiters ++ &1))
            |> Map.put(:running_waiters, [])
            |> schedule_timer()

          {:noreply, Map.put(state, map_id, entry)}
        else
          finish_layout(map_id, result, entry, state)
        end

      _stale_or_missing ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, reason}, state) do
    case Enum.find(state, fn {_map_id, entry} -> entry.monitor == monitor end) do
      {map_id, entry} ->
        Logger.warning("Automatic map layout worker crashed: #{inspect(reason)}")
        retry_request(map_id, entry, state)

      nil ->
        {:noreply, state}
    end
  end

  defp start_layout(map_id, entry, state) do
    request = pending_request(entry)
    scheduler = self()

    {_pid, monitor} =
      spawn_monitor(fn ->
        result = calculate_layout(map_id, request)
        send(scheduler, {:layout_finished, map_id, result})
      end)

    entry = %{
      entry
      | timer: nil,
        timer_token: nil,
        monitor: monitor,
        running_request: request,
        running_waiters: entry.pending_waiters,
        dirty: false,
        pending_system_ids: MapSet.new(),
        publish_system_ids: MapSet.new(),
        selections: %{},
        additions: %{},
        jumps: [],
        pending_waiters: []
    }

    {:noreply, Map.put(state, map_id, entry)}
  end

  defp finish_layout(map_id, {:ok, request, plan}, entry, state) do
    case commit_plan(map_id, request, plan) do
      :ok ->
        publish_systems(map_id, request.publish_system_ids)
        commit_jumps(map_id, request.jumps)
        publish_selections(map_id, request.selections)
        reply_waiters(entry.running_waiters, :ok)
        {:noreply, Map.delete(state, map_id)}

      {:error, reason} ->
        Logger.warning("Automatic map layout commit failed: #{inspect(reason)}")
        retry_request(map_id, entry, state)
    end
  end

  defp finish_layout(map_id, {:error, request, reason}, entry, state) do
    Logger.warning("Automatic map layout failed: #{inspect(reason)}")
    retry_request(map_id, %{entry | running_request: request}, state)
  end

  defp retry_request(map_id, entry, state) do
    entry =
      entry
      |> requeue_running_request()
      |> clear_running()
      |> Map.update!(:pending_waiters, &(entry.running_waiters ++ &1))
      |> Map.put(:running_waiters, [])
      |> schedule_timer(@retry_ms)

    {:noreply, Map.put(state, map_id, entry)}
  end

  defp calculate_layout(map_id, request) do
    settings = WandererApp.LayoutSettings.get(map_id)

    with {:ok, systems} <- WandererApp.MapSystemRepo.get_visible_by_map(map_id),
         {:ok, connections} <- WandererApp.MapConnectionRepo.get_by_map(map_id),
         systems = merge_virtual_systems(systems, request.additions),
         connections = merge_virtual_connections(connections, request.jumps),
         {:ok, plan} <-
           WandererApp.Map.Layout.calculate_graph(systems, connections, settings,
             new_system_ids: request.pending_system_ids
           ) do
      {:ok, request, plan}
    else
      {:error, reason} -> {:error, request, reason}
    end
  rescue
    error -> {:error, request, error}
  catch
    kind, reason -> {:error, request, {kind, reason}}
  end

  defp commit_plan(map_id, request, plan) do
    positions = positions_by_system_id(plan.nodes)

    with :ok <-
           SystemsImpl.commit_layout_additions(
             map_id,
             Map.values(request.additions),
             positions
           ),
         :ok <- WandererApp.Map.Layout.apply_positions(map_id, plan.nodes) do
      :ok
    end
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp commit_without_layout(map_id, entry) do
    case SystemsImpl.commit_unmanaged_layout_additions(map_id, Map.values(entry.additions)) do
      :ok ->
        publish_systems(map_id, entry.publish_system_ids)
        commit_jumps(map_id, entry.jumps)
        publish_selections(map_id, entry.selections)
        :ok

      {:error, _reason} = error ->
        error
    end
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp positions_by_system_id(nodes) do
    Map.new(nodes, fn %{"id" => id, "x" => x, "y" => y} ->
      {String.to_integer(id), %{x: round(x), y: round(y)}}
    end)
  end

  defp merge_virtual_systems(systems, additions) do
    addition_ids = additions |> Map.keys() |> MapSet.new()
    existing = Enum.reject(systems, &MapSet.member?(addition_ids, &1.solar_system_id))
    existing ++ Enum.map(additions, fn {_id, addition} -> addition.candidate end)
  end

  defp merge_virtual_connections(connections, jumps) do
    existing_keys = MapSet.new(connections, &connection_key/1)

    {_keys, virtual_connections} =
      Enum.reduce(jumps, {existing_keys, []}, fn jump, {keys, virtual_connections} ->
        key = connection_key(jump)

        if MapSet.member?(keys, key) do
          {keys, virtual_connections}
        else
          connection = %{
            solar_system_source: jump.old_location.solar_system_id,
            solar_system_target: jump.location.solar_system_id
          }

          {MapSet.put(keys, key), [connection | virtual_connections]}
        end
      end)

    connections ++ Enum.reverse(virtual_connections)
  end

  defp commit_jumps(map_id, jumps) do
    Enum.each(jumps, fn jump ->
      try do
        ConnectionsImpl.maybe_add_connection(
          map_id,
          jump.location,
          jump.old_location,
          jump.character_id,
          false,
          nil,
          schedule_layout: false
        )
      rescue
        error ->
          Logger.error(
            "Failed to commit managed layout jump map=#{map_id} character=#{jump.character_id}: #{Exception.message(error)}"
          )
      catch
        kind, reason ->
          Logger.error(
            "Failed to commit managed layout jump map=#{map_id} character=#{jump.character_id}: #{inspect({kind, reason})}"
          )
      end
    end)
  end

  defp publish_systems(map_id, system_ids) do
    Enum.each(system_ids, fn solar_system_id ->
      try do
        case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id) do
          {:ok, %{visible: true} = system} ->
            SystemsImpl.publish_added_system(map_id, system, schedule_layout: false)

          _ ->
            Logger.warning(
              "Pending layout system is not visible map=#{map_id} system=#{solar_system_id}"
            )
        end
      rescue
        error ->
          Logger.error(
            "Failed to publish managed layout system map=#{map_id} system=#{solar_system_id}: #{Exception.message(error)}"
          )
      end
    end)
  end

  defp publish_selections(map_id, selections) do
    Enum.each(selections, fn {character_id, solar_system_id} ->
      Impl.broadcast!(map_id, :maybe_select_system, %{
        character_id: character_id,
        solar_system_id: solar_system_id
      })
    end)
  end

  defp schedule_timer(entry, delay \\ @debounce_ms) do
    if entry.timer, do: Process.cancel_timer(entry.timer)

    timer_token = make_ref()
    timer = Process.send_after(self(), {:run, entry.map_id, timer_token}, delay)
    %{entry | timer: timer, timer_token: timer_token}
  end

  defp merge_request(entry, request) do
    entry
    |> pending_request()
    |> merge_requests(request)
    |> then(&put_pending_request(entry, &1))
  end

  @doc false
  def merge_requests(older, newer) do
    %{
      pending_system_ids: MapSet.union(older.pending_system_ids, newer.pending_system_ids),
      publish_system_ids: MapSet.union(older.publish_system_ids, newer.publish_system_ids),
      selections: Map.merge(older.selections, newer.selections),
      additions: Map.merge(older.additions, newer.additions),
      jumps: older.jumps ++ newer.jumps
    }
  end

  defp pending_request(entry) do
    %{
      pending_system_ids: entry.pending_system_ids,
      publish_system_ids: entry.publish_system_ids,
      selections: entry.selections,
      additions: entry.additions,
      jumps: entry.jumps
    }
  end

  defp has_pending_request?(entry) do
    MapSet.size(entry.pending_system_ids) > 0 or MapSet.size(entry.publish_system_ids) > 0 or
      entry.selections != %{} or entry.additions != %{} or
      entry.jumps != []
  end

  defp normalize_request(opts) do
    additions =
      opts
      |> Keyword.get(:additions, [])
      |> Map.new(&{&1.candidate.solar_system_id, &1})

    addition_ids = additions |> Map.keys() |> MapSet.new()

    jumps =
      opts
      |> Keyword.get(:jumps, [])
      |> Enum.to_list()

    selections =
      case Keyword.get(opts, :selection) do
        %{character_id: character_id, solar_system_id: solar_system_id} ->
          %{character_id => solar_system_id}

        _ ->
          %{}
      end

    %{
      pending_system_ids:
        opts |> Keyword.get(:new_system_ids, []) |> MapSet.new() |> MapSet.union(addition_ids),
      publish_system_ids:
        opts
        |> Keyword.get(:publish_system_ids, [])
        |> MapSet.new()
        |> MapSet.union(addition_ids),
      selections: selections,
      additions: additions,
      jumps: jumps
    }
  end

  defp clear_running(entry) do
    %{entry | monitor: nil, running_request: nil, dirty: false}
  end

  defp requeue_running_request(entry) do
    pending = pending_request(entry)

    entry
    |> put_pending_request(empty_request())
    |> merge_request(entry.running_request || empty_request())
    |> merge_request(pending)
  end

  defp put_pending_request(entry, request) do
    %{
      entry
      | pending_system_ids: request.pending_system_ids,
        publish_system_ids: request.publish_system_ids,
        selections: request.selections,
        additions: request.additions,
        jumps: request.jumps
    }
  end

  defp reply_waiters(waiters, result) do
    Enum.each(waiters, &GenServer.reply(&1, result))
  end

  defp empty_request do
    %{
      pending_system_ids: MapSet.new(),
      publish_system_ids: MapSet.new(),
      selections: %{},
      additions: %{},
      jumps: []
    }
  end

  defp new_entry(map_id) do
    empty_request()
    |> Map.merge(%{
      map_id: map_id,
      timer: nil,
      timer_token: nil,
      monitor: nil,
      running_request: nil,
      pending_waiters: [],
      running_waiters: [],
      dirty: false
    })
  end

  defp layout_enabled?(map_id) do
    WandererApp.Env.layout_service_enabled?() and
      WandererApp.LayoutSettings.get(map_id)["enabled"] == true
  end

  defp connection_key(%{solar_system_source: source, solar_system_target: target}),
    do: ordered_pair(source, target)

  defp connection_key(%{location: location, old_location: old_location}),
    do: ordered_pair(location.solar_system_id, old_location.solar_system_id)

  defp ordered_pair(left, right) when left <= right, do: {left, right}
  defp ordered_pair(left, right), do: {right, left}
end
