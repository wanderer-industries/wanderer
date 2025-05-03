defmodule WandererAppWeb.Plugs.CheckMapSubscription do
  @moduledoc """
  A plug that checks the Map has active subscription
  Halts with 401 if no active subscription.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # First check if map_id is already in conn.assigns (from CheckMapApiKey)
    case get_map_id_from_assigns_or_params(conn) do
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

  # First try to get map_id from conn.assigns
  defp get_map_id_from_assigns_or_params(conn) do
    if Map.has_key?(conn.assigns, :map_id) do
      Logger.debug("Found map_id in conn.assigns: #{conn.assigns.map_id}")
      {:ok, conn.assigns.map_id}
    else
      # Fall back to query params if not in assigns
      fetch_map_id(conn.query_params)
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
