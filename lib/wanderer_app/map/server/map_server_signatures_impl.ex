defmodule WandererApp.Map.Server.SignaturesImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Api.{MapSystem, MapSystemSignature}
  alias WandererApp.Character
  alias WandererApp.User.ActivityTracker
  alias WandererApp.Map.Server.{Impl, ConnectionsImpl, SystemsImpl}

  @doc """
  Public entrypoint for updating signatures on a map system.
  """
  def update_signatures(
        %{map_id: map_id} = state,
        %{
          solar_system_id: system_solar_id,
          character_id: char_id,
          user_id: user_id,
          delete_connection_with_sigs: delete_conn?,
          added_signatures: added_params,
          updated_signatures: updated_params,
          removed_signatures: removed_params
        }
      )
      when not is_nil(char_id) do
    with {:ok, system} <-
           MapSystem.read_by_map_and_solar_system(%{
             map_id: map_id,
             solar_system_id: system_solar_id
           }),
         {:ok, %{eve_id: char_eve_id}} <- Character.get_character(char_id) do
      do_update_signatures(
        state,
        system,
        char_eve_id,
        user_id,
        delete_conn?,
        added_params,
        updated_params,
        removed_params
      )
    else
      error ->
        Logger.warning("Skipping signature update: #{inspect(error)}")
        state
    end
  end

  def update_signatures(state, _), do: state

  defp do_update_signatures(
         state,
         system,
         character_eve_id,
         user_id,
         delete_conn?,
         added_params,
         updated_params,
         removed_params
       ) do
    # parse incoming DTOs
    added_sigs = parse_signatures(added_params, character_eve_id, system.id)
    updated_sigs = parse_signatures(updated_params, character_eve_id, system.id)
    removed_sigs = parse_signatures(removed_params, character_eve_id, system.id)

    # fetch both current & all (including deleted) signatures once
    existing_current = MapSystemSignature.by_system_id!(system.id)
    existing_all = MapSystemSignature.by_system_id_all!(system.id)

    removed_ids = Enum.map(removed_sigs, & &1.eve_id)
    updated_ids = Enum.map(updated_sigs, & &1.eve_id)
    added_ids = Enum.map(added_sigs, & &1.eve_id)

    # 1. Removals
    existing_current
    |> Enum.filter(&(&1.eve_id in removed_ids))
    |> Enum.each(&remove_signature(&1, state, system, delete_conn?))

    # 2. Updates
    existing_current
    |> Enum.filter(&(&1.eve_id in updated_ids))
    |> Enum.each(fn existing ->
      update = Enum.find(updated_sigs, &(&1.eve_id == existing.eve_id))
      apply_update_signature(existing, update)
    end)

    # 3. Additions & restorations
    added_eve_ids = Enum.map(added_sigs, & &1.eve_id)

    existing_index =
      MapSystemSignature.by_system_id_all!(system.id)
      |> Enum.filter(&(&1.eve_id in added_eve_ids))
      |> Map.new(&{&1.eve_id, &1})

    added_sigs
    |> Enum.each(fn sig ->
      case existing_index[sig.eve_id] do
        nil ->
          MapSystemSignature.create!(sig)

        %MapSystemSignature{deleted: true} = deleted_sig ->
          MapSystemSignature.update!(
            deleted_sig,
            Map.take(sig, [
              :name,
              :description,
              :kind,
              :group,
              :type,
              :character_eve_id,
              :custom_info,
              :deleted,
              :update_forced_at
            ])
          )

        _ ->
          :noop
      end
    end)

    # 4. Activity tracking
    if added_ids != [] do
      track_activity(
        :signatures_added,
        state.map_id,
        system.solar_system_id,
        user_id,
        character_eve_id,
        added_ids
      )
    end

    if removed_ids != [] do
      track_activity(
        :signatures_removed,
        state.map_id,
        system.solar_system_id,
        user_id,
        character_eve_id,
        removed_ids
      )
    end

    # 5. Broadcast to any live subscribers
    Impl.broadcast!(state.map_id, :signatures_updated, system.solar_system_id)

    state
  end

  defp remove_signature(sig, state, system, delete_conn?) do
    # optionally remove the linked connection
    if delete_conn? && sig.linked_system_id do
      ConnectionsImpl.delete_connection(state, %{
        solar_system_source_id: system.solar_system_id,
        solar_system_target_id: sig.linked_system_id
      })
    end

    # clear any linked_sig_eve_id on the target system
    if sig.linked_system_id do
      SystemsImpl.update_system_linked_sig_eve_id(state, %{
        solar_system_id: sig.linked_system_id,
        linked_sig_eve_id: nil
      })
    end

    # mark as deleted
    MapSystemSignature.update!(sig, %{deleted: true})
  end

  defp apply_update_signature(%MapSystemSignature{} = existing, update_params)
       when not is_nil(update_params) do
    case MapSystemSignature.update(
           existing,
           update_params |> Map.put(:update_forced_at, DateTime.utc_now())
         ) do
      {:ok, _updated} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to update signature #{existing.id}: #{inspect(reason)}")
    end
  end

  defp track_activity(event, map_id, solar_system_id, user_id, character_id, signatures) do
    ActivityTracker.track_map_event(event, %{
      map_id: map_id,
      solar_system_id: solar_system_id,
      user_id: user_id,
      character_id: character_id,
      signatures: signatures
    })
  end

  @doc false
  defp parse_signatures(signatures, character_eve_id, system_id) do
    Enum.map(signatures, fn sig ->
      %{
        system_id: system_id,
        eve_id: sig["eve_id"],
        name: sig["name"],
        description: Map.get(sig, "description"),
        kind: sig["kind"],
        group: sig["group"],
        type: Map.get(sig, "type"),
        custom_info: Map.get(sig, "custom_info"),
        character_eve_id: character_eve_id,
        deleted: false
      }
    end)
  end
end
