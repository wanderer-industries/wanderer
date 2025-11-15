defmodule WandererAppWeb.MapSystemSignatureAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.Api.MapSystemSignature
  alias WandererApp.Map.Operations, as: MapOperations

  @moduledoc """
  API controller for managing map system signatures.
  """

  # Inlined OpenAPI schema for a map system signature
  @signature_schema %OpenApiSpex.Schema{
    title: "MapSystemSignature",
    description: "A cosmic signature scanned in an EVE Online solar system",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{
        type: :string,
        format: :uuid,
        description: "Unique signature identifier"
      },
      solar_system_id: %OpenApiSpex.Schema{
        type: :integer,
        description: "EVE Online solar system ID"
      },
      eve_id: %OpenApiSpex.Schema{
        type: :string,
        description: "In-game signature ID (e.g., ABC-123)"
      },
      character_eve_id: %OpenApiSpex.Schema{
        type: :string,
        description:
          "EVE character ID who scanned/updated this signature. Must be a valid character in the database. If not provided, defaults to the map owner's character.",
        nullable: true
      },
      name: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Signature name"},
      description: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Additional notes"
      },
      type: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Signature type"},
      linked_system_id: %OpenApiSpex.Schema{
        type: :integer,
        nullable: true,
        description: "Connected solar system ID for wormholes"
      },
      kind: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Signature kind (e.g., cosmic_signature)"
      },
      group: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Signature group (e.g., wormhole, data, relic)"
      },
      custom_info: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Custom metadata"
      },
      updated: %OpenApiSpex.Schema{type: :integer, nullable: true, description: "Update counter"},
      inserted_at: %OpenApiSpex.Schema{
        type: :string,
        format: :date_time,
        description: "Creation timestamp"
      },
      updated_at: %OpenApiSpex.Schema{
        type: :string,
        format: :date_time,
        description: "Last update timestamp"
      }
    },
    required: [
      :id,
      :solar_system_id,
      :eve_id
    ],
    example: %{
      id: "sig-uuid-1",
      solar_system_id: 30_000_142,
      eve_id: "ABC-123",
      character_eve_id: "123456789",
      name: "Wormhole K162",
      description: "Leads to unknown space",
      type: "Wormhole",
      linked_system_id: 30_000_144,
      kind: "cosmic_signature",
      group: "wormhole",
      custom_info: "Fresh",
      updated: 1,
      inserted_at: "2025-04-30T10:00:00Z",
      updated_at: "2025-04-30T10:00:00Z"
    }
  }

  @doc """
  List all signatures for a map.
  """
  operation(:index,
    summary: "List all signatures for a map",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok:
        {"List of signatures", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             data: %OpenApiSpex.Schema{
               type: :array,
               items: @signature_schema
             }
           },
           example: %{
             data: [@signature_schema.example]
           }
         }}
    ]
  )

  def index(conn, _params) do
    map_id = conn.assigns.map_id
    signatures = MapOperations.list_signatures(map_id)
    json(conn, %{data: signatures})
  end

  @doc """
  Show a single signature by ID.
  """
  operation(:show,
    summary: "Show a single signature by ID",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ],
      id: [in: :path, description: "Signature UUID", type: :string, required: true]
    ],
    responses: [
      ok:
        {"Signature", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: @signature_schema},
           example: %{data: @signature_schema.example}
         }}
    ]
  )

  def show(conn, %{"id" => id}) do
    map_id = conn.assigns.map_id

    case MapSystemSignature.by_id(id) do
      {:ok, signature} ->
        case WandererApp.Api.MapSystem.by_id(signature.system_id) do
          {:ok, system} when system.map_id == map_id ->
            # Add solar_system_id and remove system_id
            # Convert to a plain map to avoid encoder issues
            signature_data =
              signature
              |> Map.from_struct()
              |> Map.put(:solar_system_id, system.solar_system_id)
              |> Map.drop([:system_id, :__meta__, :system, :aggregates, :calculations])

            json(conn, %{data: signature_data})

          _ ->
            conn |> put_status(:not_found) |> json(%{error: "Signature not found"})
        end

      _ ->
        conn |> put_status(:not_found) |> json(%{error: "Signature not found"})
    end
  end

  @doc """
  Create a new signature.

  The `character_eve_id` field is optional. If provided, it must be a valid character
  that exists in the database, otherwise a 422 error will be returned. If not provided,
  the signature will be associated with the map owner's character.
  """
  operation(:create,
    summary: "Create a new signature",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ]
    ],
    request_body: {"Signature", "application/json", @signature_schema},
    responses: [
      created:
        {"Created signature", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: @signature_schema},
           example: %{data: @signature_schema.example}
         }},
      unprocessable_entity:
        {"Validation error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             error: %OpenApiSpex.Schema{
               type: :string,
               description:
                 "Error type (e.g., 'invalid_character', 'system_not_found', 'missing_params')"
             }
           },
           example: %{error: "invalid_character"}
         }}
    ]
  )

  def create(conn, params) do
    case MapOperations.create_signature(conn, params) do
      {:ok, sig} -> conn |> put_status(:created) |> json(%{data: sig})
      {:error, error} -> conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end

  @doc """
  Update a signature by ID.

  The `character_eve_id` field is optional. If provided, it must be a valid character
  that exists in the database, otherwise a 422 error will be returned.
  """
  operation(:update,
    summary: "Update a signature by ID",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ],
      id: [in: :path, description: "Signature UUID", type: :string, required: true]
    ],
    request_body: {"Signature update", "application/json", @signature_schema},
    responses: [
      ok:
        {"Updated signature", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: @signature_schema},
           example: %{data: @signature_schema.example}
         }},
      unprocessable_entity:
        {"Validation error", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             error: %OpenApiSpex.Schema{
               type: :string,
               description: "Error type (e.g., 'invalid_character', 'unexpected_error')"
             }
           },
           example: %{error: "invalid_character"}
         }}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    case MapOperations.update_signature(conn, id, params) do
      {:ok, sig} -> json(conn, %{data: sig})
      {:error, error} -> conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end

  @doc """
  Delete a signature by ID.
  """
  operation(:delete,
    summary: "Delete a signature by ID",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ],
      id: [in: :path, description: "Signature UUID", type: :string, required: true]
    ],
    responses: [
      no_content:
        {"Deleted", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           example: %{}
         }}
    ]
  )

  def delete(conn, %{"id" => id}) do
    case MapOperations.delete_signature(conn, id) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, error} -> conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end
end
