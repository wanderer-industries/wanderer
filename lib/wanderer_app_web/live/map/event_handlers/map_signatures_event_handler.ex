defmodule WandererAppWeb.MapSignaturesEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererApp.Map.Server.SignaturesImpl
  alias WandererAppWeb.{MapCoreEventHandler, MapEventHandler}

  def handle_server_event(
        %{
          event: :maybe_link_signature,
          payload: %{
            character_id: character_id,
            solar_system_source: solar_system_source,
            solar_system_target: solar_system_target
          }
        },
        %{
          assigns: %{
            current_user: current_user,
            map_id: map_id,
            map_user_settings: map_user_settings
          }
        } = socket
      ) do
    is_user_character =
      current_user.characters |> Enum.map(& &1.id) |> Enum.member?(character_id)

    is_link_signature_on_splash =
      map_user_settings
      |> WandererApp.MapUserSettingsRepo.to_form_data!()
      |> WandererApp.MapUserSettingsRepo.get_boolean_setting("link_signature_on_splash")

    {:ok, signatures} =
      WandererApp.Api.MapSystem.read_by_map_and_solar_system(%{
        map_id: map_id,
        solar_system_id: solar_system_source
      })
      |> case do
        {:ok, system} ->
          {:ok,
           get_system_signatures(system.id)
           |> Enum.filter(fn signature ->
             is_nil(signature.linked_system) && signature.group == "Wormhole"
           end)}

        _ ->
          {:ok, []}
      end

    (is_user_character && is_link_signature_on_splash && not (signatures |> Enum.empty?()))
    |> case do
      true ->
        socket
        |> MapEventHandler.push_map_event("link_signature_to_system", %{
          solar_system_source: solar_system_source,
          solar_system_target: solar_system_target
        })

      false ->
        socket
    end
  end

  def handle_server_event(
        %{event: :signatures_updated, payload: solar_system_id},
        socket
      ),
      do:
        socket
        |> MapEventHandler.push_map_event(
          "signatures_updated",
          solar_system_id
        )

  def handle_server_event(
        %{event: :remove_signatures, payload: {solar_system_id, removed_signatures}},
        %{
          assigns: %{
            current_user: %{id: current_user_id},
            main_character_id: main_character_id,
            map_id: map_id,
            map_user_settings: map_user_settings,
            removed_sig_eve_ids: removed_sig_eve_ids
          }
        } = socket
      ) do
    solar_system_id = get_integer(solar_system_id)

    delete_connection_with_sigs =
      map_user_settings
      |> WandererApp.MapUserSettingsRepo.to_form_data!()
      |> WandererApp.MapUserSettingsRepo.get_boolean_setting("delete_connection_with_sigs")

    to_remove =
      removed_signatures
      |> Enum.filter(fn %{"eve_id" => eve_id} ->
        "#{solar_system_id}_#{eve_id}" in removed_sig_eve_ids
      end)

    to_remove_eve_ids =
      to_remove
      |> Enum.map(fn %{"eve_id" => eve_id} -> eve_id end)

    map_id
    |> WandererApp.Map.Server.update_signatures(%{
      solar_system_id: solar_system_id,
      character_id: main_character_id,
      user_id: current_user_id,
      delete_connection_with_sigs: delete_connection_with_sigs,
      added_signatures: [],
      updated_signatures: [],
      removed_signatures: to_remove
    })

    socket
    |> assign(
      removed_sig_eve_ids:
        removed_sig_eve_ids
        |> Enum.reject(fn sig_id ->
          sig_id in Enum.map(to_remove_eve_ids, &"#{solar_system_id}_#{&1}")
        end)
    )
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "load_signatures",
        _event,
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    {:ok, systems} = map_id |> WandererApp.Map.list_systems()

    system_signatures =
      systems
      |> Enum.reduce(%{}, fn %{id: system_id, solar_system_id: solar_system_id}, acc ->
        signatures =
          system_id
          |> get_system_signatures()
          |> Enum.filter(fn signature ->
            signature.group == "Wormhole"
          end)

        acc |> Map.put(solar_system_id, signatures)
      end)

    {:noreply,
     socket
     |> MapEventHandler.push_map_event(
       "map_updated",
       %{system_signatures: system_signatures}
     )}
  end

  def handle_ui_event(
        "update_signatures",
        %{
          "system_id" => solar_system_id,
          "added" => added_signatures,
          "updated" => updated_signatures,
          "removed" => removed_signatures,
          "deleteTimeout" => delete_timeout
        },
        %{
          assigns:
            %{
              current_user: %{id: current_user_id},
              map_id: map_id,
              main_character_id: main_character_id,
              map_user_settings: _map_user_settings,
              user_permissions: %{update_system: true}
            } = assigns
        } = socket
      )
      when not is_nil(main_character_id) do
    solar_system_id = get_integer(solar_system_id)

    old_removed_sig_eve_ids = Map.get(assigns, :removed_sig_eve_ids, [])

    new_removed_sig_eve_ids =
      removed_signatures
      |> Enum.map(fn %{"eve_id" => eve_id} -> eve_id end)

    Process.send_after(
      self(),
      %{event: :remove_signatures, payload: {solar_system_id, removed_signatures}},
      delete_timeout
    )

    map_id
    |> WandererApp.Map.Server.update_signatures(%{
      solar_system_id: solar_system_id,
      character_id: main_character_id,
      user_id: current_user_id,
      delete_connection_with_sigs: false,
      added_signatures: added_signatures,
      updated_signatures: updated_signatures,
      removed_signatures: []
    })

    saved_eve_ids =
      (added_signatures ++ updated_signatures) |> Enum.map(fn sig -> sig["eve_id"] end)

    saved_system_keys = saved_eve_ids |> Enum.map(&"#{solar_system_id}_#{&1}")
    just_removed_system_keys = new_removed_sig_eve_ids |> Enum.map(&"#{solar_system_id}_#{&1}")

    updated_removed_sig_eve_ids =
      (old_removed_sig_eve_ids ++ just_removed_system_keys)
      |> Enum.uniq()
      |> Enum.reject(fn key -> key in saved_system_keys end)

    {:noreply,
     socket
     |> assign(removed_sig_eve_ids: updated_removed_sig_eve_ids)}
  end

  def handle_ui_event(
        "get_signatures",
        %{"system_id" => solar_system_id},
        %{
          assigns:
            %{
              map_id: map_id
            } = assigns
        } = socket
      ) do
    solar_system_id_int = get_integer(solar_system_id)

    case WandererApp.Api.MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: solar_system_id_int
         }) do
      {:ok, system} ->
        removed_sig_eve_ids = Map.get(assigns, :removed_sig_eve_ids, [])

        system_signatures =
          get_system_signatures(system.id)
          |> Enum.map(fn sig ->
            if "#{solar_system_id_int}_#{sig.eve_id}" in removed_sig_eve_ids do
              sig |> Map.put(:deleted, true)
            else
              sig
            end
          end)

        {:reply, %{signatures: system_signatures}, socket}

      _ ->
        {:reply, %{signatures: []}, socket}
    end
  end

  def handle_ui_event(
        "link_signature_to_system",
        %{
          "signature_eve_id" => signature_eve_id,
          "solar_system_source" => solar_system_source,
          "solar_system_target" => solar_system_target
        },
        %{
          assigns: %{
            map_id: map_id,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } = socket
      )
      when not is_nil(main_character_id) and not is_nil(solar_system_source) and
             not is_nil(solar_system_target) do
    with solar_system_source <- get_integer(solar_system_source),
         solar_system_target <- get_integer(solar_system_target),
         source_system when not is_nil(source_system) <-
           WandererApp.Map.find_system_by_location(
             map_id,
             %{solar_system_id: solar_system_source}
           ),
         signature when not is_nil(signature) <-
           WandererApp.Api.MapSystemSignature.by_system_id!(source_system.id)
           |> Enum.find(fn s -> s.eve_id == signature_eve_id end),
         target_system when not is_nil(target_system) <-
           WandererApp.Map.find_system_by_location(
             map_id,
             %{solar_system_id: solar_system_target}
           ) do
      SignaturesImpl.link_signature(map_id, signature, solar_system_target)
      {:noreply, socket}
    else
      _ ->
        {:noreply, socket}
    end
  end

  def handle_ui_event(
        "unlink_signature",
        %{
          "signature_eve_id" => signature_eve_id,
          "solar_system_source" => solar_system_source
        },
        %{
          assigns: %{
            map_id: map_id,
            main_character_id: main_character_id,
            has_tracked_characters?: true,
            user_permissions: %{update_system: true}
          }
        } = socket
      )
      when not is_nil(main_character_id) do
    solar_system_source = get_integer(solar_system_source)

    case WandererApp.Api.MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: solar_system_source
         }) do
      {:ok, system} ->
        WandererApp.Api.MapSystemSignature.by_system_id!(system.id)
        |> Enum.filter(fn s -> s.eve_id == signature_eve_id end)
        |> Enum.each(fn s ->
          SignaturesImpl.unlink_signature(map_id, s)
        end)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_ui_event(
        "undo_delete_signatures",
        %{"system_id" => solar_system_id, "eve_ids" => eve_ids} = _payload,
        %{
          assigns: %{
            map_id: map_id,
            main_character_id: main_character_id,
            user_permissions: %{update_system: true},
            removed_sig_eve_ids: removed_sig_eve_ids
          }
        } = socket
      )
      when not is_nil(main_character_id) do
    solar_system_id_int = get_integer(solar_system_id)
    WandererApp.Map.Server.Impl.broadcast!(map_id, :signatures_updated, solar_system_id)

    {:noreply,
     socket
     |> assign(
       removed_sig_eve_ids:
         removed_sig_eve_ids
         |> Enum.reject(fn sig_id ->
           sig_id in Enum.map(eve_ids, &"#{solar_system_id_int}_#{&1}")
         end)
     )}
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  def get_system_signatures(system_id) do
    signatures = system_id |> WandererApp.Api.MapSystemSignature.by_system_id!()

    character_eve_ids =
      signatures |> Enum.map(& &1.character_eve_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    character_names_map =
      character_eve_ids
      |> Enum.reduce(%{}, fn eve_id, acc ->
        case WandererApp.Character.get_by_eve_id(eve_id) do
          {:ok, character} -> Map.put(acc, eve_id, character.name)
          _ -> acc
        end
      end)

    signatures
    |> Enum.map(fn %{
                     inserted_at: inserted_at,
                     updated_at: updated_at,
                     linked_system_id: linked_system_id
                   } = s ->
      s
      |> Map.take([
        :eve_id,
        :character_eve_id,
        :name,
        :temporary_name,
        :description,
        :kind,
        :group,
        :type,
        :custom_info
      ])
      |> Map.put(:character_name, Map.get(character_names_map, s.character_eve_id))
      |> Map.put(:linked_system, MapEventHandler.get_system_static_info(linked_system_id))
      |> Map.put(:inserted_at, inserted_at |> Calendar.strftime("%Y/%m/%d %H:%M:%S"))
      |> Map.put(:updated_at, updated_at |> Calendar.strftime("%Y/%m/%d %H:%M:%S"))
    end)
  end

  defp get_integer(nil), do: nil
  defp get_integer(value) when is_binary(value), do: String.to_integer(value)
  defp get_integer(value), do: value
end
