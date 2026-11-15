defmodule WandererAppWeb.MapHomeAPIController do
  @moduledoc """
  Hands out the way into a map's home to whoever holds the token it was shared with.

  This is deliberately narrow: the home and the routes that lead into it, never the rest of the
  chain. A map that has not been shared, or a token that does not match, is a 404 - there is no
  reason to tell a stranger which of the two it was.
  """

  use WandererAppWeb, :controller

  alias WandererApp.Map.HomeShares

  def show(conn, %{"map_identifier" => slug}) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, %{home_solar_system_id: home, home_share_token: shared} = map}
         when is_integer(home) and is_binary(shared) <-
           WandererApp.Api.Map.get_map_by_slug(slug),
         true <- Plug.Crypto.secure_compare(shared, token) do
      json(conn, HomeShares.payload_for(map))
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> {:ok, String.trim(token)}
      ["bearer " <> token | _] -> {:ok, String.trim(token)}
      _ -> :error
    end
  end
end
