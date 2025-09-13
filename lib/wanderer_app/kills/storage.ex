defmodule WandererApp.Kills.Storage do
  @moduledoc """
  Manages caching and storage of killmail data.

  Provides a centralized interface for storing and retrieving kill-related data
  using Cachex for distributed caching.
  """

  require Logger

  alias WandererApp.Kills.Config

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
  This should only be used for kill count updates from the WebSocket service.
  """
  @spec store_kill_count(integer(), non_neg_integer()) :: :ok | {:error, any()}
  def store_kill_count(system_id, count) do
    key = "zkb:kills:#{system_id}"
    ttl = Config.kill_count_ttl()
    metadata_key = "zkb:kills:metadata:#{system_id}"

    # Store both the count and metadata about when it was set
    # This helps detect if we should trust incremental updates or the absolute count
    timestamp = System.system_time(:millisecond)

    with :ok <- WandererApp.Cache.insert(key, count, ttl: ttl),
         :ok <-
           WandererApp.Cache.insert(
             metadata_key,
             %{
               "source" => "websocket",
               "timestamp" => timestamp,
               "absolute_count" => count
             },
             ttl: ttl
           ) do
      :ok
    else
      # Nebulex might return true instead of :ok
      true -> :ok
      error -> error
    end
  end

  @doc """
  Updates the kill count by adding to the existing count.
  This is used when processing incoming killmails.
  """
  @spec update_kill_count(integer(), non_neg_integer(), pos_integer()) :: :ok | {:error, any()}
  def update_kill_count(system_id, additional_kills, ttl) do
    key = "zkb:kills:#{system_id}"
    metadata_key = "zkb:kills:metadata:#{system_id}"

    # Check metadata to see if we should trust incremental updates
    metadata = WandererApp.Cache.get(metadata_key)
    current_time = System.system_time(:millisecond)

    # If we have recent websocket data (within 5 seconds), don't increment
    # This prevents double counting when both killmail and count updates arrive
    should_increment =
      case metadata do
        %{"source" => "websocket", "timestamp" => ws_timestamp} ->
          current_time - ws_timestamp > 5000

        _ ->
          true
      end

    if should_increment do
      # Use atomic update operation
      result =
        WandererApp.Cache.insert_or_update(
          key,
          additional_kills,
          fn current_count -> current_count + additional_kills end,
          ttl: ttl
        )

      case result do
        :ok ->
          # Update metadata to indicate this was an incremental update
          WandererApp.Cache.insert(
            metadata_key,
            %{
              "source" => "incremental",
              "timestamp" => current_time,
              "last_increment" => additional_kills
            },
            ttl: ttl
          )

          :ok

        {:ok, _} ->
          :ok

        true ->
          :ok

        error ->
          error
      end
    else
      # Skip increment as we have recent absolute count from websocket
      Logger.debug(
        "[Storage] Skipping kill count increment for system #{system_id} due to recent websocket update"
      )

      :ok
    end
  end

  @doc """
  Retrieves the kill count for a system.
  """
  @spec get_kill_count(integer()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def get_kill_count(system_id) do
    key = "zkb:kills:#{system_id}"

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
    key = "zkb:killmail:#{killmail_id}"

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
    kill_ids = WandererApp.Cache.get("zkb:kills:list:#{system_id}") || []

    if kill_ids == [] do
      {:error, :not_found}
    else
      # Fetch details for each killmail
      kills =
        kill_ids
        |> Enum.map(&WandererApp.Cache.get("zkb:killmail:#{&1}"))
        |> Enum.reject(&is_nil/1)

      {:ok, kills}
    end
  end

  @doc """
  Reconciles kill count with actual kill list length.
  This can be called periodically to ensure consistency.
  """
  @spec reconcile_kill_count(integer()) :: :ok | {:error, term()}
  def reconcile_kill_count(system_id) do
    key = "zkb:kills:#{system_id}"
    list_key = "zkb:kills:list:#{system_id}"
    metadata_key = "zkb:kills:metadata:#{system_id}"
    ttl = Config.kill_count_ttl()

    # Get actual kill list length
    actual_count =
      case WandererApp.Cache.get(list_key) do
        nil -> 0
        list when is_list(list) -> length(list)
        _ -> 0
      end

    # Update the count to match reality
    with :ok <- WandererApp.Cache.insert(key, actual_count, ttl: ttl),
         :ok <-
           WandererApp.Cache.insert(
             metadata_key,
             %{
               "source" => "reconciliation",
               "timestamp" => System.system_time(:millisecond),
               "actual_count" => actual_count
             },
             ttl: ttl
           ) do
      :ok
    else
      true -> :ok
      error -> error
    end
  end

  # Private functions

  defp store_individual_killmails(killmails, ttl) do
    results =
      killmails
      |> Enum.filter(fn killmail ->
        killmail_id = Map.get(killmail, "killmail_id") || Map.get(killmail, :killmail_id)
        not is_nil(killmail_id)
      end)
      |> Enum.map(fn killmail ->
        killmail_id = Map.get(killmail, "killmail_id") || Map.get(killmail, :killmail_id)
        key = "zkb:killmail:#{killmail_id}"
        WandererApp.Cache.insert(key, killmail, ttl: ttl)
      end)

    # Check if any storage operations failed
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp update_system_kill_list(system_id, new_killmails, ttl) do
    # Store as a list of killmail IDs for compatibility with ZkbDataFetcher
    key = "zkb:kills:list:#{system_id}"
    kill_list_limit = Config.kill_list_limit()

    # Extract killmail IDs from new kills
    new_ids =
      new_killmails
      |> Enum.map(fn kill ->
        Map.get(kill, "killmail_id") || Map.get(kill, :killmail_id)
      end)
      |> Enum.reject(&is_nil/1)

    # Use atomic update to prevent race conditions
    case WandererApp.Cache.insert_or_update(
           key,
           new_ids,
           fn existing_ids ->
             # Merge with existing, keeping unique IDs and newest first
             (new_ids ++ existing_ids)
             |> Enum.uniq()
             |> Enum.take(kill_list_limit)
           end,
           ttl: ttl
         ) do
      :ok ->
        :ok

      {:ok, _} ->
        :ok

      true ->
        :ok

      error ->
        Logger.error(
          "[Storage] Failed to update system kill list for system #{system_id}: #{inspect(error)}"
        )

        {:error, :cache_update_failed}
    end
  end
end
