defmodule WandererAppWeb.Plugs.SubscriptionGuard do
  @moduledoc """
  A plug that checks if the map has an active subscription.
  Designed to work after authentication and map resolution.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns do
      %{map: map} ->
        check_subscription(conn, map.id)

      %{map_id: map_id} ->
        check_subscription(conn, map_id)

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Map not found in request context"})
        |> halt()
    end
  end

  defp check_subscription(conn, map_id) do
    case WandererApp.Map.is_subscription_active?(map_id) do
      {:ok, true} ->
        conn

      {:ok, false} ->
        conn
        |> put_status(:payment_required)
        |> json(%{error: "Map subscription is not active"})
        |> halt()

      {:error, reason} ->
        Logger.error("Failed to check subscription status: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to verify subscription status"})
        |> halt()
    end
  end
end
