defmodule WandererApp.Zkb.KillsPreloader do
  @moduledoc """
  Preloads kills from zKillboard for the last 24 hours, for all visible systems in all maps,
  with concurrency at the map level.
  """

  use GenServer
  require Logger

  alias WandererApp.Zkb.KillsProvider.Fetcher

  @default_max_concurrency 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %{
      max_concurrency: Keyword.get(opts, :max_concurrency, @default_max_concurrency),
      calls_count: 0
    }

    send(self(), :preload_kills)
    {:ok, state}
  end

  def handle_info(:preload_kills, state) do
    start_time = System.monotonic_time()
    new_state = do_preload_all_maps(state)
    end_time = System.monotonic_time()

    elapsed_ms =
      System.convert_time_unit(end_time - start_time, :native, :millisecond)

    Logger.info("""
    [KillsPreloader] Finished kills preload => total calls=#{new_state.calls_count}, elapsed=#{elapsed_ms} ms
    """)

    {:noreply, new_state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp do_preload_all_maps(state) do
    case WandererApp.Api.Map.available() do
      {:ok, maps} ->
        maps
        |> Task.async_stream(
          fn map -> preload_map(map, state) end,
          max_concurrency: state.max_concurrency,
          timeout: :timer.minutes(5)
        )
        |> Enum.reduce(state, fn
          {:ok, map_state}, acc_state ->
            merge_calls_count(acc_state, map_state)

          {:error, reason}, acc_state ->
            Logger.error("[KillsPreloader] Task failed => #{inspect(reason)}")
            acc_state
        end)

      {:error, reason} ->
        Logger.error("[KillsPreloader] Could not load maps => #{inspect(reason)}")
        state
    end
  end

  # Preload all visible systems for a given map, returning updated state.
  defp preload_map(map, state) do
    Logger.debug("[KillsPreloader] Preloading kills for map=#{map.name} (id=#{map.id})")

    case WandererApp.MapSystemRepo.get_visible_by_map(map.id) do
      {:ok, systems} ->
        system_ids = Enum.map(systems, & &1.solar_system_id)

        case Fetcher.fetch_kills_for_systems_with_state(system_ids, 24, state) do
          {:ok, kills_map, updated_state} ->
            # Broadcast the kills_map for this map
            notify_detailed_kills_updated(map.id, kills_map)
            updated_state

          {:error, reason, updated_state} ->
            Logger.error("""
            [KillsPreloader] fetch_kills_for_systems_with_state failed for map=#{map.id} => #{inspect(reason)}
            """)
            updated_state
        end

      {:error, reason} ->
        Logger.error("[KillsPreloader] Could not get systems for map=#{map.id} => #{inspect(reason)}")
        state
    end
  end

  defp merge_calls_count(s1, s2) do
    %{s1 | calls_count: s1.calls_count + s2.calls_count}
  end

  def notify_detailed_kills_updated(map_id, kills_map) do
    Logger.debug("[KillsPreloader] Broadcasting kills for map=#{map_id}, kills_map size=#{map_size(kills_map)}")

    Phoenix.PubSub.broadcast!(
      WandererApp.PubSub,
      map_id,
      %{event: :detailed_kills_updated, payload: kills_map}
    )
  end


end
