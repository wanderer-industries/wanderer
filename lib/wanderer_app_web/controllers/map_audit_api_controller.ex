defmodule WandererAppWeb.MapAuditAPIController do
  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias WandererApp.Api

  alias WandererAppWeb.Helpers.APIUtils

  # -----------------------------------------------------------------
  # Inline Schemas
  # -----------------------------------------------------------------

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

  @map_audit_event_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      entity_type: %OpenApiSpex.Schema{type: :string},
      event_name: %OpenApiSpex.Schema{type: :string},
      event_data: %OpenApiSpex.Schema{type: :string},
      character: @character_schema,
      inserted_at: %OpenApiSpex.Schema{type: :string, format: :date_time}
    },
    required: ["entity_type", "event_name", "event_data", "inserted_at"]
  }

  @map_audit_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: @map_audit_event_schema
      }
    },
    required: ["data"]
  }

  # -----------------------------------------------------------------
  # MAP endpoints
  # -----------------------------------------------------------------

  @doc """
  GET /api/map/audit

  Requires either `?map_id=<UUID>` **OR** `?slug=<map-slug>` in the query params.

  Examples:
      GET /api/map/audit?map_id=466e922b-e758-485e-9b86-afae06b88363&period=1H
      GET /api/map/audit?slug=my-unique-wormhole-map&period=1H
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:index,
    summary: "List Map Audit events",
    description:
      "Lists all audit events for a map. Requires either 'map_id' or 'slug' as a query parameter to identify the map.",
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
      period: [
        in: :query,
        description: "Activity period (1H, 1D, 1W, 1M, 2M, 3M)",
        type: :string,
        required: true,
        example: "1D"
      ]
    ],
    responses: [
      ok: {
        "List of map audit events",
        "application/json",
        @map_audit_response_schema
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
             "error" => "Must provide either ?map_id=UUID or ?slug=SLUG"
           }
         }}
    ]
  )

  def index(conn, params) do
    with {:ok, map_id} <- APIUtils.fetch_map_id(params),
         {:ok, period} <- APIUtils.require_param(params, "period"),
         query <- WandererApp.Map.Audit.get_map_activity_query(map_id, period, "all"),
         {:ok, data} <-
           Ash.read(query) do
      data = Enum.map(data, &map_audit_event_to_json/1)
      json(conn, %{data: data})
    else
      {:error, msg} when is_binary(msg) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Request failed: #{inspect(reason)}"})
    end
  end

  defp map_audit_event_to_json(
         %{event_type: event_type, event_data: event_data, character: character} = event
       ) do
    # Start with the basic system data
    result =
      Map.take(event, [
        :entity_type,
        :inserted_at
      ])

    result
    |> Map.put(:character, WandererAppWeb.MapEventHandler.map_ui_character_stat(character))
    |> Map.put(:event_name, WandererAppWeb.UserActivity.get_event_name(event_type))
    |> Map.put(
      :event_data,
      WandererAppWeb.UserActivity.get_event_data(
        event_type,
        Jason.decode!(event_data) |> Map.drop(["character_id"])
      )
    )
  end
end
