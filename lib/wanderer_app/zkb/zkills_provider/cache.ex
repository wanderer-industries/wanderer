defmodule WandererApp.Zkb.KillsProvider.KillsCache do
  @moduledoc """
  Provides helper functions for putting/fetching kill data
  """

  require Logger
  alias WandererApp.Cache

  @killmail_ttl :timer.hours(24)
  @system_kills_ttl :timer.hours(1)

  # Base (average) expiry of 15 minutes for "recently fetched" systems
  @base_full_fetch_expiry_ms 900_000
  @jitter_percent 0.1

  def killmail_ttl, do: @killmail_ttl
  def system_kills_ttl, do: @system_kills_ttl

  @doc """
  Store the killmail data, keyed by killmail_id, with a 24h TTL.
  """
  def put_killmail(killmail_id, kill_data) do
    Logger.debug("[KillsCache] Storing killmail => killmail_id=#{killmail_id}")
    Cache.put(killmail_key(killmail_id), kill_data, ttl: @killmail_ttl)
  end

  @doc """
  Fetch kills for `system_id` from the local cache only.
  Returns a list of killmail maps (could be empty).
  """
  def fetch_cached_kills(system_id) do
    killmail_ids = get_system_killmail_ids(system_id)
    # Debug-level log for performance checks
    Logger.debug("[KillsCache] fetch_cached_kills => system_id=#{system_id}, count=#{length(killmail_ids)}")

    killmail_ids
    |> Enum.map(&get_killmail/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Fetch cached kills for multiple solar system IDs.
  Returns a map of `%{ solar_system_id => list_of_kills }`.
  """
  def fetch_cached_kills_for_systems(system_ids) when is_list(system_ids) do
    Enum.reduce(system_ids, %{}, fn sid, acc ->
      kills_list = fetch_cached_kills(sid)
      Map.put(acc, sid, kills_list)
    end)
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
        existing_list = existing_list || []
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
    Cache.incr(
      system_kills_key(solar_system_id),
      amount,
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
  Check if the system is still in its "recently fetched" window.
  We store an `expires_at` timestamp (in ms). If `now < expires_at`,
  this system is still considered "recently fetched".
  """
  def recently_fetched?(system_id) do
    case Cache.lookup(fetched_timestamp_key(system_id)) do
      {:ok, expires_at_ms} when is_integer(expires_at_ms) ->
        now_ms = current_time_ms()
        now_ms < expires_at_ms

      _ ->
        false
    end
  end

  @doc """
  Puts a jittered `expires_at` in the cache for `system_id`,
  marking it as fully fetched for ~15 minutes (+/- 10%).
  """
  def put_full_fetched_timestamp(system_id) do
    now_ms = current_time_ms()
    max_jitter = round(@base_full_fetch_expiry_ms * @jitter_percent)
    # random offset in range [-max_jitter..+max_jitter]
    offset = :rand.uniform(2 * max_jitter + 1) - (max_jitter + 1)
    final_expiry_ms = max(@base_full_fetch_expiry_ms + offset, 60_000)
    expires_at_ms = now_ms + final_expiry_ms

    Logger.debug("[KillsCache] Marking system=#{system_id} recently_fetched? until #{expires_at_ms} (ms)")
    Cache.put(fetched_timestamp_key(system_id), expires_at_ms)
  end

  @doc """
  Returns how many ms remain until this system's "recently fetched" window ends.
  If it's already expired (or doesn't exist), returns -1.
  """
  def fetch_age_ms(system_id) do
    now_ms = current_time_ms()

    case Cache.lookup(fetched_timestamp_key(system_id)) do
      {:ok, expires_at_ms} when is_integer(expires_at_ms) ->
        if now_ms < expires_at_ms do
          expires_at_ms - now_ms
        else
          -1
        end

      _ ->
        -1
    end
  end

  defp killmail_key(killmail_id), do: "zkb_killmail_#{killmail_id}"
  defp system_kills_key(solar_system_id), do: "zkb_kills_#{solar_system_id}"
  defp system_kills_list_key(solar_system_id), do: "zkb_kills_list_#{solar_system_id}"
  defp fetched_timestamp_key(system_id), do: "zkb_system_fetched_at_#{system_id}"

  defp current_time_ms() do
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end
end
