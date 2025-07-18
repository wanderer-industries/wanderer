# lib/wanderer_app_web/controllers/map_connection_api_controller.ex
defmodule WandererAppWeb.MapConnectionAPIController do
  @moduledoc """
  API controller for managing map connections.
  Provides operations to list, show, create, delete, and batch-delete connections, with legacy routing support.
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias OpenApiSpex.Schema
  alias WandererApp.Map, as: MapData
  alias WandererApp.Map.Operations
  alias WandererAppWeb.Helpers.APIUtils
  alias WandererAppWeb.Schemas.ResponseSchemas

  action_fallback WandererAppWeb.FallbackController

  # -- JSON Schemas --
  @connection_request_schema %Schema{
    type: :object,
    properties: %{
      solar_system_source: %Schema{type: :integer, description: "Source system ID"},
      solar_system_target: %Schema{type: :integer, description: "Target system ID"},
      type: %Schema{type: :integer, description: "Connection type (default 0)"},
      mass_status: %Schema{type: :integer, description: "Mass status (0-3)", nullable: true},
      time_status: %Schema{type: :integer, description: "Time status (0-3)", nullable: true},
      ship_size_type: %Schema{
        type: :integer,
        description: "Ship size limit (0-3)",
        nullable: true
      },
      locked: %Schema{type: :boolean, description: "Locked flag", nullable: true},
      custom_info: %Schema{type: :string, nullable: true, description: "Optional metadata"},
      wormhole_type: %Schema{type: :string, nullable: true, description: "Wormhole code"}
    },
    required: ~w(solar_system_source solar_system_target)a,
    example: %{
      solar_system_source: 30_000_142,
      solar_system_target: 30_000_144,
      type: 0,
      mass_status: 1,
      time_status: 2,
      ship_size_type: 1,
      locked: false,
      custom_info: "Frigate only",
      wormhole_type: "C2"
    }
  }

  @list_response_schema %Schema{
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string},
            map_id: %Schema{type: :string},
            solar_system_source: %Schema{type: :integer},
            solar_system_target: %Schema{type: :integer},
            type: %Schema{type: :integer},
            mass_status: %Schema{type: :integer},
            time_status: %Schema{type: :integer},
            ship_size_type: %Schema{type: :integer},
            locked: %Schema{type: :boolean},
            custom_info: %Schema{type: :string, nullable: true},
            wormhole_type: %Schema{type: :string, nullable: true}
          }
        }
      }
    },
    example: %{
      data: [
        %{
          id: "conn-uuid-1",
          map_id: "map-uuid-1",
          solar_system_source: 30_000_142,
          solar_system_target: 30_000_144,
          type: 0,
          mass_status: 1,
          time_status: 2,
          ship_size_type: 1,
          locked: false,
          custom_info: "Frigate only",
          wormhole_type: "C2"
        }
      ]
    }
  }

  @detail_response_schema %Schema{
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string},
          map_id: %Schema{type: :string},
          solar_system_source: %Schema{type: :integer},
          solar_system_target: %Schema{type: :integer},
          type: %Schema{type: :integer},
          mass_status: %Schema{type: :integer},
          time_status: %Schema{type: :integer},
          ship_size_type: %Schema{type: :integer},
          locked: %Schema{type: :boolean},
          custom_info: %Schema{type: :string, nullable: true},
          wormhole_type: %Schema{type: :string, nullable: true}
        }
      }
    },
    example: %{
      data: %{
        id: "conn-uuid-1",
        map_id: "map-uuid-1",
        solar_system_source: 30_000_142,
        solar_system_target: 30_000_144,
        type: 0,
        mass_status: 1,
        time_status: 2,
        ship_size_type: 1,
        locked: false,
        custom_info: "Frigate only",
        wormhole_type: "C2"
      }
    }
  }

  # -- Actions --

  operation(:index,
    summary: "List Map Connections",
    description: "Lists all connections for a map.",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ],
      solar_system_source: [
        in: :query,
        description: "Filter connections by source system ID",
        type: :integer,
        required: false,
        example: 30_000_142
      ],
      solar_system_target: [
        in: :query,
        description: "Filter connections by target system ID",
        type: :integer,
        required: false,
        example: 30_000_144
      ]
    ],
    responses: [
      ok: {
        "List of Map Connections",
        "application/json",
        @list_response_schema
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
             "error" => "Map not found"
           }
         }}
    ]
  )

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
  defp filter_by_source(conns, s), do: Enum.filter(conns, &(&1.solar_system_source == s))

  defp filter_by_target(conns, nil), do: conns
  defp filter_by_target(conns, t), do: Enum.filter(conns, &(&1.solar_system_target == t))

  operation(:show,
    summary: "Show Connection (by id or by source/target)",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ],
      id: [in: :path, type: :string, required: false],
      solar_system_source: [in: :query, type: :integer, required: false],
      solar_system_target: [in: :query, type: :integer, required: false]
    ],
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  )

  def show(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    case Operations.get_connection(map_id, id) do
      {:ok, conn_struct} -> APIUtils.respond_data(conn, APIUtils.connection_to_json(conn_struct))
      err -> err
    end
  end

  def show(%{assigns: %{map_id: map_id}} = conn, %{
        "solar_system_source" => src,
        "solar_system_target" => tgt
      }) do
    with {:ok, source} <- APIUtils.parse_int(src),
         {:ok, target} <- APIUtils.parse_int(tgt),
         {:ok, conn_struct} when not is_nil(conn_struct) <-
           Operations.get_connection_by_systems(map_id, source, target) do
      APIUtils.respond_data(conn, APIUtils.connection_to_json(conn_struct))
    else
      {:ok, nil} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Connection not found"})

      err ->
        err
    end
  end

  operation(:create,
    summary: "Create Connection",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ]
    ],
    request_body: {"Connection create", "application/json", @connection_request_schema},
    responses: ResponseSchemas.create_responses(@detail_response_schema)
  )

  def create(conn, params) do
    # Filter out map_id to prevent external modification
    filtered_params = Map.drop(params, ["map_id", :map_id])

    case Operations.create_connection(conn, filtered_params) do
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

      {:error, :precondition_failed, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid request parameters"})

      _other ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Unexpected error"})
    end
  end

  operation(:delete,
    summary: "Delete Connection (by id or by source/target)",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ],
      id: [in: :path, type: :string, required: false],
      solar_system_source: [in: :query, type: :integer, required: false],
      solar_system_target: [in: :query, type: :integer, required: false]
    ],
    responses: ResponseSchemas.delete_responses(nil)
  )

  def delete(%{assigns: %{map_id: _map_id}} = conn, %{"id" => id}) do
    case delete_connection_id(conn, id) do
      {:ok, _conn_struct} -> send_resp(conn, :no_content, "")
      error -> error
    end
  end

  def delete(%{assigns: %{map_id: _map_id}} = conn, %{
        "solar_system_source" => src,
        "solar_system_target" => tgt
      }) do
    delete_by_systems(conn, src, tgt)
  end

  # Private helpers for delete/2

  defp delete_connection_id(conn, id) do
    case Operations.get_connection(conn.assigns.map_id, id) do
      {:ok, conn_struct} ->
        source_id = conn_struct.solar_system_source
        target_id = conn_struct.solar_system_target

        case Operations.delete_connection(conn, source_id, target_id) do
          :ok -> {:ok, conn_struct}
          error -> error
        end

      {:error, "Connection not found"} ->
        {:error, :not_found}

      _ ->
        {:error, :invalid_id}
    end
  end

  defp delete_by_systems(conn, src, tgt) do
    with {:ok, source} <- APIUtils.parse_int(src),
         {:ok, target} <- APIUtils.parse_int(tgt) do
      do_delete_by_systems(conn, source, target, src, tgt)
    else
      {:error, :not_found} ->
        Logger.error(
          "[delete_connection] Connection not found for source=#{inspect(src)}, target=#{inspect(tgt)}"
        )

        {:error, :not_found}

      {:error, reason} ->
        Logger.error("[delete_connection] Error: #{inspect(reason)}")
        {:error, reason}

      error ->
        Logger.error("[delete_connection] Unexpected error: #{inspect(error)}")
        {:error, :internal_server_error}
    end
  end

  defp do_delete_by_systems(conn, source, target, src, tgt) do
    map_id = conn.assigns.map_id

    case Operations.get_connection_by_systems(map_id, source, target) do
      {:ok, nil} ->
        Logger.error(
          "[delete_connection] No connection found for source=#{inspect(source)}, target=#{inspect(target)}"
        )

        try_reverse_delete(conn, source, target, src, tgt)

      {:ok, conn_struct} ->
        case Operations.delete_connection(
               conn,
               conn_struct.solar_system_source,
               conn_struct.solar_system_target
             ) do
          :ok -> send_resp(conn, :no_content, "")
          error -> {:error, error}
        end

      {:error, _} ->
        try_reverse_delete(conn, source, target, src, tgt)
    end
  end

  defp try_reverse_delete(conn, source, target, src, tgt) do
    map_id = conn.assigns.map_id

    case Operations.get_connection_by_systems(map_id, target, source) do
      {:ok, nil} ->
        Logger.error(
          "[delete_connection] No connection found for source=#{inspect(target)}, target=#{inspect(source)}"
        )

        {:error, :not_found}

      {:ok, conn_struct} ->
        case Operations.delete_connection(
               conn,
               conn_struct.solar_system_source,
               conn_struct.solar_system_target
             ) do
          :ok -> send_resp(conn, :no_content, "")
          error -> {:error, error}
        end

      {:error, reason} ->
        Logger.error(
          "[delete_connection] Connection not found for source=#{inspect(src)}, target=#{inspect(tgt)} (both orders)"
        )

        {:error, reason}
    end
  end

  operation(:update,
    summary: "Update Connection (by id or by source/target)",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ],
      id: [in: :path, type: :string, required: false],
      solar_system_source: [in: :query, type: :integer, required: false],
      solar_system_target: [in: :query, type: :integer, required: false]
    ],
    request_body: {"Connection update", "application/json", @connection_request_schema},
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  )

  def update(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    allowed_fields = [
      "mass_status",
      "ship_size_type",
      "time_status",
      "locked",
      "custom_info",
      "type"
    ]

    attrs =
      conn.body_params
      |> Map.take(allowed_fields)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    update_by_id(conn, map_id, id, attrs)
  end

  def update(%{assigns: %{map_id: map_id}} = conn, %{
        "solar_system_source" => src,
        "solar_system_target" => tgt
      }) do
    allowed_fields = [
      "mass_status",
      "ship_size_type",
      "time_status",
      "locked",
      "custom_info",
      "type"
    ]

    attrs =
      conn.body_params
      |> Map.take(allowed_fields)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    update_by_systems(conn, map_id, src, tgt, attrs)
  end

  # Private helpers for update/2

  defp update_by_id(conn, _map_id, id, attrs) do
    case Operations.update_connection(conn, id, attrs) do
      {:ok, updated_conn} ->
        APIUtils.respond_data(conn, APIUtils.connection_to_json(updated_conn))

      err ->
        err
    end
  end

  defp update_by_systems(conn, _map_id, src, tgt, attrs) do
    require Logger

    with {:ok, source} <- APIUtils.parse_int(src),
         {:ok, target} <- APIUtils.parse_int(tgt) do
      do_update_by_systems(conn, source, target, src, tgt, attrs)
    else
      {:error, :not_found} ->
        Logger.error(
          "[update_connection] Connection not found for source=#{inspect(src)}, target=#{inspect(tgt)}"
        )

        {:error, :not_found}

      {:error, reason} ->
        Logger.error("[update_connection] Error: #{inspect(reason)}")
        {:error, reason}

      error ->
        Logger.error("[update_connection] Unexpected error: #{inspect(error)}")
        {:error, :internal_server_error}
    end
  end

  defp do_update_by_systems(conn, source, target, src, tgt, attrs) do
    map_id = conn.assigns.map_id

    case Operations.get_connection_by_systems(map_id, source, target) do
      {:ok, nil} ->
        Logger.error(
          "[update_connection] No connection found for source=#{inspect(source)}, target=#{inspect(target)}"
        )

        try_reverse_update(conn, source, target, src, tgt, attrs)

      {:ok, conn_struct} ->
        do_update_connection(conn, conn_struct.id, attrs)

      {:error, _} ->
        try_reverse_update(conn, source, target, src, tgt, attrs)
    end
  end

  defp try_reverse_update(conn, source, target, src, tgt, attrs) do
    map_id = conn.assigns.map_id

    case Operations.get_connection_by_systems(map_id, target, source) do
      {:ok, nil} ->
        Logger.error(
          "[update_connection] No connection found for source=#{inspect(target)}, target=#{inspect(source)}"
        )

        {:error, :not_found}

      {:ok, conn_struct} ->
        do_update_connection(conn, conn_struct.id, attrs)

      {:error, reason} ->
        Logger.error(
          "[update_connection] Connection not found for source=#{inspect(src)}, target=#{inspect(tgt)} (both orders)"
        )

        {:error, reason}
    end
  end

  defp do_update_connection(conn, id, attrs) do
    case Operations.update_connection(conn, id, attrs) do
      {:ok, updated_conn} ->
        APIUtils.respond_data(conn, APIUtils.connection_to_json(updated_conn))

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
        Logger.error("[update_connection] Ash update NotFound for id=#{id}")
        {:error, :not_found}

      err ->
        err
    end
  end

  @deprecated "Use GET /api/maps/:map_identifier/systems instead"
  operation(:list_all_connections,
    summary: "List All Connections (Legacy)",
    description:
      "Legacy endpoint for listing connections. Use GET /api/maps/:map_identifier/connections instead. Requires exactly one of map_id or slug as a query parameter. If both are provided, a 400 Bad Request will be returned.",
    deprecated: true,
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Exactly one of map_id or slug must be provided",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Exactly one of map_id or slug must be provided",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: {
        "List of Map Connections",
        "application/json",
        @list_response_schema
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
             "error" => "Must provide exactly one of map_id or slug as a query parameter"
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
             "error" =>
               "Map not found. Please provide a valid map_id or slug as a query parameter."
           }
         }}
    ]
  )

  def list_all_connections(%{assigns: %{map_id: map_id}} = conn, _params) do
    connections = Operations.list_connections(map_id)
    data = Enum.map(connections, &APIUtils.connection_to_json/1)
    APIUtils.respond_data(conn, data)
  end
end
