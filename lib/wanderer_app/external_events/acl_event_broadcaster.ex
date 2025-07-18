defmodule WandererApp.ExternalEvents.AclEventBroadcaster do
  @moduledoc """
  Shared module for broadcasting ACL member events to all maps that use a specific ACL.

  This module extracts the common broadcasting logic that was duplicated between
  access_list_member_api_controller.ex and access_lists_live.ex to maintain DRY principles.
  """

  require Logger

  @doc """
  Broadcasts an ACL member event to all maps that use the specified ACL.

  ## Parameters

  - `acl_id` - The ID of the access list
  - `member` - The ACL member data structure
  - `event_type` - The type of event (:acl_member_added, :acl_member_updated, :acl_member_removed)

  ## Example

      broadcast_member_event("acl-123", member, :acl_member_added)
  """
  @spec broadcast_member_event(String.t(), map(), atom()) :: :ok | {:error, term()}
  def broadcast_member_event(acl_id, member, event_type) do
    # Validate member data
    with :ok <- validate_member(member),
         :ok <- validate_event_type(event_type) do
      Logger.debug(fn ->
        "Broadcasting ACL member event: #{event_type} for member #{member.name} (#{member.id}) in ACL #{acl_id}"
      end)

      # Find all maps that use this ACL
      case Ash.read(
             WandererApp.Api.MapAccessList
             |> Ash.Query.for_read(:read_by_acl, %{acl_id: acl_id})
           ) do
        {:ok, map_acls} ->
          Logger.debug(fn ->
            "Found #{length(map_acls)} maps using ACL #{acl_id}: #{inspect(Enum.map(map_acls, & &1.map_id))}"
          end)

          # Get the member type and EVE ID
          {member_type, eve_id} = get_member_type_and_id(member)

          # Skip broadcasting if no valid EVE ID
          if is_nil(member_type) || is_nil(eve_id) do
            Logger.warning("Cannot broadcast event for member without EVE ID: #{member.id}")
            {:error, :no_eve_id}
          else
            # Build the event payload
            payload = %{
              acl_id: acl_id,
              member_id: member.id,
              member_name: member.name,
              member_type: member_type,
              eve_id: eve_id,
              role: member.role
            }

            Logger.debug(fn ->
              "Broadcasting #{event_type} event with payload: #{inspect(payload)}"
            end)

            # Broadcast to each map
            Enum.each(map_acls, fn map_acl ->
              Logger.debug(fn -> "Broadcasting #{event_type} to map #{map_acl.map_id}" end)
              WandererApp.ExternalEvents.broadcast(map_acl.map_id, event_type, payload)
            end)

            Logger.debug(fn ->
              "Successfully broadcast #{event_type} event to #{length(map_acls)} maps"
            end)

            :ok
          end

        {:error, error} ->
          Logger.error("Failed to find maps for ACL #{acl_id}: #{inspect(error)}")
          {:error, {:map_lookup_failed, error}}
      end
    else
      error -> error
    end
  end

  # Private helper functions

  defp validate_member(member) do
    cond do
      is_nil(member) ->
        {:error, :member_is_nil}

      not is_map(member) ->
        {:error, :member_not_map}

      is_nil(Map.get(member, :id)) ->
        {:error, :member_id_missing}

      is_nil(Map.get(member, :name)) ->
        {:error, :member_name_missing}

      is_nil(Map.get(member, :role)) ->
        {:error, :member_role_missing}

      Map.get(member, :role) not in [:admin, :manager, :member, :viewer, :blocked] ->
        {:error, {:invalid_role, Map.get(member, :role)}}

      true ->
        :ok
    end
  end

  defp validate_event_type(event_type) do
    if event_type in [:acl_member_added, :acl_member_updated, :acl_member_removed] do
      :ok
    else
      {:error, {:invalid_event_type, event_type}}
    end
  end

  defp get_member_type_and_id(member) do
    cond do
      member.eve_character_id ->
        {"character", member.eve_character_id}

      member.eve_corporation_id ->
        {"corporation", member.eve_corporation_id}

      member.eve_alliance_id ->
        {"alliance", member.eve_alliance_id}

      true ->
        # Handle the case when no EVE IDs are set
        {nil, nil}
    end
  end
end
