defmodule WandererApp.Zkb.Provider.Cache do
  @moduledoc """
  Caching functionality for zKillboard killmails and counts using `WandererApp.Cache`.
  """

  require Logger
  alias WandererApp.Cache
  alias WandererApp.Zkb.Provider.Key

  @type killmail_id :: pos_integer()
  @type system_id    :: pos_integer()
  @type killmail     :: map()
  @type cache_result :: :ok | {:error, term()}

  # TTL values in milliseconds
  @killmail_ttl            :timer.hours(24)
  @system_kills_ttl        :timer.hours(1)
  @fetched_timestamp_ttl   :timer.minutes(5)

  # -------------------------------------------------------------------
  # Generic cache operations
  # -------------------------------------------------------------------

  @doc "Fetch a value from the cache."
  @spec get(String.t()) :: {:ok, term() | nil} | {:error, term()}
  def get(key), do: Cache.lookup(key)

  @doc "Set a value in the cache with TTL (in ms)."
  @spec set(String.t(), term(), non_neg_integer()) :: cache_result()
  def set(key, value, ttl), do: Cache.insert(key, value, ttl: ttl)

  @doc "Delete a key from the cache."
  @spec delete(String.t()) :: cache_result()
  def delete(key), do: Cache.delete(key)

  @doc "Get a value or default if missing."
  @spec get!(String.t(), term()) :: term()
  def get!(key, default), do: Cache.lookup!(key, default)

  # -------------------------------------------------------------------
  # Killmail operations
  # -------------------------------------------------------------------

  @doc "Store a killmail map under its ID."
  @spec put_killmail(killmail_id(), killmail()) :: cache_result()
  def put_killmail(id, killmail) when is_integer(id) and is_map(killmail) do
    case insert(Key.killmail_key(id), killmail, @killmail_ttl) do
      :ok ->
        :ok
      error ->
        Logger.error("[Cache] Failed to store killmail #{id}: #{inspect(error)}")
        error
    end
  end

  @doc "Retrieve a killmail by ID."
  @spec get_killmail(killmail_id()) :: {:ok, killmail() | nil} | {:error, term()}
  def get_killmail(id) when is_integer(id) do
    get(Key.killmail_key(id))
  end

  # -------------------------------------------------------------------
  # System-specific killmail list
  # -------------------------------------------------------------------

  @doc "Add a killmail ID to a system's list of kills."
  @spec add_killmail_id_to_system_list(system_id(), killmail_id()) :: cache_result()
  def add_killmail_id_to_system_list(system_id, killmail_id) when is_integer(system_id) and is_integer(killmail_id) do
    key = Key.system_kills_list_key(system_id)

    try do
      _updated_list = Cache.insert_or_update(
        key,
        [killmail_id],  # Initial value if key doesn't exist
        fn existing_list -> [killmail_id | existing_list] end,  # Update function to prepend
        ttl: @killmail_ttl
      )
      :ok
    rescue
      # Handle ETS errors during shutdown gracefully
      error in [ArgumentError] ->
        Logger.warning("[Cache] Failed to add killmail #{killmail_id} to system #{system_id} list during shutdown: #{inspect(error)}")
        {:error, error}
      error ->
        Logger.error("[Cache] Unexpected error adding killmail #{killmail_id} to system #{system_id} list: #{inspect(error)}")
        {:error, error}
    catch
      # Handle ETS table not existing errors
      :error, :badarg ->
        Logger.warning("[Cache] ETS table not available for system #{system_id} killmail list (likely shutting down)")
        {:error, :cache_unavailable}
    end
  end

  @doc "Get killmail IDs for a given system."
  @spec get_system_killmail_ids(system_id()) :: [killmail_id()]
  def get_system_killmail_ids(system_id) when is_integer(system_id) do
    get!(Key.system_kills_list_key(system_id), [])
    |> Enum.reverse()
  end

  @doc "Get all killmail maps for a system, filtering out misses and logging errors."
  @spec get_killmails_for_system(system_id()) :: {:ok, [killmail()]} | {:error, term()}
  def get_killmails_for_system(system_id) when is_integer(system_id) do
    try do
      ids = get_system_killmail_ids(system_id)

      {killmails, errors} = ids
      |> Enum.reduce({[], []}, fn id, {acc, err_acc} ->
        case get_killmail(id) do
          {:ok, nil} ->
            {acc, err_acc}

          {:ok, killmail} ->
            {[killmail | acc], err_acc}

          {:error, reason} ->
            Logger.error("[Cache] Failed to fetch killmail #{id}: #{inspect(reason)}")
            {acc, [reason | err_acc]}
        end
      end)

      result = Enum.reverse(killmails)

      case errors do
        [] -> {:ok, result}
        _ ->
          if length(killmails) > 0 do
            # Return partial results with a warning
            Logger.warning("[Cache] Returning #{length(killmails)} killmails for system #{system_id}, but #{length(errors)} failed to load")
            {:ok, result}
          else
            # If no killmails loaded and we have errors, return the first error
            {:error, List.first(errors)}
          end
      end
    rescue
      e ->
        Logger.error("[Cache] Exception in get_killmails_for_system for system #{system_id}: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end

  # -------------------------------------------------------------------
  # Kill-count operations
  # -------------------------------------------------------------------

  @doc "Get the current kill count for a system."
  @spec get_kill_count(system_id()) :: non_neg_integer()
  def get_kill_count(system_id) when is_integer(system_id) do
    get!(Key.kill_count_key(system_id), 0)
  end

  @doc "Increment the kill count for a system."
  @spec increment_kill_count(system_id()) :: cache_result()
  def increment_kill_count(system_id) when is_integer(system_id) do
    try do
      _updated_count = Cache.insert_or_update(
        Key.kill_count_key(system_id),
        1,
        &(&1 + 1),
        ttl: @system_kills_ttl
      )
      :ok
    rescue
      # Handle ETS errors during shutdown gracefully
      error in [ArgumentError] ->
        Logger.warning("[Cache] Failed to increment kill count for system #{system_id} during shutdown: #{inspect(error)}")
        {:error, error}
      error ->
        Logger.error("[Cache] Unexpected error incrementing kill count for system #{system_id}: #{inspect(error)}")
        {:error, error}
    catch
      # Handle ETS table not existing errors
      :error, :badarg ->
        Logger.warning("[Cache] ETS table not available for system #{system_id} kill count (likely shutting down)")
        {:error, :cache_unavailable}
    end
  end

  # -------------------------------------------------------------------
  # Fetch-timestamp operations
  # -------------------------------------------------------------------

  @doc "Return true if kills for the system were fetched recently."
  @spec recently_fetched?(system_id()) :: boolean()
  def recently_fetched?(system_id) when is_integer(system_id) do
    case get(Key.fetched_timestamp_key(system_id)) do
      {:ok, ts} when is_integer(ts) ->
        System.system_time(:millisecond) - ts < @fetched_timestamp_ttl

      _ ->
        false
    end
  end

  @doc "Store the current time as the last fetched timestamp for a system."
  @spec put_full_fetched_timestamp(system_id()) :: cache_result()
  def put_full_fetched_timestamp(system_id) when is_integer(system_id) do
    insert(
      Key.fetched_timestamp_key(system_id),
      System.system_time(:millisecond),
      @fetched_timestamp_ttl
    )
  end

  # -------------------------------------------------------------------
  # Map-specific operations
  # -------------------------------------------------------------------

  @doc "Store kill counts for all systems in a map."
  @spec put_map_kill_counts(String.t(), %{integer() => non_neg_integer()}, non_neg_integer()) :: cache_result()
  def put_map_kill_counts(map_id, kill_counts, ttl) when is_binary(map_id) and is_map(kill_counts) do
    set("map_#{map_id}:zkb_kills", kill_counts, ttl)
  end

  @doc "Get kill counts for all systems in a map."
  @spec get_map_kill_counts(String.t()) :: {:ok, %{integer() => non_neg_integer()}} | {:error, term()}
  def get_map_kill_counts(map_id) when is_binary(map_id) do
    case get("map_#{map_id}:zkb_kills") do
      {:ok, nil} -> {:ok, %{}}
      {:ok, counts} when is_map(counts) -> {:ok, counts}
      error -> error
    end
  end

  @doc "Store detailed kill data for all systems in a map."
  @spec put_map_detailed_kills(String.t(), %{integer() => [killmail()]}, non_neg_integer()) :: cache_result()
  def put_map_detailed_kills(map_id, detailed_kills, ttl) when is_binary(map_id) and is_map(detailed_kills) do
    set("map_#{map_id}:zkb_detailed_kills", detailed_kills, ttl)
  end

  @doc "Get detailed kill data for all systems in a map."
  @spec get_map_detailed_kills(String.t()) :: {:ok, %{integer() => [killmail()]}} | {:error, term()}
  def get_map_detailed_kills(map_id) when is_binary(map_id) do
    case get("map_#{map_id}:zkb_detailed_kills") do
      {:ok, nil} -> {:ok, %{}}
      {:ok, kills} when is_map(kills) -> {:ok, kills}
      error -> error
    end
  end

  @doc "Store killmail IDs for all systems in a map."
  @spec put_map_killmail_ids(String.t(), %{integer() => MapSet.t(integer())}, non_neg_integer()) :: cache_result()
  def put_map_killmail_ids(map_id, ids_map, ttl) when is_binary(map_id) and is_map(ids_map) do
    set("map_#{map_id}:zkb_ids", ids_map, ttl)
  end

  @doc "Get killmail IDs for all systems in a map."
  @spec get_map_killmail_ids(String.t()) :: {:ok, %{integer() => MapSet.t(integer())}} | {:error, term()}
  def get_map_killmail_ids(map_id) when is_binary(map_id) do
    case get("map_#{map_id}:zkb_ids") do
      {:ok, nil} -> {:ok, %{}}
      {:ok, ids} when is_map(ids) -> {:ok, ids}
      error -> error
    end
  end

  @doc "Check if a map is started."
  @spec is_map_started?(String.t()) :: boolean()
  def is_map_started?(map_id) when is_binary(map_id) do
    Cache.lookup!("map_#{map_id}:started", false)
  end

  # -------------------------------------------------------------------
  # Utilities
  # -------------------------------------------------------------------

  @doc "Clear all zKillboard-related cache entries."
  @spec clear() :: :ok
  def clear do
    Cache.delete_all("zkb_*")
    :ok
  end

  @doc "Fetch cached kills for multiple systems at once."
  @spec fetch_cached_kills_for_systems([system_id()]) :: %{system_id() => [killmail()]}
  def fetch_cached_kills_for_systems(system_ids) when is_list(system_ids) do
    for sid <- system_ids, into: %{} do
      case get_killmails_for_system(sid) do
        {:ok, kills} -> {sid, kills}
        {:error, _reason} -> {sid, []}
      end
    end
  end

  # -------------------------------------------------------------------
  # Private helpers
  # -------------------------------------------------------------------

  defp insert(key, value, ttl), do: Cache.insert(key, value, ttl: ttl)
end
