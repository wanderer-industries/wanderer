defmodule WandererApp.MapCharacterSettingsRepo do
  use WandererApp, :repository

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

  def track(settings) do
    {:ok, _} = get(settings.map_id, settings.character_id)
    # Only update the tracked field, preserving other fields
    WandererApp.Api.MapCharacterSettings.track(%{
      map_id: settings.map_id,
      character_id: settings.character_id
    })
  end

  def untrack(settings) do
    {:ok, _} = get(settings.map_id, settings.character_id)
    # Only update the tracked field, preserving other fields
    WandererApp.Api.MapCharacterSettings.untrack(%{
      map_id: settings.map_id,
      character_id: settings.character_id
    })
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

  def follow(settings) do
    WandererApp.Api.MapCharacterSettings.follow(%{
      map_id: settings.map_id,
      character_id: settings.character_id
    })
  end

  def unfollow(settings) do
    WandererApp.Api.MapCharacterSettings.unfollow(%{
      map_id: settings.map_id,
      character_id: settings.character_id
    })
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
