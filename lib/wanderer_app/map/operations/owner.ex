defmodule WandererApp.Map.Operations.Owner do
  @moduledoc """
  Handles fetching and caching of the main character info for a map owner.
  """

  # Cache TTL in milliseconds (24 hours)
  @owner_info_cache_ttl 86_400_000

  alias WandererApp.{
    MapRepo,
    MapCharacterSettingsRepo,
    MapUserSettingsRepo,
    Cache
  }

  alias WandererApp.Character
  alias WandererApp.Character.TrackingUtils

  @spec get_owner_character_id(String.t()) ::
          {:ok, %{id: term(), user_id: term()}} | {:error, String.t()}
  def get_owner_character_id(map_id) when is_binary(map_id) do
    cache_key = "map_#{map_id}:owner_info"

    case Cache.lookup!(cache_key) do
      nil ->
        with {:ok, owner} <- fetch_map_owner(map_id),
             {:ok, char_ids} <- fetch_character_ids(map_id),
             {:ok, characters} <- load_characters(char_ids),
             {:ok, user_settings} <- MapUserSettingsRepo.get(map_id, owner.id),
             {:ok, main} <-
               TrackingUtils.get_main_character(user_settings, characters, characters) do
          result = %{id: main.id, user_id: main.user_id}
          Cache.insert(cache_key, result, ttl: @owner_info_cache_ttl)
          {:ok, result}
        else
          {:error, msg} -> {:error, msg}
          _ -> {:error, "Failed to resolve main character"}
        end

      cached ->
        {:ok, cached}
    end
  end

  def get_owner_character_id(_map_id) do
    {:error, "Invalid map_id: must be a string"}
  end

  defp fetch_map_owner(map_id) do
    case MapRepo.get(map_id, [:owner]) do
      {:ok, %{owner: %_{} = owner}} -> {:ok, owner}
      {:ok, %{owner: nil}} -> {:error, "Map has no owner"}
      {:error, _} -> {:error, "Map not found"}
    end
  end

  defp fetch_character_ids(map_id) do
    case MapCharacterSettingsRepo.get_all_by_map(map_id) do
      {:ok, settings} when is_list(settings) and settings != [] ->
        {:ok, Enum.map(settings, & &1.character_id)}

      {:ok, []} ->
        {:error, "No character settings found"}

      {:error, _} ->
        {:error, "Failed to fetch character settings"}
    end
  end

  defp load_characters(ids) when is_list(ids) do
    ids
    |> Enum.map(&Character.get_character/1)
    |> Enum.flat_map(fn
      {:ok, ch} -> [ch]
      _ -> []
    end)
    |> case do
      [] -> {:error, "No valid characters found"}
      chars -> {:ok, chars}
    end
  end
end
