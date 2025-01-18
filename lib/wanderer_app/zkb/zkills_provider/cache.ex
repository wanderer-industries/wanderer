defmodule WandererApp.Zkb.KillsProvider.KillsCache do
  @moduledoc """
  Provides helper functions for putting/fetching kill data
  in the Nebulex cache, so the calling code doesn't have to worry
  about the exact cache key structure or TTL logic.
  """

  alias WandererApp.Cache

  @killmail_ttl :timer.hours(24)
  @system_kills_ttl :timer.hours(1)

  @doc """
  Store the killmail data, keyed by killmail_id, with a 24h TTL.
  """
  def put_killmail(killmail_id, kill_data) do
    Cache.put(killmail_key(killmail_id), kill_data, ttl: @killmail_ttl)
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
  Fetch the killmail data (if any) from the cache, by killmail_id.
  """
  def get_killmail(killmail_id) do
    Cache.get(killmail_key(killmail_id))
  end

  @doc """
  Returns a list of killmail IDs for the given system, or [] if none.
  """
  def get_system_killmail_ids(solar_system_id) do
    Cache.get(system_kills_list_key(solar_system_id)) || []
  end

  @doc """
  Returns the integer count of kills for this system in the last hour, or 0.
  """
  def get_system_kill_count(solar_system_id) do
    Cache.get(system_kills_key(solar_system_id)) || 0
  end

  defp killmail_key(killmail_id), do: "zkb_killmail_#{killmail_id}"
  defp system_kills_key(solar_system_id), do: "zkb_kills_#{solar_system_id}"
  defp system_kills_list_key(solar_system_id), do: "zkb_kills_list_#{solar_system_id}"
end
