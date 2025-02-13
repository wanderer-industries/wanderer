defmodule WandererAppWeb.AccessListMemberAPIController do
  @moduledoc """
  Handles creation, role updates, and deletion of individual ACL members.
  """

  use WandererAppWeb, :controller
  alias WandererApp.Api.{AccessListMember, Character}

  @doc """
  POST /api/acls/:acl_id/members

  Creates a new member for the given ACL.

  Request Body example:
      {
        "member": {
          "eve_character_id": "CHARACTER_EXTERNAL_EVE_ID",
          "role": "viewer"  // optional; defaults to "viewer" if not provided
        }
      }

  Behavior:
  The controller looks up the character by filtering on its external EVE ID (field `eve_id`),
  injects the character's name into the membership, and creates the membership record.
  """
  def create(conn, %{"acl_id" => acl_id, "member" => member_params}) do
    with eve_id when not is_nil(eve_id) <- Map.get(member_params, "eve_character_id"),
         # Build a query to find the character by its external EVE id (eve_id)
         query = Character |> Ash.Query.new() |> Ash.Query.filter(eve_id: eve_id),
         {:ok, characters} <- WandererApp.Api.read(query),
         [character] <- characters do
      # Inject the looked-up name into the parameters.
      member_params = Map.put(member_params, "name", character.name)
      # Merge in the ACL id so that Ash knows which ACL the member belongs to.
      merged_params = Map.put(member_params, "access_list_id", acl_id)

      case AccessListMember.create(merged_params) do
        {:ok, new_member} ->
          json(conn, %{data: member_to_json(new_member)})

        {:error, error} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Failed to create member: #{inspect(error)}"})
      end
    else
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing eve_character_id in member payload"})

      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Character not found"})

      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Character lookup failed: #{inspect(error)}"})
    end
  end

  @doc """
  PUT /api/acls/:acl_id/members/:member_id

  Updates a single ACL member’s role based on the external EVE ID provided in the URL.

  Request Body example:
      {
        "member": {
          "role": "admin"
        }
      }

  """
  def update_role(conn, %{"acl_id" => acl_id, "member_id" => eve_id, "member" => member_params}) do
    membership_query =
      AccessListMember
      |> Ash.Query.new()
      |> Ash.Query.filter(eve_character_id: eve_id)
      |> Ash.Query.filter(access_list_id: acl_id)

    case WandererApp.Api.read(membership_query) do
      {:ok, [membership]} ->
        case AccessListMember.update_role(membership, member_params) do
          {:ok, updated_membership} ->
            json(conn, %{data: member_to_json(updated_membership)})

          {:error, error} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: inspect(error)})
        end

      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Membership not found for given ACL and eve_character_id"})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(error)})
    end
  end

  @doc """
  DELETE /api/acls/:acl_id/members/:member_id

  Deletes a member from an ACL based on the external EVE ID provided in the URL.

  """
  def delete(conn, %{"acl_id" => acl_id, "member_id" => eve_id}) do
    membership_query =
      AccessListMember
      |> Ash.Query.new()
      |> Ash.Query.filter(eve_character_id: eve_id)
      |> Ash.Query.filter(access_list_id: acl_id)

    case WandererApp.Api.read(membership_query) do
      {:ok, [membership]} ->
        case AccessListMember.destroy(membership) do
          :ok ->
            json(conn, %{ok: true})

          {:error, error} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: inspect(error)})
        end

      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Membership not found for given ACL and eve_character_id"})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(error)})
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------
  defp member_to_json(member) do
    %{
      id: member.id,
      name: member.name,
      role: member.role,
      eve_character_id: member.eve_character_id,
      inserted_at: member.inserted_at,
      updated_at: member.updated_at
    }
  end
end
