defmodule WandererAppWeb.MapNotificationsTest do
  use WandererAppWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias WandererApp.Api.MapDiscordNotification
  alias WandererAppWeb.Factory

  setup %{conn: conn} do
    # `Api.Map.owner_id` points at a CHARACTER, not a user, and
    # `Factory.create_map/1` passes `owner_id` straight through. Passing a user
    # id here would fail the foreign key.
    user = Factory.insert(:user, %{})
    character = Factory.insert(:character, %{user_id: user.id})
    map = Factory.insert(:map, %{owner_id: character.id})

    %{conn: log_in_user(conn, user), map: map, user: user, character: character}
  end

  # The app has no `log_in_user/2` test helper: `UserAuth.on_mount/4` reads
  # `session["user_id"]` directly, so seeding the test session is enough.
  defp log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end

  test "owner sees the notifications tab", %{conn: conn, map: map} do
    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    assert has_element?(view, "[phx-value-tab='notifications']")
  end

  test "saving a valid webhook url creates the record", %{conn: conn, map: map} do
    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    view
    |> element("[phx-value-tab='notifications']")
    |> render_click()

    view
    |> form("#discord-notification-form", %{
      "notification" => %{
        "webhook_url" => "https://discord.com/api/webhooks/123/tok",
        "wh_only" => "true",
        "enabled" => "true"
      }
    })
    |> render_submit()

    assert {:ok, rec} = MapDiscordNotification.by_map(map.id)
    assert rec.wh_only == true
    # Regression guard: the Enabled checkbox must render during creation too.
    # When it was hidden behind `:if={@notification}` the param was absent, so
    # `params["enabled"] == "true"` was false and every new config was born
    # disabled — invisibly, because the UI showed no checkbox to contradict it.
    assert rec.enabled? == true
  end

  test "a new configuration is enabled when the box is left checked", %{conn: conn, map: map} do
    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    view
    |> element("[phx-value-tab='notifications']")
    |> render_click()

    # Submit exactly what the browser sends for a checked box rendered with a
    # preceding hidden "false": both keys, last one winning.
    view
    |> form("#discord-notification-form", %{
      "notification" => %{"webhook_url" => "https://discord.com/api/webhooks/123/tok"}
    })
    |> render_submit()

    assert {:ok, rec} = MapDiscordNotification.by_map(map.id)
    assert rec.enabled? == true
  end

  test "an invalid url is rejected with a message", %{conn: conn, map: map} do
    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    view
    |> element("[phx-value-tab='notifications']")
    |> render_click()

    html =
      view
      |> form("#discord-notification-form", %{
        "notification" => %{"webhook_url" => "https://evil.example.com/x"}
      })
      |> render_submit()

    assert html =~ "Discord webhook URL"
    assert {:error, _} = MapDiscordNotification.by_map(map.id)
  end

  test "unchecking 'enabled' actually disables", %{conn: conn, map: map} do
    {:ok, _} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/tok"
      })

    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    view |> element("[phx-value-tab='notifications']") |> render_click()

    # An unchecked checkbox submits NO value at all. The hidden companion input
    # is what makes "off" distinguishable from "field absent"; without it the
    # record would silently re-enable itself on every save.
    view
    |> form("#discord-notification-form", %{
      "notification" => %{"enabled" => "false", "wh_only" => "false"}
    })
    |> render_submit()

    assert {:ok, rec} = MapDiscordNotification.by_map(map.id)
    assert rec.enabled? == false
    assert rec.wh_only == false
  end

  test "re-checking 'enabled' turns it back on", %{conn: conn, map: map} do
    {:ok, rec} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/tok"
      })

    {:ok, _} = MapDiscordNotification.update(rec, %{enabled?: false})

    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    view |> element("[phx-value-tab='notifications']") |> render_click()

    # A checked box wins: the browser sends both hidden "false" and "true",
    # and Phoenix keeps the last value.
    view
    |> form("#discord-notification-form", %{
      "notification" => %{"enabled" => "true", "wh_only" => "true"}
    })
    |> render_submit()

    assert {:ok, updated} = MapDiscordNotification.by_map(map.id)
    assert updated.enabled? == true
  end

  test "the saved url is never rendered in full", %{conn: conn, map: map} do
    {:ok, _} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/SUPERSECRETTOKEN"
      })

    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    html =
      view
      |> element("[phx-value-tab='notifications']")
      |> render_click()

    refute html =~ "SUPERSECRETTOKEN"
  end

  test "the excluded-systems picker searches by system name", %{conn: conn, map: map} do
    Factory.insert(:solar_system, %{
      solar_system_id: 30_000_142,
      solar_system_name: "Jita",
      region_name: "The Forge"
    })

    {:ok, _} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/tok"
      })

    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    view |> element("[phx-value-tab='notifications']") |> render_click()

    # LiveSelect keeps its dropdown hidden until the user types, so open it
    # first; otherwise the options are in state but never rendered.
    view
    |> with_target("#excluded_system_live_select_component")
    |> render_change("change", %{"text" => "Jita"})

    # Drive the search event AT THE COMPONENT. Sending it to `view` would go to
    # the parent LiveView, whose existing ACL `live_select_change` handler
    # answers unconditionally with ACL options — the test would pass while
    # proving nothing about our component. `with_target/2` routes to the
    # component the same way `phx-target={@myself}` does at runtime, so this
    # test actually covers the hijack risk.
    view
    |> with_target("#map-notifications")
    |> render_change("live_select_change", %{
      "id" => "excluded_system_live_select_component",
      "text" => "Jita",
      "field" => "excluded_system"
    })

    # `with_target/2` proves our handler produces system options, but it routes
    # by hand. What proves the event will not escape to the PARENT at runtime is
    # the DOM: LiveSelect pushes `live_select_change` to `data-phx-target`, and
    # `phx-target={@myself}` is what makes that a component ref rather than the
    # root LiveView. Without it this attribute is the root and the parent's ACL
    # handler would answer instead.
    component_ref =
      view
      |> element("#map-notifications")
      |> render()
      |> then(&Regex.run(~r/data-phx-component="(\d+)"/, &1))
      |> Enum.at(1)

    assert has_element?(
             view,
             "#excluded_system_live_select_component[data-phx-target='#{component_ref}']"
           )

    # Options are pushed into the component; assert the search found Jita by
    # name rather than requiring the user to know id 30000142. The region
    # suffix is produced only by this component's option formatter.
    assert render(view) =~ "Jita (The Forge)"
    # And assert we did NOT get the parent's ACL options instead.
    refute render(view) =~ "access list"
  end

  test "send test message reports the global kill-switch", %{conn: conn, map: map} do
    {:ok, _} =
      MapDiscordNotification.create(%{
        map_id: map.id,
        webhook_url: "https://discord.com/api/webhooks/123/tok"
      })

    # `config/test.exs` leaves webhooks disabled, which is exactly the
    # production kill-switch case: the worker Registry does not exist, so this
    # must return an error rather than crash the LiveView.
    {:ok, view, _html} = live(conn, ~p"/maps/#{map.slug}/settings")

    view |> element("[phx-value-tab='notifications']") |> render_click()

    html = view |> element("button[phx-click='send-test']") |> render_click()

    assert html =~ "disabled on this server"
  end

  test "a non-owner cannot reach map settings", %{conn: conn} do
    other_user = Factory.insert(:user, %{})
    other_character = Factory.insert(:character, %{user_id: other_user.id})
    other_map = Factory.insert(:map, %{owner_id: other_character.id})

    assert {:error, _} = live(conn, ~p"/maps/#{other_map.slug}/settings")
  end
end
