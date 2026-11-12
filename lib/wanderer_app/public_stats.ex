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
  alias WandererApp.Cache

  @cache_key :public_stats_snapshot
  @refresh_interval :timer.minutes(10)
  @empty_snapshot %{online_users: 0, registered_characters: 0}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def snapshot do
    Cache.lookup!(@cache_key, @empty_snapshot)
  end

  @impl true
  def init(_opts) do
    refresh_snapshot()
    schedule_refresh()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:refresh, state) do
    refresh_snapshot()
    schedule_refresh()

    {:noreply, state}
  end

  defp refresh_snapshot do
    with {:ok, registered_characters} <- count_registered_characters(),
         {:ok, online_users} <- count_online_users() do
      Cache.insert(@cache_key, %{
        online_users: online_users,
        registered_characters: registered_characters
      })
    else
      {:error, reason} ->
        Logger.warning("Could not refresh public statistics: #{inspect(reason)}")
    end
  rescue
    error ->
      Logger.warning("Could not refresh public statistics: #{Exception.message(error)}")
  end

  defp count_registered_characters do
    Character
    |> Ash.Query.filter(deleted == false)
    |> Ash.count(authorize?: false)
  end

  defp count_online_users do
    query =
      Character
      |> Ash.Query.filter(deleted == false and online == true and not is_nil(user_id))

    case Ash.aggregate(
           query,
           {:online_users, :count, field: :user_id, uniq?: true},
           authorize?: false
         ) do
      {:ok, %{online_users: online_users}} -> {:ok, online_users}
      {:error, reason} -> {:error, reason}
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
