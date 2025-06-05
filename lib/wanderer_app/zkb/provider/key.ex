defmodule WandererApp.Zkb.Provider.Key do
  @moduledoc """
  Helper for generating cache keys for zKillboard data.
  """

  @doc """
  Generates a cache key for a killmail.
  """
  def killmail_key(kill_id) do
    "zkb_killmail_#{kill_id}"
  end

  @doc """
  Generates a cache key for a system's kill count.
  """
  def kill_count_key(system_id) do
    "zkb_kill_count_#{system_id}"
  end

  @doc """
  Generates a cache key for a system's killmail ID list.
  """
  def system_kills_list_key(system_id) do
    "zkb_system_kills_list_#{system_id}"
  end

  @doc """
  Generates a cache key for a system's fetched timestamp.
  """
  def fetched_timestamp_key(system_id) do
    "zkb_fetched_timestamp_#{system_id}"
  end

  @doc """
  Returns the current time in milliseconds since the Unix epoch.
  """
  def current_time_ms do
    System.system_time(:millisecond)
  end
end
