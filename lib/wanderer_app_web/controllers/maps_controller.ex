defmodule WandererAppWeb.MapsController do
  use WandererAppWeb, :controller

  def last(%{assigns: %{current_user: %{last_map_id: last_map_id}} = _assigns} = conn, _params)
      when not is_nil(last_map_id) do
    {:ok, map} = WandererApp.Api.Map.by_id(last_map_id)

    conn
    |> redirect(to: ~p"/#{map.slug}")
  end

  def last(conn, _params) do
    conn
    |> redirect(to: ~p"/maps")
  end
end
