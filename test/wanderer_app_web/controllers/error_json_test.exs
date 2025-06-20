defmodule WandererAppWeb.ErrorJSONTest do
  use WandererAppWeb.ConnCase, async: true

  @moduletag :unit

  test "renders 404" do
    assert WandererAppWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert WandererAppWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
