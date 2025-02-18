defmodule WandererApp.Map.Server.SignaturesImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.Server.{Impl, ConnectionsImpl, SystemsImpl}

  def update_signatures(
        %{map_id: map_id} = state,
        %{
          solar_system_id: solar_system_id,
          character: character,
          user_id: user_id,
          delete_connection_with_sigs: delete_connection_with_sigs,
          added_signatures: added_signatures,
          updated_signatures: updated_signatures,
          removed_signatures: removed_signatures
        } =
          _signatures_update
      ) do
    WandererApp.Api.MapSystem.read_by_map_and_solar_system(%{
      map_id: map_id,
      solar_system_id: solar_system_id
    })
    |> case do
      {:ok, system} ->
        character_eve_id = character.eve_id

        case not is_nil(character_eve_id) do
          true ->
            added_signatures =
              added_signatures
              |> parse_signatures(character_eve_id, system.id)

            updated_signatures =
              updated_signatures
              |> parse_signatures(character_eve_id, system.id)

            updated_signatures_eve_ids =
              updated_signatures
              |> Enum.map(fn s -> s.eve_id end)

            removed_signatures_eve_ids =
              removed_signatures
              |> parse_signatures(character_eve_id, system.id)
              |> Enum.map(fn s -> s.eve_id end)

            WandererApp.Api.MapSystemSignature.by_system_id!(system.id)
            |> Enum.filter(fn s -> s.eve_id in removed_signatures_eve_ids end)
            |> Enum.each(fn s ->
              if delete_connection_with_sigs && not is_nil(s.linked_system_id) do
                state
                |> ConnectionsImpl.delete_connection(%{
                  solar_system_source_id: system.solar_system_id,
                  solar_system_target_id: s.linked_system_id
                })
              end

              if not is_nil(s.linked_system_id) do
                state
                |> SystemsImpl.update_system_linked_sig_eve_id(%{
                  solar_system_id: s.linked_system_id,
                  linked_sig_eve_id: nil
                })
              end

              s
              |> Ash.destroy!()
            end)

            WandererApp.Api.MapSystemSignature.by_system_id!(system.id)
            |> Enum.filter(fn s -> s.eve_id in updated_signatures_eve_ids end)
            |> Enum.each(fn s ->
              updated = updated_signatures |> Enum.find(fn u -> u.eve_id == s.eve_id end)

              if not is_nil(updated) do
                s
                |> WandererApp.Api.MapSystemSignature.update(
                  updated
                  |> Map.put(:updated, System.os_time())
                )
              end
            end)

            added_signatures
            |> Enum.each(fn s ->
              s |> WandererApp.Api.MapSystemSignature.create!()
            end)

            added_signatures_eve_ids =
              added_signatures
              |> Enum.map(fn s -> s.eve_id end)

            if not is_nil(character) &&
                 not (added_signatures_eve_ids |> Enum.empty?()) do
              WandererApp.User.ActivityTracker.track_map_event(:signatures_added, %{
                character_id: character.id,
                user_id: user_id,
                map_id: map_id,
                solar_system_id: system.solar_system_id,
                signatures: added_signatures_eve_ids
              })
            end

            if not is_nil(character) &&
                 not (removed_signatures_eve_ids |> Enum.empty?()) do
              WandererApp.User.ActivityTracker.track_map_event(:signatures_removed, %{
                character_id: character.id,
                user_id: user_id,
                map_id: map_id,
                solar_system_id: system.solar_system_id,
                signatures: removed_signatures_eve_ids
              })
            end

            Impl.broadcast!(map_id, :signatures_updated, system.solar_system_id)

            state

          _ ->
            state
        end

      _ ->
        state
    end
  end

  defp parse_signatures(signatures, character_eve_id, system_id),
    do:
      signatures
      |> Enum.map(fn %{
                       "eve_id" => eve_id,
                       "name" => name,
                       "kind" => kind,
                       "group" => group
                     } = signature ->
        %{
          system_id: system_id,
          eve_id: eve_id,
          name: name,
          description: Map.get(signature, "description"),
          kind: kind,
          group: group,
          type: Map.get(signature, "type"),
          custom_info: Map.get(signature, "custom_info"),
          character_eve_id: character_eve_id
        }
      end)
end
