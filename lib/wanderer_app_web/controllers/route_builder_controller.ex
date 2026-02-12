defmodule WandererAppWeb.RouteBuilderController do
  use WandererAppWeb, :controller

  require Logger

  def find_closest(conn, params) do
    payload = %{
      origin: Map.get(params, "origin") || Map.get(params, :origin),
      flag: Map.get(params, "flag") || Map.get(params, :flag) || "shortest",
      connections: Map.get(params, "connections") || Map.get(params, :connections) || [],
      avoid: Map.get(params, "avoid") || Map.get(params, :avoid) || [],
      count: Map.get(params, "count") || Map.get(params, :count) || 1,
      type: Map.get(params, "type") || Map.get(params, :type) || "blueLoot"
    }

    case WandererApp.RouteBuilderClient.find_closest(payload) do
      {:ok, body} ->
        json(conn, body)

      {:error, reason} ->
        Logger.warning("[RouteBuilderController] find_closest failed: #{inspect(reason)}")
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "route_builder_failed"})
    end
  end
end
