defmodule WandererAppWeb.CharactersAPIController do
  @moduledoc """
  Exposes an endpoint for listing ALL characters in the database

  Endpoint:
    GET /api/characters
  """

  use WandererAppWeb, :controller
  alias WandererApp.Api.Character

  @doc """
  GET /api/characters

  Lists ALL characters in the database
  Returns an array of objects, each with `id`, `eve_id`, `name`, etc.
  """
  def index(conn, _params) do
    case WandererApp.Api.read(Character) do
      {:ok, characters} ->
        result =
          characters
          |> Enum.map(&%{
            id: &1.id,
            eve_id: &1.eve_id,
            name: &1.name,
            corporation_name: &1.corporation_name,
            alliance_name: &1.alliance_name
          })

        json(conn, %{data: result})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(error)})
    end
  end
end
