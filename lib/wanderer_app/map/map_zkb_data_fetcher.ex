defmodule WandererApp.Map.ZkbDataFetcher do
  @moduledoc """
  Fetches zKillboard data for the map.
  """
  use GenServer

  require Logger

  alias WandererApp.Zkb.Provider.Cache

  @interval :timer.seconds(15)
  @store_map_kills_timeout :timer.hours(1)
  @logger Application.compile_env(:wanderer_app, :logger)

  # This means 120 "ticks" of 15s each → ~30 minutes
  @preload_cycle_ticks 120

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    {:ok, _timer_ref} = :timer.send_interval(@interval, :fetch_data)
    {:ok, %{iteration: 0}}
  end

  @impl true
  def handle_info(:fetch_data, %{iteration: iteration} = state) do
    zkill_preload_disabled = WandererApp.Env.zkill_preload_disabled?()
    active_maps = WandererApp.Map.RegistryHelper.list_all_maps()

    active_maps
    |> Task.async_stream(
      fn %{id: map_id, pid: _server_pid} ->
        try do
          if WandererApp.Map.Server.map_pid(map_id) do
            update_map_kills(map_id)

            {:ok, is_subscription_active} = map_id |> WandererApp.Map.is_subscription_active?()

            can_preload_zkill = not zkill_preload_disabled && is_subscription_active

            if can_preload_zkill do
              update_detailed_map_kills(map_id)
            end
          end
        rescue
          e ->
            @logger.error(Exception.message(e))
        end
      end,
      max_concurrency: 10,
      on_timeout: :kill_task
    )
    |> Enum.each(fn _ -> :ok end)

    new_iteration = iteration + 1

    cond do
      zkill_preload_disabled ->
        # If preload is disabled, just update iteration
        {:noreply, %{state | iteration: new_iteration}}

      new_iteration >= @preload_cycle_ticks ->
        WandererApp.Zkb.Preloader.run_preload_now()
        {:noreply, %{state | iteration: 0}}

      true ->
        {:noreply, %{state | iteration: new_iteration}}
    end
  end

  # Catch any async task results we aren't explicitly pattern-matching
  @impl true
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp update_map_kills(map_id) do
    with_started_map(map_id, "basic kills update", fn ->
      systems = map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:systems, %{})

      kills_map = systems
      |> Enum.into(%{}, fn {solar_system_id, _system} ->
        kill_count = Cache.get_kill_count(solar_system_id)
        {solar_system_id, kill_count}
      end)

      maybe_broadcast_map_kills(kills_map, map_id)
    end)
  end

  defp update_detailed_map_kills(map_id) do
    with_started_map(map_id, "detailed kills update", fn ->
      systems =
        map_id
        |> WandererApp.Map.get_map!()
        |> Map.get(:systems, %{})

      # Get all system IDs and their killmail IDs
      new_ids_map =
        Enum.into(systems, %{}, fn {solar_system_id, _} ->
          ids = Cache.get_system_killmail_ids(solar_system_id) |> MapSet.new()
          {solar_system_id, ids}
        end)

      _total_killmail_ids = new_ids_map |> Map.values() |> Enum.map(&MapSet.size/1) |> Enum.sum()

      # Get all cached kills for all systems
      new_details_map =
        systems
        |> Map.keys()
        |> Enum.reduce(%{}, fn system_id, acc ->
          case Cache.get_killmails_for_system(system_id) do
            {:ok, kills} -> Map.put(acc, system_id, kills)
            {:error, reason} ->
              Logger.warning("[ZkbDataFetcher] Failed to get killmails for system #{system_id}: #{inspect(reason)}")
              Map.put(acc, system_id, [])
          end
        end)

      _total_detailed_kills = new_details_map |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

      # Store updated data
      :ok = Cache.put_map_killmail_ids(map_id, new_ids_map, @store_map_kills_timeout)
      :ok = Cache.put_map_detailed_kills(map_id, new_details_map, @store_map_kills_timeout)

      # Broadcast changes
      WandererApp.Map.Server.Impl.broadcast!(map_id, :detailed_kills_updated, new_details_map)

      :ok
    end)
  end

  defp maybe_broadcast_map_kills(new_kills_map, map_id) do
    current_kills =
      case Cache.get_map_kill_counts(map_id) do
        {:ok, kills} ->
          kills
        {:error, _reason} ->
          %{}
      end

    payload =
      new_kills_map
      |> Enum.filter(fn {system_id, new_count} ->
        old_count = Map.get(current_kills, system_id, 0)
        changed = new_count != old_count and (new_count > 0 or old_count > 0)
        changed
      end)
      |> Enum.into(%{})

    persist_and_broadcast(map_id, new_kills_map, payload)
  end

  # clause for "nothing changed"
  defp persist_and_broadcast(_map_id, _new_kills_map, payload) when payload == %{} do
    :ok
  end

  # clause for "we have diffs"
  defp persist_and_broadcast(map_id, new_kills_map, payload) do
    :ok = Cache.put_map_kill_counts(map_id, new_kills_map, @store_map_kills_timeout)
    WandererApp.Map.Server.Impl.broadcast!(map_id, :kills_updated, payload)
    :ok
  end

  defp with_started_map(map_id, _label, fun) when is_function(fun, 0) do
    if Cache.is_map_started?(map_id) do
      fun.()
    else
      :ok
    end
  end
end
