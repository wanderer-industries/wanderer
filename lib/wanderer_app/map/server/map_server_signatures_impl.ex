defmodule WandererApp.Map.Server.SignaturesImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Api.{MapSystem, MapSystemSignature}
  alias WandererApp.Character
  alias WandererApp.User.ActivityTracker
  alias WandererApp.Map.Server.{Impl, ConnectionsImpl, SystemsImpl}
  alias WandererApp.Utils.EVEUtil

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
           }) do
      do_update_signatures(
        state,
        system,
        char_id,
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
         character_id,
         user_id,
         delete_conn?,
         added_params,
         updated_params,
         removed_params
       ) do
    # Get character EVE ID for signature parsing
    character_eve_id =
      case Character.get_character(character_id) do
        {:ok, %{eve_id: eve_id}} ->
          eve_id

        _ ->
          Logger.warning("Could not get character EVE ID for character_id: #{character_id}")
          nil
      end

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
      apply_update_signature(state, existing, update)
    end)

    # 3. Additions & restorations
    added_eve_ids = Enum.map(added_sigs, & &1.eve_id)

    existing_index =
      existing_all
      |> Enum.filter(&(&1.eve_id in added_eve_ids))
      |> Map.new(&{&1.eve_id, &1})

    added_sigs
    |> Enum.each(fn sig ->
      case existing_index[sig.eve_id] do
        nil ->
          MapSystemSignature.create!(sig)

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
        character_id,
        added_ids
      )
    end

    if removed_ids != [] do
      track_activity(
        :signatures_removed,
        state.map_id,
        system.solar_system_id,
        user_id,
        character_id,
        removed_ids
      )
    end

    # 5. Broadcast to any live subscribers
    Impl.broadcast!(state.map_id, :signatures_updated, system.solar_system_id)

    # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
    # Send individual signature events
    Enum.each(added_sigs, fn sig ->
      WandererApp.ExternalEvents.broadcast(state.map_id, :signature_added, %{
        solar_system_id: system.solar_system_id,
        signature_id: sig.eve_id,
        name: sig.name,
        kind: sig.kind,
        group: sig.group,
        type: sig.type
      })
    end)

    Enum.each(removed_ids, fn sig_eve_id ->
      WandererApp.ExternalEvents.broadcast(state.map_id, :signature_removed, %{
        solar_system_id: system.solar_system_id,
        signature_id: sig_eve_id
      })
    end)

    # Also send the summary event for backwards compatibility
    WandererApp.ExternalEvents.broadcast(state.map_id, :signatures_updated, %{
      solar_system_id: system.solar_system_id,
      added_count: length(added_ids),
      updated_count: length(updated_ids),
      removed_count: length(removed_ids)
    })

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

    sig
    |> MapSystemSignature.destroy!()
  end

  def apply_update_signature(
        state,
        %MapSystemSignature{} = existing,
        update_params
      )
      when not is_nil(update_params) do
    case MapSystemSignature.update(
           existing,
           update_params |> Map.put(:update_forced_at, DateTime.utc_now())
         ) do
      {:ok, updated} ->
        maybe_update_connection_time_status(state, existing, updated)
        maybe_update_connection_mass_status(state, existing, updated)
        :ok

      {:error, reason} ->
        Logger.error("Failed to update signature #{existing.id}: #{inspect(reason)}")
    end
  end

  defp maybe_update_connection_time_status(
         state,
         %{custom_info: old_custom_info} = old_sig,
         %{custom_info: new_custom_info, system_id: system_id, linked_system_id: linked_system_id} =
           updated_sig
       )
       when not is_nil(linked_system_id) do
    old_time_status = get_time_status(old_custom_info)
    new_time_status = get_time_status(new_custom_info)

    if old_time_status != new_time_status do
      {:ok, source_system} = MapSystem.by_id(system_id)

      ConnectionsImpl.update_connection_time_status(state, %{
        solar_system_source_id: source_system.solar_system_id,
        solar_system_target_id: linked_system_id,
        time_status: new_time_status
      })
    end
  end

  defp maybe_update_connection_time_status(_state, _old_sig, _updated_sig), do: :ok

  defp maybe_update_connection_mass_status(
         state,
         %{type: old_type} = old_sig,
         %{type: new_type, system_id: system_id, linked_system_id: linked_system_id} =
           updated_sig
       )
       when not is_nil(linked_system_id) do
    if old_type != new_type do
      {:ok, source_system} = MapSystem.by_id(system_id)
      signature_ship_size_type = EVEUtil.get_wh_size(new_type)

      if not is_nil(signature_ship_size_type) do
        ConnectionsImpl.update_connection_ship_size_type(state, %{
          solar_system_source_id: source_system.solar_system_id,
          solar_system_target_id: linked_system_id,
          ship_size_type: signature_ship_size_type
        })
      end
    end
  end

  defp maybe_update_connection_mass_status(_state, _old_sig, _updated_sig), do: :ok

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
        temporary_name: sig["temporary_name"],
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

  defp get_time_status(nil), do: nil

  defp get_time_status(custom_info_json) do
    custom_info_json
    |> Jason.decode!()
    |> Map.get("time_status")
  end
end
