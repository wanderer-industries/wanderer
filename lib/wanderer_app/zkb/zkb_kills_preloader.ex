defmodule WandererApp.Zkb.KillsPreloader do
  @moduledoc """
  On startup, kicks off two passes (quick and expanded) to preload kills data.

  There is also a `run_preload_now/0` function for manual triggering of the same logic.
  """

  use GenServer
  require Logger

  alias WandererApp.Zkb.KillsProvider
  alias WandererApp.Zkb.KillsProvider.KillsCache

  # ----------------
  # Configuration
  # ----------------

  # (1) Quick pass
  @quick_limit 1
  @quick_hours 1

  # (2) Expanded pass
  @expanded_limit 25
  @expanded_hours 24

  # How many minutes back we look for “last active” maps
  @last_active_cutoff 30

  # Default concurrency if not provided
  @default_max_concurrency 2

  @doc """
  Starts the GenServer with optional opts (like `max_concurrency`).
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Public helper to explicitly request a fresh preload pass (both quick & expanded).
  """
  def run_preload_now() do
    send(__MODULE__, :start_preload)
  end

  @impl true
  def init(opts) do
    state = %{
      phase: :idle,
      calls_count: 0,
      max_concurrency: Keyword.get(opts, :max_concurrency, @default_max_concurrency)
    }

    # Kick off the preload passes once at startup
    send(self(), :start_preload)
    {:ok, state}
  end

  @impl true
  def handle_info(:start_preload, state) do
    # Gather last-active maps (or fallback).
    cutoff_time =
      DateTime.utc_now()
      |> DateTime.add(-@last_active_cutoff, :minute)

    last_active_maps_result = WandererApp.Api.MapState.get_last_active(cutoff_time)
    last_active_maps = resolve_last_active_maps(last_active_maps_result)
    active_maps_with_subscription = get_active_maps_with_subscription(last_active_maps)

    # Gather systems from those maps
    system_tuples = gather_visible_systems(active_maps_with_subscription)
    unique_systems = Enum.uniq(system_tuples)

    Logger.debug(fn ->
      """
      [KillsPreloader] Found #{length(unique_systems)} unique systems \
      across #{length(active_maps_with_subscription)} map(s)
      """
    end)

    # ---- QUICK PASS ----
    state_quick = %{state | phase: :quick_pass}

    {time_quick_ms, state_after_quick} =
      measure_execution_time(fn ->
        do_pass(unique_systems, :quick, @quick_hours, @quick_limit, state_quick)
      end)

    Logger.info(
      "[KillsPreloader] Phase 1 (quick) done => calls_count=#{state_after_quick.calls_count}, elapsed=#{time_quick_ms}ms"
    )

    # ---- EXPANDED PASS ----
    state_expanded = %{state_after_quick | phase: :expanded_pass}

    {time_expanded_ms, final_state} =
      measure_execution_time(fn ->
        do_pass(unique_systems, :expanded, @quick_hours, @expanded_limit, state_expanded)
      end)

    Logger.info(
      "[KillsPreloader] Phase 2 (expanded) done => calls_count=#{final_state.calls_count}, elapsed=#{time_expanded_ms}ms"
    )

    # Reset phase to :idle
    {:noreply, %{final_state | phase: :idle}}
  end

  @impl true
  def handle_info(_other, state), do: {:noreply, state}

  defp resolve_last_active_maps({:ok, []}) do
    Logger.warning("[KillsPreloader] No last-active maps found. Using fallback logic...")

    case WandererApp.Maps.get_available_maps() do
      {:ok, []} ->
        Logger.error("[KillsPreloader] Fallback: get_available_maps returned zero maps!")
        []

      {:ok, maps} ->
        # pick the newest map by updated_at
        fallback_map = Enum.max_by(maps, & &1.updated_at, fn -> nil end)
        if fallback_map, do: [fallback_map], else: []
    end
  end

  defp resolve_last_active_maps({:ok, maps}) when is_list(maps),
    do: maps

  defp resolve_last_active_maps({:error, reason}) do
    Logger.error("[KillsPreloader] Could not load last-active maps => #{inspect(reason)}")
    []
  end

  defp get_active_maps_with_subscription(maps) do
    maps
    |> Enum.filter(fn map ->
      {:ok, is_subscription_active} = map.id |> WandererApp.Map.is_subscription_active?()
      is_subscription_active
    end)
  end

  defp gather_visible_systems(maps) do
    maps
    |> Enum.flat_map(fn map_record ->
      the_map_id = Map.get(map_record, :map_id) || Map.get(map_record, :id)

      case WandererApp.MapSystemRepo.get_visible_by_map(the_map_id) do
        {:ok, systems} ->
          Enum.map(systems, fn sys -> {the_map_id, sys.solar_system_id} end)

        {:error, reason} ->
          Logger.warning(
            "[KillsPreloader] get_visible_by_map failed => map_id=#{inspect(the_map_id)}, reason=#{inspect(reason)}"
          )

          []
      end
    end)
  end

  defp do_pass(unique_systems, pass_type, hours, limit, state) do
    Logger.info(
      "[KillsPreloader] Starting #{pass_type} pass => #{length(unique_systems)} systems"
    )

    {final_state, kills_map} =
      unique_systems
      |> Task.async_stream(
        fn {_map_id, system_id} ->
          fetch_kills_for_system(system_id, pass_type, hours, limit, state)
        end,
        max_concurrency: state.max_concurrency,
        timeout: pass_timeout_ms(pass_type)
      )
      |> Enum.reduce({state, %{}}, fn task_result, {acc_state, acc_map} ->
        reduce_task_result(pass_type, task_result, acc_state, acc_map)
      end)

    if map_size(kills_map) > 0 do
      broadcast_all_kills(kills_map, pass_type)
    end

    final_state
  end

  defp fetch_kills_for_system(system_id, :quick, hours, limit, state) do
    Logger.debug(fn ->
      "[KillsPreloader] Quick fetch => system=#{system_id}, hours=#{hours}, limit=#{limit}"
    end)

    case KillsProvider.Fetcher.fetch_kills_for_system(system_id, hours, state,
           limit: limit,
           force: false
         ) do
      {:ok, kills, updated_state} ->
        {:ok, system_id, kills, updated_state}

      {:error, reason, updated_state} ->
        Logger.warning(
          "[KillsPreloader] Quick fetch failed => system=#{system_id}, reason=#{inspect(reason)}"
        )

        {:error, reason, updated_state}
    end
  end

  defp fetch_kills_for_system(system_id, :expanded, hours, limit, state) do
    Logger.debug(fn ->
      "[KillsPreloader] Expanded fetch => system=#{system_id}, hours=#{hours}, limit=#{limit} (forcing refresh)"
    end)

    with {:ok, kills_1h, updated_state} <-
           KillsProvider.Fetcher.fetch_kills_for_system(system_id, hours, state,
             limit: limit,
             force: true
           ),
         {:ok, final_kills, final_state} <-
           maybe_fetch_more_if_needed(system_id, kills_1h, limit, updated_state) do
      {:ok, system_id, final_kills, final_state}
    else
      {:error, reason, updated_state} ->
        Logger.warning(
          "[KillsPreloader] Expanded fetch (#{hours}h) failed => system=#{system_id}, reason=#{inspect(reason)}"
        )

        {:error, reason, updated_state}
    end
  end

  # If we got fewer kills than `limit` from the 1h fetch, top up from 24h
  defp maybe_fetch_more_if_needed(system_id, kills_1h, limit, state) do
    if length(kills_1h) < limit do
      needed = limit - length(kills_1h)

      Logger.debug(fn ->
        "[KillsPreloader] Expanding to #{@expanded_hours}h => system=#{system_id}, need=#{needed} more kills"
      end)

      case KillsProvider.Fetcher.fetch_kills_for_system(system_id, @expanded_hours, state,
             limit: needed,
             force: true
           ) do
        {:ok, _kills_24h, updated_state2} ->
          final_kills =
            KillsCache.fetch_cached_kills(system_id)
            |> Enum.take(limit)

          {:ok, final_kills, updated_state2}

        {:error, reason2, updated_state2} ->
          Logger.warning(
            "[KillsPreloader] #{@expanded_hours}h fetch failed => system=#{system_id}, reason=#{inspect(reason2)}"
          )

          {:error, reason2, updated_state2}
      end
    else
      {:ok, kills_1h, state}
    end
  end

  defp reduce_task_result(pass_type, task_result, acc_state, acc_map) do
    case task_result do
      {:ok, {:ok, sys_id, kills, updated_state}} ->
        # Merge calls count from updated_state into acc_state
        new_state = merge_calls_count(acc_state, updated_state)
        new_map = Map.put(acc_map, sys_id, kills)
        {new_state, new_map}

      {:ok, {:error, reason, updated_state}} ->
        log_failed_task(pass_type, reason)
        new_state = merge_calls_count(acc_state, updated_state)
        {new_state, acc_map}

      {:error, reason} ->
        Logger.error("[KillsPreloader] #{pass_type} fetch task crashed => #{inspect(reason)}")
        {acc_state, acc_map}
    end
  end

  defp log_failed_task(:quick, reason),
    do: Logger.warning("[KillsPreloader] Quick fetch task failed => #{inspect(reason)}")

  defp log_failed_task(:expanded, reason),
    do: Logger.error("[KillsPreloader] Expanded fetch task failed => #{inspect(reason)}")

  defp broadcast_all_kills(kills_map, pass_type) do
    Logger.info(
      "[KillsPreloader] Broadcasting kills => #{map_size(kills_map)} systems (#{pass_type})"
    )

    Phoenix.PubSub.broadcast!(
      WandererApp.PubSub,
      "zkb_preload",
      %{
        event: :detailed_kills_updated,
        payload: kills_map,
        fetch_type: pass_type
      }
    )
  end

  defp merge_calls_count(%{calls_count: c1} = st1, %{calls_count: c2}),
    do: %{st1 | calls_count: c1 + c2}

  defp merge_calls_count(st1, _other),
    do: st1

  defp pass_timeout_ms(:quick), do: :timer.minutes(2)
  defp pass_timeout_ms(:expanded), do: :timer.minutes(5)

  defp measure_execution_time(fun) when is_function(fun, 0) do
    start = System.monotonic_time()
    result = fun.()
    finish = System.monotonic_time()
    ms = System.convert_time_unit(finish - start, :native, :millisecond)
    {ms, result}
  end
end
