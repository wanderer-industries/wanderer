defmodule WandererApp.Kills.CacheKeys do
  @moduledoc """
  Provides consistent cache key generation for the kills system.
  """

  @doc """
  Generate cache key for system kill count.
  """
  @spec system_kill_count(integer()) :: String.t()
  def system_kill_count(system_id) do
    "zkb:kills:#{system_id}"
  end

  @doc """
  Generate cache key for system kill list.
  """
  @spec system_kill_list(integer()) :: String.t()
  def system_kill_list(system_id) do
    "zkb:kills:list:#{system_id}"
  end

  @doc """
  Generate cache key for individual killmail.
  """
  @spec killmail(integer()) :: String.t()
  def killmail(killmail_id) do
    "zkb:killmail:#{killmail_id}"
  end

  @doc """
  Generate cache key for kill count metadata.
  """
  @spec kill_count_metadata(integer()) :: String.t()
  def kill_count_metadata(system_id) do
    "zkb:kills:metadata:#{system_id}"
  end
end
