defmodule WandererAppWeb.Plugs.CheckMapSubscription do
  @moduledoc """
  A plug that checks the Map has active subscription
  Halts with 401 if no active subscription.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case fetch_map_id(conn.query_params) do
      {:ok, map_id} ->
        {:ok, is_subscription_active} = map_id |> WandererApp.Map.is_subscription_active?()

        if is_subscription_active do
          conn
        else
          conn
          |> send_resp(401, "Unauthorized (map subscription not active)")
          |> halt()
        end

      {:error, msg} ->
        conn
        |> send_resp(400, msg)
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
