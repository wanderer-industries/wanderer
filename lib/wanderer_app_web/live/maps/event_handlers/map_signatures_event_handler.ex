defmodule WandererAppWeb.MapSignaturesEventHandler do
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

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
          {:ok, get_system_signatures(system.id)}

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

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "update_signatures",
        %{
          "system_id" => solar_system_id,
          "added" => added_signatures,
          "updated" => updated_signatures,
          "removed" => removed_signatures
        },
        %{
          assigns: %{
            current_user: current_user,
            map_id: map_id,
            map_user_settings: map_user_settings,
            user_characters: user_characters,
            user_permissions: %{update_system: true}
          }
        } = socket
      ) do
    first_character_eve_id =
      user_characters |> List.first()

    character =
      current_user.characters
      |> Enum.find(fn c -> c.eve_id === first_character_eve_id end)

    delete_connection_with_sigs =
      map_user_settings
      |> WandererApp.MapUserSettingsRepo.to_form_data!()
      |> WandererApp.MapUserSettingsRepo.get_boolean_setting("delete_connection_with_sigs")

    map_id
    |> WandererApp.Map.Server.update_signatures(%{
      solar_system_id: solar_system_id |> String.to_integer(),
      character: character,
      user_id: current_user.id,
      delete_connection_with_sigs: delete_connection_with_sigs,
      added_signatures: added_signatures,
      updated_signatures: updated_signatures,
      removed_signatures: removed_signatures
    })

    {:noreply, socket}
  end

  def handle_ui_event(
        "get_signatures",
        %{"system_id" => solar_system_id},
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    case WandererApp.Api.MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: solar_system_id |> String.to_integer()
         }) do
      {:ok, system} ->
        {:reply, %{signatures: get_system_signatures(system.id)}, socket}

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
            user_characters: user_characters,
            user_permissions: %{update_system: true}
          }
        } = socket
      ) do
    case WandererApp.Api.MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: solar_system_source
         }) do
      {:ok, system} ->
        first_character_eve_id =
          user_characters |> List.first()

        case not is_nil(first_character_eve_id) do
          true ->
            WandererApp.Api.MapSystemSignature.by_system_id!(system.id)
            |> Enum.filter(fn s -> s.eve_id == signature_eve_id end)
            |> Enum.each(fn s ->
              s
              |> WandererApp.Api.MapSystemSignature.update_group!(%{group: "Wormhole"})
              |> WandererApp.Api.MapSystemSignature.update_linked_system(%{
                linked_system_id: solar_system_target
              })
            end)

            map_system =
              WandererApp.Map.find_system_by_location(
                map_id,
                %{solar_system_id: solar_system_target}
              )

            if not is_nil(map_system) && is_nil(map_system.linked_sig_eve_id) do
              map_id
              |> WandererApp.Map.Server.update_system_linked_sig_eve_id(%{
                solar_system_id: solar_system_target,
                linked_sig_eve_id: signature_eve_id
              })
            end

            Phoenix.PubSub.broadcast!(WandererApp.PubSub, map_id, %{
              event: :signatures_updated,
              payload: solar_system_source
            })

            {:noreply, socket}

          _ ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "You should enable tracking for at least one character to work with signatures."
             )}
        end

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
            user_characters: user_characters,
            user_permissions: %{update_system: true}
          }
        } = socket
      ) do
    case WandererApp.Api.MapSystem.read_by_map_and_solar_system(%{
           map_id: map_id,
           solar_system_id: solar_system_source
         }) do
      {:ok, system} ->
        first_character_eve_id =
          user_characters |> List.first()

        case not is_nil(first_character_eve_id) do
          true ->
            WandererApp.Api.MapSystemSignature.by_system_id!(system.id)
            |> Enum.filter(fn s -> s.eve_id == signature_eve_id end)
            |> Enum.each(fn s ->
              s
              |> WandererApp.Api.MapSystemSignature.update_linked_system(%{
                linked_system_id: nil
              })
            end)

            Phoenix.PubSub.broadcast!(WandererApp.PubSub, map_id, %{
              event: :signatures_updated,
              payload: solar_system_source
            })

            {:noreply, socket}

          _ ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "You should enable tracking for at least one character to work with signatures."
             )}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  def get_system_signatures(system_id),
    do:
      system_id
      |> WandererApp.Api.MapSystemSignature.by_system_id!()
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
          :description,
          :kind,
          :group,
          :type,
          :custom_info
        ])
        |> Map.put(:linked_system, MapEventHandler.get_system_static_info(linked_system_id))
        |> Map.put(:inserted_at, inserted_at |> Calendar.strftime("%Y/%m/%d %H:%M:%S"))
        |> Map.put(:updated_at, updated_at |> Calendar.strftime("%Y/%m/%d %H:%M:%S"))
      end)
end
