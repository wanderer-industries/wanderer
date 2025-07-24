defmodule WandererAppWeb.CharactersAPIController do
  @moduledoc """
  Exposes an endpoint for listing ALL characters in the database
  """

  use WandererAppWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias WandererApp.Api.Character

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
      }
    },
    required: ["data"]
  }

  @doc """
  GET /api/characters
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  operation(:index,
    summary: "List Characters",
    description: "Lists ALL characters in the database.",
    responses: [
      ok: {
        "List of characters",
        "application/json",
        @characters_index_response_schema
      }
    ]
  )

  def index(conn, _params) do
    case Ash.read(Character) do
      {:ok, characters} ->
        result =
          characters
          |> Enum.map(&WandererAppWeb.MapEventHandler.map_ui_character_stat/1)

        json(conn, %{data: result})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(error)})
    end
  end
end
