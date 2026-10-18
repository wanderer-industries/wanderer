defmodule WandererAppWeb.PageCharactersLiveTest do
  use WandererAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WandererAppWeb.Factory

  setup %{conn: conn} do
    start_supervised!({WandererApp.Character.TrackerManager, []})

    user = Factory.insert(:user, %{})
    character = Factory.insert(:character, %{user_id: user.id, name: "React Prototype Pilot"})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)

    %{conn: conn, character: character}
  end

  test "mounts the React hook on a route separate from the existing Characters page", ctx do
    {:ok, view, html} = live(ctx.conn, ~p"/characters-react")

    assert html =~ ~s(id="page-characters-root")
    assert html =~ ~s(phx-hook="PageCharacters")
    assert has_element?(view, "#page-characters-root[phx-update=ignore]")
  end

  test "sends a serialized character snapshot through the socket contract", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/characters-react")

    render_hook(view, "page_characters_init", %{})

    assert_push_event(view, "page_characters_event", %{type: "snapshot", body: payload})
    assert payload.wallet_tracking_enabled in [true, false]
    assert [character] = payload.characters
    assert character.id == ctx.character.id
    assert character.eve_id == ctx.character.eve_id
    assert character.name == "React Prototype Pilot"
    assert character.corporation_id == ctx.character.corporation_id
    assert Map.has_key?(character, :ship_type_id)
    assert Map.has_key?(character, :system_info)
    assert Map.has_key?(character, :station_name)
  end

  test "pushes a point update when tracked character data changes", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/characters-react")

    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{ctx.character.id}",
      {:character_tracking_updated, ctx.character.id}
    )

    assert_push_event(view, "page_characters_event", %{
      type: "character_updated",
      body: character
    })

    assert character.id == ctx.character.id
  end
end
