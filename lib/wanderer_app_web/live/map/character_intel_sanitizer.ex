defmodule WandererAppWeb.MapCharacterIntelSanitizer do
  @moduledoc false

  @hide_character_intel_key "hide_character_intel"

  def hide_character_intel?(options, user_permissions) do
    option_enabled?(options, @hide_character_intel_key) and not manager_or_admin?(user_permissions)
  end

  def sanitize_character(character, options, user_permissions, own_character_eve_ids \\ [])

  def sanitize_character(nil, _options, _user_permissions, _own_character_eve_ids), do: nil

  def sanitize_character(character, options, user_permissions, own_character_eve_ids)
      when is_map(character) do
    if hide_character_intel?(options, user_permissions) and
         not own_character?(character, own_character_eve_ids) do
      character
      |> Map.drop([
        :location,
        :ship,
        :solar_system_id,
        :station_id,
        :structure_id,
        :ship_name,
        :ship_type_id,
        :ship_item_id,
        "location",
        "ship",
        "solar_system_id",
        "station_id",
        "structure_id",
        "ship_name",
        "ship_type_id",
        "ship_item_id"
      ])
      |> Map.put(:location, nil)
      |> Map.put(:ship, nil)
    else
      character
    end
  end

  def sanitize_characters(characters, options, user_permissions, own_character_eve_ids)
      when is_list(characters) do
    Enum.map(characters, &sanitize_character(&1, options, user_permissions, own_character_eve_ids))
  end

  def sanitize_present_character_eve_ids(eve_ids, options, user_permissions, own_character_eve_ids)
      when is_list(eve_ids) do
    if hide_character_intel?(options, user_permissions) do
      own_ids = normalize_ids(own_character_eve_ids)

      eve_ids
      |> Enum.filter(fn eve_id -> MapSet.member?(own_ids, normalize_id(eve_id)) end)
    else
      eve_ids
    end
  end

  def filter_passages(passages, options, user_permissions, own_character_eve_ids)
      when is_list(passages) do
    if hide_character_intel?(options, user_permissions) do
      Enum.filter(passages, fn passage ->
        passage
        |> character_from()
        |> own_character?(own_character_eve_ids)
      end)
    else
      passages
    end
  end

  def filter_activity(activity, options, user_permissions, own_character_eve_ids)
      when is_list(activity) do
    if hide_character_intel?(options, user_permissions) do
      Enum.filter(activity, fn row ->
        row
        |> character_from()
        |> own_character?(own_character_eve_ids)
      end)
    else
      activity
    end
  end

  def map_options(map_id) do
    case WandererApp.Map.get_options(map_id) do
      {:ok, options} when is_map(options) -> options
      _ -> %{}
    end
  end

  def own_character_eve_ids(%{characters: characters}) when is_list(characters),
    do: Enum.map(characters, &Map.get(&1, :eve_id))

  def own_character_eve_ids(_), do: []

  defp own_character?(nil, _own_character_eve_ids), do: false

  defp own_character?(character, own_character_eve_ids) when is_map(character) do
    own_ids = normalize_ids(own_character_eve_ids)

    character
    |> eve_id()
    |> normalize_id()
    |> then(&MapSet.member?(own_ids, &1))
  end

  defp manager_or_admin?(%{manage_map: true}), do: true
  defp manager_or_admin?(%{admin_map: true}), do: true
  defp manager_or_admin?(%{"manage_map" => true}), do: true
  defp manager_or_admin?(%{"admin_map" => true}), do: true
  defp manager_or_admin?(_), do: false

  defp option_enabled?(options, key) when is_map(options) do
    options
    |> Map.get(key, Map.get(options, :hide_character_intel, false))
    |> truthy?()
  end

  defp option_enabled?(_options, _key), do: false

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?(_), do: false

  defp eve_id(character), do: Map.get(character, :eve_id) || Map.get(character, "eve_id")

  defp character_from(nil), do: nil

  defp character_from(container) when is_map(container),
    do: Map.get(container, :character) || Map.get(container, "character")

  defp character_from(_container), do: nil

  defp normalize_ids(ids), do: ids |> Enum.map(&normalize_id/1) |> Enum.reject(&is_nil/1) |> MapSet.new()
  defp normalize_id(nil), do: nil
  defp normalize_id(id), do: to_string(id)
end
