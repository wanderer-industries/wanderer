defmodule WandererApp.Zkb.Preloader do
  @moduledoc """
  Preloads killmail data for active maps.

  On startup:
    1. Runs a one-off quick preload (last 1h, limit 5).
    2. Exposes `run_preload_now/0` for an expanded preload (last 24h, limit 100).

  Typically, expanded passes are triggered by WandererApp.Map.ZkbDataFetcher.
  """

  use GenServer
  require Logger

  alias WandererApp.{Api.MapState, MapSystemRepo}
  alias WandererApp.Zkb.Provider.Fetcher

  @type pass_type :: :quick | :expanded
  @type fetch_result :: {integer(), non_neg_integer()}

  @passes %{
    quick:    %{hours: 1,  limit: 5},
    expanded: %{hours: 24, limit: 100}
  }

  # how many minutes back we look for "active" maps
  @last_active_cutoff_minutes 30

  @default_max_concurrency 2
  @task_timeout_ms        :timer.seconds(30)

  ## Public API

  @doc false
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @doc """
  Starts the KillsPreloader GenServer.

  Options:
    - `:max_concurrency` (integer, default: #{@default_max_concurrency})
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an expanded preload pass (last 24h, limit 100).
  """
  @spec run_preload_now() :: :ok
  def run_preload_now do
    GenServer.cast(__MODULE__, :run_expanded_pass)
  end

  ## GenServer callbacks

  @impl true
  def init(opts) do
    max_concurrency = Keyword.get(opts, :max_concurrency, @default_max_concurrency)
    spawn_pass(:quick, max_concurrency)
    {:ok, %{max_concurrency: max_concurrency}}
  end

  @impl true
  def handle_cast(:run_expanded_pass, %{max_concurrency: max} = state) do
    spawn_pass(:expanded, max)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    # Only log actual crashes, not normal exits or expected errors
    case reason do
      :normal -> :ok
      :no_active_subscribed_maps -> :ok
      :no_active_systems -> :ok
      _ -> Logger.error("[ZkbPreloader] Preload task crashed: #{inspect(reason)}")
    end
    {:noreply, state}
  end

  ## Internal

  defp spawn_pass(pass_type, max_concurrency) do
    case Task.start(fn -> do_pass(pass_type, max_concurrency) end) do
      {:ok, task} ->
        Process.monitor(task)
        :ok
      {:error, reason} ->
        Logger.error("[ZkbPreloader] Failed to start preload task: #{inspect(reason)}")
        :error
    end
  end

  @spec do_pass(pass_type(), pos_integer()) :: :ok
  defp do_pass(pass_type, max_concurrency) do
    %{hours: hours, limit: limit} = @passes[pass_type]
    Logger.metadata(pass: pass_type)
    start_time = System.monotonic_time(:millisecond)

    case load_system_ids() do
      {:ok, system_ids} ->
        stats =
          system_ids
          |> Task.async_stream(
               &fetch_system(&1, hours, limit),
               max_concurrency: max_concurrency,
               timeout: @task_timeout_ms,
               on_timeout: :kill_task
             )
          |> Enum.reduce(%{success: 0, failed: 0, total_kills: 0}, &accumulate_results/2)

        log_stats(pass_type, system_ids, stats, start_time)

      {:error, reason} ->
        Logger.error("Failed #{pass_type} preload: #{inspect(reason)}")
    end

    :ok
  end

  defp log_stats(type, ids, %{success: s, failed: f, total_kills: k}, start_ms) do
    elapsed_s = (System.monotonic_time(:millisecond) - start_ms) / 1_000

    Logger.info("""
    Completed #{type} zkill preload:
      • Systems: #{length(ids)}
      • Success: #{s}
      • Failed: #{f}
      • Total Kills: #{k}
      • Elapsed: #{Float.round(elapsed_s, 2)}s
    """)
  end

  @spec accumulate_results(
          {:ok, fetch_result()} | {:exit, any()} | {:error, any()},
          %{success: integer(), failed: integer(), total_kills: integer()}
        ) :: %{success: integer(), failed: integer(), total_kills: integer()}
  defp accumulate_results({:ok, {_id, count}}, acc) do
    %{acc | success: acc.success + 1, total_kills: acc.total_kills + count}
  end
  defp accumulate_results({:exit, _}, acc),  do: %{acc | failed: acc.failed + 1}
  defp accumulate_results({:error, _}, acc), do: %{acc | failed: acc.failed + 1}

  @spec fetch_system(integer(), pos_integer(), pos_integer()) :: fetch_result()
  defp fetch_system(system_id, since_hours, limit) do
    case Fetcher.fetch_killmails_for_system(system_id, since_hours: since_hours, limit: limit) do
      {:ok, kills} ->
        {system_id, length(kills)}

      {:error, reason} ->
        Logger.debug("Fetch error for system #{system_id}: #{inspect(reason)}")
        {system_id, 0}
    end
  end

  @doc """
  Loads system IDs from active maps with active subscriptions.
  """
  @spec load_system_ids() :: {:ok, [integer()]} | {:error, term()}
  def load_system_ids do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@last_active_cutoff_minutes * 60, :second)

    case MapState.get_last_active(cutoff) do
      {:error, reason} ->
        Logger.error("[ZkbPreloader] MapState.get_last_active failed: #{inspect(reason)}")
        {:error, reason}

      {:ok, maps} ->
        maps
        |> Enum.filter(&subscription_active?/1)
        |> handle_active_maps()
    end
  end

  defp handle_active_maps([]), do: {:error, :no_active_subscribed_maps}
  defp handle_active_maps(active_maps) do
    ids =
      active_maps
      |> Enum.flat_map(&fetch_ids_for_map/1)
      |> Enum.uniq()

    case ids do
      [] -> {:error, :no_active_systems}
      _  -> {:ok, ids}
    end
  end

  defp fetch_ids_for_map(map) do
    case MapSystemRepo.get_visible_by_map(map.map_id) do
      {:ok, systems} -> Enum.map(systems, & &1.solar_system_id)
      _              -> []
    end
  end

  @spec subscription_active?(struct()) :: boolean()
  defp subscription_active?(map) do
    case WandererApp.Map.is_subscription_active?(map.id) do
      {:ok, true} -> true
      _           -> false
    end
  end
end
