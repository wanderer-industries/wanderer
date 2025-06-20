defmodule WandererAppWeb.Legacy.MapAccessListAPIController do
  @moduledoc """
  API endpoints for managing Access Lists.

  Endpoints:
    - GET /api/map/acls?map_id=... or ?slug=...   (list ACLs)
    - POST /api/map/acls                         (create ACL)
    - GET /api/acls/:id                          (show ACL)
    - PUT /api/acls/:id                          (update ACL)
  """

  @deprecated "Use /api/v1/access_lists JSON:API endpoints instead. This controller will be removed after 2025-12-31."

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias WandererApp.Api.{AccessList, Character}
  alias WandererAppWeb.Helpers.APIUtils
  alias WandererAppWeb.Schemas
  import Ash.Query
  require Logger

  action_fallback WandererAppWeb.FallbackController

  # ------------------------------------------------------------------------
  # Schemas for OpenApiSpex
  # ------------------------------------------------------------------------

  @acl_list_item_schema %Schema{
    type: :object,
    properties: %{
      id: Schemas.uuid_schema("ACL ID"),
      name: %Schema{type: :string, description: "ACL name"},
      description: %Schema{type: :string, description: "ACL description"},
      owner_eve_id: %Schema{type: :string, description: "Owner's EVE character ID"},
      inserted_at: Schemas.timestamp_schema("Creation timestamp"),
      updated_at: Schemas.timestamp_schema("Last update timestamp")
    },
    required: ["id", "name"]
  }

  @acl_index_response_schema Schemas.index_response_schema(
                               @acl_list_item_schema,
                               "List of access control lists"
                             )

  @acl_create_properties %{
    owner_eve_id: %Schema{
      type: :string,
      description: "EVE character ID of the owner (must match an existing character)"
    },
    name: %Schema{
      type: :string,
      description: "Name of the access list"
    },
    description: %Schema{
      type: :string,
      description: "Optional description of the access list"
    }
  }

  @acl_create_request_schema %Schema{
    type: :object,
    properties: %{
      acl:
        Schemas.create_request_schema(
          @acl_create_properties,
          ["owner_eve_id", "name"]
        )
        |> Schemas.with_example(%{
          "owner_eve_id" => "2112073677",
          "name" => "My Access List",
          "description" => "Optional description"
        })
    },
    required: ["acl"]
  }

  @acl_resource_schema %Schema{
    type: :object,
    properties: %{
      id: Schemas.uuid_schema("ACL ID"),
      name: %Schema{type: :string, description: "ACL name"},
      description: %Schema{type: :string, description: "ACL description"},
      owner_id: Schemas.uuid_schema("Owner ID"),
      api_key: Schemas.api_key_schema("ACL API key for authentication"),
      inserted_at: Schemas.timestamp_schema("Creation timestamp"),
      updated_at: Schemas.timestamp_schema("Last update timestamp")
    },
    required: ["id", "name"]
  }

  @acl_create_response_schema Schemas.create_response_schema(
                                @acl_resource_schema,
                                "Created access control list"
                              )

  @acl_member_schema %Schema{
    type: :object,
    properties: %{
      id: Schemas.uuid_schema("Member ID"),
      name: %Schema{type: :string, description: "Member name"},
      role: %Schema{type: :string, description: "Member role"},
      eve_character_id: Schemas.eve_character_id_schema(),
      eve_corporation_id: %Schema{type: :string, description: "EVE corporation ID"},
      eve_alliance_id: %Schema{type: :string, description: "EVE alliance ID"},
      inserted_at: Schemas.timestamp_schema("Member added timestamp"),
      updated_at: Schemas.timestamp_schema("Member updated timestamp")
    },
    required: ["id", "name", "role"]
  }

  @acl_detailed_schema %Schema{
    type: :object,
    properties: %{
      id: Schemas.uuid_schema("ACL ID"),
      name: %Schema{type: :string, description: "ACL name"},
      description: %Schema{type: :string, description: "ACL description"},
      owner_id: Schemas.uuid_schema("Owner ID"),
      api_key: Schemas.api_key_schema("ACL API key for authentication"),
      inserted_at: Schemas.timestamp_schema("Creation timestamp"),
      updated_at: Schemas.timestamp_schema("Last update timestamp"),
      members: %Schema{
        type: :array,
        items: @acl_member_schema,
        description: "List of ACL members"
      }
    },
    required: ["id", "name"]
  }

  @acl_show_response_schema Schemas.show_response_schema(
                              @acl_detailed_schema,
                              "Access control list details with members"
                            )

  @acl_update_properties %{
    name: %Schema{type: :string, description: "ACL name"},
    description: %Schema{type: :string, description: "ACL description"}
  }

  @acl_update_request_schema %Schema{
    type: :object,
    properties: %{
      acl: Schemas.update_request_schema(@acl_update_properties)
    },
    required: ["acl"]
  }

  # Used in operation :update => the response "Updated ACL"
  @acl_update_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          id: %OpenApiSpex.Schema{type: :string},
          name: %OpenApiSpex.Schema{type: :string},
          description: %OpenApiSpex.Schema{type: :string},
          owner_id: %OpenApiSpex.Schema{type: :string},
          api_key: %OpenApiSpex.Schema{type: :string},
          inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
          updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
          members: %OpenApiSpex.Schema{
            type: :array,
            items: %OpenApiSpex.Schema{
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
          }
        },
        required: ["id", "name"]
      }
    },
    required: ["data"]
  }

  # ------------------------------------------------------------------------
  # ENDPOINTS
  # ------------------------------------------------------------------------

  @doc """
  GET /api/map/acls?map_id=... or ?slug=...

  Lists the ACLs for a given map.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:index,
    summary: "List ACLs for a Map",
    description:
      "Lists the ACLs for a given map. Provide only one of map_id or slug as a query parameter. If both are provided, the request will fail.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Provide only one of map_id or slug.",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Provide only one of map_id or slug.",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: {"List of ACLs", "application/json", @acl_index_response_schema},
      bad_request:
        {"Error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{error: %OpenApiSpex.Schema{type: :string}},
           required: ["error"],
           example: %{"error" => "Must provide only one of map_id or slug as a query parameter"}
         }}
    ]
  )

  def index(conn, params) do
    case APIUtils.fetch_map_id(params) do
      {:ok, map_identifier} ->
        with {:ok, map} <- get_map(map_identifier),
             {:ok, loaded_map} <- Ash.load(map, acls: [:owner]) do
          acls = loaded_map.acls || []
          json(conn, %{data: Enum.map(acls, &acl_to_list_json/1)})
        else
          {:error, :map_not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{
              error: "Map not found. Please provide a valid map_id or slug as a query parameter."
            })

          {:error, error} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: inspect(error)})
        end

      {:error, _msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"})
    end
  end

  @doc """
  POST /api/map/acls

  Creates a new ACL for a map.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:create,
    summary: "Create ACL for a Map",
    description:
      "Creates a new ACL for a given map. Provide only one of map_id or slug as a query parameter. If both are provided, the request will fail.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Provide only one of map_id or slug.",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Provide only one of map_id or slug.",
        type: :string,
        required: false
      ]
    ],
    request_body: {"ACL parameters", "application/json", @acl_create_request_schema},
    responses: [
      created: {"Created ACL", "application/json", @acl_create_response_schema},
      bad_request:
        {"Error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{error: %OpenApiSpex.Schema{type: :string}},
           required: ["error"],
           example: %{"error" => "Must provide only one of map_id or slug as a query parameter"}
         }}
    ]
  )

  def create(conn, params) do
    with {:ok, map_identifier} <- APIUtils.fetch_map_id(params),
         {:ok, map} <- get_map(map_identifier),
         %{"acl" => acl_params} <- params,
         owner_eve_id when not is_nil(owner_eve_id) <- Map.get(acl_params, "owner_eve_id"),
         owner_eve_id_str = to_string(owner_eve_id),
         {:ok, character} <- find_character_by_eve_id(owner_eve_id_str),
         {:ok, new_api_key} <- {:ok, UUID.uuid4()},
         new_params <-
           acl_params
           |> Map.delete("owner_eve_id")
           |> Map.put("owner_id", character.id)
           |> Map.put("api_key", new_api_key),
         {:ok, new_acl} <- AccessList.new(new_params),
         {:ok, _updated_map} <- associate_acl_with_map(map, new_acl) do
      conn
      |> put_status(:created)
      |> json(%{data: acl_to_json(new_acl)})
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Map not found. Please provide a valid map_id or slug as a query parameter."
        })

      {:error, "Must provide either ?map_id=UUID or ?slug=SLUG"} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"})

      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required field: owner_eve_id"})

      {:error, "owner_eve_id does not match any existing character"} = _error ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error:
            "Character not found: The provided owner_eve_id does not match any existing character"
        })

      %{} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required 'acl' object in request body"})

      error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(error)})
    end
  end

  @doc """
  GET /api/acls

  Lists all ACLs owned by the authenticated character.
  """
  @spec list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:list,
    summary: "List user's ACLs",
    description: "Lists all ACLs owned by the authenticated character.",
    responses: [
      ok: {"List of user's ACLs", "application/json", @acl_index_response_schema}
    ]
  )

  def list(conn, _params) do
    # Get character from authentication context
    character_id = conn.assigns.current_character.id

    query =
      AccessList
      |> Ash.Query.new()
      |> filter(owner_id == ^character_id)

    case WandererApp.Api.read(query) do
      {:ok, acls} ->
        json(conn, %{data: Enum.map(acls, &acl_to_list_json/1)})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error reading ACLs: #{inspect(error)}"})
    end
  end

  @doc """
  POST /api/acls

  Creates a new ACL owned by the authenticated character.
  """
  @spec create_simple(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:create_simple,
    summary: "Create ACL",
    description: "Creates a new ACL owned by the authenticated character.",
    request_body:
      {"ACL parameters", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           acl: %OpenApiSpex.Schema{
             type: :object,
             properties: %{
               name: %OpenApiSpex.Schema{type: :string},
               description: %OpenApiSpex.Schema{type: :string}
             },
             required: ["name"]
           }
         },
         required: ["acl"]
       }},
    responses: [
      created: {"Created ACL", "application/json", @acl_create_response_schema}
    ]
  )

  def create_simple(conn, params) do
    case params do
      %{"acl" => acl_params} ->
        create_acl_with_params(conn, acl_params)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Missing required 'acl' object in request body"})
    end
  end

  defp create_acl_with_params(conn, acl_params) do
    character_id = conn.assigns.current_character.id

    api_key = generate_secure_api_key("acl")

    new_params =
      acl_params
      |> Map.put("owner_id", character_id)
      |> Map.put("api_key", api_key)

    case AccessList.new(new_params) do
      {:ok, new_acl} ->
        conn
        |> put_status(:created)
        |> json(%{data: acl_to_json(new_acl)})

      {:error, error} ->
        handle_acl_creation_error(conn, error)
    end
  end

  defp handle_acl_creation_error(conn, %Ash.Error.Invalid{errors: validation_errors}) do
    formatted_errors = format_validation_errors(validation_errors)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: formatted_errors})
  end

  defp handle_acl_creation_error(conn, error) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Failed to create ACL: #{inspect(error)}"})
  end

  defp format_validation_errors(validation_errors) do
    Enum.reduce(validation_errors, %{}, fn err, acc ->
      case err do
        %Ash.Error.Changes.InvalidAttribute{field: field, message: message} ->
          Map.put(acc, field, [message])

        %Ash.Error.Changes.Required{field: field} ->
          Map.put(acc, field, ["is required"])

        _ ->
          acc
      end
    end)
  end

  @doc """
  GET /api/acls/:id

  Shows a specific ACL (with its members).
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:show,
    summary: "Get ACL details",
    description: "Retrieves details for a specific ACL by its ID.",
    parameters: [
      id: [
        in: :path,
        description: "ACL identifier (UUID)",
        type: :string,
        required: true,
        example: "00000000-0000-0000-0000-000000000000"
      ]
    ],
    responses: [
      ok: {
        "ACL details",
        "application/json",
        @acl_show_response_schema
      },
      not_found:
        {"Error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             error: %OpenApiSpex.Schema{type: :string}
           },
           required: ["error"],
           example: %{
             "error" => "ACL not found"
           }
         }},
      internal_server_error:
        {"Error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             error: %OpenApiSpex.Schema{type: :string}
           },
           required: ["error"],
           example: %{
             "error" => "Failed to load ACL members: reason"
           }
         }}
    ]
  )

  def show(conn, %{"id" => id}) do
    # Validate UUID format
    case Ecto.UUID.cast(id) do
      {:ok, _} ->
        query =
          AccessList
          |> Ash.Query.new()
          |> filter(id == ^id)

        case WandererApp.Api.read(query) do
          {:ok, [acl]} ->
            load_and_show_acl(conn, acl)

          {:ok, []} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "ACL not found"})

          {:error, error} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Error reading ACL: #{inspect(error)}"})
        end

      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "ACL not found"})
    end
  end

  @doc """
  PUT /api/acls/:id

  Updates an ACL.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:update,
    summary: "Update an ACL",
    description: "Updates an existing ACL by its ID.",
    parameters: [
      id: [
        in: :path,
        description: "ACL identifier (UUID)",
        type: :string,
        required: true,
        example: "00000000-0000-0000-0000-000000000000"
      ]
    ],
    request_body: {
      "ACL update payload",
      "application/json",
      @acl_update_request_schema
    },
    responses: [
      ok: {
        "Updated ACL",
        "application/json",
        @acl_update_response_schema
      },
      bad_request:
        {"Error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             error: %OpenApiSpex.Schema{type: :string}
           },
           required: ["error"],
           example: %{
             "error" => "Failed to update ACL: invalid parameters"
           }
         }},
      not_found:
        {"Error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             error: %OpenApiSpex.Schema{type: :string}
           },
           required: ["error"],
           example: %{
             "error" => "ACL not found"
           }
         }}
    ]
  )

  def update(conn, %{"id" => id, "acl" => acl_params}) do
    # Validate UUID format
    case Ecto.UUID.cast(id) do
      {:ok, _} ->
        with {:ok, acl} <- AccessList.by_id(id),
             {:ok, updated_acl} <- AccessList.update(acl, acl_params),
             {:ok, updated_acl} <- Ash.load(updated_acl, :members) do
          json(conn, %{data: acl_to_json(updated_acl)})
        else
          {:error, %Ash.Error.Query.NotFound{}} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "ACL not found"})

          {:error, %Ash.Error.Invalid{errors: validation_errors}} ->
            handle_update_validation_errors(conn, validation_errors)

          {:error, error} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Failed to update ACL: #{inspect(error)}"})
        end

      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "ACL not found"})
    end
  end

  @doc """
  DELETE /api/acls/:id

  Deletes an ACL.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:delete,
    summary: "Delete an ACL",
    description: "Deletes an existing ACL by its ID.",
    parameters: [
      id: [
        in: :path,
        description: "ACL identifier (UUID)",
        type: :string,
        required: true
      ]
    ],
    responses: [
      no_content:
        {"ACL deleted successfully", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found:
        {"Error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{error: %OpenApiSpex.Schema{type: :string}},
           required: ["error"]
         }}
    ]
  )

  def delete(conn, %{"id" => id}) do
    # Validate UUID format
    case Ecto.UUID.cast(id) do
      {:ok, _} ->
        with {:ok, acl} <- AccessList.by_id(id),
             :ok <- AccessList.destroy(acl) do
          conn
          |> put_status(:no_content)
          |> json(%{})
        else
          {:error, %Ash.Error.Invalid{}} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "ACL not found"})

          {:error, %Ash.Error.Query.NotFound{}} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "ACL not found"})

          {:error, error} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Failed to delete ACL: #{inspect(error)}"})
        end

      :error ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "ACL not found"})
    end
  end

  # ---------------------------------------------------------------------------
  # Private / Helper Functions
  # ---------------------------------------------------------------------------
  defp get_map(map_identifier) do
    case WandererApp.Api.Map.by_id(map_identifier) do
      {:ok, map} -> {:ok, map}
      {:error, _} -> {:error, :map_not_found}
    end
  end

  defp acl_to_json(acl) do
    members =
      case acl.members do
        %Ash.NotLoaded{} -> []
        list when is_list(list) -> Enum.map(list, &member_to_json/1)
        _ -> []
      end

    %{
      id: acl.id,
      name: acl.name,
      description: acl.description,
      owner_id: acl.owner_id,
      api_key: acl.api_key,
      inserted_at: acl.inserted_at,
      updated_at: acl.updated_at,
      members: members
    }
  end

  defp acl_to_list_json(acl) do
    owner_eve_id =
      case acl.owner do
        %Character{eve_id: eid} -> eid
        _ -> nil
      end

    %{
      id: acl.id,
      name: acl.name,
      description: acl.description,
      owner_eve_id: owner_eve_id,
      inserted_at: acl.inserted_at,
      updated_at: acl.updated_at
    }
  end

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

  defp find_character_by_eve_id(eve_id) do
    query =
      Character
      |> Ash.Query.new()
      |> filter(eve_id == ^eve_id)

    case WandererApp.Api.read(query) do
      {:ok, [character]} ->
        {:ok, character}

      {:ok, []} ->
        {:error, "owner_eve_id does not match any existing character"}

      other ->
        other
    end
  end

  defp load_and_show_acl(conn, acl) do
    case Ash.load(acl, :members) do
      {:ok, loaded_acl} ->
        json(conn, %{data: acl_to_json(loaded_acl)})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to load ACL members: #{inspect(error)}"})
    end
  end

  defp handle_update_validation_errors(conn, validation_errors) do
    formatted_errors = format_validation_errors(validation_errors)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: formatted_errors})
  end

  # Helper to associate a new ACL with a map.
  defp associate_acl_with_map(map, new_acl) do
    with {:ok, api_map} <- WandererApp.Api.Map.by_id(map.id),
         {:ok, loaded_map} <- Ash.load(api_map, :acls) do
      new_acl_id = if is_binary(new_acl), do: new_acl, else: new_acl.id

      # Extract IDs from current ACLs to ensure we're working with UUIDs only
      current_acl_ids =
        loaded_map.acls
        |> Kernel.||([])
        |> Enum.map(fn
          acl when is_binary(acl) -> acl
          acl -> acl.id
        end)

      updated_acls = current_acl_ids ++ [new_acl_id]

      case WandererApp.Api.Map.update_acls(loaded_map, %{acls: updated_acls}) do
        {:ok, updated_map} ->
          {:ok, updated_map}

        {:error, error} ->
          Logger.error("Failed to update map #{loaded_map.id} with new ACL: #{inspect(error)}")
          {:error, error}
      end
    else
      error ->
        Logger.error("Error loading map ACLs: #{inspect(error)}")
        {:error, error}
    end
  end

  # Generate a cryptographically secure API key with the given prefix
  defp generate_secure_api_key(prefix) do
    # Use 24 bytes for higher entropy (32 chars base64)
    random_part = 
      :crypto.strong_rand_bytes(24)
      |> Base.url_encode64(padding: false)
    
    # Add timestamp component to ensure uniqueness even with same random bytes
    timestamp = System.system_time(:microsecond) |> Integer.to_string(36)
    
    "#{prefix}_#{timestamp}_#{random_part}"
  end
end
