defmodule WandererApp.Map.Operations.Signatures do
  @moduledoc """
  CRUD for map signatures.
  """

  require Logger
  alias WandererApp.Map.Operations
  alias WandererApp.Map.Operations.Connections
  alias WandererApp.Api.{Character, MapSystem, MapSystemSignature}
  alias WandererApp.Map.Server
  alias WandererApp.Utils.EVEUtil

  @spec validate_character_eve_id(map() | nil, String.t()) ::
          {:ok, String.t()} | {:error, :invalid_character} | {:error, :unexpected_error}
  defp validate_character_eve_id(params, fallback_char_id) when is_map(params) do
    case Map.get(params, "character_eve_id") do
      nil ->
        {:ok, fallback_char_id}

      provided_char_eve_id when is_binary(provided_char_eve_id) ->
        case Character.by_eve_id(provided_char_eve_id) do
          {:ok, character} ->
            {:ok, character.id}

          {:error, %Ash.Error.Query.NotFound{}} ->
            {:error, :invalid_character}

          {:error, %Ash.Error.Invalid{}} ->
            # Invalid format (e.g., non-numeric string for an integer field)
            {:error, :invalid_character}

          {:error, reason} ->
            Logger.error(
              "[validate_character_eve_id] Unexpected error looking up character: #{inspect(reason)}"
            )

            {:error, :unexpected_error}
        end

      _ ->
        {:error, :invalid_character}
    end
  end

  defp validate_character_eve_id(_params, fallback_char_id) do
    {:ok, fallback_char_id}
  end

  @spec list_signatures(String.t()) :: [map()]
  def list_signatures(map_id) do
    systems = Operations.list_systems(map_id)

    if systems != [] do
      systems
      |> Enum.flat_map(fn sys ->
        with {:ok, sigs} <- MapSystemSignature.by_system_id(sys.id) do
          # Add solar_system_id to each signature and remove system_id
          Enum.map(sigs, fn sig ->
            sig
            |> Map.from_struct()
            |> Map.put(:solar_system_id, sys.solar_system_id)
            |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])
          end)
        else
          err ->
            Logger.error("[list_signatures] error: #{inspect(err)}")
            []
        end
      end)
    else
      []
    end
  end

  @spec create_signature(Plug.Conn.t(), map()) :: {:ok, map()} | {:error, atom()}
  def create_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        %{"solar_system_id" => solar_system_id} = params
      )
      when is_integer(solar_system_id) do
    with {:ok, validated_char_uuid} <- validate_character_eve_id(params, char_id),
         {:ok, system} <- ensure_system_on_map(map_id, solar_system_id, user_id, char_id) do
      attrs =
        params
        |> Map.put("system_id", system.id)
        |> Map.delete("solar_system_id")

      case Server.update_signatures(map_id, %{
             added_signatures: [attrs],
             updated_signatures: [],
             removed_signatures: [],
             solar_system_id: solar_system_id,
             character_id: validated_char_uuid,
             user_id: user_id,
             delete_connection_with_sigs: false
           }) do
        :ok ->
          # Handle linked_system_id if provided - auto-add system and create/update connection
          linked_system_id = Map.get(params, "linked_system_id")
          wormhole_type = Map.get(params, "type")

          if is_integer(linked_system_id) and linked_system_id != solar_system_id do
            handle_linked_system(
              map_id,
              solar_system_id,
              linked_system_id,
              wormhole_type,
              user_id,
              char_id
            )
          end

          # Try to fetch the created signature to return with proper fields
          with {:ok, sigs} <-
                 MapSystemSignature.by_system_id_and_eve_ids(system.id, [attrs["eve_id"]]),
               sig when not is_nil(sig) <- List.first(sigs) do
            result =
              sig
              |> Map.from_struct()
              |> Map.put(:solar_system_id, system.solar_system_id)
              |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])

            {:ok, result}
          else
            _ ->
              # Fallback: return attrs with solar_system_id added
              attrs_result =
                attrs
                |> Map.put(:solar_system_id, solar_system_id)
                |> Map.drop(["system_id"])

              {:ok, attrs_result}
          end

        err ->
          Logger.error("[create_signature] Unexpected error: #{inspect(err)}")
          {:error, :unexpected_error}
      end
    else
      {:error, :invalid_character} ->
        Logger.error("[create_signature] Invalid character_eve_id provided")
        {:error, :invalid_character}

      {:error, :unexpected_error} ->
        Logger.error("[create_signature] Unexpected error during character validation")
        {:error, :unexpected_error}

      {:error, :invalid_solar_system} ->
        Logger.error(
          "[create_signature] Invalid solar_system_id: #{solar_system_id} (not a valid EVE system)"
        )

        {:error, :invalid_solar_system}

      _ ->
        Logger.error(
          "[create_signature] System not found for solar_system_id: #{solar_system_id}"
        )

        {:error, :system_not_found}
    end
  end

  def create_signature(
        %{assigns: %{map_id: _map_id, owner_character_id: _char_id, owner_user_id: _user_id}} =
          _conn,
        %{"solar_system_id" => _invalid} = _params
      ),
      do: {:error, :missing_params}

  def create_signature(_conn, _params), do: {:error, :missing_params}

  # Check cache (not DB) to ensure system is actually visible on the map.
  @spec ensure_system_on_map(String.t(), integer(), String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  defp ensure_system_on_map(map_id, solar_system_id, user_id, char_id) do
    case WandererApp.Map.find_system_by_location(map_id, %{solar_system_id: solar_system_id}) do
      nil -> add_system_to_map(map_id, solar_system_id, user_id, char_id)
      system -> {:ok, system}
    end
  end

  @spec add_system_to_map(String.t(), integer(), String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  defp add_system_to_map(map_id, solar_system_id, user_id, char_id) do
    with {:ok, static_info} when not is_nil(static_info) <-
           WandererApp.CachedInfo.get_system_static_info(solar_system_id),
         :ok <-
           Server.add_system(
             map_id,
             %{solar_system_id: solar_system_id, coordinates: nil},
             user_id,
             char_id
           ),
         system when not is_nil(system) <- fetch_system_after_add(map_id, solar_system_id) do
      Logger.info("[create_signature] Auto-added system #{solar_system_id} to map #{map_id}")
      {:ok, system}
    else
      {:ok, nil} ->
        {:error, :invalid_solar_system}

      {:error, _} ->
        {:error, :invalid_solar_system}

      nil ->
        Logger.error("[add_system_to_map] Failed to fetch system after add")
        {:error, :system_add_failed}

      error ->
        Logger.error("[add_system_to_map] Failed to add system: #{inspect(error)}")
        {:error, :system_add_failed}
    end
  end

  defp fetch_system_after_add(map_id, solar_system_id) do
    case WandererApp.Map.find_system_by_location(map_id, %{solar_system_id: solar_system_id}) do
      nil ->
        case MapSystem.read_by_map_and_solar_system(%{
               map_id: map_id,
               solar_system_id: solar_system_id
             }) do
          {:ok, system} -> system
          _ -> nil
        end

      system ->
        system
    end
  end

  # Handles the linked_system_id logic: auto-adds the linked system and creates/updates connection
  @spec handle_linked_system(
          String.t(),
          integer(),
          integer(),
          String.t() | nil,
          String.t(),
          String.t()
        ) :: :ok | {:error, atom()}
  defp handle_linked_system(
         map_id,
         source_system_id,
         linked_system_id,
         wormhole_type,
         user_id,
         char_id
       ) do
    # Ensure the linked system is on the map
    case ensure_system_on_map(map_id, linked_system_id, user_id, char_id) do
      {:ok, _linked_system} ->
        # Check if connection exists between the systems
        case Connections.get_connection_by_systems(map_id, source_system_id, linked_system_id) do
          {:ok, nil} ->
            # No connection exists, create one
            create_connection_with_wormhole_type(
              map_id,
              source_system_id,
              linked_system_id,
              wormhole_type,
              char_id
            )

          {:ok, _existing_conn} ->
            # Connection exists, update wormhole type if provided
            update_connection_wormhole_type(
              map_id,
              source_system_id,
              linked_system_id,
              wormhole_type
            )

          {:error, reason} ->
            Logger.warning(
              "[handle_linked_system] Failed to check connection: #{inspect(reason)}"
            )

            {:error, :connection_check_failed}
        end

      {:error, :invalid_solar_system} ->
        Logger.warning(
          "[handle_linked_system] Invalid linked_system_id: #{linked_system_id} (not a valid EVE system)"
        )

        {:error, :invalid_linked_system}

      {:error, reason} ->
        Logger.warning("[handle_linked_system] Failed to add linked system: #{inspect(reason)}")
        {:error, :linked_system_add_failed}
    end
  end

  # Creates a connection between two systems with the specified wormhole type
  @spec create_connection_with_wormhole_type(
          String.t(),
          integer(),
          integer(),
          String.t() | nil,
          String.t()
        ) :: :ok | {:error, atom()}
  defp create_connection_with_wormhole_type(
         map_id,
         source_system_id,
         target_system_id,
         wormhole_type,
         char_id
       ) do
    conn_attrs = %{
      "solar_system_source" => source_system_id,
      "solar_system_target" => target_system_id,
      "type" => 0,
      "wormhole_type" => wormhole_type
    }

    case Connections.create(conn_attrs, map_id, char_id) do
      {:ok, :created} ->
        Logger.info(
          "[create_signature] Auto-created connection #{source_system_id} <-> #{target_system_id} (type: #{wormhole_type || "unknown"})"
        )

        :ok

      {:skip, :exists} ->
        # Connection already exists (race condition), update it instead
        update_connection_wormhole_type(map_id, source_system_id, target_system_id, wormhole_type)

      error ->
        Logger.warning(
          "[create_connection_with_wormhole_type] Failed to create connection: #{inspect(error)}"
        )

        {:error, :connection_create_failed}
    end
  end

  # Updates the wormhole type and ship size for an existing connection
  @spec update_connection_wormhole_type(String.t(), integer(), integer(), String.t() | nil) ::
          :ok | {:error, atom()}
  defp update_connection_wormhole_type(_map_id, _source, _target, nil), do: :ok

  defp update_connection_wormhole_type(map_id, source_system_id, target_system_id, wormhole_type) do
    # Get ship size from wormhole type
    ship_size_type = EVEUtil.get_wh_size(wormhole_type)

    if not is_nil(ship_size_type) do
      case Server.update_connection_ship_size_type(map_id, %{
             solar_system_source_id: source_system_id,
             solar_system_target_id: target_system_id,
             ship_size_type: ship_size_type
           }) do
        :ok ->
          Logger.info(
            "[create_signature] Updated connection #{source_system_id} <-> #{target_system_id} ship_size_type to #{ship_size_type} (wormhole: #{wormhole_type})"
          )

          :ok

        error ->
          Logger.warning(
            "[update_connection_wormhole_type] Failed to update ship size: #{inspect(error)}"
          )

          {:error, :ship_size_update_failed}
      end
    else
      :ok
    end
  end

  @spec update_signature(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def update_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        sig_id,
        params
      ) do
    with {:ok, validated_char_uuid} <- validate_character_eve_id(params, char_id),
         {:ok, sig} <- MapSystemSignature.by_id(sig_id),
         {:ok, system} <- MapSystem.by_id(sig.system_id) do
      base = %{
        "eve_id" => sig.eve_id,
        "name" => sig.name,
        "kind" => sig.kind,
        "group" => sig.group,
        "type" => sig.type,
        "custom_info" => sig.custom_info,
        "description" => sig.description,
        "linked_system_id" => sig.linked_system_id
      }

      # Merge user params (which may include character_eve_id) with base
      attrs = Map.merge(base, params)

      :ok =
        Server.update_signatures(map_id, %{
          added_signatures: [],
          updated_signatures: [attrs],
          removed_signatures: [],
          solar_system_id: system.solar_system_id,
          character_id: validated_char_uuid,
          user_id: user_id,
          delete_connection_with_sigs: false
        })

      # Fetch the updated signature to return with proper fields
      with {:ok, updated_sig} <- MapSystemSignature.by_id(sig_id) do
        result =
          updated_sig
          |> Map.from_struct()
          |> Map.put(:solar_system_id, system.solar_system_id)
          |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])

        {:ok, result}
      else
        _ -> {:ok, attrs}
      end
    else
      {:error, :invalid_character} ->
        Logger.error("[update_signature] Invalid character_eve_id provided")
        {:error, :invalid_character}

      {:error, :unexpected_error} ->
        Logger.error("[update_signature] Unexpected error during character validation")
        {:error, :unexpected_error}

      err ->
        Logger.error("[update_signature] Signature or system not found: #{inspect(err)}")
        {:error, :not_found}
    end
  end

  def update_signature(_conn, _sig_id, _params), do: {:error, :missing_params}

  @spec delete_signature(Plug.Conn.t(), String.t()) :: :ok | {:error, atom()}
  def delete_signature(
        %{assigns: %{map_id: map_id, owner_character_id: char_id, owner_user_id: user_id}} =
          _conn,
        sig_id
      ) do
    with {:ok, sig} <- MapSystemSignature.by_id(sig_id),
         {:ok, system} <- MapSystem.by_id(sig.system_id) do
      removed = [
        %{
          "eve_id" => sig.eve_id,
          "name" => sig.name,
          "kind" => sig.kind,
          "group" => sig.group
        }
      ]

      :ok =
        Server.update_signatures(map_id, %{
          added_signatures: [],
          updated_signatures: [],
          removed_signatures: removed,
          solar_system_id: system.solar_system_id,
          character_id: char_id,
          user_id: user_id,
          delete_connection_with_sigs: false
        })

      :ok
    else
      err ->
        Logger.error("[delete_signature] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def delete_signature(_conn, _sig_id), do: {:error, :missing_params}

  @doc """
  Links a signature to a target system, creating the association between
  the signature and the wormhole connection to that system.

  This also:
  - Updates the signature's group to "Wormhole"
  - Sets the target system's linked_sig_eve_id
  - Copies temporary_name from signature to target system
  - Updates connection time_status and ship_size_type from signature data
  """
  @spec link_signature(Plug.Conn.t(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def link_signature(
        %{assigns: %{map_id: map_id}} = _conn,
        sig_id,
        %{"solar_system_target" => solar_system_target}
      )
      when is_integer(solar_system_target) do
    with {:ok, signature} <- MapSystemSignature.by_id(sig_id),
         {:ok, source_system} <- MapSystem.by_id(signature.system_id),
         true <- source_system.map_id == map_id,
         target_system when not is_nil(target_system) <-
           WandererApp.Map.find_system_by_location(map_id, %{solar_system_id: solar_system_target}) do
      # Update signature group to Wormhole and set linked_system_id
      {:ok, updated_signature} =
        signature
        |> MapSystemSignature.update_group!(%{group: "Wormhole"})
        |> MapSystemSignature.update_linked_system(%{linked_system_id: solar_system_target})

      # Only update target system if it doesn't already have a linked signature
      if is_nil(target_system.linked_sig_eve_id) do
        # Set the target system's linked_sig_eve_id
        Server.update_system_linked_sig_eve_id(map_id, %{
          solar_system_id: solar_system_target,
          linked_sig_eve_id: signature.eve_id
        })

        # Copy temporary_name if present
        if not is_nil(signature.temporary_name) do
          Server.update_system_temporary_name(map_id, %{
            solar_system_id: solar_system_target,
            temporary_name: signature.temporary_name
          })
        end

        # Update connection time_status from signature custom_info
        signature_time_status =
          if not is_nil(signature.custom_info) do
            case Jason.decode(signature.custom_info) do
              {:ok, map} -> Map.get(map, "time_status")
              {:error, _} -> nil
            end
          else
            nil
          end

        if not is_nil(signature_time_status) do
          Server.update_connection_time_status(map_id, %{
            solar_system_source_id: source_system.solar_system_id,
            solar_system_target_id: solar_system_target,
            time_status: signature_time_status
          })
        end

        # Update connection ship_size_type from signature wormhole type
        signature_ship_size_type = EVEUtil.get_wh_size(signature.type)

        if not is_nil(signature_ship_size_type) do
          Server.update_connection_ship_size_type(map_id, %{
            solar_system_source_id: source_system.solar_system_id,
            solar_system_target_id: solar_system_target,
            ship_size_type: signature_ship_size_type
          })
        end
      end

      # Broadcast update
      Server.Impl.broadcast!(map_id, :signatures_updated, source_system.solar_system_id)

      # Return the updated signature
      result =
        updated_signature
        |> Map.from_struct()
        |> Map.put(:solar_system_id, source_system.solar_system_id)
        |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])

      {:ok, result}
    else
      false ->
        {:error, :not_found}

      nil ->
        {:error, :target_system_not_found}

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :not_found}

      err ->
        Logger.error("[link_signature] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def link_signature(_conn, _sig_id, %{"solar_system_target" => _}),
    do: {:error, :invalid_solar_system_target}

  def link_signature(_conn, _sig_id, _params), do: {:error, :missing_params}

  @doc """
  Unlinks a signature from its target system.
  """
  @spec unlink_signature(Plug.Conn.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def unlink_signature(%{assigns: %{map_id: map_id}} = _conn, sig_id) do
    with {:ok, signature} <- MapSystemSignature.by_id(sig_id),
         {:ok, source_system} <- MapSystem.by_id(signature.system_id),
         :ok <- if(source_system.map_id == map_id, do: :ok, else: {:error, :not_found}),
         :ok <- if(not is_nil(signature.linked_system_id), do: :ok, else: {:error, :not_linked}) do
      # Clear the target system's linked_sig_eve_id
      Server.update_system_linked_sig_eve_id(map_id, %{
        solar_system_id: signature.linked_system_id,
        linked_sig_eve_id: nil
      })

      # Clear the signature's linked_system_id using the wrapper for logging
      {:ok, updated_signature} =
        Server.SignaturesImpl.update_signature_linked_system(signature, %{
          linked_system_id: nil
        })

      # Broadcast update
      Server.Impl.broadcast!(map_id, :signatures_updated, source_system.solar_system_id)

      # Return the updated signature
      result =
        updated_signature
        |> Map.from_struct()
        |> Map.put(:solar_system_id, source_system.solar_system_id)
        |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])

      {:ok, result}
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :not_linked} ->
        {:error, :not_linked}

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :not_found}

      err ->
        Logger.error("[unlink_signature] Unexpected error: #{inspect(err)}")
        {:error, :unexpected_error}
    end
  end

  def unlink_signature(_conn, _sig_id), do: {:error, :missing_params}
end
