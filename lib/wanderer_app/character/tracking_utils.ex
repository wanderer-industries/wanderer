defmodule WandererApp.Character.TrackingUtils do
  @moduledoc """
  Utility functions for handling character tracking and following operations.

  """

  require Logger

  @doc """
  Toggles the tracking state for a character on a map.
  Returns the updated tracking data for all characters with access to the map.
  """
  def update_tracking(
        map_id,
        character_eve_id,
        current_user_id,
        track,
        caller_pid,
        only_tracked_characters
      )
      when not is_nil(caller_pid) do
    with {:ok, character} <-
           WandererApp.Character.get_by_eve_id("#{character_eve_id}"),
         {:ok, %{tracked: is_tracked}} <-
           do_update_character_tracking(character, map_id, track, caller_pid) do
      # Determine which event to send based on tracking mode and previous state
      if only_tracked_characters && not is_tracked do
        {:ok, nil, :not_all_characters_tracked}
      else
        # Get updated tracking data
        {:ok, tracking_data} = build_tracking_data(map_id, current_user_id)

        {:ok, tracking_data, %{event: :refresh_user_characters}}
      end
    else
      error ->
        Logger.error("Failed to toggle tracking: #{inspect(error)}")
        {:error, "Failed to toggle tracking"}
    end
  end

  def update_tracking(
        _map_id,
        _character_id,
        _current_user_id,
        _track,
        _caller_pid,
        _only_tracked_characters
      ) do
    Logger.error("Failed to update tracking")
    {:error, "Failed to update tracking"}
  end

  @doc """
  Builds tracking data for all characters with access to a map.
  Only includes characters that have actual tracking permission.
  """
  def build_tracking_data(map_id, current_user_id) do
    with {:ok, map} <- WandererApp.MapRepo.get(map_id),
         {:ok, user_settings} <- WandererApp.MapUserSettingsRepo.get(map_id, current_user_id),
         {:ok, %{characters: characters_with_access}} <-
           WandererApp.Maps.load_characters(map, current_user_id) do
      # Filter to only characters with actual tracking permission
      characters_with_tracking_permission =
        filter_characters_with_tracking_permission(characters_with_access, map)

      # Map characters to tracking data
      {:ok, characters_data} =
        build_character_tracking_data(characters_with_tracking_permission)

      {:ok, main_character} =
        get_main_character(
          user_settings,
          characters_with_tracking_permission,
          characters_with_tracking_permission
        )

      following_character_eve_id =
        case user_settings do
          nil -> nil
          %{following_character_eve_id: following_character_eve_id} -> following_character_eve_id
        end

      main_character_eve_id =
        case main_character do
          nil -> nil
          %{eve_id: eve_id} -> eve_id
        end

      {:ok,
       %{
         characters: characters_data,
         main: main_character_eve_id,
         following: following_character_eve_id
       }}
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
  defp build_character_tracking_data(characters) do
    {:ok,
     Enum.map(characters, fn char ->
       %{
         character: char |> WandererAppWeb.MapEventHandler.map_ui_character_stat(),
         tracked: char.tracked
       }
     end)}
  end

  # Filter characters to only include those with actual tracking permission
  # This prevents showing characters in the tracking dialog that will fail when toggled
  defp filter_characters_with_tracking_permission(characters, %{id: map_id, owner_id: owner_id}) do
    # Load ACLs with members properly (same approach as get_map_characters)
    acls = load_map_acls_with_members(map_id)

    Enum.filter(characters, fn character ->
      has_tracking_permission?(character, owner_id, acls)
    end)
  end

  # Load ACLs with members in the correct format for permission checking
  defp load_map_acls_with_members(map_id) do
    case WandererApp.Api.MapAccessList.read_by_map(%{map_id: map_id},
           load: [access_list: [:owner, :members]]
         ) do
      {:ok, map_access_lists} ->
        map_access_lists
        |> Enum.map(fn mal -> mal.access_list end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  # Check if a character has tracking permission on a map
  # Returns true if the character can be tracked, false otherwise
  defp has_tracking_permission?(character, owner_id, acls) do
    cond do
      # Map owner always has tracking permission
      character.id == owner_id ->
        true

      # Character belongs to same user as map owner
      # Note: character data from load_characters may not have user_id, so we need to load it
      check_same_user_as_owner_by_id(character.id, owner_id) ->
        true

      # Check ACL-based permissions
      true ->
        case WandererApp.Permissions.check_characters_access([character], acls) do
          [character_permissions] ->
            map_permissions = WandererApp.Permissions.get_permissions(character_permissions)
            map_permissions.track_character and map_permissions.view_system

          _ ->
            false
        end
    end
  end

  # Check if character belongs to the same user as the map owner (by character IDs)
  defp check_same_user_as_owner_by_id(_character_id, nil), do: false

  defp check_same_user_as_owner_by_id(character_id, owner_id) do
    with {:ok, character} <- WandererApp.Character.get_character(character_id),
         {:ok, owner_character} <- WandererApp.Character.get_character(owner_id) do
      character.user_id != nil and character.user_id == owner_character.user_id
    else
      _ -> false
    end
  end

  # Private implementation of update character tracking
  defp do_update_character_tracking(character, map_id, track, caller_pid) do
    # First check current tracking state to avoid unnecessary permission checks
    current_settings = WandererApp.MapCharacterSettingsRepo.get(map_id, character.id)

    case {track, current_settings} do
      # Already tracked and wants to stay tracked - no permission check needed
      {true, {:ok, %{tracked: true} = settings}} ->
        do_update_character_tracking_impl(character, map_id, track, caller_pid, {:ok, settings})

      # Wants to enable tracking - check permissions first
      {true, settings_result} ->
        case check_character_tracking_permission(character, map_id) do
          {:ok, :allowed} ->
            do_update_character_tracking_impl(
              character,
              map_id,
              track,
              caller_pid,
              settings_result
            )

          {:error, reason} ->
            Logger.warning(
              "[CharacterTracking] Character #{character.id} cannot be tracked on map #{map_id}: #{reason}"
            )

            {:error, reason}
        end

      # Untracking is always allowed
      {false, settings_result} ->
        do_update_character_tracking_impl(character, map_id, track, caller_pid, settings_result)
    end
  end

  # Check if a character has permission to be tracked on a map
  defp check_character_tracking_permission(character, map_id) do
    with {:ok, %{acls: acls, owner_id: owner_id}} <-
           WandererApp.MapRepo.get(map_id,
             acls: [
               :owner_id,
               members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
             ]
           ) do
      # Check if character is the map owner
      if character.id == owner_id do
        {:ok, :allowed}
      else
        # Check if character belongs to same user as owner (Option 3 check)
        case check_same_user_as_owner(character, owner_id) do
          true ->
            {:ok, :allowed}

          false ->
            # Check ACL-based permissions
            [character_permissions] =
              WandererApp.Permissions.check_characters_access([character], acls)

            map_permissions = WandererApp.Permissions.get_permissions(character_permissions)

            if map_permissions.track_character and map_permissions.view_system do
              {:ok, :allowed}
            else
              {:error,
               "Character does not have tracking permission on this map. Please add the character to a map access list or ensure you are the map owner."}
            end
        end
      end
    else
      {:error, _} ->
        {:error, "Failed to verify map permissions"}
    end
  end

  # Check if character belongs to the same user as the map owner
  defp check_same_user_as_owner(_character, nil), do: false

  defp check_same_user_as_owner(character, owner_id) do
    case WandererApp.Character.get_character(owner_id) do
      {:ok, owner_character} ->
        character.user_id != nil and character.user_id == owner_character.user_id

      _ ->
        false
    end
  end

  defp do_update_character_tracking_impl(character, map_id, track, caller_pid, settings_result) do
    case settings_result do
      # Untracking flow
      {:ok, %{tracked: true} = existing_settings} ->
        if not track do
          {:ok, updated_settings} =
            WandererApp.MapCharacterSettingsRepo.untrack(existing_settings)

          :ok = untrack([character], map_id, caller_pid)
          {:ok, updated_settings}
        else
          {:ok, existing_settings}
        end

      # Tracking flow
      {:ok, %{tracked: false} = existing_settings} ->
        if track do
          {:ok, updated_settings} = WandererApp.MapCharacterSettingsRepo.track(existing_settings)
          # Ensure character is in map state (fixes race condition where character
          # might not be synced yet from presence updates)
          :ok = WandererApp.Map.add_character(map_id, character)
          :ok = track([character], map_id, true, caller_pid)
          {:ok, updated_settings}
        else
          {:ok, existing_settings}
        end

      {:error, :not_found} ->
        if track do
          # Create new settings with tracking enabled
          {:ok, settings} =
            WandererApp.MapCharacterSettingsRepo.create(%{
              character_id: character.id,
              map_id: map_id,
              tracked: true
            })

          # Add character to map state immediately (fixes race condition where
          # character wouldn't appear on map until next update_presence cycle)
          :ok = WandererApp.Map.add_character(map_id, character)
          :ok = track([character], map_id, true, caller_pid)
          {:ok, settings}
        else
          {:error, "Character settings not found"}
        end

      error ->
        error
    end
  end

  # Helper functions for character tracking

  def track([], _map_id, _is_track_character?, _), do: :ok

  def track([character | characters], map_id, is_track_allowed, caller_pid) do
    with :ok <- track_character(character, map_id, is_track_allowed, caller_pid) do
      track(characters, map_id, is_track_allowed, caller_pid)
    end
  end

  defp track_character(
         %{
           id: character_id,
           eve_id: eve_id
         } = _character,
         map_id,
         is_track_allowed,
         caller_pid
       ) do
    WandererAppWeb.Presence.update(caller_pid, map_id, character_id, %{
      tracked: is_track_allowed,
      from: DateTime.utc_now()
    })
    |> case do
      {:ok, _} ->
        :ok

      {:error, :nopresence} ->
        WandererAppWeb.Presence.track(caller_pid, map_id, character_id, %{
          tracked: is_track_allowed,
          from: DateTime.utc_now()
        })

      error ->
        Logger.error("Failed to update presence: #{inspect(error)}")
        {:error, "Failed to update presence"}
    end

    cache_key = "#{inspect(caller_pid)}_map_#{map_id}:character_#{character_id}:tracked"

    case WandererApp.Cache.lookup!(cache_key, false) do
      true ->
        :ok

      _ ->
        :ok = Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{eve_id}")
        :ok = WandererApp.Cache.put(cache_key, true)
    end

    if is_track_allowed do
      :ok = WandererApp.Character.TrackerManager.start_tracking(character_id)

      # Immediately set tracking_start_time cache key to enable map tracking
      # This ensures the character is tracked for updates even before the
      # Tracker process is fully started (avoids race condition)
      tracking_start_key = "character:#{character_id}:map:#{map_id}:tracking_start_time"

      case WandererApp.Cache.lookup(tracking_start_key) do
        {:ok, nil} ->
          WandererApp.Cache.put(tracking_start_key, DateTime.utc_now())

          # Clear stale location caches for fresh tracking
          WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:solar_system_id")
          WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:station_id")
          WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:structure_id")

        _ ->
          # Already tracking, no need to update
          :ok
      end

      # Also call update_track_settings to update character state when tracker is ready
      WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
        map_id: map_id,
        track: true
      })
    end

    :ok
  end

  defp track_character(
         character,
         _map_id,
         _is_track_allowed,
         _caller_pid
       ) do
    Logger.error(
      "Invalid character data for tracking - character must have :id and :eve_id fields, got: #{inspect(character)}"
    )

    {:error, "Invalid character data"}
  end

  def untrack(characters, map_id, caller_pid) do
    with false <- is_nil(caller_pid) do
      character_ids = characters |> Enum.map(& &1.id)

      character_ids
      |> Enum.each(fn character_id ->
        WandererAppWeb.Presence.update(caller_pid, map_id, character_id, %{
          tracked: false,
          from: DateTime.utc_now()
        })
      end)

      :ok
    else
      true ->
        Logger.error("caller_pid is required for untracking characters 2")
        {:error, "caller_pid is required"}
    end
  end

  def get_main_character(
        nil,
        current_user_characters,
        available_map_characters
      ),
      do:
        get_main_character(
          %{main_character_eve_id: nil},
          current_user_characters,
          available_map_characters
        )

  def get_main_character(
        %{main_character_eve_id: nil} = _map_user_settings,
        _current_user_characters,
        available_map_characters
      ),
      do: {:ok, available_map_characters |> Enum.sort_by(& &1.inserted_at) |> List.first()}

  def get_main_character(
        %{main_character_eve_id: main_character_eve_id} = _map_user_settings,
        current_user_characters,
        _available_map_characters
      ),
      do:
        {:ok,
         current_user_characters
         |> Enum.find(fn c -> c.eve_id === main_character_eve_id end)}
end
