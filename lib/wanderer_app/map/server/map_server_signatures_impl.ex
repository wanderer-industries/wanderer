defmodule WandererApp.Map.Server.SignaturesImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Api.{MapSystem, MapSystemSignature}
  alias WandererApp.Character
  alias WandererApp.Map.Server
  alias WandererApp.Map.Server.{ConnectionsImpl, Impl, SystemsImpl}
  alias WandererApp.User.ActivityTracker
  alias WandererApp.Utils.EVEUtil

  @doc """
  Public entrypoint for updating signatures on a map system.
  """
  def update_signatures(
        map_id,
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
        map_id,
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
    end
  end

  def update_signatures(_map_id, _), do: :ok

  defp do_update_signatures(
         map_id,
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
    |> Enum.each(&remove_signature(map_id, &1, system, delete_conn?))

    # 2. Updates
    existing_current
    |> Enum.filter(&(&1.eve_id in updated_ids))
    |> Enum.each(fn existing ->
      update = Enum.find(updated_sigs, &(&1.eve_id == existing.eve_id))
      apply_update_signature(map_id, existing, update)
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

        existing ->
          # If signature already exists, update it instead of ignoring
          # This handles the case where frontend sends existing sigs as "added"
          apply_update_signature(map_id, existing, sig)
      end
    end)

    # 4. Activity tracking
    if added_ids != [] do
      track_activity(
        :signatures_added,
        map_id,
        system.solar_system_id,
        user_id,
        character_id,
        added_ids
      )
    end

    if removed_ids != [] do
      track_activity(
        :signatures_removed,
        map_id,
        system.solar_system_id,
        user_id,
        character_id,
        removed_ids
      )
    end

    # 5. Broadcast to any live subscribers
    Impl.broadcast!(map_id, :signatures_updated, system.solar_system_id)

    # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
    # Send individual signature events
    Enum.each(added_sigs, fn sig ->
      WandererApp.ExternalEvents.broadcast(map_id, :signature_added, %{
        solar_system_id: system.solar_system_id,
        signature_id: sig.eve_id,
        name: sig.name,
        kind: sig.kind,
        group: sig.group,
        type: sig.type
      })
    end)

    Enum.each(removed_ids, fn sig_eve_id ->
      WandererApp.ExternalEvents.broadcast(map_id, :signature_removed, %{
        solar_system_id: system.solar_system_id,
        signature_id: sig_eve_id
      })
    end)

    # Also send the summary event for backwards compatibility
    WandererApp.ExternalEvents.broadcast(map_id, :signatures_updated, %{
      solar_system_id: system.solar_system_id,
      added_count: length(added_ids),
      updated_count: length(updated_ids),
      removed_count: length(removed_ids)
    })

    # Always return :ok - external event failures should not affect the main operation
    :ok
  end

  defp remove_signature(map_id, sig, system, delete_conn?) do
    # Check if this signature is the active one for the target system
    # This prevents deleting connections when old/orphan signatures are removed
    is_active = sig.linked_system_id && is_active_signature_for_target?(map_id, sig)

    # Only delete connection if this signature is the active one
    if delete_conn? && is_active do
      ConnectionsImpl.delete_connection(map_id, %{
        solar_system_source_id: system.solar_system_id,
        solar_system_target_id: sig.linked_system_id
      })
    end

    # Only clear linked_sig_eve_id if this signature is the active one
    if is_active do
      SystemsImpl.update_system_linked_sig_eve_id(map_id, %{
        solar_system_id: sig.linked_system_id,
        linked_sig_eve_id: nil
      })
    end

    # Handle back-link signature removal
    # If there is exactly one signature in the target system pointing back, remove it
    if sig.linked_system_id do
      case MapSystem.read_by_map_and_solar_system(%{
             map_id: map_id,
             solar_system_id: sig.linked_system_id
           }) do
        {:ok, target_system} ->
          back_link_sigs =
            target_system.id
            |> MapSystemSignature.by_system_id!()
            |> Enum.filter(fn s -> s.linked_system_id == system.solar_system_id end)

          other_source_sigs =
            system.id
            |> MapSystemSignature.by_system_id!()
            |> Enum.filter(fn s ->
              s.eve_id != sig.eve_id and s.linked_system_id == sig.linked_system_id
            end)

          if length(back_link_sigs) == 1 and length(other_source_sigs) == 0 do
            back_sig = hd(back_link_sigs)

            # Check if back_sig is active for our system before we destroy it
            back_sig_is_active = is_active_signature_for_target?(map_id, back_sig)

            # Ensure the connection is deleted since we're removing the only linked signatures.
            # (If `is_active` was true, the connection was already deleted above)
            if delete_conn? and not is_active do
              ConnectionsImpl.delete_connection(map_id, %{
                solar_system_source_id: system.solar_system_id,
                solar_system_target_id: sig.linked_system_id
              })
            end

            if back_sig_is_active do
              SystemsImpl.update_system_linked_sig_eve_id(map_id, %{
                solar_system_id: system.solar_system_id,
                linked_sig_eve_id: nil
              })
            end

            back_sig |> MapSystemSignature.destroy!()

            # Broadcast removal
            Impl.broadcast!(map_id, :signatures_updated, target_system.solar_system_id)

            WandererApp.ExternalEvents.broadcast(map_id, :signature_removed, %{
              solar_system_id: target_system.solar_system_id,
              signature_id: back_sig.eve_id
            })

            WandererApp.ExternalEvents.broadcast(map_id, :signatures_updated, %{
              solar_system_id: target_system.solar_system_id,
              added_count: 0,
              updated_count: 0,
              removed_count: 1
            })
          end

        _ ->
          :ok
      end
    end

    sig
    |> MapSystemSignature.destroy!()
  end

  defp is_active_signature_for_target?(map_id, sig) do
    case MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: sig.linked_system_id
         }) do
      {:ok, target_system} -> target_system.linked_sig_eve_id == sig.eve_id
      _ -> false
    end
  end

  def apply_update_signature(
        map_id,
        %MapSystemSignature{} = existing,
        update_params
      )
      when not is_nil(update_params) do
    case MapSystemSignature.update(
           existing,
           update_params |> Map.put(:update_forced_at, DateTime.utc_now())
         ) do
      {:ok, updated} ->
        maybe_update_connection_time_status(map_id, existing, updated)
        maybe_update_connection_mass_status(map_id, existing, updated)
        maybe_sync_custom_mass_status_to_connection(map_id, existing, updated)
        :ok

      {:error, reason} ->
        Logger.error("Failed to update signature #{existing.id}: #{inspect(reason)}")
    end
  end

  defp maybe_update_connection_time_status(
         map_id,
         %{custom_info: old_custom_info} = _old_sig,
         %{custom_info: new_custom_info, system_id: system_id, linked_system_id: linked_system_id} =
           _updated_sig
       )
       when not is_nil(linked_system_id) do
    old_time_status = get_time_status(old_custom_info)
    new_time_status = get_time_status(new_custom_info)

    if old_time_status != new_time_status do
      {:ok, source_system} = MapSystem.by_id(system_id)

      ConnectionsImpl.update_connection_time_status(map_id, %{
        solar_system_source_id: source_system.solar_system_id,
        solar_system_target_id: linked_system_id,
        time_status: new_time_status
      })
    end
  end

  defp maybe_update_connection_time_status(_map_id, _old_sig, _updated_sig), do: :ok

  defp maybe_update_connection_mass_status(
         map_id,
         %{type: old_type} = _old_sig,
         %{type: new_type, system_id: system_id, linked_system_id: linked_system_id} =
           _updated_sig
       )
       when not is_nil(linked_system_id) do
    if old_type != new_type do
      {:ok, source_system} = MapSystem.by_id(system_id)
      signature_ship_size_type = EVEUtil.get_wh_size(new_type)

      if not is_nil(signature_ship_size_type) do
        ConnectionsImpl.update_connection_ship_size_type(map_id, %{
          solar_system_source_id: source_system.solar_system_id,
          solar_system_target_id: linked_system_id,
          ship_size_type: signature_ship_size_type
        })
      end
    end
  end

  defp maybe_update_connection_mass_status(_map_id, _old_sig, _updated_sig), do: :ok

  defp maybe_sync_custom_mass_status_to_connection(
         map_id,
         %{custom_info: old_custom_info} = _old_sig,
         %{custom_info: new_custom_info, system_id: system_id, linked_system_id: linked_system_id} =
           _updated_sig
       )
       when not is_nil(linked_system_id) do
    old_mass_status = get_mass_status(old_custom_info)
    new_mass_status = get_mass_status(new_custom_info)

    if old_mass_status != new_mass_status and not is_nil(new_mass_status) do
      {:ok, source_system} = MapSystem.by_id(system_id)

      ConnectionsImpl.update_connection_mass_status(map_id, %{
        solar_system_source_id: source_system.solar_system_id,
        solar_system_target_id: linked_system_id,
        mass_status: new_mass_status
      })
    end
  end

  defp maybe_sync_custom_mass_status_to_connection(_map_id, _old_sig, _updated_sig), do: :ok

  @doc """
  Finds the "forward" signature in a target system that links back to the source system.
  Used for back-link detection: when a K162 is linked from System B → System A,
  finds the existing signature in System A that already links to System B (e.g., H296).
  """
  def find_forward_signature(target_system_uuid, source_solar_system_id) do
    target_system_uuid
    |> MapSystemSignature.by_system_id!()
    |> Enum.find(fn sig -> sig.linked_system_id == source_solar_system_id end)
  rescue
    e ->
      Logger.warning("[find_forward_signature] Error: #{inspect(e)}")
      nil
  end

  @doc """
  Wrapper for updating a signature's linked_system_id with logging.
  Logs all unlink operations (when linked_system_id is set to nil) with context
  to help diagnose unexpected unlinking issues.
  """
  def update_signature_linked_system(signature, %{linked_system_id: nil} = params) do
    # Log all unlink operations with context for debugging
    Logger.warning(
      "[Signature Unlink] eve_id=#{signature.eve_id} " <>
        "system_id=#{signature.system_id} " <>
        "old_linked_system_id=#{signature.linked_system_id} " <>
        "stacktrace=#{format_stacktrace()}"
    )

    MapSystemSignature.update_linked_system(signature, params)
  end

  def update_signature_linked_system(signature, params) do
    MapSystemSignature.update_linked_system(signature, params)
  end

  defp format_stacktrace do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

    stacktrace
    |> Enum.take(10)
    |> Enum.map_join(" <- ", fn {mod, fun, arity, _} ->
      "#{inspect(mod)}.#{fun}/#{arity}"
    end)
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
      base = %{
        system_id: system_id,
        eve_id: sig["eve_id"],
        name: sig["name"],
        temporary_name: sig["temporary_name"],
        description: Map.get(sig, "description"),
        kind: sig["kind"],
        group: sig["group"],
        type: Map.get(sig, "type"),
        custom_info: Map.get(sig, "custom_info"),
        # Use character_eve_id from sig if provided, otherwise use the default
        character_eve_id: Map.get(sig, "character_eve_id", character_eve_id),
        deleted: false
      }

      # Only include linked_system_id when explicitly provided in the payload.
      # Frontend sends "linked_system" (object), not "linked_system_id" (integer).
      # Including nil would silently clear the DB value via the Ash :update action.
      if Map.has_key?(sig, "linked_system_id") do
        Map.put(base, :linked_system_id, sig["linked_system_id"])
      else
        base
      end
    end)
  end

  defp get_time_status(nil), do: nil

  defp get_time_status(custom_info_json) do
    custom_info_json
    |> Jason.decode!()
    |> Map.get("time_status")
  end

  defp get_mass_status(nil), do: nil

  defp get_mass_status(custom_info_json) do
    custom_info_json
    |> Jason.decode!()
    |> Map.get("mass_status")
  end

  @doc """
  Links a signature to a target solar system and synchronizes naming/connections.
  """
  def link_signature(map_id, signature, solar_system_target) do
    with {:ok, source_system} <- MapSystem.by_id(signature.system_id),
         true <- source_system.map_id == map_id,
         target_system when not is_nil(target_system) <-
           WandererApp.Map.find_system_by_location(map_id, %{solar_system_id: solar_system_target}) do
      prev_linked_system_id = signature.linked_system_id

      # Update signature group to Wormhole and set linked_system_id
      {:ok, updated_signature} =
        signature
        |> MapSystemSignature.update_group!(%{group: "Wormhole"})
        |> MapSystemSignature.update_linked_system(%{linked_system_id: solar_system_target})

      if not is_nil(prev_linked_system_id) and prev_linked_system_id != solar_system_target do
        with prev_target when not is_nil(prev_target) <-
               WandererApp.Map.find_system_by_location(map_id, %{
                 solar_system_id: prev_linked_system_id
               }),
             true <- prev_target.linked_sig_eve_id == signature.eve_id do
          if not is_nil(prev_target.temporary_name) do
            Server.update_system_temporary_name(map_id, %{
              solar_system_id: prev_linked_system_id,
              temporary_name: nil
            })
          end

          Server.update_system_linked_sig_eve_id(map_id, %{
            solar_system_id: prev_linked_system_id,
            linked_sig_eve_id: nil
          })
        else
          _ -> :ok
        end
      end

      forward_sig =
        find_forward_signature(
          target_system.id,
          source_system.solar_system_id
        )

      has_active_linked_sig? =
        if is_nil(target_system.linked_sig_eve_id) do
          false
        else
          case MapSystemSignature.by_linked_system_id(solar_system_target) do
            {:ok, sigs} ->
              Enum.any?(sigs, fn s ->
                s.eve_id == target_system.linked_sig_eve_id and
                  match?({:ok, %{map_id: ^map_id}}, MapSystem.by_id(s.system_id))
              end)

            _ ->
              false
          end
        end

      is_return_sig? = return_hole_signature?(signature)

      # Only set linked_sig_eve_id and temporary_name if this is not a return hole
      updated_signature =
        if not is_return_sig? and
             (not has_active_linked_sig? or target_system.linked_sig_eve_id == signature.eve_id) and
             (target_system.linked_sig_eve_id == signature.eve_id or is_nil(forward_sig)) do
          # Set the target system's linked_sig_eve_id
          Server.update_system_linked_sig_eve_id(map_id, %{
            solar_system_id: solar_system_target,
            linked_sig_eve_id: signature.eve_id
          })

          # Copy temporary_name if present
          if not is_nil(signature.temporary_name) and signature.temporary_name != "" do
            Server.update_system_temporary_name(map_id, %{
              solar_system_id: solar_system_target,
              temporary_name: signature.temporary_name
            })

            updated_signature
          else
            if target_system.linked_sig_eve_id == signature.eve_id do
              if not is_nil(target_system.temporary_name) do
                Server.update_system_temporary_name(map_id, %{
                  solar_system_id: solar_system_target,
                  temporary_name: nil,
                  skip_signature_sync: true
                })
              end

              updated_signature
            else
              SystemsImpl.maybe_sync_to_signatures(
                map_id,
                WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(
                  map_id,
                  solar_system_target
                )
              )

              MapSystemSignature.by_id!(updated_signature.id)
            end
          end
        else
          updated_signature
        end

      # Update connection time_status and mass_status from signature custom_info
      {signature_time_status, signature_mass_status} =
        if not is_nil(signature.custom_info) do
          case Jason.decode(signature.custom_info) do
            {:ok, decoded} -> {Map.get(decoded, "time_status"), Map.get(decoded, "mass_status")}
            {:error, _} -> {nil, nil}
          end
        else
          {nil, nil}
        end

      # Update connection ship_size_type from signature wormhole type
      signature_ship_size_type = EVEUtil.get_wh_size(signature.type)

      # Back-link detection: if current signature yields no ship_size_type (e.g., K162),
      # look for a forward signature in the target system that links back to our source
      {signature_time_status, signature_ship_size_type, signature_mass_status} =
        if is_nil(signature_ship_size_type) do
          case forward_sig do
            nil ->
              {signature_time_status, signature_ship_size_type, signature_mass_status}

            forward_sig ->
              Logger.info(
                "[link_signature] Back-link detected: " <>
                  "using forward sig type=#{forward_sig.type} from target system"
              )

              forward_ship_size = EVEUtil.get_wh_size(forward_sig.type)

              {forward_time_status, forward_mass_status} =
                if not is_nil(forward_sig.custom_info) do
                  case Jason.decode(forward_sig.custom_info) do
                    {:ok, decoded} ->
                      # Always prefer forward sig values over K162 defaults
                      fwd_time = Map.get(decoded, "time_status") || signature_time_status
                      fwd_mass = Map.get(decoded, "mass_status") || signature_mass_status

                      {fwd_time, fwd_mass}

                    {:error, _} ->
                      {signature_time_status, signature_mass_status}
                  end
                else
                  {signature_time_status, signature_mass_status}
                end

              {forward_time_status, forward_ship_size, forward_mass_status}
          end
        else
          {signature_time_status, signature_ship_size_type, signature_mass_status}
        end

      if not is_nil(signature_time_status) do
        Server.update_connection_time_status(map_id, %{
          solar_system_source_id: source_system.solar_system_id,
          solar_system_target_id: solar_system_target,
          time_status: signature_time_status
        })
      end

      if not is_nil(signature_ship_size_type) do
        Server.update_connection_ship_size_type(map_id, %{
          solar_system_source_id: source_system.solar_system_id,
          solar_system_target_id: solar_system_target,
          ship_size_type: signature_ship_size_type
        })
      end

      if not is_nil(signature_mass_status) do
        Server.update_connection_mass_status(map_id, %{
          solar_system_source_id: source_system.solar_system_id,
          solar_system_target_id: solar_system_target,
          mass_status: signature_mass_status
        })
      end

      # Update K162's custom_info to match the resolved connection values
      updated_signature =
        if not is_nil(signature_time_status) or not is_nil(signature_mass_status) do
          updated_custom_info =
            (signature.custom_info || "{}")
            |> Jason.decode!()
            |> then(fn decoded ->
              decoded
              |> then(fn d ->
                if not is_nil(signature_time_status),
                  do: Map.put(d, "time_status", signature_time_status),
                  else: d
              end)
              |> then(fn d ->
                if not is_nil(signature_mass_status),
                  do: Map.put(d, "mass_status", signature_mass_status),
                  else: d
              end)
            end)
            |> Jason.encode!()

          case MapSystemSignature.update(updated_signature, %{custom_info: updated_custom_info}) do
            {:ok, sig} -> sig
            _ -> updated_signature
          end
        else
          updated_signature
        end

      # Broadcast update
      Impl.broadcast!(map_id, :signatures_updated, source_system.solar_system_id)

      {:ok, updated_signature}
    else
      false -> {:error, :not_found}
      nil -> {:error, :target_system_not_found}
      err -> err
    end
  end

  @doc """
  Unlinks a signature and clears target system link metadata if matching.
  """
  def unlink_signature(map_id, signature) do
    with {:ok, source_system} <- MapSystem.by_id(signature.system_id),
         :ok <- if(source_system.map_id == map_id, do: :ok, else: {:error, :not_found}),
         :ok <- if(not is_nil(signature.linked_system_id), do: :ok, else: {:error, :not_linked}) do
      prev_linked_system_id = signature.linked_system_id

      # Clear the signature's linked_system_id using the wrapper for logging before cleaning up target system
      {:ok, updated_signature} =
        update_signature_linked_system(signature, %{
          linked_system_id: nil
        })

      # Clear the target system's linked_sig_eve_id only if it matches this signature
      with target_system when not is_nil(target_system) <-
             WandererApp.Map.find_system_by_location(map_id, %{
               solar_system_id: prev_linked_system_id
             }),
           true <- target_system.linked_sig_eve_id == signature.eve_id do
        if not is_nil(target_system.temporary_name) and
             target_system.temporary_name == signature.temporary_name do
          Server.update_system_temporary_name(map_id, %{
            solar_system_id: prev_linked_system_id,
            temporary_name: nil
          })
        end

        Server.update_system_linked_sig_eve_id(map_id, %{
          solar_system_id: prev_linked_system_id,
          linked_sig_eve_id: nil
        })
      else
        _ -> :ok
      end

      Impl.broadcast!(map_id, :signatures_updated, source_system.solar_system_id)

      {:ok, updated_signature}
    end
  end

  @doc """
  Checks if a signature represents a return-hole wormhole.
  """
  def return_hole_signature?(signature) do
    temp_name = Map.get(signature, :temporary_name)

    custom_info_return? =
      case Map.get(signature, :custom_info) do
        info when is_binary(info) and info != "" ->
          case Jason.decode(info) do
            {:ok, decoded} when is_map(decoded) ->
              is_nil(Map.get(decoded, "bookmark_index")) and
                (is_binary(Map.get(decoded, "bookmark_index_chained")) or
                   is_binary(Map.get(decoded, "bookmark_index_chained_letters")))

            _ ->
              false
          end

        _ ->
          false
      end

    temp_name == "<" or custom_info_return?
  end
end
