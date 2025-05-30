defmodule WandererApp.Zkb.Provider.Api do
  @moduledoc """
  High-level interface for interacting with zKillboard API and caching results.
  """

  require Logger
  alias WandererApp.Zkb.Provider.{HttpClient, Cache}
  alias WandererApp.Zkb.Provider.Key

  @kill_count_ttl 300

  @doc """
  Fetches a killmail by its ID.

  Delegates to HttpClient; returns `{:ok, killmail}` or `{:error, reason}`.
  """
  @spec get_killmail(integer()) :: {:ok, map()} | {:error, term()}
  defdelegate get_killmail(killmail_id), to: HttpClient, as: :get_killmail

  @doc """
  Fetches all killmails for a system.

  Delegates to HttpClient; returns `{:ok, list_of_killmails}` or `{:error, reason}`.
  """
  @spec get_system_killmails(integer()) :: {:ok, [map()]} | {:error, term()}
  defdelegate get_system_killmails(system_id), to: HttpClient, as: :get_system_killmails

  @doc """
  Alias for `get_system_killmails/1` retained for backwards compatibility.
  """
  @spec get_kills_for_system(integer()) :: {:ok, [map()]} | {:error, term()}
  defdelegate get_kills_for_system(system_id), to: HttpClient, as: :get_system_killmails

  @doc """
  Retrieves the cached kill count for a system, or fetches and caches it if missing.

  Returns `{:ok, count}` or `{:error, reason}`.
  """
  @spec get_kill_count(integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_kill_count(system_id) when is_integer(system_id) do
    key = Key.kill_count_key(system_id)

    case Cache.get(key) do
      {:ok, count} when is_integer(count) ->
        {:ok, count}

      {:ok, _} ->
        fetch_and_cache_count(key, system_id)

      {:error, reason} ->
        log_cache_error(reason)
        {:error, reason}
    end
  end

  def get_kill_count(system_id) do
    Logger.warning("[ZkbProvider.Api] Invalid system_id type: #{inspect(system_id)}")
    {:error, :invalid_system_id}
  end

  defp log_cache_error(reason) do
    Logger.error("[ZkbProvider.Api] Cache error: #{inspect(reason)}")
  end

  defp fetch_and_cache_count(key, system_id) do
    case get_system_killmails(system_id) do
      {:ok, killmails} ->
        count = length(killmails)
        case Cache.set(key, count, @kill_count_ttl) do
          :ok ->
            {:ok, count}
          {:error, reason} ->
            Logger.warning("[ZkbProvider.Api] Failed to cache kill count for system #{system_id}: #{inspect(reason)}")
            {:ok, count}  # Still return the count even if caching failed
        end

      {:error, reason} ->
        Logger.error("[ZkbProvider.Api] Failed to fetch killmails for system #{system_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
