defmodule WandererApp.Kills.Storage do
  @moduledoc """
  Manages caching and storage of killmail data.

  Provides a centralized interface for storing and retrieving kill-related data
  using Cachex for distributed caching.
  """

  alias WandererApp.Kills.{Config, CacheKeys}

  @doc """
  Stores killmails for a specific system.

  Stores both individual killmails by ID and a list of kills for the system.
  """
  @spec store_killmails(integer(), list(map()), pos_integer()) :: :ok | {:error, term()}
  def store_killmails(system_id, killmails, ttl) do
    result1 = store_individual_killmails(killmails, ttl)
    require Logger
    Logger.debug("[Storage] store_individual_killmails returned: #{inspect(result1)}")

    result2 = update_system_kill_list(system_id, killmails, ttl)
    Logger.debug("[Storage] update_system_kill_list returned: #{inspect(result2)}")

    case {result1, result2} do
      {:ok, :ok} ->
        :ok

      {{:error, reason}, _} ->
        Logger.error("[Storage] Failed to store individual killmails: #{inspect(reason)}")
        {:error, reason}

      {_, {:error, reason}} ->
        Logger.error("[Storage] Failed to update system kill list: #{inspect(reason)}")
        {:error, reason}

      other ->
        Logger.error("[Storage] Unexpected results: #{inspect(other)}")
        {:error, {:unexpected_results, other}}
    end
  end

  @doc """
  Stores or updates the kill count for a system.
  """
  @spec store_kill_count(integer(), non_neg_integer()) :: :ok
  def store_kill_count(system_id, count) do
    key = CacheKeys.system_kill_count(system_id)
    ttl = Config.kill_count_ttl()

    WandererApp.Cache.insert(key, count, ttl: ttl)
    :ok
  end

  @doc """
  Updates the kill count by adding to the existing count.
  """
  @spec update_kill_count(integer(), non_neg_integer(), pos_integer()) :: :ok
  def update_kill_count(system_id, additional_kills, ttl) do
    key = CacheKeys.system_kill_count(system_id)

    # Use atomic update operation
    WandererApp.Cache.insert_or_update(
      key,
      additional_kills,
      fn current_count -> current_count + additional_kills end,
      ttl: ttl
    )

    :ok
  end

  @doc """
  Retrieves the kill count for a system.
  """
  @spec get_kill_count(integer()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def get_kill_count(system_id) do
    key = CacheKeys.system_kill_count(system_id)

    case WandererApp.Cache.get(key) do
      nil -> {:error, :not_found}
      count -> {:ok, count}
    end
  end

  @doc """
  Retrieves a specific killmail by ID.
  """
  @spec get_killmail(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_killmail(killmail_id) do
    key = CacheKeys.killmail(killmail_id)

    case WandererApp.Cache.get(key) do
      nil -> {:error, :not_found}
      killmail -> {:ok, killmail}
    end
  end

  @doc """
  Retrieves all kills for a specific system.
  """
  @spec get_system_kills(integer()) :: {:ok, list(map())} | {:error, :not_found}
  def get_system_kills(system_id) do
    # Get the list of killmail IDs for this system
    kill_ids = WandererApp.Cache.get(CacheKeys.system_kill_list(system_id)) || []

    if kill_ids == [] do
      {:error, :not_found}
    else
      # Fetch details for each killmail
      kills =
        kill_ids
        |> Enum.map(&WandererApp.Cache.get(CacheKeys.killmail(&1)))
        |> Enum.reject(&is_nil/1)

      {:ok, kills}
    end
  end

  # Private functions

  defp store_individual_killmails(killmails, ttl) do
    results =
      Enum.map(killmails, fn killmail ->
        killmail_id = Map.get(killmail, "killmail_id") || Map.get(killmail, :killmail_id)

        if killmail_id do
          key = CacheKeys.killmail(killmail_id)
          # Nebulex's put returns true on success
          WandererApp.Cache.insert(key, killmail, ttl: ttl)
          :ok
        else
          {:error, :missing_killmail_id}
        end
      end)

    # Check if any failed
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  # Make kill list limit configurable
  @default_kill_list_limit 100

  defp update_system_kill_list(system_id, new_killmails, ttl) do
    # Store as a list of killmail IDs for compatibility with ZkbDataFetcher
    key = CacheKeys.system_kill_list(system_id)
    kill_list_limit = Config.kill_list_limit() || @default_kill_list_limit

    # Extract killmail IDs from new kills
    new_ids =
      new_killmails
      |> Enum.map(fn kill ->
        Map.get(kill, "killmail_id") || Map.get(kill, :killmail_id)
      end)
      |> Enum.reject(&is_nil/1)

    # Use atomic update to prevent race conditions
    # Note: insert_or_update returns true on success
    WandererApp.Cache.insert_or_update(
      key,
      new_ids,
      fn existing_ids ->
        # Merge with existing, keeping unique IDs and newest first
        (new_ids ++ existing_ids)
        |> Enum.uniq()
        |> Enum.take(kill_list_limit)
      end,
      ttl: ttl
    )

    :ok
  end
end
