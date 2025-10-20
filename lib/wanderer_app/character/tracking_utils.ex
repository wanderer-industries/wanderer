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
  """
  def build_tracking_data(map_id, current_user_id) do
    with {:ok, map} <-
           WandererApp.MapRepo.get(map_id,
             acls: [
               :owner_id,
               members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
             ]
           ),
         {:ok, user_settings} <- WandererApp.MapUserSettingsRepo.get(map_id, current_user_id),
         {:ok, %{characters: characters_with_access}} <-
           WandererApp.Maps.load_characters(map, current_user_id) do
      # Map characters to tracking data
      {:ok, characters_data} =
        build_character_tracking_data(characters_with_access)

      {:ok, main_character} =
        get_main_character(user_settings, characters_with_access, characters_with_access)

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

  # Private implementation of update character tracking
  defp do_update_character_tracking(character, map_id, track, caller_pid) do
    WandererApp.MapCharacterSettingsRepo.get(map_id, character.id)
    |> case do
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

      # WandererApp.Map.Server.untrack_characters(map_id, character_ids)

      :ok
    else
      true ->
        Logger.error("caller_pid is required for untracking characters 2")
        {:error, "caller_pid is required"}
    end
  end

  # def add_characters([], _map_id, _track_character), do: :ok

  # def add_characters([character | characters], map_id, track_character) do
  #   :ok = WandererApp.Map.Server.add_character(map_id, character, track_character)
  #   add_characters(characters, map_id, track_character)
  # end

  # def remove_characters([], _map_id), do: :ok

  # def remove_characters([character | characters], map_id) do
  #   :ok = WandererApp.Map.Server.remove_character(map_id, character.id)
  #   remove_characters(characters, map_id)
  # end

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
