defmodule WandererAppWeb.Plugs.CheckMapApiKey do
  @moduledoc """
  A plug that checks the "Authorization: Bearer <token>" header
  against the map’s stored public_api_key. Halts with 401 if invalid.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    header = get_req_header(conn, "authorization") |> List.first()

    case header do
      "Bearer " <> incoming_token ->
        case fetch_map_id(conn.query_params) do
          {:ok, map_id} ->
            case WandererApp.Api.Map.by_id(map_id) do
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

          {:error, msg} ->
            conn
            |> send_resp(400, msg)
            |> halt()
        end

      _ ->
        conn
        |> send_resp(401, "Missing or invalid 'Bearer' token")
        |> halt()
    end
  end

  defp fetch_map_id(%{"map_id" => mid}) when is_binary(mid) and mid != "" do
    {:ok, mid}
  end

  defp fetch_map_id(%{"slug" => slug}) when is_binary(slug) and slug != "" do
    case WandererApp.Api.Map.get_map_by_slug(slug) do
      {:ok, map} ->
        {:ok, map.id}

      {:error, _reason} ->
        {:error, "No map found for slug=#{slug}"}
    end
  end

  defp fetch_map_id(_), do: {:error, "Must provide either ?map_id=UUID or ?slug=SLUG"}
end
