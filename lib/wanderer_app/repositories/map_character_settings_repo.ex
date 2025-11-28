defmodule WandererApp.MapCharacterSettingsRepo do
  use WandererApp, :repository

  require Logger

  def get(map_id, character_id) do
    case WandererApp.Api.MapCharacterSettings.read_by_map_and_character(%{
           map_id: map_id,
           character_id: character_id
         }) do
      {:ok, settings} when not is_nil(settings) ->
        {:ok, settings}

      _ ->
        WandererApp.Api.MapCharacterSettings.create(%{
          character_id: character_id,
          map_id: map_id,
          tracked: false
        })
    end
  end

  def create(settings) do
    WandererApp.Api.MapCharacterSettings.create(settings)
  end

  def update(map_id, character_id, updated_settings) do
    case get(map_id, character_id) do
      {:ok, settings} when not is_nil(settings) ->
        settings
        |> WandererApp.Api.MapCharacterSettings.update(updated_settings)

      _ ->
        {:ok, nil}
    end
  end

  def get_tracked_by_map_filtered(map_id, character_ids),
    do:
      WandererApp.Api.MapCharacterSettings.tracked_by_map_filtered(%{
        map_id: map_id,
        character_ids: character_ids
      })

  def get_by_map_filtered(map_id, character_ids),
    do:
      WandererApp.Api.MapCharacterSettings.by_map_filtered(%{
        map_id: map_id,
        character_ids: character_ids
      })

  def get_all_by_map(map_id),
    do: WandererApp.Api.MapCharacterSettings.read_by_map(%{map_id: map_id})

  def get_tracked_by_map_all(map_id),
    do: WandererApp.Api.MapCharacterSettings.tracked_by_map_all(%{map_id: map_id})

  def track(%{map_id: map_id, character_id: character_id}) do
    # First ensure the record exists (get creates if not exists)
    case get(map_id, character_id) do
      {:ok, settings} when not is_nil(settings) ->
        # Now update the tracked field
        settings
        |> WandererApp.Api.MapCharacterSettings.update(%{tracked: true})

      error ->
        Logger.error(
          "Failed to track character: #{character_id} on map: #{map_id}, #{inspect(error)}"
        )

        {:error, error}
    end
  end

  def untrack(%{map_id: map_id, character_id: character_id}) do
    # First ensure the record exists (get creates if not exists)
    case get(map_id, character_id) do
      {:ok, settings} when not is_nil(settings) ->
        # Now update the tracked field
        settings
        |> WandererApp.Api.MapCharacterSettings.update(%{tracked: false})

      error ->
        Logger.error(
          "Failed to untrack character: #{character_id} on map: #{map_id}, #{inspect(error)}"
        )

        {:error, error}
    end
  end

  def track!(settings) do
    case track(settings) do
      {:ok, result} -> result
      error -> raise "Failed to track: #{inspect(error)}"
    end
  end

  def untrack!(settings) do
    case untrack(settings) do
      {:ok, result} -> result
      error -> raise "Failed to untrack: #{inspect(error)}"
    end
  end

  def follow(%{map_id: map_id, character_id: character_id} = _settings) do
    # First ensure the record exists (get creates if not exists)
    case get(map_id, character_id) do
      {:ok, settings} when not is_nil(settings) ->
        settings
        |> WandererApp.Api.MapCharacterSettings.update(%{followed: true})

      error ->
        Logger.error(
          "Failed to follow character: #{character_id} on map: #{map_id}, #{inspect(error)}"
        )

        {:error, error}
    end
  end

  def unfollow(%{map_id: map_id, character_id: character_id} = _settings) do
    # First ensure the record exists (get creates if not exists)
    case get(map_id, character_id) do
      {:ok, settings} when not is_nil(settings) ->
        settings
        |> WandererApp.Api.MapCharacterSettings.update(%{followed: false})

      error ->
        Logger.error(
          "Failed to unfollow character: #{character_id} on map: #{map_id}, #{inspect(error)}"
        )

        {:error, error}
    end
  end

  def follow!(settings) do
    case follow(settings) do
      {:ok, result} -> result
      error -> raise "Failed to follow: #{inspect(error)}"
    end
  end

  def unfollow!(settings) do
    case unfollow(settings) do
      {:ok, result} -> result
      error -> raise "Failed to unfollow: #{inspect(error)}"
    end
  end

  def destroy!(settings) do
    case Ash.destroy(settings) do
      :ok -> settings
      {:error, error} -> raise "Failed to destroy: #{inspect(error)}"
    end
  end
end
