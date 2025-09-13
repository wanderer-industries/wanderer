defmodule WandererApp.Character.Activity do
  @moduledoc """
  Functions for processing and managing character activity data.
  """
  require Logger

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
              Map.get(a, :passages, 0) +
                Map.get(a, :connections, 0) +
                Map.get(a, :signatures, 0)
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
  - `current_user`: Current user struct (used only to get user settings)

  ## Returns
  - List of processed activity data
  """
  def process_character_activity(map_id, current_user) do
    with {:ok, map_user_settings} <- get_map_user_settings(map_id, current_user.id),
         {:ok, raw_activity} <- WandererApp.Map.get_character_activity(map_id),
         {:ok, user_characters} <-
           WandererApp.Api.Character.active_by_user(%{user_id: current_user.id}) do
      process_activity_data(raw_activity, map_user_settings, user_characters)
    else
      _ ->
        []
    end
  end

  def get_map_user_settings(map_id, user_id) do
    case WandererApp.MapUserSettingsRepo.get(map_id, user_id) do
      {:ok, settings} when not is_nil(settings) ->
        {:ok, settings}

      _ ->
        {:ok, %{main_character_eve_id: nil}}
    end
  end

  @doc """
  Gets character settings for a map.

  ## Parameters
  - `map_id`: ID of the map

  ## Returns
  - `{:ok, settings}` with list of settings or empty list
  """
  def get_map_character_settings(map_id) do
    case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
      {:ok, settings} -> {:ok, settings}
      _ -> {:ok, []}
    end
  end

  # Handle empty activity list
  defp process_activity_data([], _map_user_settings, _all_characters), do: []

  # Process activity data
  defp process_activity_data(all_activity, map_user_settings, all_characters) do
    # Group activities by user ID
    activities_by_user = Enum.group_by(all_activity, &Map.get(&1, :user_id, "unknown"))

    # Process each user's activities
    activities_by_user
    |> Enum.flat_map(fn {user_id, user_activities} ->
      process_user_activity(user_id, user_activities, map_user_settings, all_characters)
    end)
    |> sort_by_timestamp()
  end

  defp process_user_activity(
         user_id,
         user_activities,
         %{user_id: user_id, main_character_eve_id: main_id} = _map_user_settings,
         all_characters
       )
       when not is_nil(main_id) do
    # Group activities by character
    activities_by_character = group_activities_by_character(user_activities)

    main_id_str = to_string(main_id)

    display_character =
      case Enum.find(all_characters, &(to_string(&1.eve_id) == main_id_str)) do
        # Fall back to most active
        nil -> find_most_active_character_details(activities_by_character)
        main_char -> main_char
      end

    build_activity_entry_if_valid(display_character, activities_by_character, user_id)
  end

  defp process_user_activity(user_id, user_activities, _map_user_settings, _all_characters) do
    # Group activities by character
    activities_by_character = group_activities_by_character(user_activities)

    # Find the most active character
    display_character = find_most_active_character_details(activities_by_character)

    build_activity_entry_if_valid(display_character, activities_by_character, user_id)
  end

  # Helper function to build activity entry only if display character is valid
  defp build_activity_entry_if_valid(nil, _activities_by_character, user_id) do
    Logger.warning("No suitable character found for user #{user_id}")
    []
  end

  defp build_activity_entry_if_valid(display_character, activities_by_character, _user_id) do
    build_activity_entry(display_character, activities_by_character)
  end

  # Group activities by character ID
  defp group_activities_by_character(activities) do
    Enum.group_by(activities, fn activity ->
      cond do
        character = Map.get(activity, :character) -> Map.get(character, :id)
        id = Map.get(activity, :character_id) -> id
        id = Map.get(activity, :character_eve_id) -> id
        true -> "unknown_#{System.unique_integer([:positive])}"
      end
    end)
  end

  # Find the details of the most active character
  defp find_most_active_character_details(activities_by_character) do
    with most_active_id when not is_nil(most_active_id) <-
           find_most_active_character(activities_by_character),
         most_active_activities <- Map.get(activities_by_character, most_active_id, []),
         [first_activity | _] <- most_active_activities,
         character when not is_nil(character) <- Map.get(first_activity, :character) do
      character
    else
      _ ->
        Logger.warning("Could not find most active character")
        nil
    end
  end

  # Build activity entry with the provided character and sum all activities
  defp build_activity_entry(character, activities_by_character) do
    # Sum up all activities
    all_passages = sum_all_activities(activities_by_character, :passages)
    all_connections = sum_all_activities(activities_by_character, :connections)
    all_signatures = sum_all_activities(activities_by_character, :signatures)

    # Only create entry if there's at least some activity
    if all_passages + all_connections + all_signatures > 0 do
      [
        %{
          character: character,
          passages: all_passages,
          connections: all_connections,
          signatures: all_signatures,
          timestamp: get_latest_timestamp(activities_by_character)
        }
      ]
    else
      Logger.warning("Character has no activity, not creating entry")
      []
    end
  end

  # Sum up activities of a specific type across all characters
  defp sum_all_activities(activities_by_character, key) do
    activities_by_character
    |> Enum.flat_map(fn {_, char_activities} -> char_activities end)
    |> Enum.map(&Map.get(&1, key, 0))
    |> Enum.sum()
  end

  # Get the most recent timestamp across all characters
  defp get_latest_timestamp(activities_by_character) do
    activities_by_character
    |> Enum.flat_map(fn {_, char_activities} -> char_activities end)
    |> Enum.map(&Map.get(&1, :timestamp, DateTime.utc_now()))
    |> Enum.sort_by(& &1, {:desc, DateTime})
    |> List.first() || DateTime.utc_now()
  end

  defp sort_by_timestamp(activities) do
    Enum.sort_by(activities, & &1.timestamp, {:desc, DateTime})
  end
end
