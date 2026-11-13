defmodule WandererApp.PublicStats do
  @moduledoc """
  Periodically refreshes the public statistics displayed on the welcome page.

  Requests only read the cached snapshot; database aggregation happens in this
  process every ten minutes.
  """

  use GenServer

  require Ash.Query
  require Logger

  alias WandererApp.Api.Character
  alias WandererApp.Api.Map, as: ApiMap
  alias WandererApp.Cache

  @cache_key :public_stats_snapshot
  @default_refresh_interval :timer.seconds(30)
  @startup_refresh_interval :timer.seconds(5)
  @startup_refreshes 12
  @retry_interval :timer.seconds(10)
  @empty_snapshot %{
    online_users: 0,
    online_characters: 0,
    registered_characters: 0,
    created_maps: 0
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def snapshot do
    @empty_snapshot
    |> Map.merge(Cache.lookup!(@cache_key, @empty_snapshot))
  end

  @impl true
  def init(_opts) do
    refresh_snapshot()
    schedule_refresh(@startup_refresh_interval)

    {:ok,
     %{
       startup_refreshes_remaining: @startup_refreshes,
       refresh_interval: refresh_interval()
     }}
  end

  @impl true
  def handle_info(:refresh, state) do
    result = refresh_snapshot()
    {delay, state} = next_refresh(result, state)
    schedule_refresh(delay)

    {:noreply, state}
  end

  defp refresh_snapshot do
    with {:ok, registered_characters} <- count_registered_characters(),
         {:ok, created_maps} <- count_created_maps(),
         {:ok, online_activity} <- count_online_activity() do
      Cache.insert(@cache_key, %{
        online_users: online_activity.online_users,
        online_characters: online_activity.online_characters,
        registered_characters: registered_characters,
        created_maps: created_maps
      })

      :ok
    else
      {:error, reason} ->
        Logger.warning("Could not refresh public statistics: #{inspect(reason)}")
        :error
    end
  rescue
    error ->
      Logger.warning("Could not refresh public statistics: #{Exception.message(error)}")
      :error
  end

  defp count_registered_characters do
    Character
    |> Ash.Query.filter(deleted == false)
    |> Ash.count(authorize?: false)
  end

  defp count_created_maps do
    ApiMap
    |> Ash.Query.filter(deleted == false)
    |> Ash.count(authorize?: false)
  end

  @doc false
  def count_online_activity do
    with {:ok, character_ids} <- Cache.lookup("tracked_characters", []) do
      {online_user_ids, online_characters} =
        character_ids
        |> Enum.uniq()
        |> Enum.reduce({MapSet.new(), 0}, fn character_id, {user_ids, character_count} ->
          case Cachex.get(:character_cache, character_id) do
            {:ok, %{online: true} = character} ->
              if Map.get(character, :deleted, false) do
                {user_ids, character_count}
              else
                user_ids = maybe_add_user(user_ids, Map.get(character, :user_id))
                {user_ids, character_count + 1}
              end

            _ ->
              {user_ids, character_count}
          end
        end)

      {:ok,
       %{
         online_users: MapSet.size(online_user_ids),
         online_characters: online_characters
       }}
    end
  end

  defp maybe_add_user(user_ids, nil), do: user_ids
  defp maybe_add_user(user_ids, user_id), do: MapSet.put(user_ids, user_id)

  defp next_refresh(_result, %{startup_refreshes_remaining: remaining} = state)
       when remaining > 1 do
    {@startup_refresh_interval, %{state | startup_refreshes_remaining: remaining - 1}}
  end

  defp next_refresh(result, %{startup_refreshes_remaining: 1} = state) do
    next_refresh(result, %{state | startup_refreshes_remaining: 0})
  end

  defp next_refresh(:ok, %{refresh_interval: refresh_interval} = state),
    do: {refresh_interval, state}

  defp next_refresh(:error, state), do: {@retry_interval, state}

  defp refresh_interval do
    case WandererApp.Env.public_stats_refresh_interval_ms() do
      interval when is_integer(interval) and interval > 0 -> interval
      _ -> @default_refresh_interval
    end
  end

  defp schedule_refresh(delay) do
    Process.send_after(self(), :refresh, delay)
  end
end
