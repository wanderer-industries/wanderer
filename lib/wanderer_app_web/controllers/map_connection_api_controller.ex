# lib/wanderer_app_web/controllers/map_connection_api_controller.ex
defmodule WandererAppWeb.MapConnectionAPIController do
  @moduledoc """
  API controller for managing map connections.
  Provides operations to list, show, create, delete, and batch-delete connections, with legacy routing support.
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias WandererApp.Map, as: MapData
  alias WandererApp.Map.Operations
  alias WandererAppWeb.APIUtils
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}
  require Logger

  action_fallback WandererAppWeb.FallbackController

  # -- JSON Schemas --
  @map_connection_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Unique connection ID"},
      map_id: %Schema{type: :string, description: "Map UUID"},
      solar_system_source: %Schema{type: :integer, description: "Source system ID"},
      solar_system_target: %Schema{type: :integer, description: "Target system ID"},
      type: %Schema{type: :integer, description: "Connection type"},
      mass_status: %Schema{type: :integer, description: "Mass status (0-3)"},
      time_status: %Schema{type: :integer, description: "Time status (0-3)"},
      ship_size_type: %Schema{type: :integer, description: "Ship size limit (0-3)"},
      locked: %Schema{type: :boolean, description: "Locked flag"},
      custom_info: %Schema{type: :string, nullable: true, description: "Optional metadata"},
      wormhole_type: %Schema{type: :string, nullable: true, description: "Wormhole code"}
    },
    required: ~w(id map_id solar_system_source solar_system_target)a
  }

  @connection_request_schema %Schema{
    type: :object,
    properties: %{
      solar_system_source: %Schema{type: :integer, description: "Source system ID"},
      solar_system_target: %Schema{type: :integer, description: "Target system ID"},
      type: %Schema{type: :integer, description: "Connection type (default 0)"}
    },
    required: ~w(solar_system_source solar_system_target)a,
    example: %{solar_system_source: 30_000_142, solar_system_target: 30_000_144, type: 0}
  }

  @batch_delete_schema %Schema{
    type: :object,
    properties: %{
      connection_ids: %Schema{
        type: :array,
        items: %Schema{type: :string, description: "Connection UUID"},
        description: "IDs to delete"
      }
    },
    required: ["connection_ids"]
  }

  @list_response_schema ApiSchemas.data_wrapper(%Schema{type: :array, items: @map_connection_schema})
  @detail_response_schema ApiSchemas.data_wrapper(@map_connection_schema)
  @batch_delete_response_schema ApiSchemas.data_wrapper(
    %Schema{
      type: :object,
      properties: %{deleted_count: %Schema{type: :integer, description: "Deleted count"}},
      required: ["deleted_count"]
    }
  )

  # -- Actions --

  operation :index,
    summary: "List Map Connections",
    parameters: [
      map_slug: [in: :path, type: :string],
      map_id: [in: :path, type: :string],
      system_id: [in: :path, type: :string, required: false]
    ],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  def index(%{assigns: %{map_id: map_id}} = conn, %{"system_id" => sid}) do
    with {:ok, system_id} <- APIUtils.parse_int(sid),
         all_conns <- MapData.list_connections!(map_id),
         filtered <- Enum.filter(all_conns, &involves_system?(&1, system_id)),
         data <- Enum.map(filtered, &APIUtils.connection_to_json/1) do
      APIUtils.respond_data(conn, data)
    end
  end

  def index(%{assigns: %{map_id: map_id}} = conn, _params) do
    data =
      MapData.list_connections!(map_id)
      |> Enum.map(&APIUtils.connection_to_json/1)

    APIUtils.respond_data(conn, data)
  end

  operation :show,
    summary: "Show Connection",
    parameters: [map_slug: [in: :path], map_id: [in: :path], system_id: [in: :path], id: [in: :path]],
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  def show(%{assigns: %{map_id: map_id}} = conn, %{"system_id" => sid, "id" => id}) do
    with {:ok, system_id} <- APIUtils.parse_int(sid),
         {:ok, conn_struct} <- Operations.get_connection(map_id, id),
         true <- involves_system?(conn_struct, system_id) do
      APIUtils.respond_data(conn, APIUtils.connection_to_json(conn_struct))
    else
      {:error, _} = err -> err
      _ -> {:error, :not_found}
    end
  end

  operation :create,
    summary: "Create Connection",
    parameters: [map_slug: [in: :path], map_id: [in: :path], system_id: [in: :path]],
    request_body: {"Connection create", "application/json", @connection_request_schema},
    responses: ResponseSchemas.create_responses(@detail_response_schema)
  def create(%{assigns: %{map_id: map_id}} = conn, _params) do
    # Create connection (character ID is determined in Operations)
    case Operations.create_connection(conn.body_params, map_id) do
      :ok ->
        # Connection created successfully, return a success response
        source = conn.body_params["solar_system_source"]
        target = conn.body_params["solar_system_target"]
        type = conn.body_params["type"] || 0

        # Return a simple success response with source/target info
        APIUtils.respond_data(conn, %{
          status: "success",
          map_id: map_id,
          solar_system_source: source,
          solar_system_target: target,
          type: type
        })

      {:skip, :exists} ->
        APIUtils.respond_data(conn, %{status: "connection_exists"})

      {:error, reason} ->
        Logger.error("Connection creation failed: #{inspect(reason)}")
        {:error, reason}

      error ->
        Logger.error("Unexpected error creating connection: #{inspect(error)}")
        {:error, :internal_server_error}
    end
  end

  def create(_, _), do: {:error, :bad_request}

  operation :delete,
    summary: "Delete Connection",
    parameters: [map_slug: [in: :path], map_id: [in: :path], system_id: [in: :path], id: [in: :path]],
    responses: ResponseSchemas.delete_responses(nil)
  def delete(%{assigns: %{map_id: map_id}} = conn, %{"map_system_api_id" => sid, "id" => id} = params) do
    with {:ok, system_id} <- APIUtils.parse_int(sid),
         {:ok, conn_struct} <- Operations.get_connection(map_id, id) do
      if involves_system?(conn_struct, system_id) do
        case MapData.remove_connection(map_id, conn_struct) do
          :ok ->
            send_resp(conn, :no_content, "")
          error ->
            {:error, error}
        end
      else
        {:error, :not_found}
      end
    else
      {:error, reason} ->
        {:error, reason}
      _ ->
        {:error, :not_found}
    end
  end

  operation :batch_delete,
    summary: "Batch Delete Connections",
    parameters: [map_slug: [in: :path], map_id: [in: :path]],
    request_body: {"Batch delete", "application/json", @batch_delete_schema},
    responses: ResponseSchemas.standard_responses(@batch_delete_response_schema),
    deprecated: true,
    description: "Deprecated. Use individual DELETE requests instead."
  def batch_delete(%{assigns: %{map_id: map_id}} = conn, %{"connection_ids" => ids})
      when is_list(ids) do
    deleted_count =
      ids
      |> Enum.map(&fetch_and_delete(map_id, &1))
      |> Enum.count(&(&1 == :ok))

    APIUtils.respond_data(conn, %{deleted_count: deleted_count})
  end

  def batch_delete(_, _), do: {:error, :bad_request}

  # -- Legacy route --
  @deprecated "Use GET /api/maps/:map_identifier/systems/:system_id/connections instead"
  operation :list_all_connections,
    summary: "List All Connections (Legacy)",
    deprecated: true,
    parameters: [map_id: [in: :query]],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  defdelegate list_all_connections(conn, params), to: __MODULE__, as: :index

  operation :update,
    summary: "Update Connection (partial)",
    parameters: [map_slug: [in: :path], map_id: [in: :path], system_id: [in: :path], id: [in: :path]],
    request_body: {"Connection update", "application/json", @connection_request_schema},
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  def update(%{assigns: %{map_id: map_id}} = conn, %{"system_id" => sid, "id" => id} = params) do
    require Logger
    with {:ok, system_id} <- APIUtils.parse_int(sid),
         {:ok, conn_struct} <- Operations.get_connection(map_id, id),
         true <- involves_system?(conn_struct, system_id) do
      # Only allow certain fields to be updated
      allowed_fields = ["mass_status", "ship_size_type", "locked", "custom_info", "type"]
      attrs =
        conn.body_params
        |> Map.take(allowed_fields)
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.into(%{})

      case Operations.update_connection(map_id, id, attrs) do
        {:ok, updated_conn} ->
          APIUtils.respond_data(conn, APIUtils.connection_to_json(updated_conn))
        {:error, reason} ->
          Logger.error("[PATCH] Connection update failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, _} = err ->
        Logger.error("[PATCH] Error in update preconditions: #{inspect(err)}")
        err
      _ ->
        Logger.error("[PATCH] Connection not found or not associated with system_id: #{sid}")
        {:error, :not_found}
    end
  end

  # -- Helpers --

  defp involves_system?(%{"solar_system_source" => s, "solar_system_target" => t}, id),
    do: s == id or t == id

  defp involves_system?(%{solar_system_source: s, solar_system_target: t}, id),
    do: s == id or t == id

  defp fetch_and_delete(map_id, id) do
    case Operations.get_connection(map_id, id) do
      {:ok, conn_struct} -> MapData.remove_connection(map_id, conn_struct)
      _ -> :error
    end
  end

  defp fetch_connection!(map_id, id) do
    MapData.list_connections!(map_id)
    |> Enum.find(&(&1.id == id))
    |> case do
      nil -> raise "Connection #{id} not found"
      conn -> conn
    end
  end
end
