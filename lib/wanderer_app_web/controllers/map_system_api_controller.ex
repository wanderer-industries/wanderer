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

  # -----------------------------------------------------------------
  # V1 API Actions (for compatibility with versioned API router)
  # -----------------------------------------------------------------

  def index_v1(conn, params) do
    # Delegate to existing index action
    index(conn, params)
  end

  def show_v1(conn, params) do
    # Delegate to existing show action
    show(conn, params)
  end

  def create_v1(conn, params) do
    # Delegate to existing create action
    create(conn, params)
  end

  def update_v1(conn, params) do
    # Delegate to existing update action
    update(conn, params)
  end

  def delete_v1(conn, params) do
    # Delegate to existing delete action
    delete(conn, params)
  end

  # -- JSON Schemas --
  @map_system_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Map system UUID"},
      map_id: %Schema{type: :string, description: "Map UUID"},
      solar_system_id: %Schema{type: :integer, description: "EVE solar system ID"},
      solar_system_name: %Schema{type: :string, description: "EVE solar system name"},
      region_name: %Schema{type: :string, description: "EVE region name"},
      custom_name: %Schema{
        type: :string,
        nullable: true,
        description: "Custom name for the system"
      },
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
    required: ~w(id map_id solar_system_id)a
  }

  @system_request_schema %Schema{
    type: :object,
    properties: %{
      solar_system_id: %Schema{type: :integer, description: "EVE solar system ID"},
      solar_system_name: %Schema{type: :string, description: "EVE solar system name"},
      custom_name: %Schema{
        type: :string,
        nullable: true,
        description: "Custom name for the system"
      },
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
      labels: %Schema{type: :string, description: "Comma-separated list of labels"},
      update_existing: %Schema{
        type: :boolean,
        nullable: true,
        description: "Update existing system"
      }
    },
    required: ~w(solar_system_id)a,
    example: %{
      solar_system_id: 30_000_142,
      solar_system_name: "Jita",
      custom_name: "Trade Hub",
      position_x: 100,
      position_y: 200,
      visible: true,
      labels: "market,hub",
      update_existing: false
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
      custom_name: %Schema{
        type: :string,
        nullable: true,
        description: "Custom name for the system"
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
      custom_name: "Trade Hub",
      position_x: 101,
      position_y: 202,
      visible: false,
      status: 0,
      tag: "HQ",
      locked: true,
      labels: "market,hub"
    }
  }

  @map_connection_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Connection UUID"},
      map_id: %Schema{type: :string, description: "Map UUID"},
      solar_system_source: %Schema{type: :integer},
      solar_system_target: %Schema{type: :integer},
      type: %Schema{type: :integer},
      mass_status: %Schema{type: :integer, nullable: true},
      time_status: %Schema{type: :integer, nullable: true},
      ship_size_type: %Schema{type: :integer, nullable: true},
      locked: %Schema{type: :boolean},
      custom_info: %Schema{type: :string, nullable: true},
      wormhole_type: %Schema{type: :string, nullable: true}
    },
    required: ~w(id map_id solar_system_source solar_system_target)a
  }

  @list_response_schema %Schema{
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          systems: %Schema{type: :array, items: @map_system_schema},
          connections: %Schema{type: :array, items: @map_connection_schema}
        }
      }
    },
    example: %{
      data: %{
        systems: [
          %{
            id: "sys-uuid-1",
            map_id: "map-uuid-1",
            solar_system_id: 30_000_142,
            solar_system_name: "Jita",
            region_name: "The Forge",
            custom_name: "Trade Hub Central",
            position_x: 100.5,
            position_y: 200.3,
            status: "active",
            visible: true,
            description: "Trade hub",
            tag: "HQ",
            locked: false,
            temporary_name: nil,
            labels: ["market", "hub"]
          }
        ],
        connections: [
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
  }

  @detail_response_schema %Schema{
    type: :object,
    properties: %{
      data: @map_system_schema
    },
    example: %{
      data: %{
        id: "sys-uuid-1",
        map_id: "map-uuid-1",
        solar_system_id: 30_000_142,
        solar_system_name: "Jita",
        region_name: "The Forge",
        custom_name: "Trade Hub Central",
        position_x: 100.5,
        position_y: 200.3,
        status: "active",
        visible: true,
        description: "Trade hub",
        tag: "HQ",
        locked: false,
        temporary_name: nil,
        labels: ["market", "hub"]
      }
    }
  }

  @delete_response_schema %Schema{
    type: :object,
    properties: %{deleted: %Schema{type: :boolean, description: "Deleted flag"}},
    required: ["deleted"],
    example: %{deleted: true}
  }

  @batch_response_schema %Schema{
    type: :object,
    properties: %{
      data: %Schema{
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
      }
    },
    example: %{
      data: %{
        systems: %{created: 2, updated: 1},
        connections: %{created: 1, updated: 0, deleted: 1}
      }
    }
  }

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

  @batch_delete_response_schema %Schema{
    type: :object,
    properties: %{deleted_count: %Schema{type: :integer, description: "Deleted count"}},
    required: ["deleted_count"],
    example: %{deleted_count: 2}
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

  def index(%{assigns: %{map_id: map_id}} = conn, _params) do
    systems = Operations.list_systems(map_id) |> Enum.map(&APIUtils.map_system_to_json/1)
    connections = Operations.list_connections(map_id) |> Enum.map(&APIUtils.connection_to_json/1)
    APIUtils.respond_data(conn, %{systems: systems, connections: connections})
  end

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

  def show(%{assigns: %{map_id: map_id}} = conn, %{"id" => id}) do
    with {:ok, system_uuid} <- APIUtils.validate_uuid(id),
         {:ok, system} <- WandererApp.Api.MapSystem.by_id(system_uuid) do
      # Verify the system belongs to the requested map
      if system.map_id == map_id do
        APIUtils.respond_data(conn, APIUtils.map_system_to_json(system))
      else
        {:error, :not_found}
      end
    else
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
      error -> error
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
    responses: ResponseSchemas.standard_responses(@batch_response_schema)
  )

  def create(conn, params) do
    systems = Map.get(params, "systems", [])
    connections = Map.get(params, "connections", [])

    case Operations.upsert_systems_and_connections(conn, systems, connections) do
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
    with {:ok, system_uuid} <- APIUtils.validate_uuid(id),
         {:ok, system} <- WandererApp.Api.MapSystem.by_id(system_uuid),
         {:ok, attrs} <- APIUtils.extract_update_params(params),
         {:ok, updated_system} <- Ash.update(system, attrs) do
      APIUtils.respond_data(conn, APIUtils.map_system_to_json(updated_system))
    end
  end

  operation(:delete_batch,
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
    responses: ResponseSchemas.standard_responses(@batch_delete_response_schema)
  )

  def delete_batch(conn, params) do
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
      {:ok, sid} -> Operations.delete_system(conn, sid)
      _ -> {:error, :invalid_id}
    end
  end

  defp delete_connection_id(conn, id) do
    case Operations.get_connection(conn, id) do
      {:ok, conn_struct} ->
        source_id = conn_struct.solar_system_source
        target_id = conn_struct.solar_system_target

        case Operations.delete_connection(conn, source_id, target_id) do
          :ok -> {:ok, conn_struct}
          error -> error
        end

      _ ->
        {:error, :invalid_id}
    end
  end

  operation(:delete,
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
    responses: ResponseSchemas.standard_responses(@delete_response_schema)
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, sid} <- APIUtils.parse_int(id),
         {:ok, _} <- Operations.delete_system(conn, sid) do
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

      error ->
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
