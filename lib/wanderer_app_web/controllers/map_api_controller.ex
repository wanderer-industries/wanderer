defmodule WandererAppWeb.MapAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ash.Query, only: [filter: 2]
  require Logger

  alias WandererApp.Api.Character
  alias WandererApp.MapSystemRepo
  alias WandererApp.MapCharacterSettingsRepo
  alias WandererApp.MapConnectionRepo
  alias WandererApp.Zkb.KillsProvider.KillsCache
  alias WandererAppWeb.Helpers.APIUtils
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}

  # -----------------------------------------------------------------
  # Schema Definitions
  # -----------------------------------------------------------------

  # Basic entity schemas
  @character_schema ApiSchemas.character_schema()
  @solar_system_schema ApiSchemas.solar_system_basic_schema()

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

  @tracked_characters_response_schema ApiSchemas.data_wrapper(
    %OpenApiSpex.Schema{
      type: :array,
      items: @character_tracking_schema
    }
  )

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

  @structure_timers_response_schema ApiSchemas.data_wrapper(
    %OpenApiSpex.Schema{
      type: :array,
      items: @structure_timer_schema
    }
  )

  # System kills schemas
  @kill_detail_schema %OpenApiSpex.Schema{
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
        items: @kill_detail_schema
      }
    },
    required: ["solar_system_id", "kills"]
  }

  @systems_kills_response_schema ApiSchemas.data_wrapper(
    %OpenApiSpex.Schema{
      type: :array,
      items: @system_kills_schema
    }
  )

  # Character activity schemas
  @character_activity_schema %OpenApiSpex.Schema{
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

  @character_activity_response_schema ApiSchemas.data_wrapper(
    %OpenApiSpex.Schema{
      type: :array,
      items: @character_activity_schema
    }
  )

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

  @user_characters_response_schema ApiSchemas.data_wrapper(
    %OpenApiSpex.Schema{
      type: :array,
      items: @user_character_group_schema
    }
  )

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

  @map_connections_response_schema ApiSchemas.data_wrapper(
    %OpenApiSpex.Schema{
      type: :array,
      items: @map_connection_schema
    }
  )

  # -----------------------------------------------------------------
  # Helper functions for the API controller
  # -----------------------------------------------------------------

  defp get_map_id_by_slug(slug) do
    case WandererApp.Api.Map.get_map_by_slug(slug) do
      {:ok, map} -> {:ok, map.id}
      {:error, error} -> {:error, "Map not found for slug: #{slug}, error: #{inspect(error)}"}
    end
  end

  @doc """
  Debug route for helping diagnose routing issues
  """
  def route_debug(conn, _params) do
    require Logger

    map_identifier = conn.params["map_identifier"]
    Logger.warn("Debug route accessed - map_identifier: #{inspect(map_identifier)}")

    # Gather parameters
    path_params = conn.path_params
    all_params = conn.params

    # Log and return all relevant information
    debug_info = %{
      status: "ok",
      path_params: path_params,
      all_params: all_params,
      conn_data: %{
        method: conn.method,
        request_path: conn.request_path,
        host: conn.host
      }
    }

    Logger.warn("Debug info: #{inspect(debug_info)}")
    json(conn, debug_info)
  end

  defp find_tracked_characters_by_map(map_id) do
    case WandererApp.Api.MapCharacterSettings.tracked_by_map_all(%{map_id: map_id}) do
      {:ok, settings} -> {:ok, settings}
      {:error, error} -> {:error, "Could not fetch tracked characters: #{inspect(error)}"}
    end
  end

  # -----------------------------------------------------------------
  # OpenAPI Operation Definitions
  # -----------------------------------------------------------------

  @doc """
  GET /api/map/tracked-characters
  """
  operation :list_tracked_characters,
    summary: "List Tracked Characters",
    description: "Lists all characters that are tracked on a specified map.",
    parameters: [
      slug: [
        in: :query,
        description: "Map slug",
        type: :string,
        example: "my-map",
        required: true
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@tracked_characters_response_schema, "Tracked characters"),
      bad_request: ResponseSchemas.bad_request(),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  def list_tracked_characters(conn, params) do
    with {:ok, slug} <- APIUtils.require_param(params, "slug"),
         {:ok, map_id} <- get_map_id_by_slug(slug) do
      # Find tracked characters for this map
      case find_tracked_characters_by_map(map_id) do
        {:ok, settings} ->
          # Return the list of tracked characters
          json(conn, %{data: settings})

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
  GET /api/map/structure_timers

  Returns structure timers for visible systems on the map or for a specific system.
  """
  @spec show_structure_timers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation :show_structure_timers,
    summary: "Show Structure Timers",
    description: "Retrieves structure timers for a map.",
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
        description: "System ID",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: ResponseSchemas.ok(@structure_timers_response_schema, "Structure timers"),
      bad_request: ResponseSchemas.bad_request("Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"),
      not_found: ResponseSchemas.not_found("System not found"),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
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
  operation :list_systems_kills,
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
      bad_request: ResponseSchemas.bad_request("Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"),
      not_found: ResponseSchemas.not_found("Could not fetch systems")
    ]
  def list_systems_kills(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params),
         {:ok, systems} <- MapSystemRepo.get_visible_by_map(map_id) do

      hours_ago =
        parse_hours_ago(
          params["hours"]      # documented name
          || params["hours_ago"] # legacy fallback
          || params["hour_ago"]  # legacy typo
        )

      solar_ids = Enum.map(systems, & &1.solar_system_id)
      kills_map = KillsCache.fetch_cached_kills_for_systems(solar_ids)

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
  operation :character_activity,
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
      bad_request: ResponseSchemas.bad_request("Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  def character_activity(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params),
         {:ok, days} <- parse_days(params["days"]) do
      raw_activity = WandererApp.Map.get_character_activity(map_id, days)

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
  operation :user_characters,
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
      ok: ResponseSchemas.ok(@user_characters_response_schema, "User characters with main character indication"),
      bad_request: ResponseSchemas.bad_request("Must provide either ?map_id=UUID or ?slug=SLUG as a query parameter"),
      internal_server_error: ResponseSchemas.internal_server_error()
    ]
  def user_characters(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params) do
      case MapCharacterSettingsRepo.get_all_by_map(map_id) do
        {:ok, map_character_settings} when map_character_settings != [] ->
          character_ids = Enum.map(map_character_settings, &(&1.character_id))

          case WandererApp.Api.read(Character |> filter(id in ^character_ids)) do
            {:ok, characters} when characters != [] ->
              characters_by_user =
                characters
                |> Enum.filter(fn char -> not is_nil(char.user_id) end)
                |> Enum.group_by(&(&1.user_id))

              settings_query =
                WandererApp.Api.MapUserSettings
                |> Ash.Query.new()
                |> Ash.Query.filter(map_id == ^map_id)

              main_characters_by_user =
                case WandererApp.Api.read(settings_query) do
                  {:ok, map_user_settings} ->
                    Map.new(map_user_settings, fn settings -> {settings.user_id, settings.main_character_eve_id} end)
                  _ -> %{}
                end

              character_groups =
                Enum.map(characters_by_user, fn {user_id, user_characters} ->
                  %{
                    characters: Enum.map(user_characters, &character_to_json/1),
                    main_character_eve_id: Map.get(main_characters_by_user, user_id)
                  }
                end)

              json(conn, %{data: character_groups})

            {:ok, []} -> json(conn, %{data: []})
            {:error, reason} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "Failed to fetch characters: #{inspect(reason)}"})
          end
        {:ok, []} -> json(conn, %{data: []})
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

  @doc """
  GET /api/map/connections

  Requires either `?map_id=<UUID>` **OR** `?slug=<map-slug>` in the query params.
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
      ok: ResponseSchemas.ok(@map_connections_response_schema, "List of map connections"),
      bad_request: ResponseSchemas.bad_request("Must provide either ?map_id=UUID or ?slug=SLUG"),
      not_found: ResponseSchemas.not_found("Could not fetch connections")
    ]
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

  # --- Helpers for Structure Timers ---
  defp handle_all_structure_timers(conn, map_id) do
    case MapSystemRepo.get_visible_by_map(map_id) do
      {:ok, systems} ->
        all_timers = systems |> Enum.flat_map(&get_timers_for_system/1)
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

  # --- Helpers for System Kills ---
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
        %DateTime{} = dt -> DateTime.compare(dt, cutoff) != :lt
        time when is_binary(time) ->
          case DateTime.from_iso8601(time) do
            {:ok, dt, _} -> DateTime.compare(dt, cutoff) != :lt
            _ -> false
          end
        _ -> false
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
      _ -> {:ok, nil}
    end
  end

  # --- JSON Formatting Helpers ---
  defp character_to_json(ch) do
    WandererAppWeb.MapEventHandler.map_ui_character_stat(ch)
  end
end
