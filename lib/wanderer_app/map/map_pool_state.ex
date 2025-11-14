defmodule WandererApp.Map.MapPoolState do
  @moduledoc """
  Helper module for persisting MapPool state to ETS for crash recovery.

  This module provides functions to save and retrieve MapPool state from an ETS table.
  The state survives GenServer crashes but is lost on node restart, which ensures
  automatic recovery from crashes while avoiding stale state on system restart.

  ## ETS Table Ownership

  The ETS table `:map_pool_state_table` is owned by the MapPoolSupervisor,
  ensuring it survives individual MapPool process crashes.

  ## State Format

  State is stored as tuples: `{pool_uuid, map_ids, last_updated_timestamp}`
  where:
  - `pool_uuid` is the unique identifier for the pool (key)
  - `map_ids` is a list of map IDs managed by this pool
  - `last_updated_timestamp` is the Unix timestamp of the last update
  """

  require Logger

  @table_name :map_pool_state_table
  @stale_threshold_hours 24

  @doc """
  Initializes the ETS table for storing MapPool state.

  This should be called by the MapPoolSupervisor during initialization.
  The table is created as:
  - `:set` - Each pool UUID has exactly one entry
  - `:public` - Any process can read/write
  - `:named_table` - Can be accessed by name

  Returns the table reference or raises if table already exists.
  """
  @spec init_table() :: :ets.table()
  def init_table do
    :ets.new(@table_name, [:set, :public, :named_table])
  end

  @doc """
  Saves the current state of a MapPool to ETS.

  ## Parameters
  - `uuid` - The unique identifier for the pool
  - `map_ids` - List of map IDs currently managed by this pool

  ## Examples

      iex> MapPoolState.save_pool_state("pool-123", [1, 2, 3])
      :ok
  """
  @spec save_pool_state(String.t(), [integer()]) :: :ok
  def save_pool_state(uuid, map_ids) when is_binary(uuid) and is_list(map_ids) do
    timestamp = System.system_time(:second)
    true = :ets.insert(@table_name, {uuid, map_ids, timestamp})

    Logger.debug("Saved MapPool state for #{uuid}: #{length(map_ids)} maps",
      pool_uuid: uuid,
      map_count: length(map_ids)
    )

    :ok
  end

  @doc """
  Retrieves the saved state for a MapPool from ETS.

  ## Parameters
  - `uuid` - The unique identifier for the pool

  ## Returns
  - `{:ok, map_ids}` if state exists
  - `{:error, :not_found}` if no state exists for this UUID

  ## Examples

      iex> MapPoolState.get_pool_state("pool-123")
      {:ok, [1, 2, 3]}

      iex> MapPoolState.get_pool_state("non-existent")
      {:error, :not_found}
  """
  @spec get_pool_state(String.t()) :: {:ok, [integer()]} | {:error, :not_found}
  def get_pool_state(uuid) when is_binary(uuid) do
    case :ets.lookup(@table_name, uuid) do
      [{^uuid, map_ids, _timestamp}] ->
        {:ok, map_ids}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Deletes the state for a MapPool from ETS.

  This should be called when a pool is gracefully shut down.

  ## Parameters
  - `uuid` - The unique identifier for the pool

  ## Examples

      iex> MapPoolState.delete_pool_state("pool-123")
      :ok
  """
  @spec delete_pool_state(String.t()) :: :ok
  def delete_pool_state(uuid) when is_binary(uuid) do
    true = :ets.delete(@table_name, uuid)

    Logger.debug("Deleted MapPool state for #{uuid}", pool_uuid: uuid)

    :ok
  end

  @doc """
  Removes stale entries from the ETS table.

  Entries are considered stale if they haven't been updated in the last
  #{@stale_threshold_hours} hours. This helps prevent the table from growing
  unbounded due to pool UUIDs that are no longer in use.

  Returns the number of entries deleted.

  ## Examples

      iex> MapPoolState.cleanup_stale_entries()
      {:ok, 3}
  """
  @spec cleanup_stale_entries() :: {:ok, non_neg_integer()}
  def cleanup_stale_entries do
    stale_threshold = System.system_time(:second) - @stale_threshold_hours * 3600

    match_spec = [
      {
        {:"$1", :"$2", :"$3"},
        [{:<, :"$3", stale_threshold}],
        [:"$1"]
      }
    ]

    stale_uuids = :ets.select(@table_name, match_spec)

    Enum.each(stale_uuids, fn uuid ->
      :ets.delete(@table_name, uuid)

      Logger.info("Cleaned up stale MapPool state for #{uuid}",
        pool_uuid: uuid,
        reason: :stale
      )
    end)

    {:ok, length(stale_uuids)}
  end

  @doc """
  Returns all pool states currently stored in ETS.

  Useful for debugging and monitoring.

  ## Examples

      iex> MapPoolState.list_all_states()
      [
        {"pool-123", [1, 2, 3], 1699564800},
        {"pool-456", [4, 5], 1699564900}
      ]
  """
  @spec list_all_states() :: [{String.t(), [integer()], integer()}]
  def list_all_states do
    :ets.tab2list(@table_name)
  end

  @doc """
  Returns the count of pool states currently stored in ETS.

  ## Examples

      iex> MapPoolState.count_states()
      5
  """
  @spec count_states() :: non_neg_integer()
  def count_states do
    :ets.info(@table_name, :size)
  end
end
