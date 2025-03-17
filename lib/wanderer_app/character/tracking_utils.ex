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
    case WandererApp.User.load(current_user_id) do
      nil ->
        Logger.error("User not found when toggling track")
        {:error, "User not found"}

      current_user ->
        do_toggle_track(map_id, character_id, current_user, caller_pid, only_tracked_characters)
    end
  end

  defp do_toggle_track(map_id, character_id, current_user, caller_pid, only_tracked_characters) do
    with {:ok, character} <- WandererApp.Character.find_character_by_eve_id(current_user, character_id),
         {:ok, map} <- WandererApp.Api.Map.by_id(map_id),
         _map_with_acls = Ash.load!(map, :acls),
         {:ok, existing_settings} <- MapCharacterSettingsRepo.get_by_map(map_id, character.id),
         # Using proper assignment
         was_tracked = existing_settings && existing_settings.tracked,
         {:ok, _updated_settings} <- do_toggle_character_tracking(character, map_id, caller_pid),
         {:ok, tracking_data} <- build_tracking_data(map_id, current_user.id) do

      # Using pattern matching with case
      event = case {only_tracked_characters, was_tracked} do
        {true, true} -> :not_all_characters_tracked
        _ -> %{event: :refresh_user_characters}
      end

      {:ok, tracking_data, event}
    end
  end

  @doc """
  Toggles the follow state for a character on a map.
  Returns the updated tracking data for all characters with access to the map.
  """
  def toggle_follow(map_id, character_id, current_user_id, caller_pid \\ nil) do
    case WandererApp.User.load(current_user_id) do
      nil ->
        Logger.error("User not found when toggling follow")
        {:error, "User not found"}

      current_user ->
        do_toggle_follow(map_id, character_id, current_user, caller_pid)
    end
  end

  defp do_toggle_follow(map_id, character_id, current_user, caller_pid) do
    with {:ok, clicked_char} <- WandererApp.Character.find_character_by_eve_id(current_user, character_id),
         is_already_followed = get_follow_status(map_id, clicked_char.id),
         {:ok, _updated_settings} <- do_toggle_character_follow(map_id, clicked_char, is_already_followed, caller_pid),
         {:ok, tracking_data} <- build_tracking_data(map_id, current_user.id) do
      # For follow operations, always return refresh event
      {:ok, tracking_data, %{event: :refresh_user_characters}}
    end
  end

  @doc """
  Builds tracking data for all characters with access to a map.
  """
  def build_tracking_data(map_id, current_user_id) do
    case WandererApp.User.load(current_user_id) do
      nil ->
        Logger.warning("User not found when building tracking data", %{user_id: current_user_id})
        {:error, "User not found"}

      current_user ->
        build_tracking_data_for_user(map_id, current_user)
    end
  end

  defp build_tracking_data_for_user(map_id, current_user) do
    with {:ok, map} <- WandererApp.Api.Map.by_id(map_id),
         _map_with_acls = Ash.load!(map, :acls),
         {:ok, character_settings} <- MapCharacterSettingsRepo.get_all_by_map(map_id),
         {:ok, %{characters: characters_with_access}} <-
           WandererApp.Maps.load_characters(map, character_settings, current_user.id) do
      tracking_data = build_character_tracking_data(characters_with_access, character_settings)
      check_tracking_consistency(tracking_data)
      {:ok, tracking_data}
    end
  end

  defp build_character_tracking_data(characters, character_settings) do
    Enum.map(characters, fn char ->
      setting = Enum.find(character_settings, &(&1.character_id == char.id))

      %{
        character: WandererAppWeb.MapEventHandler.map_ui_character_stat(char),
        tracked: (setting && setting.tracked) || false,
        followed: (setting && setting.followed) || false
      }
    end)
  end

  defp check_tracking_consistency(tracking_data) do
    followed_chars = Enum.filter(tracking_data, & &1.followed)
    followed_but_not_tracked = Enum.filter(followed_chars, fn char -> not char.tracked end)

    Enum.each(followed_but_not_tracked, fn char ->
      Logger.warning("Inconsistent state detected: Character is followed but not tracked", %{
        character_id: char.character.eve_id,
        character_name: char.character.name
      })
    end)
  end

  # --- Toggle Character Tracking ---

  defp do_toggle_character_tracking(_character, _map_id, nil) do
    Logger.error("caller_pid is required for toggling character tracking")
    {:error, "caller_pid is required"}
  end

  defp do_toggle_character_tracking(character, map_id, caller_pid) do
    case MapCharacterSettingsRepo.get_by_map(map_id, character.id) do
      {:ok, %{tracked: true} = existing_settings} ->
        untrack_flow(character, map_id, caller_pid, existing_settings)

      {:ok, existing_settings} ->
        track_flow(character, map_id, caller_pid, existing_settings)

      {:error, :not_found} ->
        create_character_settings(character.id, map_id, true, false, caller_pid)

      error ->
        Logger.error("Error toggling character tracking: #{inspect(error)}")
        error
    end
  end

  defp untrack_flow(character, map_id, caller_pid, existing_settings) do
    with {:ok, updated_settings} <- untrack_character_settings(existing_settings),
         :ok <- untrack_characters([character], map_id, caller_pid),
         :ok <- remove_characters([character], map_id) do
      {:ok, updated_settings}
    end
  end

  defp track_flow(character, map_id, caller_pid, existing_settings) do
    with {:ok, updated_settings} <- MapCharacterSettingsRepo.track(existing_settings),
         :ok <- track_characters([character], map_id, true, caller_pid),
         :ok <- add_characters([character], map_id, true) do
      {:ok, updated_settings}
    end
  end

  defp untrack_character_settings(%{followed: true} = settings) do
    case MapCharacterSettingsRepo.unfollow(settings) do
      {:ok, unfollowed_settings} -> MapCharacterSettingsRepo.untrack(unfollowed_settings)
      error -> error
    end
  end

  defp untrack_character_settings(settings),
    do: MapCharacterSettingsRepo.untrack(settings)

  defp do_toggle_character_follow(_map_id, _clicked_char, _is_already_followed, nil) do
    Logger.error("caller_pid is required for toggling character following")
    {:error, "caller_pid is required"}
  end

  defp do_toggle_character_follow(map_id, clicked_char, true, _caller_pid) do
    case MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id) do
      {:ok, clicked_char_settings} ->
        MapCharacterSettingsRepo.unfollow(clicked_char_settings)

      error ->
        Logger.error("Error unfollowing character: #{inspect(error)}")
        error
    end
  end

  defp do_toggle_character_follow(map_id, clicked_char, false, caller_pid) do
    case MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id) do
      {:ok, clicked_char_settings} ->
        # Not followed – ensure the character is both tracked and followed.
        ensure_character_tracked_and_followed(map_id, clicked_char, clicked_char_settings, caller_pid)

      {:error, :not_found} ->
        create_character_settings(clicked_char.id, map_id, true, true, caller_pid, clicked_char)

      error ->
        Logger.error("Error toggling character follow: #{inspect(error)}")
        error
    end
  end

  defp create_character_settings(_character_id, _map_id, _tracked, _followed, nil) do
    Logger.error("caller_pid is required for creating character settings")
    {:error, "caller_pid is required"}
  end

  defp create_character_settings(character_id, map_id, tracked, followed, caller_pid) do
    with {:ok, character} <- WandererApp.Character.get(character_id) do
      create_character_settings(character_id, map_id, tracked, followed, caller_pid, character)
    else
      error ->
        Logger.error("Error finding character when creating settings: #{inspect(error)}")
        error
    end
  end

  defp create_character_settings(_character_id, _map_id, _tracked, _followed, nil, _character) do
    Logger.error("caller_pid is required for creating character settings")
    {:error, "caller_pid is required"}
  end

  defp create_character_settings(character_id, map_id, tracked, true = _followed, caller_pid, character) do
    :ok = maybe_unfollow_others(map_id, character_id, true)
    do_create_character_settings(character_id, map_id, tracked, true, caller_pid, character)
  end

  defp create_character_settings(character_id, map_id, tracked, followed, caller_pid, character) do
    do_create_character_settings(character_id, map_id, tracked, followed, caller_pid, character)
  end

  defp do_create_character_settings(character_id, map_id, true = _tracked, followed, caller_pid, character)
       when not is_nil(character) do
    with {:ok, settings} <- MapCharacterSettingsRepo.create(%{
           character_id: character_id,
           map_id: map_id,
           tracked: true,
           followed: followed
         }),
         :ok <- track_characters([character], map_id, true, caller_pid),
         :ok <- add_characters([character], map_id, true) do
      {:ok, settings}
    end
  end

  defp do_create_character_settings(character_id, map_id, tracked, followed, _caller_pid, _character)
       when is_nil(tracked) or not tracked or is_nil(_character) do
    {:ok, settings} =
      MapCharacterSettingsRepo.create(%{
        character_id: character_id,
        map_id: map_id,
        tracked: tracked,
        followed: followed
      })

    {:ok, settings}
  end

  defp maybe_unfollow_others(_map_id, _char_id, false), do: :ok

  defp maybe_unfollow_others(map_id, char_id, true) do
    with {:ok, all_settings} <- MapCharacterSettingsRepo.get_all_by_map(map_id) do
      all_settings
      |> Enum.filter(fn s -> s.character_id != char_id and s.followed end)
      |> Enum.each(&MapCharacterSettingsRepo.unfollow/1)
    end

    :ok
  end


  def track_characters(_, _, false, _), do: :ok
  def track_characters([], _map_id, _is_track_character?, _), do: :ok

  def track_characters([character | characters], map_id, true, caller_pid) do
    case track_character(character, map_id, caller_pid) do
      :ok -> track_characters(characters, map_id, true, caller_pid)
      error -> error
    end
  end

  def track_character(%{id: _character_id, eve_id: _eve_id}, _map_id, nil) do
    Logger.error("caller_pid is required for tracking characters")
    {:error, "caller_pid is required"}
  end

  def track_character(%{id: character_id, eve_id: eve_id} = _character, map_id, caller_pid) do
    WandererAppWeb.Presence.track(caller_pid, map_id, character_id, %{})
    cache_key = "#{inspect(caller_pid)}_map_#{map_id}:character_#{character_id}:tracked"

    :ok =
      case WandererApp.Cache.lookup!(cache_key, false) do
        true ->
          :ok

        _ ->
          Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{eve_id}")
          WandererApp.Cache.put(cache_key, true)
      end

    WandererApp.Character.TrackerManager.start_tracking(character_id)
  end

  def untrack_characters(_characters, _map_id, nil) do
    Logger.error("caller_pid is required for untracking characters")
    {:error, "caller_pid is required"}
  end

  def untrack_characters(characters, map_id, caller_pid) do
    Enum.each(characters, fn character ->
      WandererAppWeb.Presence.untrack(caller_pid, map_id, character.id)
      WandererApp.Cache.put("#{inspect(caller_pid)}_map_#{map_id}:character_#{character.id}:tracked", false)
      :ok = Phoenix.PubSub.unsubscribe(WandererApp.PubSub, "character:#{character.eve_id}")
    end)

    :ok
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

  # --- Follow Helpers ---

  defp ensure_character_tracked_and_followed(_map_id, _character, _settings, nil) do
    Logger.error("caller_pid is required for ensuring character is tracked and followed")
    {:error, "caller_pid is required"}
  end

  defp ensure_character_tracked_and_followed(map_id, character, %{tracked: false} = settings, caller_pid) do
    :ok = maybe_unfollow_others(map_id, character.id, true)

    with {:ok, tracked_settings} <- MapCharacterSettingsRepo.track(settings),
         :ok <- track_characters([character], map_id, true, caller_pid),
         :ok <- add_characters([character], map_id, true),
         {:ok, updated_settings} <- MapCharacterSettingsRepo.follow(tracked_settings) do
      {:ok, updated_settings}
    end
  end

  defp ensure_character_tracked_and_followed(map_id, character, settings, _caller_pid) do
    :ok = maybe_unfollow_others(map_id, character.id, true)

    case MapCharacterSettingsRepo.follow(settings) do
      {:ok, updated_settings} -> {:ok, updated_settings}
      error ->
        Logger.error("Error following character: #{inspect(error)}")
        error
    end
  end

  defp get_follow_status(map_id, character_id) do
    case MapCharacterSettingsRepo.get_by_map(map_id, character_id) do
      {:ok, settings} -> settings.followed
      _other -> false
    end
  end
end
