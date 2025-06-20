defmodule WandererAppWeb.Legacy.AccessListMemberAPIController do
  @moduledoc """
  Handles creation, role updates, and deletion of individual ACL members.
  """

  @deprecated "Use /api/v1/access_list_members JSON:API endpoints instead. This controller will be removed after 2025-12-31."

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.Api.AccessListMember
  import Ash.Query
  require Logger

  action_fallback WandererAppWeb.FallbackController

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
  GET /api/acls/:acl_id/members

  Lists ACL members with optional filtering.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:index,
    summary: "List ACL Members",
    description: "Lists all members of an ACL with optional filtering by role or type.",
    parameters: [
      acl_id: [
        in: :path,
        description: "Access List ID",
        type: :string,
        required: true
      ],
      role: [
        in: :query,
        description: "Filter by member role",
        type: :string,
        required: false
      ],
      type: [
        in: :query,
        description: "Filter by member type (character, corporation, alliance)",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: {
        "List of ACL Members",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            data: %OpenApiSpex.Schema{
              type: :array,
              items: @acl_member_create_response_schema.properties.data
            }
          },
          required: ["data"]
        }
      }
    ]
  )

  def index(conn, %{"acl_id" => acl_id} = params) do
    query = build_member_query(acl_id, params)

    case WandererApp.Api.read(query) do
      {:ok, members} ->
        json(conn, %{data: Enum.map(members, &member_to_json/1)})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error reading ACL members: #{inspect(error)}"})
    end
  end

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
      created: {
        "Created ACL Member",
        "application/json",
        @acl_member_create_response_schema
      },
      unprocessable_entity: {
        "Validation errors",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            error: %OpenApiSpex.Schema{type: :string}
          }
        }
      },
      bad_request: {
        "Bad request",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            error: %OpenApiSpex.Schema{type: :string}
          }
        }
      }
    ]
  )

  def create(conn, %{"acl_id" => acl_id} = params) do
    alias WandererAppWeb.Validations.ApiValidations

    with {:ok, validated} <- ApiValidations.validate_acl_member_params(params) do
      {key, type, eve_id} = determine_entity_details(validated)
      create_member_with_entity_info(conn, acl_id, validated, key, type, eve_id)
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
    alias WandererAppWeb.Validations.ApiValidations

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

    with {:ok, validated} <- ApiValidations.validate_member_update_params(member_params),
         {:ok, [membership]} <- WandererApp.Api.read(membership_query) do
      new_role = Map.get(validated, :role, membership.role)

      member_type =
        cond do
          membership.eve_corporation_id -> "corporation"
          membership.eve_alliance_id -> "alliance"
          membership.eve_character_id -> "character"
          true -> "character"
        end

      # Validate role restrictions for entity type
      with {:ok, _} <- ApiValidations.validate_role_for_entity_type(new_role, member_type) do
        case AccessListMember.update_role(membership, Map.put(member_params, "role", new_role)) do
          {:ok, updated_membership} ->
            json(conn, %{data: member_to_json(updated_membership)})

          {:error, error} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: inspect(error)})
        end
      end
    else
      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Membership not found for given ACL and external id"})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

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

    case WandererApp.Api.read(membership_query) do
      {:ok, [membership]} ->
        case AccessListMember.destroy(membership) do
          :ok ->
            send_resp(conn, 204, "")

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

  defp build_member_query(acl_id, params) do
    base_query =
      AccessListMember
      |> Ash.Query.new()
      |> filter(access_list_id == ^acl_id)

    base_query
    |> apply_role_filter(Map.get(params, "role"))
    |> apply_type_filter(Map.get(params, "type"))
  end

  # Define valid roles as atoms to avoid String.to_atom/1
  @valid_roles %{
    "admin" => :admin,
    "manager" => :manager,
    "member" => :member,
    "viewer" => :viewer
  }

  defp apply_role_filter(query, nil), do: query

  defp apply_role_filter(query, role) when is_binary(role) do
    case Map.get(@valid_roles, role) do
      # Invalid role, don't filter
      nil -> query
      role_atom -> filter(query, role == ^role_atom)
    end
  end

  defp apply_role_filter(query, _invalid_role), do: query

  defp apply_type_filter(query, "character") do
    filter(query, not is_nil(eve_character_id))
  end

  defp apply_type_filter(query, "corporation") do
    filter(query, not is_nil(eve_corporation_id))
  end

  defp apply_type_filter(query, "alliance") do
    filter(query, not is_nil(eve_alliance_id))
  end

  defp apply_type_filter(query, _), do: query

  defp determine_entity_details(validated) do
    cond do
      Map.get(validated, :eve_corporation_id) ->
        {"eve_corporation_id", "corporation", Map.get(validated, :eve_corporation_id)}

      Map.get(validated, :eve_alliance_id) ->
        {"eve_alliance_id", "alliance", Map.get(validated, :eve_alliance_id)}

      Map.get(validated, :eve_character_id) ->
        {"eve_character_id", "character", Map.get(validated, :eve_character_id)}
    end
  end

  defp create_member_with_entity_info(conn, acl_id, validated, key, type, eve_id) do
    info_fetcher = get_entity_info_fetcher(type)

    case info_fetcher.(to_string(eve_id)) do
      {:ok, entity_info} ->
        create_member_with_fetched_info(conn, acl_id, validated, key, eve_id, entity_info)

      error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Entity lookup failed: #{inspect(error)}"})
    end
  end

  defp get_entity_info_fetcher("character"), do: &WandererApp.Esi.get_character_info/1
  defp get_entity_info_fetcher("corporation"), do: &WandererApp.Esi.get_corporation_info/1
  defp get_entity_info_fetcher("alliance"), do: &WandererApp.Esi.get_alliance_info/1

  defp create_member_with_fetched_info(conn, acl_id, validated, key, eve_id, entity_info) do
    member_name = Map.get(entity_info, "name")

    new_params =
      validated
      |> Map.drop([:eve_corporation_id, :eve_alliance_id, :eve_character_id])
      |> Map.put(key, to_string(eve_id))
      |> Map.put("name", member_name)
      |> Map.put("access_list_id", acl_id)

    case AccessListMember.create(new_params) do
      {:ok, new_member} ->
        conn
        |> put_status(:created)
        |> json(%{data: member_to_json(new_member)})

      {:error, error} ->
        status =
          if match?(%Ash.Error.Invalid{}, error), do: :unprocessable_entity, else: :bad_request

        conn
        |> put_status(status)
        |> json(%{error: "Creation failed: #{inspect(error)}"})
    end
  end

  @doc false
  defp member_to_json(member) do
    base = %{
      id: member.id,
      name: member.name,
      role: member.role,
      eve_character_id: member.eve_character_id,
      eve_corporation_id: member.eve_corporation_id,
      eve_alliance_id: member.eve_alliance_id,
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
