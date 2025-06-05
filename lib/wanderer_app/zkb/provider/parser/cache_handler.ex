defmodule WandererApp.Zkb.Provider.Parser.CacheHandler do
  @moduledoc """
  Handles caching operations for killmails:
    - store_killmail/1 inserts the killmail and links it to its system,
      returning `{:ok, km}` or `{:error, :storage_failed}`.
    - update_kill_count/1 increments the kill count only if the kill_time
      is within the cutoff, returning `:ok` or `:skip`.
  """

  require Logger
  alias WandererApp.Zkb.Provider.Cache
  alias WandererApp.Zkb.Provider.Key

  @type killmail :: %{required(String.t()) => any()}
  @type store_result :: {:ok, killmail()} | {:error, :storage_failed}

  # cutoff = one hour ago
  @cutoff_seconds 3600

  @doc """
  Store a killmail in the cache and associate it with its solar system.
  Only `{:error, reason}` from Cache calls will be treated as a failure.
  """
  @spec store_killmail(killmail()) :: store_result()
  def store_killmail(%{"killmail_id" => id, "solar_system_id" => sys_id} = km) do
    try do
      case Cache.put_killmail(id, km) do
        :ok ->
          case Cache.add_killmail_id_to_system_list(sys_id, id) do
            :ok ->
              {:ok, km}
            {:error, reason2} ->
              # Rollback: Remove the killmail if adding to system list fails
              Cache.delete(Key.killmail_key(id))
              Logger.error(
                "[CacheHandler] add_killmail_id_to_system_list failed for system #{sys_id}: " <>
                  "#{inspect(reason2)}"
              )
              {:error, :storage_failed}
          end

        {:error, reason} ->
          Logger.error("[CacheHandler] put_killmail failed for ##{id}: #{inspect(reason)}")
          {:error, :storage_failed}
      end
    rescue
      unexpected ->
        Logger.error(
          "[CacheHandler] unexpected exception caching ##{id}: #{inspect(unexpected)}"
        )
        {:error, :storage_failed}
    end
  end

  def store_killmail(invalid) do
    Logger.error("[CacheHandler] invalid payload: #{inspect(invalid)}")
    {:error, :storage_failed}
  end

  @doc """
  Increment the kill count for this system if the kill_time is within the last hour.
  """
  @spec update_kill_count(killmail()) :: :ok | :skip
  def update_kill_count(%{"kill_time" => %DateTime{} = ts, "solar_system_id" => sys_id}) do
    if DateTime.compare(ts, cutoff()) == :gt do
      Cache.increment_kill_count(sys_id)
      :ok
    else
      :skip
    end
  end

  def update_kill_count(_), do: :skip

  #-------------------------------------------------------------------------------
  # Private helpers
  #-------------------------------------------------------------------------------
  defp cutoff do
    DateTime.utc_now()
    |> DateTime.add(-@cutoff_seconds, :second)
  end
end
