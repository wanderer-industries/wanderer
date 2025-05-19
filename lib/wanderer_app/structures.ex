defmodule WandererApp.Structure do
  @moduledoc """
  Encapsulates the logic for parsing and updating system structures.
  """

  require Logger
  alias WandererApp.Api.MapSystemStructure
  alias WandererApp.Character

  def update_structures(system, added, updated, removed, main_character_eve_id, user_id \\ nil) do
    Logger.info("[Structure] update_structures called by user_id=#{inspect(user_id)}")

    added_structs =
      parse_structures(added, main_character_eve_id, system)
      |> Enum.map(&Map.delete(&1, :id))

    updated_structs = parse_structures(updated, main_character_eve_id, system)
    removed_structs = parse_structures(removed, main_character_eve_id, system)

    remove_structures(system.id, Enum.map(removed_structs, & &1.id))
    update_structures_in_db(system.id, updated_structs, Enum.map(updated_structs, & &1.id))
    add_structures(added_structs)

    :ok
  end

  def search_corporation_names([], _search), do: {:ok, []}

  def search_corporation_names([first_char | _], search) when is_binary(search) do
    Character.search(first_char.id, params: [search: search, categories: "corporation"])
  end

  def search_corporation_names(_user_chars, _search), do: {:ok, []}

  defp parse_structures(list_of_maps, character_eve_id, system) do
    Logger.debug(fn ->
      "[Structure] parse_structures =>\n" <> inspect(list_of_maps, pretty: true)
    end)

    Enum.map(list_of_maps, fn item ->
      %{
        id: Map.get(item, "id"),
        system_id: system.id,
        solar_system_id: system.solar_system_id,
        solar_system_name: system.name,
        structure_type_id: Map.get(item, "structureTypeId") || "???",
        structure_type: Map.get(item, "structureType"),
        character_eve_id: character_eve_id,
        name: Map.get(item, "name"),
        notes: Map.get(item, "notes"),
        owner_name: Map.get(item, "ownerName"),
        owner_ticker: Map.get(item, "ownerTicker"),
        owner_id: Map.get(item, "ownerId"),
        status: Map.get(item, "status"),
        end_time: parse_end_time(Map.get(item, "endTime"))
      }
    end)
  end

  defp parse_end_time(str) when is_binary(str) do
    Logger.debug(fn ->
      "[parse_end_time] raw input => #{inspect(str)} (length=#{String.length(str)})"
    end)

    if String.trim(str) == "" do
      nil
    else
      # Attempt to parse
      case DateTime.from_iso8601(str) do
        {:ok, dt, _offset} ->
          dt

        {:error, reason} ->
          Logger.error(
            "[parse_end_time] Invalid ISO string: #{inspect(str)}, reason: #{inspect(reason)}"
          )

          nil
      end
    end
  end

  defp parse_end_time(other) do
    Logger.error("[parse_end_time] Received non-string => #{inspect(other)}. Returning nil.")
    nil
  end

  defp remove_structures(system_id, removed_ids) do
    MapSystemStructure.by_system_id!(system_id)
    |> Enum.filter(fn s -> s.id in removed_ids end)
    |> Enum.each(&Ash.destroy!/1)
  end

  defp update_structures_in_db(system_id, updated_structs, updated_ids) do
    existing_records = MapSystemStructure.by_system_id!(system_id)

    Enum.each(existing_records, fn existing ->
      if existing.id in updated_ids do
        updated_data = Enum.find(updated_structs, fn u -> u.id == existing.id end)

        if updated_data do
          Logger.debug(fn ->
            "[Structure] about to update =>\n" <>
              inspect(updated_data, pretty: true)
          end)

          # remove PK so Ash doesn't treat it as a new record
          updated_data = Map.delete(updated_data, :id)

          # Merge update data with existing record to avoid nil required fields
          merged_data =
            Map.merge(Map.from_struct(existing), updated_data, fn _k, v1, v2 ->
              if is_nil(v2), do: v1, else: v2
            end)

          # Only keep fields accepted by Ash update action
          allowed_keys = [
            :system_id,
            :solar_system_name,
            :solar_system_id,
            :structure_type_id,
            :structure_type,
            :character_eve_id,
            :name,
            :notes,
            :owner_name,
            :owner_ticker,
            :owner_id,
            :status,
            :end_time
          ]

          filtered_data = Map.take(merged_data, allowed_keys)

          Logger.debug(fn ->
            "[Structure] update_structures_in_db: calling update for id=#{existing.id} with: #{inspect(filtered_data)}"
          end)

          new_record = MapSystemStructure.update(existing, filtered_data)

          Logger.debug(fn ->
            "[Structure] update_structures_in_db: update result for id=#{existing.id}: #{inspect(new_record)}"
          end)

          Logger.debug(fn ->
            "[Structure] updated record =>\n" <> inspect(new_record, pretty: true)
          end)
        end
      end
    end)
  end

  defp add_structures(added_structs) do
    Enum.each(added_structs, fn struct_map ->
      Logger.debug(fn ->
        "[Structure] Creating structure =>\n" <> inspect(struct_map, pretty: true)
      end)

      MapSystemStructure.create!(struct_map)
    end)
  end
end
