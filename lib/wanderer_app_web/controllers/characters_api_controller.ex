defmodule WandererAppWeb.CharactersAPIController do
  @moduledoc """
  Exposes an endpoint for listing characters in the database with pagination
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs
  use WandererAppWeb.JsonAction
  use WandererAppWeb.Controllers.Behaviours.Paginated

  alias WandererApp.Api.Character
  alias OpenApiSpex.Schema

  @character_list_item_schema %Schema{
    type: :object,
    properties: %{
      eve_id: %Schema{type: :string},
      name: %Schema{type: :string},
      corporation_id: %Schema{type: :string},
      corporation_ticker: %Schema{type: :string},
      alliance_id: %Schema{type: :string},
      alliance_ticker: %Schema{type: :string}
    },
    required: ["eve_id", "name"]
  }

  @doc """
  GET /api/characters
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:index,
    summary: "List Characters",
    description: "Lists characters in the database with pagination support.",
    parameters: pagination_parameters(),
    responses: [
      ok: {
        "Paginated list of characters",
        "application/json",
        pagination_response_schema(%Schema{
          type: :array,
          items: @character_list_item_schema
        })
      },
      bad_request: {
        "Invalid pagination parameters",
        "application/json",
        WandererAppWeb.Schemas.ApiSchemas.error_response("Invalid pagination parameters")
      }
    ]
  )

  def index(conn, params) do
    paginated_response(conn, params) do
      {Character, &WandererAppWeb.MapEventHandler.map_ui_character_stat/1}
    end
  end
end
