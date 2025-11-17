defmodule WandererAppWeb.RedirectController do
  use WandererAppWeb, :controller

  import WandererAppWeb.UserAuth, only: [fetch_current_user: 2]

  plug :fetch_current_user

  def redirect_authenticated(conn, _) do
    if conn.assigns.current_user do
      WandererAppWeb.UserAuth.redirect_if_user_is_authenticated(conn, [])
    else
      redirect(conn, to: ~p"/welcome")
    end
  end

  def swaggerui_root(conn, _) do
    redirect(conn, to: "/swaggerui/v1")
  end
end
