defmodule WandererAppWeb.AccessListMemberAPIController do
  @moduledoc """
  Handles creation, role updates, and deletion of individual ACL members.

  This controller supports creation of members by accepting one of the following keys:
    - "eve_character_id"
    - "eve_corporation_id"
    - "eve_alliance_id"

  For corporation and alliance members, roles "admin" and "manager" are disallowed.
  """

  use WandererAppWeb, :controller
  alias WandererApp.Api.AccessListMember
  import Ash.Query
  require Logger

  @doc """
  POST /api/acls/:acl_id/members
  """
  def create(conn, %{"acl_id" => acl_id, "member" => member_params}) do
    chosen =
      cond do
        Map.has_key?(member_params, "eve_corporation_id") ->
          {"eve_corporation_id", "corporation"}

        Map.has_key?(member_params, "eve_alliance_id") ->
          {"eve_alliance_id", "alliance"}

        Map.has_key?(member_params, "eve_character_id") ->
          {"eve_character_id", "character"}

        true ->
          nil
      end

    if is_nil(chosen) do
      conn
      |> put_status(:bad_request)
      |> json(%{
        error:
          "Missing one of eve_character_id, eve_corporation_id, or eve_alliance_id in payload"
      })
    else
      {key, type} = chosen
      raw_id = Map.get(member_params, key)
      id_str = to_string(raw_id)  # handle string/integer input
      role = Map.get(member_params, "role", "viewer")

      if type in ["corporation", "alliance"] and role in ["admin", "manager"] do
        conn
        |> put_status(:bad_request)
        |> json(%{
          error:
            "#{String.capitalize(type)} members cannot have an admin or manager role"
        })
      else
        info_fetcher =
          case type do
            "character" -> &WandererApp.Esi.get_character_info/1
            "corporation" -> &WandererApp.Esi.get_corporation_info/1
            "alliance" -> &WandererApp.Esi.get_alliance_info/1
          end

        with {:ok, entity_info} <- info_fetcher.(id_str) do
          member_name = Map.get(entity_info, "name")

          new_params =
            member_params
            |> Map.drop(["eve_corporation_id", "eve_alliance_id", "eve_character_id"])
            |> Map.put(key, id_str)
            |> Map.put("name", member_name)
            |> Map.put("access_list_id", acl_id)

          case AccessListMember.create(new_params) do
            {:ok, new_member} ->
              json(conn, %{data: member_to_json(new_member)})

            {:error, error} ->
              conn
              |> put_status(:bad_request)
              |> json(%{error: "Creation failed: #{inspect(error)}"})
          end
        else
          {:error, error} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Entity lookup failed: #{inspect(error)}"})
        end
      end
    end
  end

  @doc """
  PUT /api/acls/:acl_id/members/:member_id
  """
  def update_role(conn, %{
        "acl_id" => acl_id,
        "member_id" => external_id,
        "member" => member_params
      }) do
    # Convert external_id to string if you expect it may come in as integer
    external_id_str = to_string(external_id)

    membership_query =
      AccessListMember
      |> Ash.Query.new()
      |> filter(access_list_id == ^acl_id)
      |> filter(
        eve_character_id == ^external_id_str or
          eve_corporation_id == ^external_id_str or
          eve_alliance_id == ^external_id_str
      )

    case WandererApp.Api.read(membership_query) do
      {:ok, [membership]} ->
        new_role = Map.get(member_params, "role", membership.role)

        member_type =
          cond do
            membership.eve_corporation_id -> "corporation"
            membership.eve_alliance_id -> "alliance"
            membership.eve_character_id -> "character"
            true -> "character"
          end

        if member_type in ["corporation", "alliance"] and new_role in ["admin", "manager"] do
          conn
          |> put_status(:bad_request)
          |> json(%{
            error:
              "#{String.capitalize(member_type)} members cannot have an admin or manager role"
          })
        else
          case AccessListMember.update_role(membership, member_params) do
            {:ok, updated_membership} ->
              json(conn, %{data: member_to_json(updated_membership)})

            {:error, error} ->
              conn
              |> put_status(:bad_request)
              |> json(%{error: inspect(error)})
          end
        end

      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Membership not found for given ACL and external id"})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(error)})
    end
  end

  @doc """
  DELETE /api/acls/:acl_id/members/:member_id
  """
  def delete(conn, %{"acl_id" => acl_id, "member_id" => external_id}) do
    external_id_str = to_string(external_id)

    membership_query =
      AccessListMember
      |> Ash.Query.new()
      |> filter(access_list_id == ^acl_id)
      |> filter(
        eve_character_id == ^external_id_str or
          eve_corporation_id == ^external_id_str or
          eve_alliance_id == ^external_id_str
      )

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
        |> json(%{error: "Membership not found for given ACL and external id"})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(error)})
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------
  @doc false
  defp member_to_json(member) do
    base = %{
      id: member.id,
      name: member.name,
      role: member.role,
      inserted_at: member.inserted_at,
      updated_at: member.updated_at
    }

    cond do
      member.eve_character_id -> Map.put(base, :eve_character_id, member.eve_character_id)
      member.eve_corporation_id -> Map.put(base, :eve_corporation_id, member.eve_corporation_id)
      member.eve_alliance_id -> Map.put(base, :eve_alliance_id, member.eve_alliance_id)
      true -> base
    end
  end
end
