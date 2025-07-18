defmodule WandererAppWeb.MapSystemStructureAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WandererApp.Api.MapSystemStructure
  alias OpenApiSpex.Schema
  alias WandererApp.Map.Operations, as: MapOperations

  @moduledoc """
  API controller for managing map system structures.
  """

  # Inlined OpenAPI schema for a map system structure
  @structure_schema %Schema{
    title: "MapSystemStructure",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      system_id: %Schema{type: :string, format: :uuid},
      solar_system_name: %Schema{type: :string},
      solar_system_id: %Schema{type: :integer},
      structure_type_id: %Schema{type: :string},
      structure_type: %Schema{type: :string},
      character_eve_id: %Schema{type: :string},
      name: %Schema{type: :string},
      notes: %Schema{type: :string, nullable: true},
      owner_name: %Schema{type: :string, nullable: true},
      owner_ticker: %Schema{type: :string, nullable: true},
      owner_id: %Schema{type: :string, nullable: true},
      status: %Schema{type: :string, nullable: true},
      end_time: %Schema{type: :string, format: :date_time, nullable: true},
      inserted_at: %Schema{type: :string, format: :date_time},
      updated_at: %Schema{type: :string, format: :date_time}
    },
    required: [
      :id,
      :system_id,
      :solar_system_name,
      :solar_system_id,
      :structure_type_id,
      :structure_type,
      :character_eve_id,
      :name
    ],
    example: %{
      id: "struct-uuid-1",
      system_id: "sys-uuid-1",
      solar_system_name: "Jita",
      solar_system_id: 30_000_142,
      structure_type_id: "35832",
      structure_type: "Astrahus",
      character_eve_id: "123456789",
      name: "Jita Trade Hub",
      notes: "Main market structure",
      owner_name: "Wanderer Corp",
      owner_ticker: "WANDR",
      owner_id: "corp-uuid-1",
      status: "anchoring",
      end_time: "2025-05-01T12:00:00Z",
      inserted_at: "2025-04-30T10:00:00Z",
      updated_at: "2025-04-30T10:00:00Z"
    }
  }

  @doc """
  List all structures for a map.
  """
  operation(:index,
    summary: "List all structures for a map",
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
        {"List of structures", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             data: %OpenApiSpex.Schema{
               type: :array,
               items: @structure_schema
             }
           },
           example: %{
             data: [@structure_schema.example]
           }
         }}
    ]
  )

  def index(conn, _params) do
    map_id = conn.assigns.map_id
    structures = MapOperations.list_structures(map_id)
    json(conn, %{data: structures})
  end

  @doc """
  Show a single structure by ID.
  """
  operation(:show,
    summary: "Show a single structure by ID",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ],
      id: [in: :path, description: "Structure UUID", type: :string, required: true]
    ],
    responses: [
      ok:
        {"Structure", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: @structure_schema},
           example: %{data: @structure_schema.example}
         }}
    ]
  )

  def show(conn, %{"id" => id}) do
    map_id = conn.assigns.map_id

    case MapSystemStructure.by_id(id) do
      {:ok, structure} ->
        case WandererApp.Api.MapSystem.by_id(structure.system_id) do
          {:ok, system} when system.map_id == map_id ->
            json(conn, %{data: structure})

          _ ->
            conn |> put_status(:not_found) |> json(%{error: "Structure not found"})
        end

      _ ->
        conn |> put_status(:not_found) |> json(%{error: "Structure not found"})
    end
  end

  @doc """
  Create a new structure.
  """
  operation(:create,
    summary: "Create a new structure",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ]
    ],
    request_body: {"Structure", "application/json", @structure_schema},
    responses: [
      created:
        {"Created structure", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: @structure_schema},
           example: %{data: @structure_schema.example}
         }}
    ]
  )

  def create(conn, params) do
    case MapOperations.create_structure(conn, params) do
      {:ok, struct} ->
        conn |> put_status(:created) |> json(%{data: struct})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Resource not found"})

      {:error, error} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end

  @doc """
  Update a structure by ID.
  """
  operation(:update,
    summary: "Update a structure by ID",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ],
      id: [in: :path, description: "Structure UUID", type: :string, required: true]
    ],
    request_body: {"Structure update", "application/json", @structure_schema},
    responses: [
      ok:
        {"Updated structure", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: @structure_schema},
           example: %{data: @structure_schema.example}
         }}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    case MapOperations.update_structure(conn, id, params) do
      {:ok, struct} ->
        json(conn, %{data: struct})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Structure not found"})

      {:error, error} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end

  @doc """
  Delete a structure by ID.
  """
  operation(:delete,
    summary: "Delete a structure by ID",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true
      ],
      id: [in: :path, description: "Structure UUID", type: :string, required: true]
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
    case MapOperations.delete_structure(conn, id) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Structure not found"})

      {:error, error} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: error})
    end
  end

  @doc """
  Get structure timers for a map.
  """
  operation(:structure_timers,
    summary: "Get structure timers for a map",
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
        {"Structure timers", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :array,
               items: @structure_schema
             }
           },
           example: %{
             data: [@structure_schema.example]
           }
         }}
    ]
  )

  def structure_timers(conn, _params) do
    map_id = conn.assigns.map_id
    structures = MapOperations.list_structures(map_id)
    json(conn, %{data: structures})
  end
end
