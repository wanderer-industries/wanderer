defmodule WandererApp.MapCharacterSettingsRepo do
  use WandererApp, :repository

  def create(settings),
    do: WandererApp.Api.MapCharacterSettings.create(settings)

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

  def track(settings), do: settings |> WandererApp.Api.MapCharacterSettings.track()
  def untrack(settings), do: settings |> WandererApp.Api.MapCharacterSettings.untrack()

  def track!(settings), do: settings |> WandererApp.Api.MapCharacterSettings.track!()
  def untrack!(settings), do: settings |> WandererApp.Api.MapCharacterSettings.untrack!()

  def follow(settings), do: settings |> WandererApp.Api.MapCharacterSettings.follow()
  def unfollow(settings), do: settings |> WandererApp.Api.MapCharacterSettings.unfollow()

  def follow!(settings), do: settings |> WandererApp.Api.MapCharacterSettings.follow!()
  def unfollow!(settings), do: settings |> WandererApp.Api.MapCharacterSettings.unfollow!()


  def destroy!(settings), do: settings |> WandererApp.Api.MapCharacterSettings.destroy!()
end
