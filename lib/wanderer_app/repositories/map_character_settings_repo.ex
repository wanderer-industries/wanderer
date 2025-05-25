defmodule WandererApp.MapCharacterSettingsRepo do
  use WandererApp, :repository

  def create(settings) do
    WandererApp.Api.MapCharacterSettings.create(settings)
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

  def get_by_map(map_id, character_id) do
    case get_by_map_filtered(map_id, [character_id]) do
      {:ok, [setting | _]} ->
        {:ok, setting}

      {:ok, []} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def track(settings) do
    # Only update the tracked field, preserving other fields
    WandererApp.Api.MapCharacterSettings.track(%{
      map_id: settings.map_id,
      character_id: settings.character_id
    })
  end

  def untrack(settings) do
    # Only update the tracked field, preserving other fields
    WandererApp.Api.MapCharacterSettings.untrack(%{
      map_id: settings.map_id,
      character_id: settings.character_id
    })
  end

  def track!(settings),
    do:
      WandererApp.Api.MapCharacterSettings.track!(%{
        map_id: settings.map_id,
        character_id: settings.character_id
      })

  def untrack!(settings),
    do:
      WandererApp.Api.MapCharacterSettings.untrack!(%{
        map_id: settings.map_id,
        character_id: settings.character_id
      })

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

  def follow!(settings),
    do:
      WandererApp.Api.MapCharacterSettings.follow!(%{
        map_id: settings.map_id,
        character_id: settings.character_id
      })

  def unfollow!(settings),
    do:
      WandererApp.Api.MapCharacterSettings.unfollow!(%{
        map_id: settings.map_id,
        character_id: settings.character_id
      })

  def destroy!(settings), do: settings |> WandererApp.Api.MapCharacterSettings.destroy!()
end
