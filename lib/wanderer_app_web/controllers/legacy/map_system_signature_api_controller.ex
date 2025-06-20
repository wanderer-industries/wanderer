defmodule WandererAppWeb.Legacy.MapSystemSignatureAPIController do
  @deprecated "Use /api/v1/signatures JSON:API endpoints instead. This controller will be removed after 2025-12-31."

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.Api.MapSystemSignature
  alias WandererApp.Contexts.MapSignatures

  action_fallback WandererAppWeb.FallbackController

  @moduledoc """
  API controller for managing map system signatures.
  """

  @deprecated "Use /api/v1/map_system_signatures JSON:API endpoints instead. This controller will be removed after 2025-12-31."

  # Inlined OpenAPI schema for a map system signature
  @signature_schema %OpenApiSpex.Schema{
    title: "MapSystemSignature",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string, format: :uuid},
      system_id: %OpenApiSpex.Schema{type: :string, format: :uuid},
      eve_id: %OpenApiSpex.Schema{type: :string},
      character_eve_id: %OpenApiSpex.Schema{type: :string},
      name: %OpenApiSpex.Schema{type: :string, nullable: true},
      description: %OpenApiSpex.Schema{type: :string, nullable: true},
      type: %OpenApiSpex.Schema{type: :string, nullable: true},
      linked_system_id: %OpenApiSpex.Schema{type: :integer, nullable: true},
      kind: %OpenApiSpex.Schema{type: :string, nullable: true},
      group: %OpenApiSpex.Schema{type: :string, nullable: true},
      custom_info: %OpenApiSpex.Schema{type: :string, nullable: true},
      updated: %OpenApiSpex.Schema{type: :integer, nullable: true},
      inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
      updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time}
    },
    required: [
      :id,
      :system_id,
      :eve_id,
      :character_eve_id
    ],
    example: %{
      id: "sig-uuid-1",
      system_id: "sys-uuid-1",
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
    signatures = MapSignatures.list_signatures(map_id)
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
            json(conn, %{data: signature})

          _ ->
            conn |> put_status(:not_found) |> json(%{error: "Signature not found"})
        end

      _ ->
        conn |> put_status(:not_found) |> json(%{error: "Signature not found"})
    end
  end

  @doc """
  Create a new signature.
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
         }}
    ]
  )

  def create(conn, params) do
    case MapSignatures.create_signature(conn, params) do
      {:ok, sig} -> conn |> put_status(:created) |> json(%{data: sig})
      {:error, error} -> conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end

  @doc """
  Update a signature by ID.
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
         }}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    case MapSignatures.update_signature(conn, id, params) do
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
    case MapSignatures.delete_signature(conn, id) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, error} -> conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end
end
