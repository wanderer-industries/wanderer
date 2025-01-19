defmodule WandererApp.Zkb.KillsProvider.KillsCache do
  @moduledoc """
  Provides helper functions for putting/fetching kill data
  in the Nebulex cache, so the calling code doesn't have to worry
  about the exact cache key structure or TTL logic.

  Also handles checks for "recently fetched" systems (timestamp caching).
  """

  alias WandererApp.Cache

  @killmail_ttl :timer.hours(24)
  @system_kills_ttl :timer.hours(1)

  # If we fetched this system within the last 15 min => skip
  @full_fetch_cache_expiry_ms 900_000

  @doc """
  Store the killmail data, keyed by killmail_id, with a 24h TTL.
  """
  def put_killmail(killmail_id, kill_data) do
    Cache.put(killmail_key(killmail_id), kill_data, ttl: @killmail_ttl)
  end

  @doc """
  Fetch kills for `system_id` from the local cache only.
  Returns a list of killmail maps (could be empty).
  """
  def fetch_cached_kills(system_id) do
    system_id
    |> get_system_killmail_ids()
    |> Enum.map(&get_killmail/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Fetch the killmail data (if any) from the cache, by killmail_id.
  """
  def get_killmail(killmail_id) do
    Cache.get(killmail_key(killmail_id))
  end

  @doc """
  Adds `killmail_id` to the list of killmail IDs for the system
  if it’s not already present. The TTL is 24 hours.
  """
  def add_killmail_id_to_system_list(solar_system_id, killmail_id) do
    Cache.update(
      system_kills_list_key(solar_system_id),
      [],
      fn existing_list ->
        existing_list =
          case existing_list do
            nil -> []
            list -> list
          end

        if killmail_id in existing_list do
          existing_list
        else
          existing_list ++ [killmail_id]
        end
      end,
      ttl: @killmail_ttl
    )
  end

  @doc """
  Returns a list of killmail IDs for the given system, or [] if none.
  """
  def get_system_killmail_ids(solar_system_id) do
    Cache.get(system_kills_list_key(solar_system_id)) || []
  end

  @doc """
  Increments the kill count for a system by `amount`. The TTL is 1 hour.
  """
  def incr_system_kill_count(solar_system_id, amount \\ 1) do
    Cache.incr(system_kills_key(solar_system_id), amount,
      default: 0,
      ttl: @system_kills_ttl
    )
  end

  @doc """
  Returns the integer count of kills for this system in the last hour, or 0.
  """
  def get_system_kill_count(solar_system_id) do
    Cache.get(system_kills_key(solar_system_id)) || 0
  end

  @doc """
  Check if the system was fetched within the last 15 minutes.
  """
  def recently_fetched?(system_id) do
    key = fetched_timestamp_key(system_id)

    case Cache.lookup(key) do
      {:ok, ms} when is_integer(ms) ->
        now_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        age = now_ms - ms
        age < @full_fetch_cache_expiry_ms

      _ ->
        false
    end
  end

  @doc """
  Puts a timestamp in the cache for `system_id`, marking it as fully fetched "now."
  """
  def put_full_fetched_timestamp(system_id) do
    now_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    Cache.put(fetched_timestamp_key(system_id), now_ms)
  end

  @doc """
  Returns how many ms ago the system was fetched, or -1 if no record.
  """
  def fetch_age_ms(system_id) do
    case Cache.lookup(fetched_timestamp_key(system_id)) do
      {:ok, ms} when is_integer(ms) ->
        now_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        now_ms - ms

      _ ->
        -1
    end
  end

  defp killmail_key(killmail_id), do: "zkb_killmail_#{killmail_id}"
  defp system_kills_key(solar_system_id), do: "zkb_kills_#{solar_system_id}"
  defp system_kills_list_key(solar_system_id), do: "zkb_kills_list_#{solar_system_id}"

  defp fetched_timestamp_key(system_id), do: "zkb_system_fetched_at_#{system_id}"
end
