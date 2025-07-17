defmodule WandererAppWeb.MapEventsAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias WandererApp.ExternalEvents.MapEventRelay
  alias WandererAppWeb.Schemas.{ApiSchemas, ResponseSchemas}

  # -----------------------------------------------------------------
  # Schema Definitions
  # -----------------------------------------------------------------

  @event_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string, description: "ULID event identifier"},
      map_id: %OpenApiSpex.Schema{type: :string, description: "Map UUID"},
      type: %OpenApiSpex.Schema{
        type: :string,
        enum: [
          "add_system",
          "deleted_system",
          "system_metadata_changed",
          "system_renamed",
          "signature_added",
          "signature_removed",
          "signatures_updated",
          "connection_added",
          "connection_removed",
          "connection_updated",
          "character_added",
          "character_removed",
          "character_updated",
          "map_kill"
        ],
        description: "Event type"
      },
      payload: %OpenApiSpex.Schema{
        type: :object,
        description: "Event-specific payload data",
        additionalProperties: true
      },
      ts: %OpenApiSpex.Schema{
        type: :string,
        format: :date_time,
        description: "Event timestamp (ISO8601)"
      }
    },
    required: [:id, :map_id, :type, :payload, :ts],
    example: %{
      id: "01J7KZXYZ123456789ABCDEF",
      map_id: "550e8400-e29b-41d4-a716-446655440000",
      type: "add_system",
      payload: %{
        solar_system_id: 30_000_142,
        solar_system_name: "Jita"
      },
      ts: "2025-01-20T12:34:56Z"
    }
  }

  @events_response_schema ApiSchemas.data_wrapper(%OpenApiSpex.Schema{
                            type: :array,
                            items: @event_schema
                          })

  @events_list_params %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      since: %OpenApiSpex.Schema{
        type: :string,
        format: :date_time,
        description: "Return events after this timestamp (ISO8601)"
      },
      limit: %OpenApiSpex.Schema{
        type: :integer,
        minimum: 1,
        maximum: 100,
        default: 100,
        description: "Maximum number of events to return"
      }
    }
  }

  # -----------------------------------------------------------------
  # OpenApiSpex Operations
  # -----------------------------------------------------------------

  operation(:list_events,
    summary: "List recent events for a map",
    description: """
    Retrieves recent events for the specified map. This endpoint provides a way to catch up on missed events
    after a WebSocket disconnection. Events are retained for approximately 10 minutes.
    """,
    tags: ["Map Events"],
    parameters: [
      map_identifier: [
        in: :path,
        description: "Map UUID or slug",
        type: :string,
        required: true
      ],
      since: [
        in: :query,
        description: "Return events after this timestamp (ISO8601)",
        type: :string,
        required: false,
        example: "2025-01-20T12:00:00Z"
      ],
      limit: [
        in: :query,
        description: "Maximum number of events to return (1-100)",
        type: :integer,
        required: false
      ]
    ],
    responses: %{
      200 => {"Success", "application/json", @events_response_schema},
      400 => ResponseSchemas.bad_request("Invalid parameters"),
      401 => ResponseSchemas.bad_request("Unauthorized"),
      404 => ResponseSchemas.not_found("Map not found"),
      500 => ResponseSchemas.internal_server_error("Internal server error")
    }
  )

  # -----------------------------------------------------------------
  # Controller Actions
  # -----------------------------------------------------------------

  def list_events(conn, %{"map_identifier" => map_identifier} = params) do
    with {:ok, map} <- get_map(conn, map_identifier),
         {:ok, since} <- parse_since_param(params),
         {:ok, limit} <- parse_limit_param(params) do
      # If no 'since' parameter provided, default to 10 minutes ago
      since_datetime = since || DateTime.add(DateTime.utc_now(), -10, :minute)

      # Check if MapEventRelay is running before calling
      events =
        if Process.whereis(MapEventRelay) do
          try do
            MapEventRelay.get_events_since(map.id, since_datetime, limit)
          catch
            :exit, {:noproc, _} ->
              Logger.error("MapEventRelay process not available")
              []

            :exit, reason ->
              Logger.error("Failed to get events from MapEventRelay: #{inspect(reason)}")
              []
          end
        else
          Logger.error("MapEventRelay is not running")
          []
        end

      # Events are already in JSON format from ETS

      json(conn, %{data: events})
    else
      {:error, :map_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Map not found"})

      {:error, :invalid_since} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid 'since' parameter. Must be ISO8601 datetime."})

      {:error, :invalid_limit} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid 'limit' parameter. Must be between 1 and 100."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end

  # -----------------------------------------------------------------
  # Private Functions
  # -----------------------------------------------------------------

  defp get_map(conn, map_identifier) do
    # The map should already be loaded by the CheckMapApiKey plug
    case conn.assigns[:map] do
      nil -> {:error, :map_not_found}
      map -> {:ok, map}
    end
  end

  defp parse_since_param(%{"since" => since_str}) when is_binary(since_str) do
    case DateTime.from_iso8601(since_str) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _} -> {:error, :invalid_since}
    end
  end

  defp parse_since_param(_), do: {:ok, nil}

  defp parse_limit_param(%{"limit" => limit_str}) when is_binary(limit_str) do
    case Integer.parse(limit_str) do
      {limit, ""} when limit >= 1 and limit <= 100 -> {:ok, limit}
      _ -> {:error, :invalid_limit}
    end
  end

  defp parse_limit_param(%{"limit" => limit}) when is_integer(limit) do
    if limit >= 1 and limit <= 100 do
      {:ok, limit}
    else
      {:error, :invalid_limit}
    end
  end

  defp parse_limit_param(_), do: {:ok, 100}
end
