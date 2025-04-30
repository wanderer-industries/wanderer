# lib/wanderer_app_web/controllers/map_system_api_controller.ex
defmodule WandererAppWeb.MapSystemAPIController do
  @moduledoc """
  API controller for managing map systems and their associated connections.
  Provides CRUD operations and batch upsert for systems and connections.
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias WandererApp.Map.Operations
  alias WandererAppWeb.Helpers.APIUtils
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}

  action_fallback WandererAppWeb.FallbackController

  # -- JSON Schemas --
  @map_system_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Map system UUID"},
      map_id: %Schema{type: :string, description: "Map UUID"},
      solar_system_id: %Schema{type: :integer, description: "EVE solar system ID"},
      solar_system_name: %Schema{type: :string, description: "EVE solar system name"},
      region_name: %Schema{type: :string, description: "EVE region name"},
      position_x: %Schema{type: :number, format: :float, description: "X coordinate"},
      position_y: %Schema{type: :number, format: :float, description: "Y coordinate"},
      status: %Schema{type: :string, description: "System status"},
      visible: %Schema{type: :boolean, description: "Visibility flag"},
      description: %Schema{type: :string, nullable: true, description: "Custom description"},
      tag: %Schema{type: :string, nullable: true, description: "Custom tag"},
      locked: %Schema{type: :boolean, description: "Lock flag"},
      temporary_name: %Schema{type: :string, nullable: true, description: "Temporary name"},
      labels: %Schema{type: :array, items: %Schema{type: :string}, nullable: true, description: "Labels"}
    },
    required: ~w(id map_id solar_system_id)a
  }

  @system_request_schema %Schema{
    type: :object,
    properties: %{
      solar_system_id: %Schema{type: :integer, description: "EVE solar system ID"},
      solar_system_name: %Schema{type: :string, description: "EVE solar system name"},
      position_x: %Schema{type: :number, format: :float, description: "X coordinate"},
      position_y: %Schema{type: :number, format: :float, description: "Y coordinate"},
      status: %Schema{type: :string, description: "System status"},
      visible: %Schema{type: :boolean, description: "Visibility flag"},
      description: %Schema{type: :string, nullable: true, description: "Custom description"},
      tag: %Schema{type: :string, nullable: true, description: "Custom tag"},
      locked: %Schema{type: :boolean, description: "Lock flag"},
      temporary_name: %Schema{type: :string, nullable: true, description: "Temporary name"},
      labels: %Schema{type: :array, items: %Schema{type: :string}, nullable: true, description: "Labels"}
    },
    required: ~w(solar_system_id)a,
    example: %{
      solar_system_id: 30_000_142,
      solar_system_name: "Jita",
      position_x: 100.5,
      position_y: 200.3,
      visible: true
    }
  }

  @list_response_schema ApiSchemas.data_wrapper(%Schema{type: :array, items: @map_system_schema})
  @detail_response_schema ApiSchemas.data_wrapper(@map_system_schema)
  @delete_response_schema ApiSchemas.data_wrapper(%Schema{
    type: :object,
    properties: %{deleted: %Schema{type: :boolean, description: "Deleted flag"}},
    required: ["deleted"]
  })

  @batch_response_schema ApiSchemas.data_wrapper(%Schema{
    type: :object,
    properties: %{
      systems: %Schema{
        type: :object,
        properties: %{created: %Schema{type: :integer}, updated: %Schema{type: :integer}},
        required: ~w(created updated)a
      },
      connections: %Schema{
        type: :object,
        properties: %{
          created: %Schema{type: :integer},
          updated: %Schema{type: :integer},
          deleted: %Schema{type: :integer}
        },
        required: ~w(created updated deleted)a
      }
    },
    required: ~w(systems connections)a
  })

  @batch_delete_schema %Schema{
    type: :object,
    properties: %{
      system_ids: %Schema{
        type: :array,
        items: %Schema{type: :integer},
        description: "IDs to delete"
      }
    },
    required: ["system_ids"]
  }

  @batch_delete_response_schema ApiSchemas.data_wrapper(%Schema{
    type: :object,
    properties: %{deleted_count: %Schema{type: :integer, description: "Deleted count"}},
    required: ["deleted_count"]
  })

  # -- Actions --

  operation :index,
    summary: "List Map Systems and Connections",
    parameters: [map_slug: [in: :path], map_id: [in: :path]],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  def index(%{assigns: %{map_id: map_id}} = conn, _params) do
    systems = Operations.list_systems(map_id) |> Enum.map(&APIUtils.map_system_to_json/1)
    connections = Operations.list_connections(map_id) |> Enum.map(&APIUtils.connection_to_json/1)
    APIUtils.respond_data(conn, %{systems: systems, connections: connections})
  end

  operation :show,
    summary: "Show Map System",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path]],
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  def show(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    with {:ok, system_id} <- APIUtils.parse_int(id),
         {:ok, system} <- Operations.get_system(map_id, system_id) do
      APIUtils.respond_data(conn, APIUtils.map_system_to_json(system))
    end
  end

  operation :create,
    summary: "Upsert Systems and Connections (batch or single)",
    request_body: {"Systems+Connections upsert", "application/json", @batch_response_schema},
    responses: ResponseSchemas.standard_responses(@batch_response_schema)
  def create(%{assigns: %{map_id: map_id}} = conn, params) do
    systems = Map.get(params, "systems", [])
    connections = Map.get(params, "connections", [])
    with {:ok, result} <- Operations.upsert_systems_and_connections(map_id, systems, connections) do
      APIUtils.respond_data(conn, result)
    else
      error ->
        error
    end
  end

  operation :update,
    summary: "Update System",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path]],
    request_body: {"System update request", "application/json", @system_update_schema},
    responses: ResponseSchemas.update_responses(@detail_response_schema)
  def update(%{assigns: %{map_id: map_id}} = conn, %{"id" => id} = params) do
    with {:ok, sid} <- APIUtils.parse_int(id),
         {:ok, attrs} <- APIUtils.extract_update_params(params),
         update_attrs = Map.put(attrs, "solar_system_id", sid),
         {:ok, system} <- Operations.update_system(map_id, sid, update_attrs) do
      APIUtils.respond_data(conn, APIUtils.map_system_to_json(system))
    end
  end

  operation :delete,
    summary: "Batch Delete Systems and Connections",
    request_body: {"Batch delete", "application/json", @batch_delete_schema},
    responses: ResponseSchemas.standard_responses(@batch_delete_response_schema)
  def delete(%{assigns: %{map_id: map_id}} = conn, params) do
    system_ids = Map.get(params, "system_ids", [])
    connection_ids = Map.get(params, "connection_ids", [])
    deleted_systems = Enum.map(system_ids, fn id ->
      case APIUtils.parse_int(id) do
        {:ok, sid} -> Operations.delete_system(map_id, sid)
        _ -> {:error, :invalid_id}
      end
    end)
    deleted_connections = Enum.map(connection_ids, fn id ->
      case Operations.get_connection(map_id, id) do
        {:ok, conn_struct} -> WandererApp.Map.Server.delete_connection(map_id, conn_struct)
        _ -> :error
      end
    end)
    deleted_count = Enum.count(deleted_systems, &match?({:ok, _}, &1)) + Enum.count(deleted_connections, &(&1 == :ok))
    APIUtils.respond_data(conn, %{deleted_count: deleted_count})
  end

  operation :delete_single,
    summary: "Delete a single Map System",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path]],
    responses: ResponseSchemas.standard_responses(@delete_response_schema)
  def delete(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    with {:ok, sid} <- APIUtils.parse_int(id),
         {:ok, _} <- Operations.delete_system(map_id, sid) do
      APIUtils.respond_data(conn, %{deleted: true})
    else
      _ -> APIUtils.respond_data(conn, %{deleted: false})
    end
  end

  # -- Legacy endpoints --

  operation :list_systems,
    summary: "List Map Systems (Legacy)",
    deprecated: true,
    description: "Deprecated, use GET /api/maps/:map_identifier/systems instead",
    parameters: [map_id: [in: :query]],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  defdelegate list_systems(conn, params), to: __MODULE__, as: :index

  operation :show_system,
    summary: "Show Map System (Legacy)",
    deprecated: true,
    description: "Deprecated, use GET /api/maps/:map_identifier/systems/:id instead",
    parameters: [map_id: [in: :query], id: [in: :query]],
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  defdelegate show_system(conn, params), to: __MODULE__, as: :show

  @deprecated "Use GET /api/maps/:map_identifier/systems instead"
  operation :list_all_connections,
    summary: "List All Connections (Legacy)",
    deprecated: true,
    parameters: [map_id: [in: :query]],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  def list_all_connections(%{assigns: %{map_id: map_id}} = conn, _params) do
    connections = Operations.list_connections(map_id)
    data = Enum.map(connections, &APIUtils.connection_to_json/1)
    APIUtils.respond_data(conn, data)
  end
end
