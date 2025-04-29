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
  alias WandererAppWeb.APIUtils
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}
  require Logger

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
    summary: "List Map Systems",
    parameters: [map_slug: [in: :path], map_id: [in: :path]],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  def index(%{assigns: %{map_id: map_id}} = conn, _params) do
    map_id
    |> Operations.list_systems()
    |> Enum.map(&APIUtils.map_system_to_json/1)
    |> then(&APIUtils.respond_data(conn, &1))
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
    summary: "Create System",
    request_body: {"System create request", "application/json", @system_request_schema},
    responses: ResponseSchemas.create_responses(@detail_response_schema)
  def create(%{assigns: %{map_id: map_id}} = conn, params) do
    with {:ok, attrs} <- APIUtils.extract_upsert_params(params),
         {:ok, system} <- Operations.create_system(map_id, attrs) do
      conn
      |> put_status(:created)
      |> APIUtils.respond_data(APIUtils.map_system_to_json(system))
    end
  end

  operation :update,
    summary: "Update System",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path]],
    request_body: {"System update request", "application/json", @system_request_schema},
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
    summary: "Delete System",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path]],
    responses: ResponseSchemas.delete_responses(@delete_response_schema)
  def delete(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    Logger.info("[DELETE SYSTEM] Received id: #{inspect(id)}")
    with {:ok, sid} <- APIUtils.parse_int(id),
         {:ok, _} <- Operations.delete_system(map_id, sid) do
      Logger.info("[DELETE SYSTEM] Successfully deleted system #{sid}")
      send_resp(conn, :no_content, "")
    else
      {:error, reason} ->
        Logger.error("[DELETE SYSTEM] Error: #{inspect(reason)}")
        {:error, reason}
      _ ->
        Logger.error("[DELETE SYSTEM] Not found")
        {:error, :not_found}
    end
  end

  operation :systems_and_connections,
    summary: "Batch Upsert Systems+Connections",
    parameters: [map_slug: [in: :path], map_id: [in: :path]],
    request_body: {"Batch upsert", "application/json", @batch_response_schema},
    responses: ResponseSchemas.standard_responses(@batch_response_schema)
  def systems_and_connections(%{assigns: %{map_id: map_id}} = conn, %{"systems" => ss, "connections" => cc}) do
    with {:ok, result} <- Operations.upsert_systems_and_connections(map_id, ss, cc) do
      APIUtils.respond_data(conn, result)
    end
  end

  operation :batch_delete,
    summary: "Batch Delete Systems",
    parameters: [map_slug: [in: :path], map_id: [in: :path]],
    request_body: {"Batch delete", "application/json", @batch_delete_schema},
    responses: ResponseSchemas.standard_responses(@batch_delete_response_schema)
  def batch_delete(%{assigns: %{map_id: map_id}} = conn, %{"system_ids" => ids}) when is_list(ids) do
    Logger.info("[BATCH DELETE SYSTEMS] Received system_ids: #{inspect(ids)}")
    parsed_ids = Enum.map(ids, fn id ->
      case APIUtils.parse_int(id) do
        {:ok, int_id} -> int_id
        _ -> id
      end
    end)
    Logger.info("[BATCH DELETE SYSTEMS] Parsed system_ids: #{inspect(parsed_ids)}")
    results = Enum.map(parsed_ids, fn sid ->
      res = Operations.delete_system(map_id, sid)
      Logger.info("[BATCH DELETE SYSTEMS] Delete result for #{sid}: #{inspect(res)}")
      res
    end)
    deleted_count = Enum.count(results, &match?({:ok, _}, &1))
    APIUtils.respond_data(conn, %{deleted_count: deleted_count})
  end
  def batch_delete(_conn, _), do: {:error, :bad_request}

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
end
