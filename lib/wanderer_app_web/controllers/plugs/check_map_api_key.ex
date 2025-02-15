defmodule WandererAppWeb.Plugs.CheckMapApiKey do
  @moduledoc """
  A plug that checks the "Authorization: Bearer <token>" header
  against the map’s stored public_api_key. Halts with 401 if invalid.
  """

  import Plug.Conn
  alias WandererAppWeb.UtilAPIController, as: Util

  def init(opts), do: opts

  def call(conn, _opts) do
    header = get_req_header(conn, "authorization") |> List.first()

    case header do
      "Bearer " <> incoming_token ->
        case fetch_map(conn.query_params) do
          {:ok, map} ->
            if map.public_api_key == incoming_token do
              conn
            else
              conn
              |> send_resp(401, "Unauthorized (invalid token for map)")
              |> halt()
            end

          {:error, _reason} ->
            conn
            |> send_resp(404, "Map not found")
            |> halt()
        end

      _ ->
        conn
        |> send_resp(401, "Missing or invalid 'Bearer' token")
        |> halt()
    end
  end

  defp fetch_map(query_params) do
    case Util.fetch_map_id(query_params) do
      {:ok, map_id} ->
        WandererApp.Api.Map.by_id(map_id)

      error ->
        error
    end
  end
end
