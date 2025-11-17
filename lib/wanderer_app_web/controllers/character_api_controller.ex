defmodule WandererAppWeb.CharactersAPIController do
  @moduledoc """
  Legacy character listing endpoint.

  ⚠️  DEPRECATED - SECURITY NOTICE ⚠️

  This endpoint lists ALL characters in the database and is deprecated
  due to security and privacy concerns.

  **Why Deprecated:**
  - Exposes all user character data globally
  - Privacy risk: Shows corporation, alliance, location data
  - No use case justifies listing all characters
  - Character data should be scoped to specific maps

  **Alternatives:**
  Use the Access Lists API to get character information for specific maps:

  - GET `/api/v1/access_lists?filter[map_id]=<map-id>&include=members`
  - GET `/api/v1/access_list_members/:id`

  **Timeline:**
  - **Now:** Deprecated with warnings
  - **3 months:** Will require explicit opt-in flag
  - **6 months:** Will be removed entirely

  **Migration Guide:** See API documentation at `/docs/api-migration-guide`

  This endpoint will be removed in a future version.
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias WandererApp.Api.Character
  require Logger

  @characters_index_response_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :array,
        items: %OpenApiSpex.Schema{
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
      },
      meta: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          deprecated: %OpenApiSpex.Schema{type: :boolean},
          deprecation_reason: %OpenApiSpex.Schema{type: :string},
          alternative: %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              endpoint: %OpenApiSpex.Schema{type: :string},
              description: %OpenApiSpex.Schema{type: :string},
              example: %OpenApiSpex.Schema{type: :string}
            }
          },
          removal_date: %OpenApiSpex.Schema{type: :string, format: :date},
          migration_guide: %OpenApiSpex.Schema{type: :string}
        }
      }
    },
    required: ["data", "meta"]
  }

  @doc """
  GET /api/characters
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:index,
    summary: "List Characters (DEPRECATED)",
    description: """
    ⚠️ DEPRECATED - DO NOT USE

    Lists ALL characters in the database. This endpoint is deprecated due to security
    and privacy concerns.

    **Deprecation Reason:** Exposes all user character data globally without proper scoping.

    **Use Instead:** Access Lists API
    - GET /api/v1/access_lists?filter[map_id]=<map-id>&include=members

    **Removal Date:** 2025-05-13

    **Migration Guide:** See /docs/api-migration-guide
    """,
    deprecated: true,
    responses: [
      ok: {
        "List of characters (DEPRECATED)",
        "application/json",
        @characters_index_response_schema
      }
    ]
  )

  def index(conn, _params) do
    # Log deprecation usage for monitoring
    ip = if conn.remote_ip, do: conn.remote_ip |> :inet.ntoa() |> to_string(), else: "unknown"
    user_agent = List.first(get_req_header(conn, "user-agent")) || "unknown"

    Logger.warning("Deprecated endpoint /api/characters accessed",
      ip: ip,
      user_agent: user_agent
    )

    # Add deprecation headers
    conn =
      conn
      |> put_resp_header("x-api-deprecated", "true")
      |> put_resp_header("x-api-deprecated-reason", "security-privacy-concerns")
      |> put_resp_header(
        "x-api-deprecated-use",
        "/api/v1/access_lists?filter[map_id]=<map-id>&include=members"
      )
      |> put_resp_header("x-api-deprecated-removal-date", "2025-05-13")
      |> put_resp_header(
        "warning",
        "299 - \"This endpoint is deprecated due to security concerns and will be removed. Use Access Lists API instead. See /docs/api-migration-guide\""
      )
      |> put_resp_header(
        "link",
        "</api/v1/access_lists>; rel=\"alternate\"; title=\"Access Lists API (recommended)\""
      )

    case Ash.read(Character) do
      {:ok, characters} ->
        result =
          characters
          |> Enum.map(&WandererAppWeb.MapEventHandler.map_ui_character_stat/1)

        # Also add deprecation info in response body
        conn
        |> json(%{
          data: result,
          meta: %{
            deprecated: true,
            deprecation_reason:
              "Security and privacy concerns - this endpoint exposes all character data globally",
            alternative: %{
              endpoint: "/api/v1/access_lists",
              description: "Use Access Lists API to get characters for specific maps",
              example: "/api/v1/access_lists?filter[map_id]=<map-id>&include=members"
            },
            removal_date: "2025-05-13",
            migration_guide: "/docs/api-migration-guide"
          }
        })

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(error)})
    end
  end
end
