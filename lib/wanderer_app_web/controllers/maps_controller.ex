defmodule WandererAppWeb.MapsController do
  use WandererAppWeb, :controller

  def last(
        %{assigns: %{current_user: %{last_map_id: last_map_id} = current_user} = _assigns} = conn,
        _params
      )
      when not is_nil(last_map_id) do
    case Ash.get(WandererApp.Api.Map, last_map_id, actor: current_user) do
      {:ok, map} ->
        conn
        |> redirect(to: ~p"/#{map.slug}")
        |> halt()

      _ ->
        # If map not found or no access, redirect to maps list
        conn
        |> redirect(to: ~p"/maps")
        |> halt()
    end
  end

  def last(conn, _params) do
    conn
    |> redirect(to: ~p"/maps")
    |> halt()
  end
end
