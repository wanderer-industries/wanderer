defmodule WandererApp.Character.Activity do
  @moduledoc """
  Functions for processing and managing character activity data.
  """
  require Logger

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
  - `current_user`: Current user struct

  ## Returns
  - List of processed activity data
  """
  def process_character_activity(map_id, current_user) do
    with {:ok, character_settings} <- get_map_character_settings(map_id),
         raw_activity <- WandererApp.Map.get_character_activity(map_id),
         {:ok, user_characters} <-
           WandererApp.Api.Character.active_by_user(%{user_id: current_user.id}) do
      process_activity_data(raw_activity, character_settings, user_characters, current_user)
    end
  end

  defp get_map_character_settings(map_id) do
    case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
      {:ok, settings} -> {:ok, settings}
      _ -> {:ok, []}
    end
  end

  defp process_activity_data([], _character_settings, _user_characters, _current_user), do: []

  defp process_activity_data([%{is_user: _is_user} | _] = activity_data, _, _, _) do
    Enum.map(activity_data, fn entry ->
      entry = if Map.has_key?(entry, :portrait_url) do
        entry
      else
        Map.put(entry, :portrait_url, WandererApp.Utils.EVEUtil.get_portrait_url(Map.get(entry, :character_id), 64))
      end

      entry = if is_nil(Map.get(entry, :character_name)) || Map.get(entry, :character_name) == "Unknown" do
        Map.put(entry, :character_name, "Character ##{Map.get(entry, :character_id, "unknown")}")
      else
        entry
      end

      if is_nil(Map.get(entry, :corporation_ticker)) do
        Map.put(entry, :corporation_ticker, "")
      else
        entry
      end
    end)
  end

  defp process_activity_data(all_activity, character_settings, user_characters, current_user) do
    all_activity
    |> group_by_user_id()
    |> process_users_activity(character_settings, user_characters, current_user)
    |> sort_by_timestamp()
  end

  defp group_by_user_id(activities) do
    Enum.group_by(activities, &Map.get(&1, :user_id, "unknown"))
  end

  defp process_users_activity(
         activity_by_user_id,
         character_settings,
         user_characters,
         current_user
       ) do
    Enum.flat_map(activity_by_user_id, fn {user_id, user_activities} ->
      process_single_user_activity(
        user_id,
        user_activities,
        character_settings,
        user_characters,
        current_user
      )
    end)
  end

  defp process_single_user_activity(
         user_id,
         user_activities,
         character_settings,
         user_characters,
         current_user
       ) do
    is_current_user = user_id == current_user.id
    activities_by_character = group_activities_by_character(user_activities)

    char_id_to_show =
      select_character_to_show(activities_by_character, character_settings, is_current_user)

    case char_id_to_show do
      nil ->
        []

      id ->
        create_character_activity_entry(
          id,
          activities_by_character,
          user_characters,
          current_user,
          is_current_user,
          user_id
        )
    end
  end

  defp group_activities_by_character(activities) do
    Enum.group_by(activities, fn activity ->
      # Character info is now in a nested 'character' field
      cond do
        character = Map.get(activity, :character) -> Map.get(character, :id)
        id = Map.get(activity, :character_id) -> id
        id = Map.get(activity, :character_eve_id) -> id
        true -> "unknown_#{System.unique_integer([:positive])}"
      end
    end)
  end

  defp select_character_to_show(activities_by_character, character_settings, is_current_user) do
    followed_char_id =
      find_followed_character(character_settings, activities_by_character, is_current_user)

    followed_char_id || find_most_active_character(activities_by_character)
  end

  defp create_character_activity_entry(
         char_id,
         activities_by_character,
         user_characters,
         current_user,
         is_current_user,
         user_id
       ) do
    char_activities = Map.get(activities_by_character, char_id, [])

    case get_character_details(char_id, char_activities, user_characters, is_current_user) do
      nil -> []
      char_details -> [build_activity_entry(char_details, char_activities)]
    end
  end

  defp get_character_details(char_id, [activity | _rest], _user_characters, false) do
    # Extract character from the nested structure
    character = Map.get(activity, :character)

    if character do
      # Character data is available in the nested structure
      %{
        id: character.id,
        eve_id: character.eve_id,
        name: character.name,
        corporation_ticker: character.corporation_ticker || "???",
        alliance_ticker: character.alliance_ticker || "",
        portrait_url: WandererApp.Utils.EVEUtil.get_portrait_url(character.eve_id, 256)
      }
    else
      # Fallback to old structure if character field is not present
      case Map.get(activity, :character_name) do
        nil ->
          Logger.error("Missing character name for activity entry",
            character_id: char_id,
            activity: inspect(activity, limit: 3)
          )
          nil

        "" ->
          Logger.error("Empty character name for activity entry",
            character_id: char_id,
            activity: inspect(activity, limit: 3)
          )
          nil

        name when is_binary(name) ->
          %{
            id: char_id,
            eve_id: Map.get(activity, :character_eve_id) || char_id,
            name: name,
            corporation_ticker: Map.get(activity, :corporation_ticker) || "???",
            alliance_ticker: Map.get(activity, :alliance_ticker) || "",
            portrait_url: WandererApp.Utils.EVEUtil.get_portrait_url(
              Map.get(activity, :character_eve_id) || char_id,
              256
            )
          }

        invalid ->
          Logger.error("Invalid character name format",
            character_id: char_id,
            value: invalid,
            type: inspect(invalid)
          )
          nil
      end
    end
  end

  defp get_character_details(char_id, _char_activities, user_characters, true) do
    Enum.find(user_characters, fn char ->
      char.id == char_id || to_string(char.eve_id) == char_id
    end)
  end

  defp build_activity_entry(
         char_details,
         char_activities
       ) do
    # Ensure all required fields are present
    character = %{
      id: char_details.id,
      eve_id: char_details.eve_id,
      name: char_details.name,
      corporation_ticker: char_details.corporation_ticker,
      alliance_ticker: Map.get(char_details, :alliance_ticker) || "",
      portrait_url: Map.get(char_details, :portrait_url) ||
                   WandererApp.Utils.EVEUtil.get_portrait_url(char_details.eve_id, 256)
    }

    %{
      character: character,
      passages: sum_activity(char_activities, :passages),
      connections: sum_activity(char_activities, :connections),
      signatures: sum_activity(char_activities, :signatures),
      timestamp: get_most_recent_timestamp(char_activities)
    }
  end

  defp sum_activity(activities, key),
    do: activities |> Enum.map(&Map.get(&1, key, 0)) |> Enum.sum()

  defp get_most_recent_timestamp(activities) do
    activities
    |> Enum.map(&Map.get(&1, :timestamp, DateTime.utc_now()))
    |> Enum.sort_by(& &1, {:desc, DateTime})
    |> List.first() || DateTime.utc_now()
  end

  defp sort_by_timestamp(activities) do
    Enum.sort_by(activities, & &1.timestamp, {:desc, DateTime})
  end
end
