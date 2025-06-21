# lib/wanderer_app_web/controllers/map_system_api_controller.ex
defmodule WandererAppWeb.Legacy.MapSystemAPIController do
  @deprecated "Use /api/v1/systems JSON:API endpoints instead. This controller will be removed after 2025-12-31."

  @moduledoc """
  API controller for managing map systems and their associated connections.
  Provides CRUD operations and batch upsert for systems and connections.

  @deprecated Use /api/v1/systems JSON:API endpoints instead. This controller will be removed after 2025-12-31.
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias WandererApp.Contexts.{MapSystems, MapConnections}
  alias WandererAppWeb.Helpers.{APIUtils, MapSerializer}
  alias WandererAppWeb.Schemas.{ApiSchemas, MapSchemas, ResponseSchemas}

  action_fallback WandererAppWeb.FallbackController

  # -- JSON Schemas --

  @system_request_schema %Schema{
    type: :object,
    properties: %{
      solar_system_id: %Schema{type: :integer, description: "EVE solar system ID"},
      solar_system_name: %Schema{type: :string, description: "EVE solar system name"},
      position_x: %Schema{type: :integer, description: "X coordinate"},
      position_y: %Schema{type: :integer, description: "Y coordinate"},
      status: %Schema{
        type: :integer,
        description:
          "System status (0: unknown, 1: friendly, 2: warning, 3: targetPrimary, 4: targetSecondary, 5: dangerousPrimary, 6: dangerousSecondary, 7: lookingFor, 8: home)"
      },
      visible: %Schema{type: :boolean, description: "Visibility flag"},
      description: %Schema{type: :string, nullable: true, description: "Custom description"},
      tag: %Schema{type: :string, nullable: true, description: "Custom tag"},
      locked: %Schema{type: :boolean, description: "Lock flag"},
      temporary_name: %Schema{type: :string, nullable: true, description: "Temporary name"},
      labels: %Schema{type: :string, description: "Comma-separated list of labels"}
    },
    required: ~w(solar_system_id)a,
    example: %{
      solar_system_id: 30_000_142,
      solar_system_name: "Jita",
      position_x: 100,
      position_y: 200,
      visible: true,
      labels: "market,hub"
    }
  }

  @system_update_schema %Schema{
    type: :object,
    properties: %{
      solar_system_name: %Schema{
        type: :string,
        description: "EVE solar system name",
        nullable: true
      },
      position_x: %Schema{type: :integer, description: "X coordinate", nullable: true},
      position_y: %Schema{type: :integer, description: "Y coordinate", nullable: true},
      status: %Schema{
        type: :integer,
        description:
          "System status (0: unknown, 1: friendly, 2: warning, 3: targetPrimary, 4: targetSecondary, 5: dangerousPrimary, 6: dangerousSecondary, 7: lookingFor, 8: home)",
        nullable: true
      },
      visible: %Schema{type: :boolean, description: "Visibility flag", nullable: true},
      description: %Schema{type: :string, nullable: true, description: "Custom description"},
      tag: %Schema{type: :string, nullable: true, description: "Custom tag"},
      locked: %Schema{type: :boolean, description: "Lock flag", nullable: true},
      temporary_name: %Schema{type: :string, nullable: true, description: "Temporary name"},
      labels: %Schema{type: :string, description: "Comma-separated list of labels"}
    },
    example: %{
      solar_system_name: "Jita",
      position_x: 101,
      position_y: 202,
      visible: false,
      status: 0,
      tag: "HQ",
      locked: true,
      labels: "market,hub"
    }
  }

  @list_response_schema %Schema{
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          systems: %Schema{type: :array, items: MapSchemas.map_system_schema()},
          connections: %Schema{type: :array, items: MapSchemas.map_connection_schema()}
        }
      }
    }
  }

  @detail_response_schema ResponseSchemas.item_response(MapSchemas.map_system_schema())

  @batch_delete_schema %Schema{
    type: :object,
    properties: %{
      system_ids: %Schema{
        type: :array,
        items: %Schema{type: :integer},
        description: "IDs to delete"
      },
      connection_ids: %Schema{
        type: :array,
        items: %Schema{type: :string},
        description: "Connection UUIDs to delete",
        nullable: true
      }
    },
    required: ["system_ids"],
    example: %{
      system_ids: [30_000_142, 30_000_143],
      connection_ids: ["conn-uuid-1", "conn-uuid-2"]
    }
  }

  @batch_request_schema ApiSchemas.data_wrapper(%Schema{
                          type: :object,
                          properties: %{
                            systems: %Schema{type: :array, items: @system_request_schema},
                            connections: %Schema{
                              type: :array,
                              items: %Schema{
                                type: :object,
                                properties: %{
                                  solar_system_source: %Schema{
                                    type: :integer,
                                    description: "Source system ID"
                                  },
                                  solar_system_target: %Schema{
                                    type: :integer,
                                    description: "Target system ID"
                                  },
                                  type: %Schema{
                                    type: :integer,
                                    description: "Connection type (default 0)"
                                  },
                                  mass_status: %Schema{
                                    type: :integer,
                                    description: "Mass status (0-3)",
                                    nullable: true
                                  },
                                  time_status: %Schema{
                                    type: :integer,
                                    description: "Time decay status (0-3)",
                                    nullable: true
                                  },
                                  ship_size_type: %Schema{
                                    type: :integer,
                                    description: "Ship size limit (0-3)",
                                    nullable: true
                                  },
                                  locked: %Schema{
                                    type: :boolean,
                                    description: "Lock flag",
                                    nullable: true
                                  },
                                  custom_info: %Schema{
                                    type: :string,
                                    description: "Optional metadata",
                                    nullable: true
                                  }
                                },
                                required: ~w(solar_system_source solar_system_target)a
                              }
                            }
                          },
                          example: %{
                            systems: [
                              %{
                                solar_system_id: 30_000_142,
                                solar_system_name: "Jita",
                                position_x: 100.5,
                                position_y: 200.3,
                                visible: true
                              }
                            ],
                            connections: [
                              %{
                                solar_system_source: 30_000_142,
                                solar_system_target: 30_000_144,
                                type: 0
                              }
                            ]
                          }
                        })

  # -- Actions --

  operation(:index,
    summary: "List Map Systems and Connections",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ]
    ],
    responses: [
      ok: {
        "List Map Systems and Connections",
        "application/json",
        @list_response_schema
      }
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(%{assigns: %{map_id: map_id, map: map}} = conn, params) do
    # Extract filter parameters
    filter_opts =
      %{}
      |> maybe_add_filter(params, "search", :search)
      |> maybe_add_filter(params, "status", :status, &safe_parse_integer/1)
      |> maybe_add_filter(params, "tag", :tag)

    systems =
      MapSystems.list_systems(map_id, filter_opts) |> Enum.map(&APIUtils.map_system_to_json/1)

    connections = MapConnections.list_connections(map_id) |> Enum.map(&APIUtils.connection_to_json/1)

    # Include map reference in response
    response_data = %{
      systems: systems,
      connections: connections,
      map: MapSerializer.serialize_map_minimal(map)
    }

    APIUtils.respond_data(conn, response_data)
  end

  # Helper function to add filter parameters
  defp maybe_add_filter(
         filter_opts,
         params,
         param_key,
         filter_key,
         transform_fn \\ fn x -> x end
       ) do
    case Map.get(params, param_key) do
      nil -> filter_opts
      value -> Map.put(filter_opts, filter_key, transform_fn.(value))
    end
  end

  # Safe integer parsing function
  defp safe_parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp safe_parse_integer(value) when is_integer(value), do: value
  defp safe_parse_integer(_), do: nil

  operation(:show,
    summary: "Show Map System",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ],
      id: [
        in: :path,
        description: "System ID",
        type: :string,
        required: true
      ]
    ],
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    with {:ok, system_id} <- APIUtils.parse_int(id),
         {:ok, system} <- MapSystems.get_system(map_id, system_id) do
      APIUtils.respond_data(conn, APIUtils.map_system_to_json(system))
    end
  end

  operation(:create,
    summary: "Upsert Systems and Connections (batch or single)",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ]
    ],
    request_body: {"Systems+Connections upsert", "application/json", @batch_request_schema},
    responses:
      ResponseSchemas.standard_responses(ResponseSchemas.systems_connections_batch_response())
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    systems = Map.get(params, "systems", [])
    connections = Map.get(params, "connections", [])

    case MapSystems.upsert_systems_and_connections(conn, systems, connections) do
      {:ok, result} ->
        APIUtils.respond_data(conn, result)

      error ->
        error
    end
  end

  operation(:update,
    summary: "Update System",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ],
      id: [
        in: :path,
        description: "System ID",
        type: :string,
        required: true
      ]
    ],
    request_body: {"System update request", "application/json", @system_update_schema},
    responses: ResponseSchemas.update_responses(@detail_response_schema)
  )

  def update(conn, %{"id" => id} = params) do
    with {:ok, sid} <- APIUtils.parse_int(id),
         {:ok, attrs} <- APIUtils.extract_update_params(params),
         update_attrs = Map.put(attrs, "solar_system_id", sid),
         {:ok, system} <- MapSystems.update_system(conn, sid, update_attrs) do
      APIUtils.respond_data(conn, APIUtils.map_system_to_json(system))
    end
  end

  operation(:delete,
    summary: "Batch Delete Systems and Connections",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ]
    ],
    request_body: {"Batch delete", "application/json", @batch_delete_schema},
    responses: ResponseSchemas.standard_responses(ResponseSchemas.bulk_delete_response_schema())
  )

  def delete(conn, params) do
    system_ids = Map.get(params, "system_ids", [])
    connection_ids = Map.get(params, "connection_ids", [])

    deleted_systems = Enum.map(system_ids, &delete_system_id(conn, &1))
    deleted_connections = Enum.map(connection_ids, &delete_connection_id(conn, &1))

    systems_deleted = Enum.count(deleted_systems, &match?({:ok, _}, &1))
    connections_deleted = Enum.count(deleted_connections, &match?({:ok, _}, &1))
    deleted_count = systems_deleted + connections_deleted

    APIUtils.respond_data(conn, %{deleted_count: deleted_count})
  end

  defp delete_system_id(conn, id) do
    case APIUtils.parse_int(id) do
      {:ok, sid} -> MapSystems.delete_system(conn, sid)
      _ -> {:error, :invalid_id}
    end
  end

  defp delete_connection_id(conn, id) do
    case MapConnections.get_connection(conn.assigns.map_id, id) do
      {:ok, conn_struct} ->
        source_id = conn_struct.solar_system_source
        target_id = conn_struct.solar_system_target

        case MapConnections.delete_connection(conn, source_id, target_id) do
          :ok -> {:ok, conn_struct}
          error -> error
        end

      _ ->
        {:error, :invalid_id}
    end
  end

  operation(:delete_single,
    summary: "Delete a single Map System",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug)",
        type: :string,
        required: true,
        example: "map-slug or map UUID"
      ],
      id: [
        in: :path,
        description: "System ID",
        type: :string,
        required: true
      ]
    ],
    responses:
      ResponseSchemas.standard_responses(%Schema{
        type: :object,
        properties: %{
          deleted: %Schema{type: :boolean, description: "Deletion success flag"}
        },
        required: ["deleted"],
        example: %{deleted: true}
      })
  )

  def delete_single(conn, %{"id" => id}) do
    with {:ok, sid} <- APIUtils.parse_int(id),
         {:ok, _} <- MapSystems.delete_system(conn, sid) do
      APIUtils.respond_data(conn, %{deleted: true})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> APIUtils.respond_data(%{deleted: false, error: "System not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> APIUtils.respond_data(%{
          deleted: false,
          error: "Failed to delete system",
          reason: reason
        })

      _ ->
        conn
        |> put_status(:bad_request)
        |> APIUtils.respond_data(%{deleted: false, error: "Invalid system ID format"})
    end
  end

  # -- Legacy endpoints --

  operation(:list_systems,
    summary: "List Map Systems (Legacy)",
    deprecated: true,
    description: "Deprecated, use GET /api/maps/:map_identifier/systems instead",
    parameters: [
      map_id: [
        in: :query,
        description:
          "Map identifier (UUID) - Either map_id or slug must be provided, but not both",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided, but not both",
        type: :string,
        required: false
      ]
    ],
    responses: ResponseSchemas.standard_responses(@list_response_schema)
  )

  defdelegate list_systems(conn, params), to: __MODULE__, as: :index

  operation(:show_system,
    summary: "Show Map System (Legacy)",
    deprecated: true,
    description: "Deprecated, use GET /api/maps/:map_identifier/systems/:id instead",
    parameters: [
      map_id: [
        in: :query,
        description:
          "Map identifier (UUID) - Either map_id or slug must be provided, but not both",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided, but not both",
        type: :string,
        required: false
      ],
      id: [
        in: :query,
        description: "System ID",
        type: :string,
        required: true
      ]
    ],
    responses: ResponseSchemas.standard_responses(@detail_response_schema)
  )

  defdelegate show_system(conn, params), to: __MODULE__, as: :show
end
