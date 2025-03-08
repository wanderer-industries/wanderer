defmodule WandererApp.Utils.CharacterUtil do
  @moduledoc """
  Utility functions for character-related operations.
  """

  @doc """
  Finds a followed character ID from a list of character settings and activities.

  ## Parameters
  - `character_settings`: List of character settings with `followed` and `character_id` fields
  - `activities_by_character`: Map of activities grouped by character_id
  - `is_current_user`: Boolean indicating if this is for the current user

  ## Returns
  - Character ID of the followed character if found, nil otherwise
  """
  def find_followed_character(character_settings, activities_by_character, is_current_user) do
    if is_current_user do
      followed_chars =
        character_settings
        |> Enum.filter(& &1.followed)
        |> Enum.map(& &1.character_id)

      # Find if any of user's characters is followed
      user_char_ids = Map.keys(activities_by_character)
      Enum.find(followed_chars, fn followed_id ->
        followed_id in user_char_ids
      end)
    else
      nil
    end
  end

  @doc """
  Finds the character with the most activity from a map of activities grouped by character_id.

  ## Parameters
  - `activities_by_character`: Map of activities grouped by character_id

  ## Returns
  - Character ID of the character with the most activity, or nil if no activities
  """
  def find_most_active_character(activities_by_character) do
    if Enum.empty?(activities_by_character) do
      nil
    else
      {char_id, _} =
        activities_by_character
        |> Enum.map(fn {char_id, activities} ->
          total_activity =
            activities
            |> Enum.map(fn a ->
              (Map.get(a, :passages, 0)) +
              (Map.get(a, :connections, 0)) +
              (Map.get(a, :signatures, 0))
            end)
            |> Enum.sum()
          {char_id, total_activity}
        end)
        |> Enum.max_by(fn {_, count} -> count end, fn -> {nil, 0} end)

      char_id
    end
  end

  @doc """
  Processes character activity data for display.

  ## Parameters
  - `map_id`: ID of the map
  - `current_user`: Current user struct

  ## Returns
  - List of processed activity data
  """
  def process_character_activity(map_id, current_user) do
    # Get character settings for the map
    character_settings =
      case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
        {:ok, settings} -> settings
        _ -> []
      end

    # Get all character activity
    all_activity = WandererApp.Map.get_character_activity(map_id)

    # Get user characters with access to the map
    {:ok, user_characters} = WandererApp.Api.Character.active_by_user(%{user_id: current_user.id})

    # Process activity data
    activity_data =
      if all_activity != [] && Map.has_key?(hd(all_activity), :is_user) do
        # This is activity data from get_character_activity
        # It doesn't have system_id, system_name, etc. fields
        # Just pass it through as is
        all_activity
      else
        # Group by user_id first
        activity_by_user_id = Enum.group_by(all_activity, fn activity ->
          # Use user_id if available, otherwise use a fallback
          Map.get(activity, :user_id, "unknown")
        end)

        # For each user, select one character to display
        Enum.flat_map(activity_by_user_id, fn {user_id, user_activities} ->
          is_current_user = user_id == current_user.id

          # Group by character_id or character_eve_id if available
          activities_by_character = Enum.group_by(user_activities, fn activity ->
            # Try character_id first, then fall back to character_eve_id
            Map.get(activity, :character_id) || Map.get(activity, :character_eve_id)
          end)

          # For current user, check if any character is followed
          followed_char_id = find_followed_character(character_settings, activities_by_character, is_current_user)

          # Decide which character to show
          char_id_to_show =
            if followed_char_id do
              followed_char_id
            else
              find_most_active_character(activities_by_character)
            end

          # If we found a character to show
          if char_id_to_show do
            # Get this character's activities
            char_activities = Map.get(activities_by_character, char_id_to_show, [])

            # Get character details
            char_details =
              if is_current_user do
                # For current user, we have the full character details
                Enum.find(user_characters, fn char ->
                  char.id == char_id_to_show || to_string(char.eve_id) == char_id_to_show
                end)
              else
                # For other users, extract details from the activity
                sample_activity = List.first(char_activities)
                %{
                  id: char_id_to_show,
                  name: Map.get(sample_activity, :character_name, "Unknown"),
                  eve_id: Map.get(sample_activity, :character_eve_id, nil),
                  corporation_ticker: Map.get(sample_activity, :corporation_ticker, ""),
                  alliance_ticker: Map.get(sample_activity, :alliance_ticker, "")
                }
              end

            # If we have character details
            if char_details do
              # Calculate aggregated activity
              total_passages = char_activities |> Enum.map(&Map.get(&1, :passages, 0)) |> Enum.sum()
              total_connections = char_activities |> Enum.map(&Map.get(&1, :connections, 0)) |> Enum.sum()
              total_signatures = char_activities |> Enum.map(&Map.get(&1, :signatures, 0)) |> Enum.sum()

              # Get most recent timestamp
              most_recent =
                char_activities
                |> Enum.map(&Map.get(&1, :timestamp, DateTime.utc_now()))
                |> Enum.sort_by(&(&1), {:desc, DateTime})
                |> List.first() || DateTime.utc_now()

              # Create one activity entry for this user
              [%{
                character_id: char_details.eve_id || char_details.id,
                character_name: char_details.name,
                portrait_url: WandererApp.Utils.EVEUtil.get_portrait_url(char_details.eve_id, 64),
                corporation_ticker: char_details.corporation_ticker,
                alliance_ticker: Map.get(char_details, :alliance_ticker, ""),
                # Use the most recent system information if available
                system_id: Map.get(List.first(char_activities) || %{}, :system_id, "unknown"),
                system_name: Map.get(List.first(char_activities) || %{}, :system_name, "Unknown System"),
                region_name: Map.get(List.first(char_activities) || %{}, :region_name, "Unknown Region"),
                security_status: Map.get(List.first(char_activities) || %{}, :security_status, 0.0),
                security_class: Map.get(List.first(char_activities) || %{}, :security_class, "unknown"),
                jumps: Map.get(List.first(char_activities) || %{}, :jumps, 0),
                # Use aggregated activity counts
                passages: total_passages,
                connections: total_connections,
                signatures: total_signatures,
                timestamp: most_recent,
                is_current_user: is_current_user,
                user_id: user_id,
                user_name: if(is_current_user, do: current_user.name, else: char_details.name)
              }]
            else
              []
            end
          else
            []
          end
        end)
        |> Enum.sort_by(&(&1.timestamp), {:desc, DateTime})
      end

    # Group by user_id and take the most active character for each user
    activity_data
    |> Enum.group_by(fn activity ->
      # Use user_id if available, otherwise use a fallback
      Map.get(activity, :user_id, "unknown")
    end)
    |> Enum.map(fn {_user_id, activities} ->
      # Sort by total activity and take the first one
      activities
      |> Enum.sort_by(fn activity ->
        (Map.get(activity, :passages, 0) +
         Map.get(activity, :connections, 0) +
         Map.get(activity, :signatures, 0))
      end, :desc)
      |> List.first()
    end)
  end
end
