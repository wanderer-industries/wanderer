defmodule WandererApp.Map.Operations.Duplication do
  @moduledoc """
  Map duplication operations with full transactional support.

  Handles copying maps including:
  - Base map attributes (name, description, settings)
  - Map systems with positions and metadata
  - System connections with their properties
  - System signatures (optional)
  - Access control lists (optional)
  - Character settings (optional)
  """

  require Logger
  import Ash.Query, only: [filter: 2]

  alias WandererApp.Api
  alias WandererApp.Api.{MapSystem, MapConnection, MapSystemSignature, MapCharacterSettings}

  @doc """
  Duplicates a complete map with all related data.

  ## Parameters
  - `source_map_id` - UUID of the map to duplicate
  - `changeset` - Ash changeset with new map attributes
  - `opts` - Options for what to copy:
    - `:copy_acls` - Copy access control lists (default: true)
    - `:copy_user_settings` - Copy user/character settings (default: true)
    - `:copy_signatures` - Copy system signatures (default: true)

  ## Returns
  - `{:ok, duplicated_map}` - Successfully duplicated map
  - `{:error, reason}` - Error during duplication
  """
  def duplicate_map(source_map_id, new_map, opts \\ []) do
    copy_acls = Keyword.get(opts, :copy_acls, true)
    copy_user_settings = Keyword.get(opts, :copy_user_settings, true)
    copy_signatures = Keyword.get(opts, :copy_signatures, true)

    Logger.info("Starting map duplication for source map: #{source_map_id}")

    # Wrap all duplication operations in a transaction
    WandererApp.Repo.transaction(fn ->
      with {:ok, source_map} <- load_source_map(source_map_id),
           {:ok, system_mapping} <- copy_systems(source_map, new_map),
           {:ok, _connections} <- copy_connections(source_map, new_map, system_mapping),
           {:ok, _signatures} <-
             maybe_copy_signatures(source_map, new_map, system_mapping, copy_signatures),
           {:ok, _acls} <- maybe_copy_acls(source_map, new_map, copy_acls),
           {:ok, _user_settings} <-
             maybe_copy_user_settings(source_map, new_map, copy_user_settings) do
        Logger.info("Successfully duplicated map #{source_map_id} to #{new_map.id}")
        new_map
      else
        {:error, reason} ->
          Logger.error("Failed to duplicate map #{source_map_id}: #{inspect(reason)}")
          WandererApp.Repo.rollback(reason)
      end
    end)
  end

  # Load source map with all required relationships
  defp load_source_map(source_map_id) do
    case Api.Map.by_id(source_map_id) do
      {:ok, map} -> {:ok, map}
      {:error, _} -> {:error, {:not_found, "Source map not found"}}
    end
  end

  # Copy all systems from source map to new map
  defp copy_systems(source_map, new_map) do
    Logger.debug("Copying systems for map #{source_map.id}")

    # Get all systems from source map using Ash
    case MapSystem |> Ash.Query.filter(map_id == ^source_map.id) |> Ash.read() do
      {:ok, source_systems} ->
        system_mapping = %{}

        Enum.reduce_while(source_systems, {:ok, system_mapping}, fn source_system,
                                                                    {:ok, acc_mapping} ->
          case copy_single_system(source_system, new_map.id) do
            {:ok, new_system} ->
              new_mapping = Map.put(acc_mapping, source_system.id, new_system.id)
              {:cont, {:ok, new_mapping}}

            {:error, reason} ->
              {:halt, {:error, {:system_copy_failed, reason}}}
          end
        end)

      {:error, error} ->
        {:error, {:systems_load_failed, error}}
    end
  end

  # Copy a single system
  defp copy_single_system(source_system, new_map_id) do
    # Get all attributes from the source system, excluding system-managed fields and metadata
    excluded_fields = [
      # System managed fields
      :id,
      :inserted_at,
      :updated_at,
      :map_id,
      :map,
      # Ash/Ecto metadata fields
      :__meta__,
      :__lateral_join_source__,
      :__metadata__,
      :__order__,
      :aggregates,
      :calculations
    ]

    # Convert the source system struct to a map and filter out excluded fields
    system_attrs =
      source_system
      |> Map.from_struct()
      |> Map.drop(excluded_fields)
      |> Map.put(:map_id, new_map_id)

    MapSystem.create(system_attrs)
  end

  # Copy all connections between systems
  defp copy_connections(source_map, new_map, system_mapping) do
    Logger.debug("Copying connections for map #{source_map.id}")

    case MapConnection |> Ash.Query.filter(map_id == ^source_map.id) |> Ash.read() do
      {:ok, source_connections} ->
        Enum.reduce_while(source_connections, {:ok, []}, fn source_connection,
                                                            {:ok, acc_connections} ->
          case copy_single_connection(source_connection, new_map.id, system_mapping) do
            {:ok, new_connection} ->
              {:cont, {:ok, [new_connection | acc_connections]}}

            {:error, reason} ->
              {:halt, {:error, {:connection_copy_failed, reason}}}
          end
        end)

      {:error, error} ->
        {:error, {:connections_load_failed, error}}
    end
  end

  # Copy a single connection with updated system references
  defp copy_single_connection(source_connection, new_map_id, system_mapping) do
    # Get all attributes from the source connection, excluding system-managed fields and metadata
    excluded_fields = [
      # System managed fields
      :id,
      :inserted_at,
      :updated_at,
      :map_id,
      :map,
      # Ash/Ecto metadata fields
      :__meta__,
      :__lateral_join_source__,
      :__metadata__,
      :__order__,
      :aggregates,
      :calculations
    ]

    # Convert the source connection struct to a map and filter out excluded fields
    connection_attrs =
      source_connection
      |> Map.from_struct()
      |> Map.drop(excluded_fields)
      |> Map.put(:map_id, new_map_id)
      |> update_system_references(system_mapping)

    MapConnection.create(connection_attrs)
  end

  # Update system references in connection attributes using the system mapping
  defp update_system_references(connection_attrs, system_mapping) do
    connection_attrs
    |> maybe_update_system_reference(:solar_system_source, system_mapping)
    |> maybe_update_system_reference(:solar_system_target, system_mapping)
  end

  # Update a single system reference if it exists in the mapping
  defp maybe_update_system_reference(attrs, field, system_mapping) do
    case Map.get(attrs, field) do
      nil ->
        attrs

      old_system_id ->
        case Map.get(system_mapping, old_system_id) do
          # Keep original if no mapping found
          nil -> attrs
          new_system_id -> Map.put(attrs, field, new_system_id)
        end
    end
  end

  # Conditionally copy signatures if requested
  defp maybe_copy_signatures(_source_map, _new_map, _system_mapping, false), do: {:ok, []}

  defp maybe_copy_signatures(source_map, new_map, system_mapping, true) do
    Logger.debug("Copying signatures for map #{source_map.id}")

    # Get signatures by iterating through systems
    source_signatures = get_all_map_signatures(source_map.id, system_mapping)

    Enum.reduce_while(source_signatures, {:ok, []}, fn source_signature, {:ok, acc_signatures} ->
      case copy_single_signature(source_signature, new_map.id, system_mapping) do
        {:ok, new_signature} ->
          {:cont, {:ok, [new_signature | acc_signatures]}}

        {:error, reason} ->
          {:halt, {:error, {:signature_copy_failed, reason}}}
      end
    end)
  end

  # Get all signatures for a map by querying each system
  defp get_all_map_signatures(_source_map_id, system_mapping) do
    # Get source system IDs and query signatures for each
    source_system_ids = Map.keys(system_mapping)

    Enum.flat_map(source_system_ids, fn system_id ->
      case MapSystemSignature |> Ash.Query.filter(system_id == ^system_id) |> Ash.read() do
        {:ok, signatures} -> signatures
        {:error, _} -> []
      end
    end)
  end

  # Copy a single signature with updated system reference
  defp copy_single_signature(source_signature, _new_map_id, system_mapping) do
    new_system_id = Map.get(system_mapping, source_signature.system_id)

    if new_system_id do
      # Get all attributes from the source signature, excluding system-managed fields and metadata
      excluded_fields = [
        # System managed fields
        :id,
        :inserted_at,
        :updated_at,
        :system_id,
        :system,
        # Fields not accepted by create action
        :linked_system_id,
        :update_forced_at,
        # Ash/Ecto metadata fields
        :__meta__,
        :__lateral_join_source__,
        :__metadata__,
        :__order__,
        :aggregates,
        :calculations
      ]

      # Convert the source signature struct to a map and filter out excluded fields
      signature_attrs =
        source_signature
        |> Map.from_struct()
        |> Map.drop(excluded_fields)
        |> Map.put(:system_id, new_system_id)

      MapSystemSignature.create(signature_attrs)
    else
      {:error, "System mapping not found for signature"}
    end
  end

  # Conditionally copy ACLs if requested
  defp maybe_copy_acls(_source_map, _new_map, false), do: {:ok, []}

  defp maybe_copy_acls(source_map, new_map, true) do
    Logger.debug("Duplicating ACLs for map #{source_map.id}")

    # Load source map with ACL relationships and their members
    case Api.Map.by_id(source_map.id, load: [acls: [:members]]) do
      {:ok, source_map_with_acls} ->
        # Create new ACLs (duplicates) and collect their IDs
        new_acl_ids =
          Enum.reduce_while(source_map_with_acls.acls, {:ok, []}, fn source_acl, {:ok, acc_ids} ->
            case duplicate_single_acl(source_acl, new_map) do
              {:ok, new_acl} ->
                {:cont, {:ok, [new_acl.id | acc_ids]}}

              {:error, reason} ->
                {:halt, {:error, {:acl_duplication_failed, reason}}}
            end
          end)

        # Associate the new ACLs with the new map
        case new_acl_ids do
          {:ok, [_ | _] = acl_ids} ->
            Api.Map.update_acls(new_map, %{acls: acl_ids})

          {:ok, []} ->
            {:ok, new_map}

          {:error, _} = error ->
            error
        end

      {:error, error} ->
        {:error, {:acl_load_failed, error}}
    end
  end

  # Duplicate a single ACL with all its members
  defp duplicate_single_acl(source_acl, new_map) do
    # Create the new ACL with a modified name to avoid conflicts
    acl_attrs = %{
      name: "#{source_acl.name} (Copy)",
      description: source_acl.description,
      owner_id: new_map.owner_id
    }

    case WandererApp.Api.AccessList.create(acl_attrs) do
      {:ok, new_acl} ->
        # Copy all members from source ACL to new ACL
        case copy_acl_members(source_acl.members, new_acl.id) do
          {:ok, _members} -> {:ok, new_acl}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Copy all members from source ACL to new ACL
  defp copy_acl_members(source_members, new_acl_id) do
    Enum.reduce_while(source_members, {:ok, []}, fn source_member, {:ok, acc_members} ->
      member_attrs = %{
        access_list_id: new_acl_id,
        name: source_member.name,
        eve_character_id: source_member.eve_character_id,
        eve_corporation_id: source_member.eve_corporation_id,
        eve_alliance_id: source_member.eve_alliance_id,
        role: source_member.role
      }

      case WandererApp.Api.AccessListMember.create(member_attrs) do
        {:ok, new_member} ->
          {:cont, {:ok, [new_member | acc_members]}}

        {:error, reason} ->
          {:halt, {:error, {:member_copy_failed, reason}}}
      end
    end)
  end

  # Conditionally copy user settings if requested
  defp maybe_copy_user_settings(_source_map, _new_map, false), do: {:ok, []}

  defp maybe_copy_user_settings(source_map, new_map, true) do
    Logger.debug("Copying user settings for map #{source_map.id}")

    case MapCharacterSettings |> Ash.Query.filter(map_id == ^source_map.id) |> Ash.read() do
      {:ok, source_settings} ->
        Enum.reduce_while(source_settings, {:ok, []}, fn source_setting, {:ok, acc_settings} ->
          case copy_single_character_setting(source_setting, new_map.id) do
            {:ok, new_setting} ->
              {:cont, {:ok, [new_setting | acc_settings]}}

            {:error, reason} ->
              {:halt, {:error, {:user_setting_copy_failed, reason}}}
          end
        end)

      {:error, error} ->
        {:error, {:user_settings_load_failed, error}}
    end
  end

  # Copy a single character setting
  defp copy_single_character_setting(source_setting, new_map_id) do
    setting_attrs = %{
      map_id: new_map_id,
      character_id: source_setting.character_id,
      tracked: source_setting.tracked || false,
      followed: source_setting.followed || false
    }

    MapCharacterSettings.create(setting_attrs)
  end
end
