defmodule WandererApp.Zkb.KillsPreloader do
  @moduledoc """
  Preloads kills from zKillboard in a **single** pass:
    - A 'full' (multi-page) fetch for each system.

  Concurrency is done at the *system* level, so that results broadcast
  as soon as each system finishes.
  """

  use GenServer
  require Logger

  alias WandererApp.Zkb.KillsProvider.Fetcher

  @default_max_concurrency 10
  @since_hours 24

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      max_concurrency: Keyword.get(opts, :max_concurrency, @default_max_concurrency),
      calls_count: 0
    }

    # Kick off the preload as soon as this GenServer starts
    send(self(), :preload_kills)
    {:ok, state}
  end

  @impl true
  def handle_info(:preload_kills, state) do
    start_time = System.monotonic_time()

    new_state = do_preload_all_maps(state)

    end_time = System.monotonic_time()
    elapsed_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

    Logger.info("""
    [KillsPreloader] Finished kills preload => total calls=#{new_state.calls_count}, elapsed=#{elapsed_ms} ms
    """)

    {:noreply, new_state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  # ------------------------------------------------------
  # Main preload (Single Pass)
  # ------------------------------------------------------
  defp do_preload_all_maps(state) do
    case WandererApp.Api.Map.available() do
      {:ok, maps} ->
        all_systems = gather_visible_systems(maps)

        # Single pass: multi-page fetch for each system
        final_state =
          all_systems
          |> Task.async_stream(
            fn {map_id, system_id} ->
              case fetch_one_system(map_id, system_id, state) do
                {:ok, updated_state} ->
                  updated_state

                other ->
                  other
              end
            end,
            max_concurrency: state.max_concurrency,
            timeout: :timer.minutes(5)
          )
          |> Enum.reduce(state, fn
            {:ok, updated_state}, acc ->
              merge_calls_count(acc, updated_state)

            {:error, reason}, acc ->
              Logger.error("[KillsPreloader] Fetch task failed => #{inspect(reason)}")
              acc
          end)

        final_state

      {:error, reason} ->
        Logger.error("[KillsPreloader] Could not load maps => #{inspect(reason)}")
        state
    end
  end

  # Gather all visible systems from the list of maps
  defp gather_visible_systems(maps) do
    maps
    |> Enum.flat_map(fn map ->
      case WandererApp.MapSystemRepo.get_visible_by_map(map.id) do
        {:ok, systems} ->
          Enum.map(systems, fn sys ->
            {map.id, sys.solar_system_id}
          end)

        {:error, reason} ->
          Logger.error("[KillsPreloader] Could not get systems for map=#{map.id} => #{inspect(reason)}")
          []
      end
    end)
  end

  # ------------------------------------------------------
  # Full (multi-page) fetch for one system
  # ------------------------------------------------------
  defp fetch_one_system(map_id, system_id, state) do
    Logger.debug("[KillsPreloader] FULL fetch => map=#{map_id}, system=#{system_id}")

    # For a truly "full" multi-page fetch:
    case Fetcher.fetch_kills_for_system(system_id, @since_hours, state) do
      {:ok, kills, updated_state} ->
        broadcast_single_system(map_id, system_id, kills)
        {:ok, updated_state}

      {:error, reason, updated_state} ->
        Logger.error("[KillsPreloader] FULL fetch failed => system=#{system_id}, reason=#{inspect(reason)}")
        {:ok, updated_state}
    end
  end

  # Broadcast results for one system
  defp broadcast_single_system(map_id, system_id, kills) do
    Phoenix.PubSub.broadcast!(
      WandererApp.PubSub,
      map_id,
      %{
        event: :detailed_kills_updated,
        payload: %{system_id => kills},
        fetch_type: :full
      }
    )
  end

  # Merges the calls_count from two states
  defp merge_calls_count(s1, s2),
    do: %{s1 | calls_count: s1.calls_count + s2.calls_count}
end
