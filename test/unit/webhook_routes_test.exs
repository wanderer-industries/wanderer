defmodule WandererAppWeb.WebhookRoutesTest do
  use WandererAppWeb.ConnCase, async: false

  alias WandererAppWeb.MapAPIController

  import WandererAppWeb.Factory

  test "routes webhook toggle requests to the map controller" do
    route =
      Phoenix.Router.route_info(
        WandererAppWeb.Router,
        "PUT",
        "/api/maps/example-map/webhooks/toggle",
        "localhost"
      )

    assert %{
             plug: WandererAppWeb.MapAPIController,
             plug_opts: :toggle_webhooks,
             path_params: %{"map_identifier" => "example-map"}
           } = route
  end

  test "toggles webhooks using the route's map identifier parameter" do
    enable_webhooks()

    map = insert(:map)
    conn = build_conn() |> assign(:current_character, %{id: map.owner_id})

    response =
      MapAPIController.toggle_webhooks(conn, %{
        "map_identifier" => map.slug,
        "enabled" => true
      })

    assert %{"webhooks_enabled" => true} = json_response(response, 200)
  end

  test "does not let a body map_id override the authenticated path map" do
    enable_webhooks()

    path_map = insert(:map)
    other_map = insert(:map, %{owner_id: path_map.owner_id})

    response =
      build_conn()
      |> put_req_header("authorization", "Bearer #{path_map.public_api_key}")
      |> put("/api/maps/#{path_map.slug}/webhooks/toggle", %{
        "enabled" => true,
        "map_id" => other_map.id
      })

    assert %{"webhooks_enabled" => true} = json_response(response, 200)
    assert {:ok, updated_path_map} = WandererApp.Api.Map.by_id(path_map.id)
    assert {:ok, unchanged_other_map} = WandererApp.Api.Map.by_id(other_map.id)
    assert updated_path_map.webhooks_enabled
    refute unchanged_other_map.webhooks_enabled
  end

  defp enable_webhooks do
    external_events = Application.get_env(:wanderer_app, :external_events, [])

    Application.put_env(
      :wanderer_app,
      :external_events,
      Keyword.put(external_events, :webhooks_enabled, true)
    )

    on_exit(fn ->
      Application.put_env(:wanderer_app, :external_events, external_events)
    end)
  end
end
