defmodule WandererAppWeb.PageCharactersLiveTest do
  use WandererAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WandererAppWeb.Factory

  setup %{conn: conn} do
    previous_flag = Application.get_env(:wanderer_app, :legacy_characters_page_enabled, false)
    Application.put_env(:wanderer_app, :legacy_characters_page_enabled, false)

    on_exit(fn ->
      Application.put_env(:wanderer_app, :legacy_characters_page_enabled, previous_flag)
    end)

    start_supervised!({WandererApp.Character.TrackerManager, []})

    user = Factory.insert(:user, %{})
    character = Factory.insert(:character, %{user_id: user.id, name: "React Prototype Pilot"})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)

    %{conn: conn, character: character}
  end

  test "mounts the React hook on the primary Characters route", ctx do
    {:ok, view, html} = live(ctx.conn, ~p"/characters")

    assert html =~ ~s(id="page-characters-root")
    assert html =~ ~s(phx-hook="PageCharacters")
    assert has_element?(view, "#page-characters-root[phx-update=ignore]")

    assert {:error, {:redirect, %{to: "/characters"}}} =
             live(ctx.conn, ~p"/characters/authorize")
  end

  test "mounts the legacy page on /characters when enabled", ctx do
    Application.put_env(:wanderer_app, :legacy_characters_page_enabled, true)

    {:ok, _legacy_view, legacy_html} = live(ctx.conn, ~p"/characters")
    assert legacy_html =~ ~s(phx-hook="ShowCharactersAddAlert")
    refute legacy_html =~ ~s(id="page-characters-root")

    {:ok, _authorize_view, authorize_html} = live(ctx.conn, ~p"/characters/authorize")
    assert authorize_html =~ "Authorize Character"
  end

  test "sends a serialized character snapshot through the socket contract", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/characters")

    render_hook(view, "page_characters_init", %{})

    assert_push_event(view, "page_characters_event", %{type: "snapshot", body: payload})
    assert payload.wallet_tracking_enabled in [true, false]
    assert [character] = payload.characters
    assert character.id == ctx.character.id
    assert character.eve_id == ctx.character.eve_id
    assert character.name == "React Prototype Pilot"
    assert character.corporation_id == ctx.character.corporation_id
    assert character.online == (ctx.character.online == true)
    assert Map.has_key?(character, :ship_type_id)
    assert Map.has_key?(character, :system_info)
    assert Map.has_key?(character, :station_id)
    assert Map.has_key?(character, :station_name)
    assert Map.has_key?(character, :structure_id)
  end

  test "pushes a point update when tracked character data changes", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/characters")

    {:ok, _state} =
      WandererApp.Character.update_character_state(ctx.character.id, %{is_online: true})

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
    assert character.online
  end
end
