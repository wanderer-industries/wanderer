defmodule WandererAppWeb.Plugs.CheckJsonApiAuthTokenOnlyTest do
  use WandererAppWeb.ApiCase, async: false

  test "request with a session but no bearer token is unauthorized", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)
      |> get("/api/v1/map_subscriptions")

    assert json_response(conn, 401)
  end
end
