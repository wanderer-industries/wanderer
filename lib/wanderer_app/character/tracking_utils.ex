defmodule WandererApp.Character.TrackingUtils do
  @moduledoc """
  Utility functions for handling character tracking and following operations.

  """

  require Logger
  alias WandererApp.MapCharacterSettingsRepo

  @doc """
  Toggles the tracking state for a character on a map.
  Returns the updated tracking data for all characters with access to the map.
  """
  def toggle_track(map_id, character_id, current_user_id, caller_pid \\ nil) do
    with current_user when not is_nil(current_user) <- WandererApp.User.load(current_user_id),
         {:ok, character} <- WandererApp.Character.find_character_by_eve_id(current_user, character_id),
         {:ok, map} <- WandererApp.Api.Map.by_id(map_id),
         map <- Ash.load!(map, :acls),
         {:ok, _updated_settings} <- do_toggle_character_tracking(character, map_id, caller_pid) do

      # Get updated tracking data
      build_tracking_data(map_id, current_user_id)
    else
      nil ->
        Logger.error("User not found when toggling track")
        {:error, "User not found"}
      error ->
        Logger.error("Failed to toggle track: #{inspect(error)}")
        {:error, "Failed to toggle track"}
    end
  end

  @doc """
  Toggles the follow state for a character on a map.
  Returns the updated tracking data for all characters with access to the map.
  """
  def toggle_follow(map_id, character_id, current_user_id, caller_pid \\ nil) do
    # Get all settings before the operation to see the followed state
    {:ok, all_settings_before} = MapCharacterSettingsRepo.get_all_by_map(map_id)
    followed_before = all_settings_before |> Enum.find(& &1.followed)

    # Check if the clicked character is already followed
    is_already_followed =
      followed_before && "#{followed_before.character_id}" == "#{character_id}"

    with current_user when not is_nil(current_user) <- WandererApp.User.load(current_user_id),
         {:ok, clicked_char} <- WandererApp.Character.find_character_by_eve_id(current_user, character_id),
         {:ok, _updated_settings} <- do_toggle_character_follow(map_id, clicked_char, is_already_followed, caller_pid) do

      # Get updated tracking data
      build_tracking_data(map_id, current_user_id)
    else
      nil ->
        Logger.error("User not found when toggling follow")
        {:error, "User not found"}
      error ->
        Logger.error("Failed to toggle follow: #{inspect(error)}")
        {:error, "Failed to toggle follow"}
    end
  end

  @doc """
  Builds tracking data for all characters with access to a map.
  """
  def build_tracking_data(map_id, current_user_id) do
    with current_user when not is_nil(current_user) <- WandererApp.User.load(current_user_id),
         {:ok, map} <- WandererApp.Api.Map.by_id(map_id),
         map <- Ash.load!(map, :acls),
         {:ok, character_settings} <- MapCharacterSettingsRepo.get_all_by_map(map_id),
         {:ok, %{characters: characters_with_access}} <-
           WandererApp.Maps.load_characters(map, character_settings, current_user.id) do

      tracking_data =
        Enum.map(characters_with_access, fn char ->
          setting = Enum.find(character_settings, &(&1.character_id == char.id))
          tracked = if setting, do: setting.tracked, else: false
          # Preserve the followed state
          followed = if setting, do: setting.followed, else: false

          %{
            character: char |> WandererAppWeb.MapEventHandler.map_ui_character_stat(),
            tracked: tracked,
            followed: followed
          }
        end)

      # Check for inconsistent state - a character that's followed but not tracked
      followed_in_data = Enum.find(tracking_data, &(&1.followed))
      followed_but_not_tracked = followed_in_data && !Enum.find(tracking_data, &(&1.followed && &1.tracked))

      # If we have a character that's followed but not tracked, that's an inconsistent state
      if followed_but_not_tracked do
        Logger.warning("Inconsistent state detected: Character is followed but not tracked", %{
          character_id: followed_in_data.character.eve_id
        })
      end

      {:ok, tracking_data}
    else
      nil ->
        Logger.warning("User not found when building tracking data", %{user_id: current_user_id})
        {:error, "User not found"}

      error ->
        Logger.error("Error building tracking data: #{inspect(error)}")
        {:error, "Failed to build tracking data"}
    end
  end

  # Private implementation of toggle character tracking
  defp do_toggle_character_tracking(character, map_id, caller_pid) do
    if is_nil(caller_pid) do
      Logger.error("caller_pid is required for toggling character tracking")
      {:error, "caller_pid is required"}
    else
      case MapCharacterSettingsRepo.get_by_map(map_id, character.id) do
        {:ok, existing_settings} ->
          if existing_settings.tracked do
            # If the character was followed, we should also unfollow it
            {:ok, updated_settings} =
              if existing_settings.followed do
                # First unfollow
                {:ok, unfollowed_settings} = MapCharacterSettingsRepo.unfollow(existing_settings)

                # Then untrack
                MapCharacterSettingsRepo.untrack(unfollowed_settings)
              else
                # Just untrack
                MapCharacterSettingsRepo.untrack(existing_settings)
              end

            case untrack_characters([character], map_id, caller_pid) do
              :ok ->
                :ok = remove_characters([character], map_id)
                {:ok, updated_settings}
              error ->
                error
            end
          else
            {:ok, updated_settings} =
              MapCharacterSettingsRepo.track(existing_settings)

            case track_characters([character], map_id, true, caller_pid) do
              :ok ->
                :ok = add_characters([character], map_id, true)
                {:ok, updated_settings}
              error ->
                error
            end
          end

        {:error, :not_found} ->
          # Create new settings with tracking enabled
          create_character_settings(character.id, map_id, true, false, caller_pid)
      end
    end
  end

  # Private implementation of toggle character follow
  defp do_toggle_character_follow(map_id, clicked_char, is_already_followed, caller_pid) do
    if is_nil(caller_pid) do
      Logger.error("caller_pid is required for toggling character following")
      {:error, "caller_pid is required"}
    else
      with {:ok, clicked_char_settings} <-
             MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id) do
        if is_already_followed do
          # If the character is not tracked remove it from the map
          if !clicked_char_settings.tracked do
            # First unfollow
            {:ok, _} = MapCharacterSettingsRepo.unfollow(clicked_char_settings)

            # Then remove from the map
            :ok = remove_characters([clicked_char], map_id)
          else
            # Just unfollow
            MapCharacterSettingsRepo.unfollow(clicked_char_settings)
          end
        else
          # Normal follow toggle - ensure character is tracked when followed
          ensure_character_tracked_and_followed(map_id, clicked_char, clicked_char_settings, caller_pid)
        end
      else
        {:error, :not_found} ->
          # Create new settings with both tracking and following enabled
          create_character_settings(clicked_char.id, map_id, true, true, caller_pid, clicked_char)
      end
    end
  end

  # Consolidated helper function to ensure a character is tracked when followed
  defp ensure_character_tracked_and_followed(map_id, character, settings, caller_pid) do
    if is_nil(caller_pid) do
      Logger.error("caller_pid is required for ensuring character is tracked and followed")
      {:error, "caller_pid is required"}
    else
      # Toggle the followed state
      followed = !settings.followed

      # Only unfollow other characters if we're explicitly following this character
      if followed do
        # We're following this character, so unfollow all others
        :ok = maybe_unfollow_others(map_id, character.id, followed)
      end

      # If we're following, make sure the character is also tracked
      if followed && !settings.tracked do
        # First track the character
        {:ok, tracked_settings} = MapCharacterSettingsRepo.track(settings)

        # Then update the follow status
        {:ok, updated_settings} = update_follow(tracked_settings, followed)

        # Make sure the character is properly tracked in the system
        case track_characters([character], map_id, true, caller_pid) do
          :ok ->
            :ok = add_characters([character], map_id, true)
            {:ok, updated_settings}
          error ->
            error
        end
      else
        # Just update the follow status without changing tracking
        {:ok, updated_settings} = update_follow(settings, followed)
        {:ok, updated_settings}
      end
    end
  end

  # Helper function to create character settings with specified tracking and following states
  defp create_character_settings(character_id, map_id, tracked, followed, caller_pid, character \\ nil) do
    if is_nil(caller_pid) do
      Logger.error("caller_pid is required for creating character settings")
      {:error, "caller_pid is required"}
    else
      # If we're following this character, unfollow all others first
      if followed do
        :ok = maybe_unfollow_others(map_id, character_id, true)
      end

      # Create the settings
      result = MapCharacterSettingsRepo.create(%{
        character_id: character_id,
        map_id: map_id,
        tracked: tracked,
        followed: followed
      })

      # If character is provided and tracking is enabled, ensure it's tracked in the system
      if character && tracked do
        case track_characters([character], map_id, true, caller_pid) do
          :ok ->
            :ok = add_characters([character], map_id, true)
            result
          error ->
            error
        end
      else
        result
      end
    end
  end

  defp maybe_unfollow_others(_map_id, _char_id, false), do: :ok

  defp maybe_unfollow_others(map_id, char_id, true) do
    # unfollow all other characters when setting a character as followed.

    {:ok, all_settings} = MapCharacterSettingsRepo.get_all_by_map(map_id)

    followed_characters = all_settings
      |> Enum.filter(&(&1.character_id != char_id && &1.followed))

    # Unfollow other characters
    followed_characters
    |> Enum.each(fn setting ->
      MapCharacterSettingsRepo.unfollow(setting)
    end)

    :ok
  end

  defp update_follow(settings, true), do: MapCharacterSettingsRepo.follow(settings)
  defp update_follow(settings, false), do: MapCharacterSettingsRepo.unfollow(settings)

  # Helper functions for character tracking
  def track_characters(_, _, false, _), do: :ok
  def track_characters([], _map_id, _is_track_character?, _), do: :ok
  def track_characters([character | characters], map_id, true, caller_pid) do
    case track_character(character, map_id, caller_pid) do
      :ok ->
        track_characters(characters, map_id, true, caller_pid)
      error ->
        error
    end
  end

  def track_character(%{id: character_id, eve_id: eve_id, corporation_id: corporation_id, alliance_id: alliance_id}, map_id, caller_pid) do
    # Require caller_pid to be provided
    if is_nil(caller_pid) do
      Logger.error("caller_pid is required for tracking characters")
      {:error, "caller_pid is required"}
    else
      WandererAppWeb.Presence.track(caller_pid, map_id, character_id, %{})

      cache_key = "#{inspect(caller_pid)}_map_#{map_id}:character_#{character_id}:tracked"

      case WandererApp.Cache.lookup!(cache_key, false) do
        true ->
          :ok
        _ ->
          :ok = Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{eve_id}")
          :ok = WandererApp.Cache.put(cache_key, true)
      end

      :ok = WandererApp.Character.TrackerManager.start_tracking(character_id)
    end
  end

  def untrack_characters(characters, map_id, caller_pid) do
    # Require caller_pid to be provided
    if is_nil(caller_pid) do
      Logger.error("caller_pid is required for untracking characters")
      {:error, "caller_pid is required"}
    else
      characters
      |> Enum.each(fn character ->
        WandererAppWeb.Presence.untrack(caller_pid, map_id, character.id)
        WandererApp.Cache.put("#{inspect(caller_pid)}_map_#{map_id}:character_#{character.id}:tracked", false)
        :ok = Phoenix.PubSub.unsubscribe(WandererApp.PubSub, "character:#{character.eve_id}")
      end)
    end
  end

  def add_characters([], _map_id, _track_character), do: :ok
  def add_characters([character | characters], map_id, track_character) do
    map_id
    |> WandererApp.Map.Server.add_character(character, track_character)
    add_characters(characters, map_id, track_character)
  end

  def remove_characters([], _map_id), do: :ok
  def remove_characters([character | characters], map_id) do
    map_id
    |> WandererApp.Map.Server.remove_character(character.id)
    remove_characters(characters, map_id)
  end
end
