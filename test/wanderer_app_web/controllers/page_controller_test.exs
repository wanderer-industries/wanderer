defmodule WandererAppWeb.PageControllerTest do
  use WandererAppWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) == "/welcome"
  end
end
