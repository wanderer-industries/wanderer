defmodule WandererAppWeb.AccessListMemberAPIController do
  @moduledoc """
  Handles creation, role updates, and deletion of individual ACL members.
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.Api.AccessListMember
  alias WandererApp.ExternalEvents.AclEventBroadcaster
  import Ash.Query
  require Logger

  # ------------------------------------------------------------------------
  # Inline Schemas
  # ------------------------------------------------------------------------
  @acl_member_create_request_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      member: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          eve_character_id: %OpenApiSpex.Schema{type: :string},
          eve_corporation_id: %OpenApiSpex.Schema{type: :string},
          eve_alliance_id: %OpenApiSpex.Schema{type: :string},
          role: %OpenApiSpex.Schema{type: :string}
        }
        # no 'required' fields if you truly allow any of them
      }
    },
    required: ["member"]
  }

  @acl_member_create_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          id: %OpenApiSpex.Schema{type: :string},
          name: %OpenApiSpex.Schema{type: :string},
          role: %OpenApiSpex.Schema{type: :string},
          eve_character_id: %OpenApiSpex.Schema{type: :string},
          eve_corporation_id: %OpenApiSpex.Schema{type: :string},
          eve_alliance_id: %OpenApiSpex.Schema{type: :string},
          inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
          updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time}
        },
        required: ["id", "name", "role"]
      }
    },
    required: ["data"]
  }

  @acl_member_update_request_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      member: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          role: %OpenApiSpex.Schema{type: :string}
        },
        required: ["role"]
      }
    },
    required: ["member"]
  }

  @acl_member_update_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          id: %OpenApiSpex.Schema{type: :string},
          name: %OpenApiSpex.Schema{type: :string},
          role: %OpenApiSpex.Schema{type: :string},
          eve_character_id: %OpenApiSpex.Schema{type: :string},
          eve_corporation_id: %OpenApiSpex.Schema{type: :string},
          eve_alliance_id: %OpenApiSpex.Schema{type: :string},
          inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
          updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time}
        },
        required: ["id", "name", "role"]
      }
    },
    required: ["data"]
  }

  @acl_member_delete_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      ok: %OpenApiSpex.Schema{type: :boolean}
    },
    required: ["ok"]
  }

  # ------------------------------------------------------------------------
  # ENDPOINTS
  # ------------------------------------------------------------------------

  @doc """
  POST /api/acls/:acl_id/members

  Creates a new ACL member.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:create,
    summary: "Create ACL Member",
    description: "Creates a new ACL member for a given ACL.",
    parameters: [
      acl_id: [
        in: :path,
        description: "Access List ID",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "ACL Member parameters",
      "application/json",
      @acl_member_create_request_schema
    },
    responses: [
      ok: {
        "Created ACL Member",
        "application/json",
        @acl_member_create_response_schema
      }
    ]
  )

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
      id_str = to_string(raw_id)
      role = Map.get(member_params, "role", "viewer")

      if type in ["corporation", "alliance"] and role in ["admin", "manager"] do
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "#{String.capitalize(type)} members cannot have an admin or manager role"
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
              # Broadcast event to all maps using this ACL
              case AclEventBroadcaster.broadcast_member_event(
                     acl_id,
                     new_member,
                     :acl_member_added
                   ) do
                :ok ->
                  broadcast_acl_updated(acl_id)

                  json(conn, %{data: member_to_json(new_member)})

                {:error, broadcast_error} ->
                  Logger.warning(
                    "Failed to broadcast ACL member added event: #{inspect(broadcast_error)}"
                  )

                  # Still broadcast internal message even if external broadcast fails
                  broadcast_acl_updated(acl_id)

                  json(conn, %{data: member_to_json(new_member)})
              end

            {:error, error} ->
              conn
              |> put_status(:bad_request)
              |> json(%{error: "Creation failed: #{inspect(error)}"})
          end
        else
          error ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Entity lookup failed: #{inspect(error)}"})
        end
      end
    end
  end

  @doc """
  PUT /api/acls/:acl_id/members/:member_id

  Updates the role of an ACL member.
  """
  @spec update_role(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:update_role,
    summary: "Update ACL Member Role",
    description: "Updates the role of an ACL member identified by ACL ID and member external ID.",
    parameters: [
      acl_id: [
        in: :path,
        description: "Access List ID",
        type: :string,
        required: true
      ],
      member_id: [
        in: :path,
        description: "Member external ID",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "ACL Member update payload",
      "application/json",
      @acl_member_update_request_schema
    },
    responses: [
      ok: {
        "Updated ACL Member",
        "application/json",
        @acl_member_update_response_schema
      }
    ]
  )

  def update_role(conn, %{
        "acl_id" => acl_id,
        "member_id" => external_id,
        "member" => member_params
      }) do
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

    case Ash.read(membership_query) do
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
              # Broadcast event to all maps using this ACL
              case AclEventBroadcaster.broadcast_member_event(
                     acl_id,
                     updated_membership,
                     :acl_member_updated
                   ) do
                :ok ->
                  broadcast_acl_updated(acl_id)

                  json(conn, %{data: member_to_json(updated_membership)})

                {:error, broadcast_error} ->
                  Logger.warning(
                    "Failed to broadcast ACL member updated event: #{inspect(broadcast_error)}"
                  )

                  # Still broadcast internal message even if external broadcast fails
                  broadcast_acl_updated(acl_id)

                  json(conn, %{data: member_to_json(updated_membership)})
              end

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

  Deletes an ACL member.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:delete,
    summary: "Delete ACL Member",
    description: "Deletes an ACL member identified by ACL ID and member external ID.",
    parameters: [
      acl_id: [
        in: :path,
        description: "Access List ID",
        type: :string,
        required: true
      ],
      member_id: [
        in: :path,
        description: "Member external ID",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok: {
        "ACL Member deletion confirmation",
        "application/json",
        @acl_member_delete_response_schema
      }
    ]
  )

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

    case Ash.read(membership_query) do
      {:ok, [membership]} ->
        case AccessListMember.destroy(membership) do
          :ok ->
            # Broadcast event to all maps using this ACL
            case AclEventBroadcaster.broadcast_member_event(
                   acl_id,
                   membership,
                   :acl_member_removed
                 ) do
              :ok ->
                broadcast_acl_updated(acl_id)

                json(conn, %{ok: true})

              {:error, broadcast_error} ->
                Logger.warning(
                  "Failed to broadcast ACL member removed event: #{inspect(broadcast_error)}"
                )

                # Still broadcast internal message even if external broadcast fails
                broadcast_acl_updated(acl_id)

                json(conn, %{ok: true})
            end

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

  defp broadcast_acl_updated(acl_id) do
    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "acls:#{acl_id}",
      {:acl_updated, %{acl_id: acl_id}}
    )
  end

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
