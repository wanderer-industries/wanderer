defmodule WandererApp.Kills.CacheKeys do
  @moduledoc """
  Centralized cache key generation for the kills subsystem.

  Provides consistent key generation for all kill-related cache entries
  to avoid duplication and ensure consistency across the codebase.
  """

  @doc """
  Generates cache key for system kill count.

  ## Examples

      iex> WandererApp.Kills.CacheKeys.system_kill_count(30000142)
      "zkb:kills:30000142"
  """
  @spec system_kill_count(integer()) :: String.t()
  def system_kill_count(system_id) when is_integer(system_id) do
    "zkb:kills:#{system_id}"
  end

  @doc """
  Generates cache key for individual killmail.

  ## Examples

      iex> WandererApp.Kills.CacheKeys.killmail(123456789)
      "zkb:killmail:123456789"
  """
  @spec killmail(integer()) :: String.t()
  def killmail(killmail_id) when is_integer(killmail_id) do
    "zkb:killmail:#{killmail_id}"
  end

  @doc """
  Generates cache key for system kill list (list of killmail IDs).

  ## Examples

      iex> WandererApp.Kills.CacheKeys.system_kill_list(30000142)
      "zkb:kills:list:30000142"
  """
  @spec system_kill_list(integer()) :: String.t()
  def system_kill_list(system_id) when is_integer(system_id) do
    "zkb:kills:list:#{system_id}"
  end

  @doc """
  Generates cache key for map kill counts.

  ## Examples

      iex> WandererApp.Kills.CacheKeys.map_kill_counts("map123")
      "map:map123:zkb:kills"
  """
  @spec map_kill_counts(String.t()) :: String.t()
  def map_kill_counts(map_id) when is_binary(map_id) do
    "map:#{map_id}:zkb:kills"
  end

  @doc """
  Generates cache key for map killmail IDs.

  ## Examples

      iex> WandererApp.Kills.CacheKeys.map_killmail_ids("map123")
      "map:map123:zkb:ids"
  """
  @spec map_killmail_ids(String.t()) :: String.t()
  def map_killmail_ids(map_id) when is_binary(map_id) do
    "map:#{map_id}:zkb:ids"
  end

  @doc """
  Generates cache key for map detailed kills.

  ## Examples

      iex> WandererApp.Kills.CacheKeys.map_detailed_kills("map123")
      "map:map123:zkb:detailed_kills"
  """
  @spec map_detailed_kills(String.t()) :: String.t()
  def map_detailed_kills(map_id) when is_binary(map_id) do
    "map:#{map_id}:zkb:detailed_kills"
  end
end
