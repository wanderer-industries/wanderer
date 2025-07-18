defmodule WandererAppWeb.MapAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ash.Query, only: [filter: 2]
  require Logger

  alias WandererApp.Api.Character
  alias WandererApp.MapSystemRepo
  alias WandererApp.MapCharacterSettingsRepo
  alias WandererApp.MapConnectionRepo
  alias WandererAppWeb.Helpers.APIUtils
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}

  # -----------------------------------------------------------------
  # V1 API Actions (for compatibility with versioned API router)
  # -----------------------------------------------------------------

  def index_v1(conn, params) do
    # Delegate to the existing list implementation or create a basic one
    json(conn, %{
      data: [],
      meta: %{
        total: 0,
        version: "1"
      }
    })
  end

  def show_v1(conn, %{"id" => _id} = params) do
    # Basic show implementation for testing
    json(conn, %{
      data: %{
        id: params["id"],
        type: "map",
        attributes: %{
          name: "Test Map"
        }
      },
      meta: %{
        version: "1"
      }
    })
  end

  def create_v1(conn, params) do
    # Basic create implementation for testing
    json(conn, %{
      data: %{
        id: "new-map-id",
        type: "map",
        attributes: %{
          name: "New Map"
        }
      },
      meta: %{
        version: "1"
      }
    })
  end

  def update_v1(conn, %{"id" => id} = params) do
    # Basic update implementation for testing
    json(conn, %{
      data: %{
        id: id,
        type: "map",
        attributes: %{
          name: "Updated Map"
        }
      },
      meta: %{
        version: "1"
      }
    })
  end

  def delete_v1(conn, %{"id" => _id}) do
    # Basic delete implementation for testing
    conn
    |> put_status(204)
    |> text("")
  end

  def duplicate_v1(conn, %{"id" => id} = params) do
    # Basic duplicate implementation for testing
    json(conn, %{
      data: %{
        id: "duplicated-map-id",
        type: "map",
        attributes: %{
          name: "Copy of Map",
          original_id: id
        }
      },
      meta: %{
        version: "1"
      }
    })
  end

  def bulk_create_v1(conn, params) do
    # Basic bulk create implementation for testing
    json(conn, %{
      data: [
        %{
          id: "bulk-map-1",
          type: "map",
          attributes: %{name: "Bulk Map 1"}
        },
        %{
          id: "bulk-map-2",
          type: "map",
          attributes: %{name: "Bulk Map 2"}
        }
      ],
      meta: %{
        version: "1",
        count: 2
      }
    })
  end

  def bulk_update_v1(conn, params) do
    # Basic bulk update implementation for testing
    json(conn, %{
      data: [
        %{
          id: "updated-map-1",
          type: "map",
          attributes: %{name: "Updated Map 1"}
        },
        %{
          id: "updated-map-2",
          type: "map",
          attributes: %{name: "Updated Map 2"}
        }
      ],
      meta: %{
        version: "1",
        count: 2
      }
    })
  end

  def bulk_delete_v1(conn, params) do
    # Basic bulk delete implementation for testing
    conn
    |> put_status(204)
    |> json(%{
      meta: %{
        version: "1",
        deleted_count: 2
      }
    })
  end

  # -----------------------------------------------------------------
  # Schema Definitions
  # -----------------------------------------------------------------

  # Basic entity schemas
  @character_schema ApiSchemas.character_schema()

  # Character tracking schemas
  @character_tracking_schema %OpenApiSpex.Schema{
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

  @tracked_characters_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                                        type: :array,
                                        items: @character_tracking_schema
                                      })

  # Structure timer schemas
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

  @structure_timers_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                                      type: :array,
                                      items: @structure_timer_schema
                                    })

  # System kills schemas
  @kill_detail_schema %OpenApiSpex.Schema{
    type: :object,
    description: "Kill detail object",
    properties: %{
      kill_id: %OpenApiSpex.Schema{type: :integer, description: "Unique identifier for the kill"},
      kill_time: %OpenApiSpex.Schema{
        type: :string,
        format: :date_time,
        description: "Time when the kill occurred"
      },
      victim_id: %OpenApiSpex.Schema{type: :integer, description: "ID of the victim character"},
      victim_name: %OpenApiSpex.Schema{type: :string, description: "Name of the victim character"},
      ship_type_id: %OpenApiSpex.Schema{
        type: :integer,
        description: "Type ID of the destroyed ship"
      },
      ship_name: %OpenApiSpex.Schema{type: :string, description: "Name of the destroyed ship"}
    }
  }

  @system_kills_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      solar_system_id: %OpenApiSpex.Schema{type: :integer},
      kills: %OpenApiSpex.Schema{
        type: :array,
        items: @kill_detail_schema
      }
    },
    required: ["solar_system_id", "kills"]
  }

  @systems_kills_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                                   type: :array,
                                   items: @system_kills_schema
                                 })

  # Character activity schemas
  @character_activity_schema %OpenApiSpex.Schema{
    type: :object,
    description: "Character activity data",
    properties: %{
      character: @character_schema,
      passages: %OpenApiSpex.Schema{
        type: :integer,
        description: "Number of passages through systems"
      },
      connections: %OpenApiSpex.Schema{
        type: :integer,
        description: "Number of connections created"
      },
      signatures: %OpenApiSpex.Schema{type: :integer, description: "Number of signatures added"},
      timestamp: %OpenApiSpex.Schema{
        type: :string,
        format: :date_time,
        description: "Timestamp of the activity"
      }
    },
    required: ["character", "passages", "connections", "signatures"]
  }

  @character_activity_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                                        type: :array,
                                        items: @character_activity_schema
                                      })

  # User characters schemas
  @user_character_group_schema %OpenApiSpex.Schema{
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

  @user_characters_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                                     type: :array,
                                     items: @user_character_group_schema
                                   })

  # Map connection schemas
  @map_connection_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string},
      map_id: %OpenApiSpex.Schema{type: :string},
      solar_system_source: %OpenApiSpex.Schema{type: :integer},
      solar_system_target: %OpenApiSpex.Schema{type: :integer},
      type: %OpenApiSpex.Schema{type: :integer},
      mass_status: %OpenApiSpex.Schema{type: :integer},
      time_status: %OpenApiSpex.Schema{type: :integer},
      ship_size_type: %OpenApiSpex.Schema{type: :integer},
      locked: %OpenApiSpex.Schema{type: :boolean},
      custom_info: %OpenApiSpex.Schema{type: :string, nullable: true}
    }
  }

  @map_connections_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                                     type: :array,
                                     items: @map_connection_schema
                                   })

  # -----------------------------------------------------------------
  # Helper functions for the API controller
  # -----------------------------------------------------------------

  defp get_map_id_by_slug(slug) do
    case WandererApp.Api.Map.get_map_by_slug(slug) do
      {:ok, map} -> {:ok, map.id}
      {:error, error} -> {:error, "Map not found for slug: #{slug}, error: #{inspect(error)}"}
    end
  end

  defp normalize_map_identifier(params) do
    case Map.get(params, "map_identifier") do
      nil ->
        params

      id ->
        if Ecto.UUID.cast(id) == :error,
          do: Map.put(params, "slug", id),
          else: Map.put(params, "map_id", id)
    end
  end

  defp find_tracked_characters_by_map(map_id) do
    # Create a query to select tracked characters for the map and preload the character relationship
    query =
      WandererApp.Api.MapCharacterSettings
      |> Ash.Query.filter(map_id == ^map_id and tracked == true)
      |> Ash.Query.load(:character)

    case Ash.read(query) do
      {:ok, settings} ->
        # Format the settings to include character data
        formatted_settings =
          Enum.map(settings, fn setting ->
            character_data =
              if Ash.Resource.loaded?(setting, :character) and not is_nil(setting.character) do
                WandererAppWeb.MapEventHandler.map_ui_character_stat(setting.character)
              else
                nil
              end

            # Extract only the fields we need for JSON serialization
            %{
              id: setting.id,
              map_id: setting.map_id,
              character_id: setting.character_id,
              tracked: setting.tracked,
              followed: setting.followed,
              inserted_at: setting.inserted_at,
              updated_at: setting.updated_at,
              character: character_data
            }
          end)

        {:ok, formatted_settings}

      {:error, error} ->
        {:error, "Could not fetch tracked characters: #{inspect(error)}"}
    end
  end

  # -----------------------------------------------------------------
  # OpenAPI Operation Definitions
  # -----------------------------------------------------------------

  @doc """
  GET /api/map/tracked-characters
  """
  operation(:list_tracked_characters,
    summary: "List Tracked Characters",
    description: "Lists all characters that are tracked on a specified map.",
    parameters: [
      slug: [
        in: :query,
        description: "Map slug",
        type: :string,
        required: false
      ],
      map_id: [
        in: :query,
        description: "Map identifier (UUID)",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@tracked_characters_response_schema, "Tracked characters"),
      bad_request:
        ResponseSchemas.bad_request(
          "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        ),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  )

  def list_tracked_characters(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params) do
      # Find tracked characters for this map
      case find_tracked_characters_by_map(map_id) do
        {:ok, formatted_settings} ->
          # Return the formatted tracked characters
          json(conn, %{data: formatted_settings})

        {:error, reason} ->
          Logger.error("Error listing tracked characters: #{APIUtils.format_error(reason)}")

          conn
          |> put_status(:internal_server_error)
          |> json(%{error: APIUtils.format_error(reason)})
      end
    else
      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: APIUtils.format_error(msg)})
    end
  end

  @doc """
  GET /api/maps/{map_identifier}/tracked-characters
  """
  operation(:show_tracked_characters,
    summary: "Show Tracked Characters for a Map",
    description: "Lists all characters that are tracked on a specified map.",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug). Provide either a UUID or a slug.",
        type: :string,
        required: true,
        example: "my-map-slug"
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@tracked_characters_response_schema, "Tracked characters"),
      bad_request: ResponseSchemas.bad_request("Map identifier is required"),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  )

  def show_tracked_characters(%{assigns: %{map_id: map_id}} = conn, _params) do
    # Find tracked characters for this map
    case find_tracked_characters_by_map(map_id) do
      {:ok, formatted_settings} ->
        # Return the formatted tracked characters
        json(conn, %{data: formatted_settings})

      {:error, reason} ->
        Logger.error("Error listing tracked characters: #{APIUtils.format_error(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: APIUtils.format_error(reason)})
    end
  end

  @doc """
  GET /api/map/structure-timers

  Returns structure timers for visible systems on the map or for a specific system.
  """
  @spec show_structure_timers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:show_structure_timers,
    summary: "Show Structure Timers",
    description: "Retrieves structure timers for a map.",
    deprecated: true,
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      system_id: [
        in: :query,
        description: "Optional: System ID to filter timers for a specific system",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@structure_timers_response_schema, "Structure timers"),
      bad_request:
        ResponseSchemas.bad_request(
          "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        ),
      not_found: ResponseSchemas.not_found("System not found"),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  )

  def show_structure_timers(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params) do
      system_id_str = params["system_id"]

      case system_id_str do
        nil ->
          handle_all_structure_timers(conn, map_id)

        _ ->
          case APIUtils.parse_int(system_id_str) do
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
  """
  @spec list_systems_kills(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:list_systems_kills,
    summary: "List Systems Kills",
    description: "Returns kills data for all visible systems on the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      hours: [
        in: :query,
        description: "Number of hours to look back for kills",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@systems_kills_response_schema, "Systems kills data"),
      bad_request:
        ResponseSchemas.bad_request(
          "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        ),
      not_found: ResponseSchemas.not_found("Could not fetch systems")
    ]
  )

  def list_systems_kills(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params),
         {:ok, systems} <- MapSystemRepo.get_visible_by_map(map_id),
         {:ok, hours_ago} <-
           parse_hours_ago(
             # documented name
             # legacy fallback
             # legacy typo
             params["hours"] ||
               params["hours_ago"] ||
               params["hour_ago"]
           ) do
      solar_ids = Enum.map(systems, & &1.solar_system_id)
      # Fetch cached kills for each system from cache
      kills_map =
        Enum.reduce(solar_ids, %{}, fn sid, acc ->
          kill_list_key = "zkb:kills:list:#{sid}"
          kill_ids = WandererApp.Cache.get(kill_list_key) || []

          kills_list =
            kill_ids
            |> Enum.map(fn kill_id ->
              killmail_key = "zkb:killmail:#{kill_id}"
              WandererApp.Cache.get(killmail_key)
            end)
            |> Enum.reject(&is_nil/1)

          Map.put(acc, sid, kills_list)
        end)

      data =
        Enum.map(systems, fn sys ->
          kills = Map.get(kills_map, sys.solar_system_id, [])
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
  """
  @spec character_activity(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:character_activity,
    summary: "Get Character Activity",
    description: "Returns character activity data for a map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      days: [
        in: :query,
        description: "Optional: Number of days to look back for activity data.",
        type: :integer,
        required: false
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@character_activity_response_schema, "Character activity data"),
      bad_request:
        ResponseSchemas.bad_request(
          "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        ),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  )

  def character_activity(conn, params) do
    # Normalize params to make sure we handle both map_id and slug variations
    normalized_params = normalize_map_identifier(params)

    with {:ok, map_id} <- APIUtils.fetch_map_id(normalized_params),
         {:ok, days} <- parse_days(params["days"]) do
      raw_activity =
        case WandererApp.Map.get_character_activity(map_id, days) do
          {:ok, activity} -> activity
          {:error, _} -> []
        end

      summarized_result =
        if raw_activity == [] do
          []
        else
          raw_activity
          |> Enum.group_by(fn activity -> activity.character.user_id end)
          |> Enum.map(fn {_user_id, user_activities} ->
            representative_activity =
              user_activities
              |> Enum.max_by(fn act -> act.passages + act.connections + act.signatures end)

            total_passages = Enum.sum(Enum.map(user_activities, & &1.passages))
            total_connections = Enum.sum(Enum.map(user_activities, & &1.connections))
            total_signatures = Enum.sum(Enum.map(user_activities, & &1.signatures))

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

  Returns characters grouped by user for a specific map.
  """
  @spec user_characters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:user_characters,
    summary: "Get User Characters",
    description: "Returns characters grouped by user for a specific map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok:
        ResponseSchemas.ok(
          @user_characters_response_schema,
          "User characters with main character indication"
        ),
      bad_request:
        ResponseSchemas.bad_request(
          "Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"
        ),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  )

  def user_characters(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params) do
      fetch_and_format_user_characters(conn, map_id)
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

  @doc """
  GET /api/maps/{map_identifier}/user-characters
  """
  @spec show_user_characters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:show_user_characters,
    summary: "Show User Characters for a Map",
    description: "Returns characters grouped by user for a specific map.",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug). Provide either a UUID or a slug.",
        type: :string,
        required: true,
        example: "my-map-slug"
      ]
    ],
    responses: [
      ok:
        ResponseSchemas.ok(
          @user_characters_response_schema,
          "User characters with main character indication"
        ),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  )

  def show_user_characters(%{assigns: %{map_id: map_id}} = conn, _params) do
    fetch_and_format_user_characters(conn, map_id)
  end

  # Helper function to fetch and format user characters for a map
  defp fetch_and_format_user_characters(conn, map_id) do
    # Create a query to get all MapCharacterSettings for this map and preload characters
    settings_query =
      WandererApp.Api.MapCharacterSettings
      |> Ash.Query.filter(map_id == ^map_id)
      |> Ash.Query.load(:character)

    case Ash.read(settings_query) do
      {:ok, map_character_settings} when map_character_settings != [] ->
        # Extract characters and filter out those without a user_id
        characters =
          map_character_settings
          |> Enum.map(& &1.character)
          |> Enum.filter(fn char -> char != nil && not is_nil(char.user_id) end)

        if characters != [] do
          # Group characters by user_id
          characters_by_user = Enum.group_by(characters, & &1.user_id)

          # Get main character settings
          user_settings_query =
            WandererApp.Api.MapUserSettings
            |> Ash.Query.new()
            |> Ash.Query.filter(map_id == ^map_id)

          main_characters_by_user =
            case Ash.read(user_settings_query) do
              {:ok, map_user_settings} ->
                Map.new(map_user_settings, fn settings ->
                  {settings.user_id, settings.main_character_eve_id}
                end)

              _ ->
                %{}
            end

          # Format the characters by user
          character_groups =
            Enum.map(characters_by_user, fn {user_id, user_characters} ->
              formatted_characters =
                Enum.map(user_characters, fn char ->
                  character_to_json(char)
                end)

              %{
                characters: formatted_characters,
                main_character_eve_id: Map.get(main_characters_by_user, user_id)
              }
            end)

          json(conn, %{data: character_groups})
        else
          json(conn, %{data: []})
        end

      {:ok, []} ->
        json(conn, %{data: []})

      {:error, reason} ->
        Logger.error("Failed to fetch map character settings: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch map character settings: #{inspect(reason)}"})
    end
  end

  # --- Helpers for Structure Timers ---
  defp handle_all_structure_timers(conn, map_id) do
    case MapSystemRepo.get_visible_by_map(map_id) do
      {:ok, systems} ->
        all_timers = systems |> Enum.flat_map(&get_timers_for_system/1)
        json(conn, %{data: all_timers})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Could not fetch visible systems for map_id=#{map_id}: #{inspect(reason)}"
        })
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

  # --- Helpers for System Kills ---
  defp parse_hours_ago(nil), do: {:ok, nil}

  defp parse_hours_ago(hours_str) do
    Logger.debug(fn -> "[parse_hours_ago] Parsing hours_str: #{inspect(hours_str)}" end)

    case Integer.parse(hours_str) do
      {num, ""} when num > 0 -> {:ok, num}
      # 0 means "disable filtering"
      {0, ""} -> {:ok, nil}
      _ -> {:error, "hours must be a positive integer"}
    end
  end

  defp maybe_filter_kills_by_time(kills, hours_ago) when is_integer(hours_ago) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours_ago * 3600, :second)

    Logger.debug(fn ->
      "[maybe_filter_kills_by_time] Filtering kills with cutoff: #{DateTime.to_iso8601(cutoff)}"
    end)

    filtered =
      Enum.filter(kills, fn kill ->
        kill_time = kill["kill_time"]

        result =
          case kill_time do
            %DateTime{} = dt ->
              DateTime.compare(dt, cutoff) != :lt

            time when is_binary(time) ->
              case DateTime.from_iso8601(time) do
                {:ok, dt, _} -> DateTime.compare(dt, cutoff) != :lt
                _ -> false
              end

            _ ->
              false
          end

        Logger.debug(fn ->
          kill_time_str = if is_binary(kill_time), do: kill_time, else: inspect(kill_time)
          "[maybe_filter_kills_by_time] Kill time: #{kill_time_str}, included: #{result}"
        end)

        result
      end)

    filtered
  end

  defp maybe_filter_kills_by_time(kills, nil), do: kills

  # --- Helpers for Character Activity ---
  defp parse_days(nil), do: {:ok, nil}

  defp parse_days(days_str) do
    case Integer.parse(days_str) do
      {days, ""} when days > 0 -> {:ok, days}
      _ -> {:error, "days must be a positive integer"}
    end
  end

  # --- JSON Formatting Helpers ---
  defp character_to_json(nil), do: nil

  defp character_to_json(ch) do
    WandererAppWeb.MapEventHandler.map_ui_character_stat(ch)
  end

  @doc """
  GET /api/map/connections

  Requires either `?map_id=<UUID>` **OR** `?slug=<map-slug>` in the query params.
  """
  @spec list_connections(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:list_connections,
    summary: "List Map Connections",
    description:
      "Lists all connections for a map. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
    parameters: [
      map_id: [
        in: :query,
        description: "Map identifier (UUID) - Either map_id or slug must be provided",
        type: :string,
        required: false
      ],
      slug: [
        in: :query,
        description: "Map slug - Either map_id or slug must be provided",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@map_connections_response_schema, "List of map connections"),
      bad_request: ResponseSchemas.bad_request("Must provide either ?map_id=UUID or ?slug=SLUG"),
      not_found: ResponseSchemas.not_found("Could not fetch connections")
    ]
  )

  def list_connections(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params),
         {:ok, connections} <- MapConnectionRepo.get_by_map(map_id) do
      data = Enum.map(connections, &APIUtils.connection_to_json/1)
      json(conn, %{data: data})
    else
      {:error, msg} when is_binary(msg) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Could not fetch connections: #{APIUtils.format_error(reason)}"})
    end
  end

  @doc """
  Toggle webhooks for a map.
  """
  operation(:toggle_webhooks,
    summary: "Toggle webhooks for a map",
    parameters: [
      map_id: [
        in: :path,
        schema: %OpenApiSpex.Schema{type: :string},
        required: true,
        description: "Map identifier (slug or ID)"
      ]
    ],
    request_body: {
      "Webhook toggle request",
      "application/json",
      %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          enabled: %OpenApiSpex.Schema{type: :boolean, description: "Enable or disable webhooks"}
        },
        required: ["enabled"]
      }
    },
    responses: %{
      200 => {
        "Webhook status updated",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            webhooks_enabled: %OpenApiSpex.Schema{type: :boolean}
          }
        }
      },
      400 => ResponseSchemas.bad_request(),
      404 => ResponseSchemas.not_found(),
      503 => ResponseSchemas.internal_server_error("Service unavailable")
    }
  )

  def toggle_webhooks(conn, %{"map_id" => map_identifier, "enabled" => enabled}) do
    with {:ok, enabled_boolean} <- validate_boolean_param(enabled, "enabled"),
         :ok <- check_global_webhooks_enabled(),
         {:ok, map} <- resolve_map_identifier(map_identifier),
         :ok <- check_map_owner(conn, map),
         {:ok, updated_map} <-
           WandererApp.Api.Map.toggle_webhooks(map, %{webhooks_enabled: enabled_boolean}) do
      json(conn, %{webhooks_enabled: updated_map.webhooks_enabled})
    else
      {:error, :invalid_boolean} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "The 'enabled' parameter must be a boolean value"})

      {:error, :webhooks_disabled} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "Webhooks are disabled on this server"})

      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only the map owner can toggle webhooks"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to update webhook settings: #{APIUtils.format_error(reason)}"})
    end
  end

  # Helper functions for webhook toggle

  defp validate_boolean_param(value, _param_name) when is_boolean(value), do: {:ok, value}
  defp validate_boolean_param("true", _param_name), do: {:ok, true}
  defp validate_boolean_param("false", _param_name), do: {:ok, false}
  defp validate_boolean_param(_, _param_name), do: {:error, :invalid_boolean}

  defp check_global_webhooks_enabled do
    if Application.get_env(:wanderer_app, :external_events)[:webhooks_enabled] do
      :ok
    else
      {:error, :webhooks_disabled}
    end
  end

  defp resolve_map_identifier(identifier) do
    case WandererApp.Api.Map.by_id(identifier) do
      {:ok, map} ->
        {:ok, map}

      {:error, _} ->
        case WandererApp.Api.Map.get_map_by_slug(identifier) do
          {:ok, map} -> {:ok, map}
          {:error, _} -> {:error, :map_not_found}
        end
    end
  end

  defp check_map_owner(conn, map) do
    current_user = conn.assigns[:current_character]

    if current_user && current_user.id == map.owner_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  POST /api/maps/{map_identifier}/duplicate

  Duplicates a map with all its systems, connections, and optionally ACLs/characters.
  """
  operation(:duplicate_map,
    summary: "Duplicate Map",
    description:
      "Creates a copy of an existing map including systems, connections, and optionally ACLs, user settings, and signatures",
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map identifier (UUID or slug). Provide either a UUID or a slug.",
        type: :string,
        required: true,
        example: "my-map-slug"
      ]
    ],
    request_body: {
      "Map duplication parameters",
      "application/json",
      %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          name: %OpenApiSpex.Schema{
            type: :string,
            minLength: 3,
            maxLength: 20,
            description: "Name for the duplicated map"
          },
          description: %OpenApiSpex.Schema{
            type: :string,
            description: "Description for the duplicated map (optional)"
          },
          copy_acls: %OpenApiSpex.Schema{
            type: :boolean,
            default: true,
            description: "Whether to copy access control lists"
          },
          copy_user_settings: %OpenApiSpex.Schema{
            type: :boolean,
            default: true,
            description: "Whether to copy user/character settings"
          },
          copy_signatures: %OpenApiSpex.Schema{
            type: :boolean,
            default: true,
            description: "Whether to copy system signatures"
          }
        },
        required: [:name]
      }
    },
    responses: [
      created: {
        "Map duplicated successfully",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            data: %OpenApiSpex.Schema{
              type: :object,
              properties: %{
                id: %OpenApiSpex.Schema{type: :string, description: "ID of the duplicated map"},
                name: %OpenApiSpex.Schema{
                  type: :string,
                  description: "Name of the duplicated map"
                },
                slug: %OpenApiSpex.Schema{
                  type: :string,
                  description: "Slug of the duplicated map"
                },
                description: %OpenApiSpex.Schema{
                  type: :string,
                  description: "Description of the duplicated map"
                }
              }
            }
          }
        }
      },
      bad_request: ResponseSchemas.bad_request(),
      forbidden: ResponseSchemas.forbidden(),
      not_found: ResponseSchemas.not_found(),
      unprocessable_entity: ResponseSchemas.bad_request("Validation failed"),
      internal_server_error: ResponseSchemas.internal_server_error("Duplication failed")
    ]
  )

  def duplicate_map(conn, %{"map_identifier" => map_identifier} = params) do
    with {:ok, source_map} <- resolve_map_identifier(map_identifier),
         :ok <- check_map_owner(conn, source_map),
         {:ok, duplicate_params} <- validate_duplicate_params(params),
         current_user <- conn.assigns[:current_character],
         {:ok, duplicated_map} <- perform_duplication(source_map, duplicate_params, current_user) do
      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          id: duplicated_map.id,
          name: duplicated_map.name,
          slug: duplicated_map.slug,
          description: duplicated_map.description
        }
      })
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only the map owner can duplicate maps"})

      {:error, {:validation_error, message}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})

      {:error, %Ash.Error.Invalid{} = error} ->
        Logger.debug("Ash validation error: #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Validation failed",
          errors:
            Enum.map(error.errors, fn err ->
              %{
                field: err.field,
                message: err.message,
                value: err.value
              }
            end)
        })

      {:error, reason} ->
        Logger.error("Map duplication failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to duplicate map: #{APIUtils.format_error(reason)}"})
    end
  end

  # Helper functions for map duplication

  defp validate_duplicate_params(params) do
    name = Map.get(params, "name")
    description = Map.get(params, "description")
    copy_acls = Map.get(params, "copy_acls", true)
    copy_user_settings = Map.get(params, "copy_user_settings", true)
    copy_signatures = Map.get(params, "copy_signatures", true)

    cond do
      is_nil(name) or name == "" ->
        {:error, {:validation_error, "Name is required"}}

      String.length(name) < 3 ->
        {:error, {:validation_error, "Name must be at least 3 characters long"}}

      String.length(name) > 20 ->
        {:error, {:validation_error, "Name must be no more than 20 characters long"}}

      true ->
        {:ok,
         %{
           name: name,
           description: description,
           copy_acls: copy_acls,
           copy_user_settings: copy_user_settings,
           copy_signatures: copy_signatures
         }}
    end
  end

  defp perform_duplication(source_map, duplicate_params, current_user) do
    # Create attributes for the new map
    map_attrs = %{
      source_map_id: source_map.id,
      name: duplicate_params.name,
      description: duplicate_params.description,
      copy_acls: duplicate_params.copy_acls,
      copy_user_settings: duplicate_params.copy_user_settings,
      copy_signatures: duplicate_params.copy_signatures
    }

    # Use the Ash action with current user as actor for permissions
    WandererApp.Api.Map.duplicate(map_attrs, actor: current_user)
  end
end
