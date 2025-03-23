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
  def toggle_track(map_id, character_id, current_user_id, caller_pid \\ nil, only_tracked_characters \\ false) do
    with current_user when not is_nil(current_user) <- WandererApp.User.load(current_user_id),
         {:ok, character} <- WandererApp.Character.find_character_by_eve_id(current_user, character_id),
         {:ok, map} <- WandererApp.Api.Map.by_id(map_id),
         map <- Ash.load!(map, :acls) do

      # Check if the character is currently tracked before toggling
      {:ok, existing_settings} = MapCharacterSettingsRepo.get_by_map(map_id, character.id)
      was_tracked = existing_settings && existing_settings.tracked

      # Toggle the tracking state
      with {:ok, _updated_settings} <- do_toggle_character_tracking(character, map_id, caller_pid) do
        # Get updated tracking data
        {:ok, tracking_data} = build_tracking_data(map_id, current_user_id)

        # Broadcast tracking update to any LiveView pages
        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "character_tracking",
          {:character_tracking_updated, map_id}
        )

        # Determine which event to send based on tracking mode and previous state
        event = case {only_tracked_characters, was_tracked} do
          {true, true} -> :not_all_characters_tracked  # Untracking in tracked-only mode
          _            -> %{event: :refresh_user_characters}  # All other cases
        end

        {:ok, tracking_data, event}
      else
        error ->
          Logger.error("Failed to toggle tracking: #{inspect(error)}")
          {:error, "Failed to toggle tracking"}
      end
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

    # Check if the clicked character is already followed
    is_already_followed =
      all_settings_before
      |> Enum.any?(fn setting ->
        setting.followed && "#{setting.character_id}" == "#{character_id}"
      end)

    with current_user when not is_nil(current_user) <- WandererApp.User.load(current_user_id),
         {:ok, clicked_char} <- WandererApp.Character.find_character_by_eve_id(current_user, character_id),
         {:ok, _updated_settings} <- do_toggle_character_follow(map_id, clicked_char, is_already_followed, caller_pid) do

      # Get updated tracking data
      {:ok, tracking_data} = build_tracking_data(map_id, current_user_id)

      # Always send refresh_user_characters for follow operations
      {:ok, tracking_data, %{event: :refresh_user_characters}}
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

      # Map characters to tracking data
      tracking_data = build_character_tracking_data(characters_with_access, character_settings)

      # Check for inconsistent state
      check_tracking_consistency(tracking_data)

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

  # Helper to build tracking data for each character
  defp build_character_tracking_data(characters, character_settings) do
    Enum.map(characters, fn char ->
      setting = Enum.find(character_settings, &(&1.character_id == char.id))

      %{
        character: char |> WandererAppWeb.MapEventHandler.map_ui_character_stat(),
        tracked: setting && setting.tracked || false,
        followed: setting && setting.followed || false
      }
    end)
  end

  # Helper to check for inconsistent tracking state
  defp check_tracking_consistency(tracking_data) do
    followed_in_data = Enum.find(tracking_data, &(&1.followed))
    followed_but_not_tracked = followed_in_data && !Enum.find(tracking_data, &(&1.followed && &1.tracked))

    if followed_but_not_tracked do
      Logger.warning("Inconsistent state detected: Character is followed but not tracked", %{
        character_id: followed_in_data.character.eve_id
      })
    end
  end

  # Private implementation of toggle character tracking
  defp do_toggle_character_tracking(character, map_id, caller_pid) do
    with false <- is_nil(caller_pid),
         {:ok, existing_settings} <- MapCharacterSettingsRepo.get_by_map(map_id, character.id) do

      case existing_settings.tracked do
        # Untracking flow
        true ->
          with {:ok, updated_settings} <- untrack_character_settings(existing_settings),
               :ok <- untrack_characters([character], map_id, caller_pid),
               :ok <- remove_characters([character], map_id) do
            {:ok, updated_settings}
          end

        # Tracking flow
        false ->
          with {:ok, updated_settings} <- MapCharacterSettingsRepo.track(existing_settings),
               :ok <- track_characters([character], map_id, true, caller_pid),
               :ok <- add_characters([character], map_id, true) do
            {:ok, updated_settings}
          end
      end
    else
      true ->
        Logger.error("caller_pid is required for toggling character tracking")
        {:error, "caller_pid is required"}

      {:error, :not_found} ->
        # Create new settings with tracking enabled
        create_character_settings(character.id, map_id, true, false, caller_pid)

      error -> error
    end
  end

  # Helper to untrack character settings, handling the followed state
  defp untrack_character_settings(settings) do
    case settings.followed do
      true ->
        # First unfollow, then untrack
        with {:ok, unfollowed_settings} <- MapCharacterSettingsRepo.unfollow(settings) do
          MapCharacterSettingsRepo.untrack(unfollowed_settings)
        end

      false ->
        # Just untrack
        MapCharacterSettingsRepo.untrack(settings)
    end
  end

  # Private implementation of toggle character follow
  defp do_toggle_character_follow(map_id, clicked_char, is_already_followed, caller_pid) do
    with false <- is_nil(caller_pid),
         {:ok, clicked_char_settings} <- MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id) do

      case {is_already_followed, clicked_char_settings.tracked} do
        # Case 1: Already followed and not tracked - unfollow and remove
        {true, false} ->
          with {:ok, _} <- MapCharacterSettingsRepo.unfollow(clicked_char_settings),
               :ok <- remove_characters([clicked_char], map_id) do
            {:ok, clicked_char_settings}
          end

        # Case 2: Already followed and tracked - just unfollow
        {true, true} ->
          MapCharacterSettingsRepo.unfollow(clicked_char_settings)

        # Case 3: Not followed - ensure tracked and followed
        {false, _} ->
          ensure_character_tracked_and_followed(map_id, clicked_char, clicked_char_settings, caller_pid)
      end
    else
      true ->
        Logger.error("caller_pid is required for toggling character following")
        {:error, "caller_pid is required"}

      {:error, :not_found} ->
        # Create new settings with both tracking and following enabled
        create_character_settings(clicked_char.id, map_id, true, true, caller_pid, clicked_char)
    end
  end

  # Consolidated helper function to ensure a character is tracked when followed
  defp ensure_character_tracked_and_followed(map_id, character, settings, caller_pid) do
    with false <- is_nil(caller_pid) do
      # Toggle the followed state
      followed = !settings.followed

      case {followed, settings.tracked} do
        # Case 1: Following and not tracked - need to track and follow
        {true, false} ->
          # Unfollow all others first
          :ok = maybe_unfollow_others(map_id, character.id, true)

          # Track and follow
          with {:ok, tracked_settings} <- MapCharacterSettingsRepo.track(settings),
               {:ok, updated_settings} <- update_follow(tracked_settings, true),
               :ok <- track_characters([character], map_id, true, caller_pid),
               :ok <- add_characters([character], map_id, true) do
            {:ok, updated_settings}
          end

        # Case 2: Following and already tracked - just follow
        {true, true} ->
          # Unfollow all others first
          :ok = maybe_unfollow_others(map_id, character.id, true)
          # Update follow status
          update_follow(settings, true)

        # Case 3: Unfollowing - just update follow status
        {false, _} ->
          update_follow(settings, false)
      end
    else
      true ->
        Logger.error("caller_pid is required for ensuring character is tracked and followed")
        {:error, "caller_pid is required"}
    end
  end

  # Helper function to create character settings with specified tracking and following states
  defp create_character_settings(character_id, map_id, tracked, followed, caller_pid, character \\ nil) do
    with false <- is_nil(caller_pid) do
      # Unfollow others if needed
      case followed do
        true -> :ok = maybe_unfollow_others(map_id, character_id, true)
        false -> :ok
      end

      # Create the settings
      {:ok, settings} = MapCharacterSettingsRepo.create(%{
        character_id: character_id,
        map_id: map_id,
        tracked: tracked,
        followed: followed
      })

      # Handle tracking based on character presence and tracking flag
      case {character, tracked} do
        {nil, _} ->
          # No character provided, just return settings
          {:ok, settings}

        {_, false} ->
          # Character provided but not tracking
          {:ok, settings}

        {_, true} ->
          # Character provided and tracking enabled
          with :ok <- track_characters([character], map_id, true, caller_pid),
               :ok <- add_characters([character], map_id, true) do
            {:ok, settings}
          end
      end
    else
      true ->
        Logger.error("caller_pid is required for creating character settings")
        {:error, "caller_pid is required"}
    end
  end

  defp maybe_unfollow_others(_map_id, _char_id, false), do: :ok
  defp maybe_unfollow_others(map_id, char_id, true) do
    # Unfollow all other characters when setting a character as followed
    with {:ok, all_settings} <- MapCharacterSettingsRepo.get_all_by_map(map_id) do
      all_settings
      |> Enum.filter(&(&1.character_id != char_id && &1.followed))
      |> Enum.each(&MapCharacterSettingsRepo.unfollow/1)

      :ok
    end
  end

  defp update_follow(settings, true), do: MapCharacterSettingsRepo.follow(settings)
  defp update_follow(settings, false), do: MapCharacterSettingsRepo.unfollow(settings)

  # Helper functions for character tracking
  def track_characters(_, _, false, _), do: :ok
  def track_characters([], _map_id, _is_track_character?, _), do: :ok
  def track_characters([character | characters], map_id, true, caller_pid) do
    with :ok <- track_character(character, map_id, caller_pid) do
      track_characters(characters, map_id, true, caller_pid)
    end
  end

  def track_character(%{id: character_id, eve_id: eve_id, corporation_id: corporation_id, alliance_id: alliance_id}, map_id, caller_pid) do
    with false <- is_nil(caller_pid) do
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
    else
      true ->
        Logger.error("caller_pid is required for tracking characters")
        {:error, "caller_pid is required"}
    end
  end

  def untrack_characters(characters, map_id, caller_pid) do
    with false <- is_nil(caller_pid) do
      characters
      |> Enum.each(fn character ->
        WandererAppWeb.Presence.untrack(caller_pid, map_id, character.id)
        WandererApp.Cache.put("#{inspect(caller_pid)}_map_#{map_id}:character_#{character.id}:tracked", false)
        :ok = Phoenix.PubSub.unsubscribe(WandererApp.PubSub, "character:#{character.eve_id}")
      end)

      :ok
    else
      true ->
        Logger.error("caller_pid is required for untracking characters")
        {:error, "caller_pid is required"}
    end
  end

  def add_characters([], _map_id, _track_character), do: :ok
  def add_characters([character | characters], map_id, track_character) do
    :ok = WandererApp.Map.Server.add_character(map_id, character, track_character)
    add_characters(characters, map_id, track_character)
  end

  def remove_characters([], _map_id), do: :ok
  def remove_characters([character | characters], map_id) do
    :ok = WandererApp.Map.Server.remove_character(map_id, character.id)
    remove_characters(characters, map_id)
  end
end
