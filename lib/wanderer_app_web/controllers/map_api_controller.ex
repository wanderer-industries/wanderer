defmodule WandererAppWeb.MapAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ash.Query, only: [filter: 2]
  require Logger

  alias WandererApp.Api
  alias WandererApp.Api.Character
  alias WandererApp.MapConnectionRepo
  alias WandererApp.MapSystemRepo
  alias WandererApp.MapCharacterSettingsRepo

  alias WandererApp.Zkb.KillsProvider.KillsCache

  alias WandererAppWeb.UtilAPIController, as: Util

  # -----------------------------------------------------------------
  # Inline Schemas
  # -----------------------------------------------------------------

  @map_system_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string},
      map_id: %OpenApiSpex.Schema{type: :string},
      solar_system_id: %OpenApiSpex.Schema{type: :integer},
      original_name: %OpenApiSpex.Schema{type: :string},
      name: %OpenApiSpex.Schema{type: :string},
      custom_name: %OpenApiSpex.Schema{type: :string},
      temporary_name: %OpenApiSpex.Schema{type: :string},
      description: %OpenApiSpex.Schema{type: :string},
      tag: %OpenApiSpex.Schema{type: :string},
      labels: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}},
      locked: %OpenApiSpex.Schema{type: :boolean},
      visible: %OpenApiSpex.Schema{type: :boolean},
      status: %OpenApiSpex.Schema{type: :string},
      position_x: %OpenApiSpex.Schema{type: :integer},
      position_y: %OpenApiSpex.Schema{type: :integer},
      inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
      updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time}
    },
    required: ["id", "solar_system_id", "original_name", "name"]
  }

  @list_map_systems_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @map_system_schema
      }
    },
    required: ["data"]
  }

  @show_map_system_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: @map_system_schema
    },
    required: ["data"]
  }

  # For operation :list_connections
  @map_connection_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string},
      map_id: %OpenApiSpex.Schema{type: :string},
      solar_system_source: %OpenApiSpex.Schema{type: :integer},
      solar_system_target: %OpenApiSpex.Schema{type: :integer},
      mass_status: %OpenApiSpex.Schema{type: :integer},
      time_status: %OpenApiSpex.Schema{type: :integer},
      ship_size_type: %OpenApiSpex.Schema{type: :integer},
      type: %OpenApiSpex.Schema{type: :integer},
      wormhole_type: %OpenApiSpex.Schema{type: :string},
      inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
      updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time}
    },
    required: ["id", "map_id", "solar_system_source", "solar_system_target", "type", "inserted_at", "updated_at"]
  }

  @list_map_connections_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @map_connection_schema
      }
    },
    required: ["data"]
  }

  @show_map_system_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: @map_connection_schema
    },
    required: ["data"]
  }

  # For operation :tracked_characters_with_info
  @character_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      eve_id: %OpenApiSpex.Schema{type: :string},
      name: %OpenApiSpex.Schema{type: :string},
      corporation_id: %OpenApiSpex.Schema{type: :string},
      corporation_ticker: %OpenApiSpex.Schema{type: :string},
      alliance_id: %OpenApiSpex.Schema{type: :string},
      alliance_ticker: %OpenApiSpex.Schema{type: :string}
    },
    required: ["eve_id", "name"]
  }

  @tracked_char_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string},
      map_id: %OpenApiSpex.Schema{type: :string},
      character_id: %OpenApiSpex.Schema{type: :string},
      tracked: %OpenApiSpex.Schema{type: :boolean},
      inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
      updated_at: %OpenApiSpex.Schema{type: :string, format: :date_time},
      character: @character_schema
    },
    required: ["id", "map_id", "character_id", "tracked"]
  }

  @tracked_characters_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @tracked_char_schema
      }
    },
    required: ["data"]
  }

  # For operation :show_structure_timers
  @structure_timer_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      system_id: %OpenApiSpex.Schema{type: :string},
      solar_system_name: %OpenApiSpex.Schema{type: :string},
      solar_system_id: %OpenApiSpex.Schema{type: :integer},
      structure_type_id: %OpenApiSpex.Schema{type: :integer},
      structure_type: %OpenApiSpex.Schema{type: :string},
      character_eve_id: %OpenApiSpex.Schema{type: :string},
      name: %OpenApiSpex.Schema{type: :string},
      notes: %OpenApiSpex.Schema{type: :string},
      owner_name: %OpenApiSpex.Schema{type: :string},
      owner_ticker: %OpenApiSpex.Schema{type: :string},
      owner_id: %OpenApiSpex.Schema{type: :string},
      status: %OpenApiSpex.Schema{type: :string},
      end_time: %OpenApiSpex.Schema{type: :string, format: :date_time}
    },
    required: ["system_id", "solar_system_id", "name", "status"]
  }

  @structure_timers_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @structure_timer_schema
      }
    },
    required: ["data"]
  }

  # For operation :list_systems_kills
  @kill_item_schema %OpenApiSpex.Schema{
    type: :object,
    description: "Kill detail object",
    properties: %{
      kill_id: %OpenApiSpex.Schema{type: :integer, description: "Unique identifier for the kill"},
      kill_time: %OpenApiSpex.Schema{type: :string, format: :date_time, description: "Time when the kill occurred"},
      victim_id: %OpenApiSpex.Schema{type: :integer, description: "ID of the victim character"},
      victim_name: %OpenApiSpex.Schema{type: :string, description: "Name of the victim character"},
      ship_type_id: %OpenApiSpex.Schema{type: :integer, description: "Type ID of the destroyed ship"},
      ship_name: %OpenApiSpex.Schema{type: :string, description: "Name of the destroyed ship"}
    }
  }

  @system_kills_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      solar_system_id: %OpenApiSpex.Schema{type: :integer},
      kills: %OpenApiSpex.Schema{
        type: :array,
        items: @kill_item_schema
      }
    },
    required: ["solar_system_id", "kills"]
  }

  @systems_kills_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @system_kills_schema
      }
    },
    required: ["data"]
  }

  # For operation :character_activity
  @character_activity_item_schema %OpenApiSpex.Schema{
    type: :object,
    description: "Character activity data",
    properties: %{
      character: @character_schema,
      passages: %OpenApiSpex.Schema{type: :integer, description: "Number of passages through systems"},
      connections: %OpenApiSpex.Schema{type: :integer, description: "Number of connections created"},
      signatures: %OpenApiSpex.Schema{type: :integer, description: "Number of signatures added"},
      timestamp: %OpenApiSpex.Schema{type: :string, format: :date_time, description: "Timestamp of the activity"}
    },
    required: ["character", "passages", "connections", "signatures"]
  }

  @character_activity_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @character_activity_item_schema
      }
    },
    required: ["data"]
  }

  # For operation :user_characters
  @user_character_schema %OpenApiSpex.Schema{
    type: :object,
    description: "Character group information with main character identification",
    properties: %{
      characters: %OpenApiSpex.Schema{
        type: :array,
        items: @character_schema,
        description: "List of characters belonging to a user"
      },
      main_character_eve_id: %OpenApiSpex.Schema{
        type: :string,
        description: "EVE ID of the main character for this user on this map",
        nullable: true
      }
    },
    required: ["characters"]
  }

  @user_characters_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @user_character_schema
      }
    },
    required: ["data"]
  }

  # -----------------------------------------------------------------
  # MAP endpoints
  # -----------------------------------------------------------------

  @doc """
  GET /api/map/systems

  Requires either `?map_id=<UUID>` **OR** `?slug=<map-slug>` in the query params.

  Only "visible" systems are returned.

  Examples:
      GET /api/map/systems?map_id=466e922b-e758-485e-9b86-afae06b88363
      GET /api/map/systems?slug=my-unique-wormhole-map
  """
  @spec list_systems(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :list_systems,
    summary: "List Map Systems",
    description: "Lists all visible systems for a map. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: ""
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: "map-name"
      ]
    ],
    responses: [
      ok: {
        "List of map systems",
        "application/json",
        @list_map_systems_response_schema
      },
      bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "Must provide either ?map_id=UUID or ?slug=SLUG"
        }
      }}
    ]
  def list_systems(conn, params) do
    with {:ok, map_id} <- Util.fetch_map_id(params),
         {:ok, systems} <- MapSystemRepo.get_visible_by_map(map_id) do
      data = Enum.map(systems, &map_system_to_json/1)
      json(conn, %{data: data})
    else
      {:error, msg} when is_binary(msg) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Could not fetch systems: #{inspect(reason)}"})
    end
  end

  @doc """
  GET /api/map/system

  Requires 'id' (the solar_system_id)
  plus either ?map_id=<UUID> or ?slug=<map-slug>.

  Example:
      GET /api/map/system?id=31002229&map_id=466e922b-e758-485e-9b86-afae06b88363
      GET /api/map/system?id=31002229&slug=my-unique-wormhole-map
  """
  @spec show_system(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :show_system,
    summary: "Show Map System",
    description: "Retrieves details for a specific map system (by solar_system_id + map). Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      id: [
        in: :query,
        description: "System ID",
        type: :string,
        required: true,
        example: "30000142"
      ],
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: ""
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: "map-name"
      ]
    ],
    responses: [
      ok: {
        "Map system details",
        "application/json",
        @show_map_system_response_schema
      },
      bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        }
      }},
      not_found: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "System not found"
        }
      }}
    ]
  def show_system(conn, params) do
    with {:ok, solar_system_str} <- Util.require_param(params, "id"),
         {:ok, solar_system_id} <- Util.parse_int(solar_system_str),
         {:ok, map_id} <- Util.fetch_map_id(params),
         {:ok, system} <- MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id) do
      data = map_system_to_json(system)
      json(conn, %{data: data})
    else
      {:error, msg} when is_binary(msg) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "System not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Could not load system: #{inspect(reason)}"})
    end
  end

  @doc """
  GET /api/map/connections

  Requires either `?map_id=<UUID>` **OR** `?slug=<map-slug>` in the query params.

  Examples:
      GET /api/map/connections?map_id=466e922b-e758-485e-9b86-afae06b88363
      GET /api/map/connections?slug=my-unique-wormhole-map
  """
@spec list_connections(Plug.Conn.t(), map()) :: Plug.Conn.t()
operation :list_connections,
  summary: "List Map Connections",
  description: "Lists all connections for a map. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
  parameters: [
    map_id: [
      in: :query,
      description: "Map identifier (UUID) - Either map_id or slug must be provided",
      type: :string,
      required: false,
      example: ""
    ],
    slug: [
      in: :query,
      description: "Map slug - Either map_id or slug must be provided",
      type: :string,
      required: false,
      example: "map-name"
    ]
  ],
  responses: [
    ok: {
      "List of map connections",
      "application/json",
      @list_map_connections_response_schema
    },
    bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
      type: :object,
      properties: %{
        error: %OpenApiSpex.Schema{type: :string}
      },
      required: ["error"],
      example: %{
        "error" => "Must provide either ?map_id=UUID or ?slug=SLUG"
      }
    }}
  ]
def list_connections(conn, params) do
  with {:ok, map_id} <- Util.fetch_map_id(params),
        {:ok, systems} <- MapConnectionRepo.get_by_map(map_id) do
    data = Enum.map(systems, &connection_to_json/1)
    json(conn, %{data: data})
  else
    {:error, msg} when is_binary(msg) ->
      conn
      |> put_status(:bad_request)
      |> json(%{error: msg})

    {:error, reason} ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Could not fetch connections: #{inspect(reason)}"})
  end
end

  @doc """
  GET /api/map/tracked_characters_with_info

  Example usage:
    GET /api/map/tracked_characters_with_info?map_id=<uuid>
    GET /api/map/tracked_characters_with_info?slug=<map-slug>

  Returns a list of tracked records, plus their fully-loaded `character` data.
  """
  @spec tracked_characters_with_info(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :tracked_characters_with_info,
    summary: "List Tracked Characters with Info",
    description: "Lists all tracked characters for a map with their information. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: ""
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: "map-name"
      ]
    ],
    responses: [
      ok: {
        "List of tracked characters",
        "application/json",
        @tracked_characters_response_schema
      },
      bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "Must provide either ?map_id=UUID or ?slug=SLUG"
        }
      }}
    ]
  def tracked_characters_with_info(conn, params) do
    with {:ok, map_id} <- Util.fetch_map_id(params),
         {:ok, settings_list} <- get_tracked_by_map_ids(map_id),
         {:ok, char_list} <- read_characters_by_ids_wrapper(Enum.map(settings_list, & &1.character_id)) do
      chars_by_id = Map.new(char_list, &{&1.id, &1})

      data =
        Enum.map(settings_list, fn setting ->
          found_char = Map.get(chars_by_id, setting.character_id)

          %{
            id: setting.id,
            map_id: setting.map_id,
            character_id: setting.character_id,
            tracked: setting.tracked,
            inserted_at: setting.inserted_at,
            updated_at: setting.updated_at,
            character:
              if found_char do
                character_to_json(found_char)
              else
                %{}
              end
          }
        end)

      json(conn, %{data: data})
    else
      {:error, :get_tracked_error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No tracked records found for map_id: #{inspect(reason)}"})

      {:error, :read_characters_by_ids_error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Could not load Character records: #{inspect(reason)}"})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  @doc """
  GET /api/map/structure_timers

  Returns structure timers for visible systems on the map
  or for a specific system if `system_id` is specified.

  **Example usage**:
  - All visible systems:
    ```
    GET /api/map/structure_timers?map_id=<uuid>
    ```
  - For a single system:
    ```
    GET /api/map/structure_timers?map_id=<uuid>&system_id=31002229
    ```
  """
  @spec show_structure_timers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :show_structure_timers,
    summary: "Show Structure Timers",
    description: "Retrieves structure timers for a map. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: ""
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: "map-name"
      ],
      system_id: [
        in: :query,
        description: "System ID",
        type: :string,
        required: false,
        example: "30000142"
      ]
    ],
    responses: [
      ok: {
        "Structure timers",
        "application/json",
        @structure_timers_response_schema
      },
      bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        }
      }}
    ]
  def show_structure_timers(conn, params) do
    with {:ok, map_id} <- Util.fetch_map_id(params) do
      system_id_str = params["system_id"]

      case system_id_str do
        nil ->
          handle_all_structure_timers(conn, map_id)

        _ ->
          case Util.parse_int(system_id_str) do
            {:ok, system_id} ->
              handle_single_structure_timers(conn, map_id, system_id)

            {:error, reason} ->
              conn
              |> put_status(:bad_request)
              |> json(%{error: "system_id must be int: #{reason}"})
          end
      end
    else
      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end

  @doc """
  GET /api/map/systems_kills

  Returns kills data for all *visible* systems on the map.

  Requires either `?map_id=<UUID>` or `?slug=<map-slug>`.
  Optional hours_ago parameter.

  Example:
      GET /api/map/systems_kills?map_id=<uuid>
      GET /api/map/systems_kills?slug=<map-slug>
      GET /api/map/systems_kills?map_id=<uuid>&hours_ago=<somehours>
  """
  @spec list_systems_kills(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :list_systems_kills,
    summary: "List Systems Kills",
    description: "Returns kills data for all visible systems on the map, optionally filtered by hours_ago. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: ""
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: "map-name"
      ],
      hours: [
        in: :query,
        description: "Number of hours to look back for kills",
        type: :string,
        required: false,
        example: "24"
      ]
    ],
    responses: [
      ok: {
        "Systems kills data",
        "application/json",
        @systems_kills_response_schema
      },
      bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        }
      }}
    ]
  def list_systems_kills(conn, params) do
    with {:ok, map_id} <- Util.fetch_map_id(params),
         # fetch visible systems from the repo
         {:ok, systems} <- MapSystemRepo.get_visible_by_map(map_id) do

      Logger.debug(fn -> "[list_systems_kills] Found #{length(systems)} visible systems for map_id=#{map_id}" end)

      # Parse the hours_ago param (check both "hours_ago" and "hour_ago" for backward compatibility)
      hours_ago = parse_hours_ago(params["hours_ago"] || params["hour_ago"])

      Logger.debug(fn -> "[list_systems_kills] Using hours_ago=#{inspect(hours_ago)}, from params: hours_ago=#{inspect(params["hours_ago"])}, hour_ago=#{inspect(params["hour_ago"])}" end)

      # Gather system IDs
      solar_ids = Enum.map(systems, & &1.solar_system_id)

      # Fetch kills for each system from the cache
      kills_map = KillsCache.fetch_cached_kills_for_systems(solar_ids)

      # Build final JSON data
      data =
        Enum.map(systems, fn sys ->
          kills = Map.get(kills_map, sys.solar_system_id, [])

          # Filter out kills older than hours_ago
          filtered_kills = maybe_filter_kills_by_time(kills, hours_ago)

          Logger.debug(fn ->
            "[list_systems_kills] For system_id=#{sys.solar_system_id}, " <>
            "found #{length(kills)} kills total, " <>
            "returning #{length(filtered_kills)} kills after hours_ago=#{inspect(hours_ago)} filter"
          end)

          %{
            solar_system_id: sys.solar_system_id,
            kills: filtered_kills
          }
        end)

      json(conn, %{data: data})
    else
      {:error, msg} when is_binary(msg) ->
        Logger.warning("[list_systems_kills] Bad request: #{msg}")
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})

      {:error, reason} ->
        Logger.error("[list_systems_kills] Could not fetch systems: #{inspect(reason)}")
        conn
        |> put_status(:not_found)
        |> json(%{error: "Could not fetch systems: #{inspect(reason)}"})
    end
  end

  @doc """
  GET /api/map/character_activity

  Returns character activity data for a map.

  Requires either `?map_id=<UUID>` or `?slug=<map-slug>`.
  Optional `days` parameter to filter activity to a specific time period.

  Example:
      GET /api/map/character_activity?map_id=<uuid>
      GET /api/map/character_activity?slug=<map-slug>
      GET /api/map/character_activity?map_id=<uuid>&days=7
  """
  @spec character_activity(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :character_activity,
    summary: "Get Character Activity",
    description: "Returns character activity data for a map. If days parameter is provided, filters activity to that time period, otherwise returns all activity. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: ""
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: "map-name"
      ],
      days: [
        in: :query,
        description: "Optional: Number of days to look back for activity data. If not provided, returns all activity history.",
        type: :integer,
        required: false,
        example: "7"
      ]
    ],
    responses: [
      ok: {
        "Character activity data",
        "application/json",
        @character_activity_response_schema
      },
      bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        }
      }}
    ]
  def character_activity(conn, params) do
    with {:ok, map_id} <- Util.fetch_map_id(params),
         {:ok, days} <- parse_days(params["days"]) do
      # Get raw activity data (filtered by days if provided, otherwise all activity)
      raw_activity = WandererApp.Map.get_character_activity(map_id, days)

      # Group activities by user_id and summarize
      summarized_result =
        if raw_activity == [] do
          # Return empty list if there's no data
          []
        else
          raw_activity
          |> Enum.group_by(fn activity ->
            # Get user_id from the character
            activity.character.user_id
          end)
          |> Enum.map(fn {_user_id, user_activities} ->
            # Get the most active or followed character for this user
            representative_activity =
              user_activities
              |> Enum.max_by(fn activity ->
                activity.passages + activity.connections + activity.signatures
              end)

            # Sum up all activities for this user
            total_passages = Enum.sum(Enum.map(user_activities, & &1.passages))
            total_connections = Enum.sum(Enum.map(user_activities, & &1.connections))
            total_signatures = Enum.sum(Enum.map(user_activities, & &1.signatures))

            # Return summarized activity with the mapped character
            %{
              character: character_to_json(representative_activity.character),
              passages: total_passages,
              connections: total_connections,
              signatures: total_signatures,
              timestamp: representative_activity.timestamp
            }
          end)
        end

      json(conn, %{data: summarized_result})
    else
      {:error, msg} when is_binary(msg) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Could not fetch character activity: #{inspect(reason)}"})
    end
  end

  @doc """
  GET /api/map/user_characters

  Returns characters grouped by user for a specific map,
  indicating which one is set as the "main" character for each user.
  Does not expose user IDs.

  Requires either `?map_id=<UUID>` or `?slug=<map-slug>`.

  Example:
      GET /api/map/user_characters?map_id=<uuid>
      GET /api/map/user_characters?slug=<map-slug>
  """
  @spec user_characters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :user_characters,
    summary: "Get User Characters",
    description: "Returns characters grouped by user for a specific map, indicating which one is set as the main character for each user. Does not expose user IDs. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: ""
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false,
        example: "map-name"
      ]
    ],
    responses: [
      ok: {
        "User characters with main character indication",
        "application/json",
        @user_characters_response_schema
      },
      bad_request: {"Error", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          error: %OpenApiSpex.Schema{type: :string}
        },
        required: ["error"],
        example: %{
          "error" => "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        }
      }}
    ]
  def user_characters(conn, params) do
    with {:ok, map_id} <- Util.fetch_map_id(params) do
      # Get all character settings for this map (tracked characters)
      case MapCharacterSettingsRepo.get_all_by_map(map_id) do
        {:ok, map_character_settings} when map_character_settings != [] ->
          # Extract character IDs from settings
          character_ids = Enum.map(map_character_settings, &(&1.character_id))

          # Get all characters based on these IDs
          characters_query =
            WandererApp.Api.Character
            |> Ash.Query.new()
            |> Ash.Query.filter(id in ^character_ids)

          case WandererApp.Api.read(characters_query) do
            {:ok, characters} when characters != [] ->
              # Group characters by user_id
              characters_by_user =
                characters
                |> Enum.filter(fn char -> not is_nil(char.user_id) end)
                |> Enum.group_by(&(&1.user_id))

              # Get user settings for this map (for main character info)
              settings_query =
                WandererApp.Api.MapUserSettings
                |> Ash.Query.new()
                |> Ash.Query.filter(map_id == ^map_id)

              # Create a map of user_id to main_character_eve_id
              main_characters_by_user =
                case WandererApp.Api.read(settings_query) do
                  {:ok, map_user_settings} ->
                    Map.new(map_user_settings, fn settings ->
                      {settings.user_id, settings.main_character_eve_id}
                    end)
                  _ -> %{}
                end

              # Build the response grouped by user
              character_groups =
                Enum.map(characters_by_user, fn {user_id, user_characters} ->
                  %{
                    characters: Enum.map(user_characters, &character_to_json/1),
                    main_character_eve_id: Map.get(main_characters_by_user, user_id)
                  }
                end)

              json(conn, %{data: character_groups})

            {:ok, []} ->
              # No characters found for the IDs in settings
              json(conn, %{data: []})

            {:error, reason} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "Failed to fetch characters: #{inspect(reason)}"})
          end

        {:ok, []} ->
          # No character settings for this map
          json(conn, %{data: []})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to fetch map character settings: #{inspect(reason)}"})
      end
    else
      {:error, msg} when is_binary(msg) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Could not fetch user characters: #{inspect(reason)}"})
    end
  end

  defp map_is_empty?(map) when is_map(map), do: map == %{}
  defp map_is_empty?(_), do: true

  # Parse days parameter, return nil if not provided to show all activity
  defp parse_days(nil), do: {:ok, nil}
  defp parse_days(days_str) do
    case Integer.parse(days_str) do
      {days, ""} when days > 0 -> {:ok, days}
      _ -> {:ok, nil} # Return nil if invalid to show all activity
    end
  end

  # If hours_str is present and valid, parse it. Otherwise return nil (no filter).
  defp parse_hours_ago(nil), do: nil
  defp parse_hours_ago(hours_str) do
    Logger.debug(fn -> "[parse_hours_ago] Parsing hours_str: #{inspect(hours_str)}" end)

    result = case Integer.parse(hours_str) do
      {num, ""} when num > 0 ->
        Logger.debug(fn -> "[parse_hours_ago] Successfully parsed to #{num}" end)
        num
      {num, rest} ->
        Logger.debug(fn -> "[parse_hours_ago] Parsed with remainder: #{num}, rest: #{inspect(rest)}" end)
        nil
      :error ->
        Logger.debug(fn -> "[parse_hours_ago] Failed to parse" end)
        nil
    end

    Logger.debug(fn -> "[parse_hours_ago] Final result: #{inspect(result)}" end)
    result
  end

  defp maybe_filter_kills_by_time(kills, hours_ago) when is_integer(hours_ago) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours_ago * 3600, :second)
    Logger.debug(fn -> "[maybe_filter_kills_by_time] Filtering kills with cutoff: #{DateTime.to_iso8601(cutoff)}" end)

    filtered = Enum.filter(kills, fn kill ->
      kill_time = kill["kill_time"]

      result = case kill_time do
        %DateTime{} = dt ->
          # Keep kills that occurred after the cutoff
          DateTime.compare(dt, cutoff) != :lt

        time when is_binary(time) ->
          # Try to parse the string time
          case DateTime.from_iso8601(time) do
            {:ok, dt, _} -> DateTime.compare(dt, cutoff) != :lt
            _ -> false
          end

        # If it's something else (nil, or a weird format), skip
        _ ->
          false
      end

      Logger.debug(fn ->
        kill_time_str = if is_binary(kill_time), do: kill_time, else: inspect(kill_time)
        "[maybe_filter_kills_by_time] Kill time: #{kill_time_str}, included: #{result}"
      end)

      result
    end)

    Logger.debug(fn -> "[maybe_filter_kills_by_time] Filtered #{length(kills)} kills to #{length(filtered)} kills" end)
    filtered
  end

  # If hours_ago is nil, no time filtering:
  defp maybe_filter_kills_by_time(kills, nil), do: kills

  defp handle_all_structure_timers(conn, map_id) do
    case MapSystemRepo.get_visible_by_map(map_id) do
      {:ok, systems} ->
        all_timers =
          systems
          |> Enum.flat_map(&get_timers_for_system/1)

        json(conn, %{data: all_timers})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Could not fetch visible systems for map_id=#{map_id}: #{inspect(reason)}"})
    end
  end

  defp handle_single_structure_timers(conn, map_id, system_id) do
    case MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
      {:ok, map_system} ->
        timers = get_timers_for_system(map_system)
        json(conn, %{data: timers})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No system with solar_system_id=#{system_id} in map=#{map_id}"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve system: #{inspect(reason)}"})
    end
  end

  defp get_timers_for_system(map_system) do
    structures = WandererApp.Api.MapSystemStructure.by_system_id!(map_system.id)

    structures
    |> Enum.filter(&timer_needed?/1)
    |> Enum.map(&structure_to_timer_json/1)
  end

  defp timer_needed?(structure) do
    structure.status in ["Anchoring", "Reinforced"] and not is_nil(structure.end_time)
  end

  defp structure_to_timer_json(s) do
    Map.take(s, [
      :system_id,
      :solar_system_name,
      :solar_system_id,
      :structure_type_id,
      :structure_type,
      :character_eve_id,
      :name,
      :notes,
      :owner_name,
      :owner_ticker,
      :owner_id,
      :status,
      :end_time
    ])
  end

  defp get_tracked_by_map_ids(map_id) do
    case MapCharacterSettingsRepo.get_tracked_by_map_all(map_id) do
      {:ok, settings_list} -> {:ok, settings_list}
      {:error, reason}     -> {:error, :get_tracked_error, reason}
    end
  end

  defp read_characters_by_ids_wrapper(ids) do
    case read_characters_by_ids(ids) do
      {:ok, char_list} ->
        {:ok, char_list}

      {:error, reason} ->
        {:error, :read_characters_by_ids_error, reason}
    end
  end

  defp read_characters_by_ids(ids) when is_list(ids) do
    if ids == [] do
      {:ok, []}
    else
      query =
        Character
        |> filter(id in ^ids)

      Api.read(query)
    end
  end

  defp map_system_to_json(system) do
    # Get the original system name from the database
    original_name = get_original_system_name(system.solar_system_id)

    # Start with the basic system data
    result = Map.take(system, [
      :id,
      :map_id,
      :solar_system_id,
      :custom_name,
      :temporary_name,
      :description,
      :tag,
      :labels,
      :locked,
      :visible,
      :status,
      :position_x,
      :position_y,
      :inserted_at,
      :updated_at
    ])

    # Add the original name
    result = Map.put(result, :original_name, original_name)

    # Set the name field based on the display priority:
    # 1. If temporary_name is set, use that
    # 2. If custom_name is set, use that
    # 3. Otherwise, use the original system name
    display_name = cond do
      not is_nil(system.temporary_name) and system.temporary_name != "" ->
        system.temporary_name
      not is_nil(system.custom_name) and system.custom_name != "" ->
        system.custom_name
      true ->
        original_name
    end

    # Add the display name as the "name" field
    Map.put(result, :name, display_name)
  end

  defp get_original_system_name(solar_system_id) do
    # Fetch the original system name from the MapSolarSystem resource
    case WandererApp.Api.MapSolarSystem.by_solar_system_id(solar_system_id) do
      {:ok, system} ->
        system.solar_system_name
      _error ->
        "Unknown System"
    end
  end

  defp connection_to_json(c) do
    Map.take(c, [
      :id,
      :map_id,
      :solar_system_source,
      :solar_system_target,
      :mass_status,
      :time_status,
      :ship_size_type,
      :type,
      :wormhole_type,
      :inserted_at,
      :updated_at
    ])
  end

  defp character_to_json(ch) do
    WandererAppWeb.MapEventHandler.map_ui_character_stat(ch)
  end
end
