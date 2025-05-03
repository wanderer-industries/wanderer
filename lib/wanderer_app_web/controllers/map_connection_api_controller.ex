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
  alias WandererAppWeb.Helpers.APIUtils
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}

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
      solar_system_source: [in: :query, type: :integer, required: false],
      solar_system_target: [in: :query, type: :integer, required: false]
    ],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  def index(%{assigns: %{map_id: map_id}} = conn, params) do
    with {:ok, src_filter} <- parse_optional(params, "solar_system_source"),
         {:ok, tgt_filter} <- parse_optional(params, "solar_system_target") do
      conns = MapData.list_connections!(map_id)
      conns =
        conns
        |> filter_by_source(src_filter)
        |> filter_by_target(tgt_filter)
      data = Enum.map(conns, &APIUtils.connection_to_json/1)
      APIUtils.respond_data(conn, data)
    else
      {:error, msg} when is_binary(msg) ->
        conn
        |> Plug.Conn.put_status(:bad_request)
        |> APIUtils.error_response(:bad_request, msg)
      {:error, _} ->
        conn
        |> Plug.Conn.put_status(:bad_request)
        |> APIUtils.error_response(:bad_request, "Invalid filter parameter")
    end
  end

  defp parse_optional(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, nil}
      val -> APIUtils.parse_int(val)
    end
  end

  defp filter_by_source(conns, nil), do: conns
  defp filter_by_source(conns, s),   do: Enum.filter(conns, &(&1.solar_system_source == s))

  defp filter_by_target(conns, nil), do: conns
  defp filter_by_target(conns, t),   do: Enum.filter(conns, &(&1.solar_system_target == t))

  operation :show,
    summary: "Show Connection (by id or by source/target)",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path, required: false], solar_system_source: [in: :query, type: :integer, required: false], solar_system_target: [in: :query, type: :integer, required: false]],
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  def show(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    case Operations.get_connection(map_id, id) do
      {:ok, conn_struct} -> APIUtils.respond_data(conn, APIUtils.connection_to_json(conn_struct))
      err -> err
    end
  end
  def show(%{assigns: %{map_id: map_id}} = conn, %{"solar_system_source" => src, "solar_system_target" => tgt}) do
    with {:ok, source} <- APIUtils.parse_int(src),
         {:ok, target} <- APIUtils.parse_int(tgt),
         {:ok, conn_struct} <- Operations.get_connection_by_systems(map_id, source, target) do
      APIUtils.respond_data(conn, APIUtils.connection_to_json(conn_struct))
    else
      err -> err
    end
  end

  operation :create,
    summary: "Create Connection",
    parameters: [map_slug: [in: :path], map_id: [in: :path], system_id: [in: :path]],
    request_body: {"Connection create", "application/json", @connection_request_schema},
    responses: ResponseSchemas.create_responses(@detail_response_schema)
  def create(conn, params) do
    map_id = conn.assigns[:map_id]
    case Operations.create_connection(params, map_id) do
      {:ok, conn_struct} when is_map(conn_struct) ->
        conn
        |> APIUtils.respond_data(APIUtils.connection_to_json(conn_struct), :created)
      {:ok, :created} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{result: "created"}})
      {:skip, :exists} ->
        conn
        |> put_status(:ok)
        |> json(%{data: %{result: "exists"}})
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
      other ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Unexpected error"})
    end
  end

  def create(_, _), do: {:error, :bad_request}

  operation :delete,
    summary: "Delete Connection (by id or by source/target)",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path, required: false], solar_system_source: [in: :query, type: :integer, required: false], solar_system_target: [in: :query, type: :integer, required: false]],
    responses: ResponseSchemas.delete_responses(nil)
  def delete(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    case Operations.get_connection(map_id, id) do
      {:ok, conn_struct} ->
        case MapData.remove_connection(map_id, conn_struct) do
          :ok -> send_resp(conn, :no_content, "")
          error -> {:error, error}
        end
      err -> err
    end
  end
  def delete(%{assigns: %{map_id: map_id}} = conn, %{"solar_system_source" => src, "solar_system_target" => tgt}) do
    with {:ok, source} <- APIUtils.parse_int(src),
         {:ok, target} <- APIUtils.parse_int(tgt),
         {:ok, conn_struct} <- Operations.get_connection_by_systems(map_id, source, target) do
      case MapData.remove_connection(map_id, conn_struct) do
        :ok -> send_resp(conn, :no_content, "")
        error -> {:error, error}
      end
    else
      err -> err
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
    summary: "Update Connection (by id or by source/target)",
    parameters: [map_slug: [in: :path], map_id: [in: :path], id: [in: :path, required: false], solar_system_source: [in: :query, type: :integer, required: false], solar_system_target: [in: :query, type: :integer, required: false]],
    request_body: {"Connection update", "application/json", @connection_request_schema},
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  def update(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    allowed_fields = ["mass_status", "ship_size_type", "locked", "custom_info", "type"]
    attrs =
      conn.body_params
      |> Map.take(allowed_fields)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})
    case Operations.update_connection(map_id, id, attrs) do
      {:ok, updated_conn} -> APIUtils.respond_data(conn, APIUtils.connection_to_json(updated_conn))
      err -> err
    end
  end
  def update(%{assigns: %{map_id: map_id}} = conn, %{"solar_system_source" => src, "solar_system_target" => tgt}) do
    allowed_fields = ["mass_status", "ship_size_type", "locked", "custom_info", "type"]
    attrs =
      conn.body_params
      |> Map.take(allowed_fields)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})
    with {:ok, source} <- APIUtils.parse_int(src),
         {:ok, target} <- APIUtils.parse_int(tgt),
         {:ok, conn_struct} <- Operations.get_connection_by_systems(map_id, source, target),
         {:ok, updated_conn} <- Operations.update_connection(map_id, conn_struct.id, attrs) do
      APIUtils.respond_data(conn, APIUtils.connection_to_json(updated_conn))
    else
      {:error, :not_found} ->
        {:error, :not_found}
      {:error, reason} ->
        {:error, reason}
      error ->
        {:error, :internal_server_error}
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
