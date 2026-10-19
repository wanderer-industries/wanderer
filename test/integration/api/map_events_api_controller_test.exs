defmodule WandererAppWeb.MapEventsAPIControllerTest do
  @moduledoc """
  No test previously existed for this controller. Added while verifying that
  loosening `list_events` from `:admin_map` to `:view_system` (see
  MapEventsAPIController) actually results in a working, correctly-shaped
  response for a viewer-role eve-token, not just "doesn't crash".
  """

  use WandererAppWeb.ApiCase, async: false

  alias WandererAppWeb.Factory

  setup do
    # /events sits behind the :api_webhooks pipeline (CheckWebhooksDisabled)
    # in addition to :api_map, and webhooks are off by default in test env.
    previous = Application.get_env(:wanderer_app, :external_events, [])
    Application.put_env(:wanderer_app, :external_events, webhooks_enabled: true)
    on_exit(fn -> Application.put_env(:wanderer_app, :external_events, previous) end)
    :ok
  end

  defp mint_eve_token(conn, map, character) do
    Mox.stub(Test.EveSsoMock, :verify_token, fn _ ->
      {:ok,
       %{
         character_id: String.to_integer(character.eve_id),
         character_name: character.name,
         scopes: ""
       }}
    end)

    exchange_conn =
      post(conn, ~p"/api/maps/#{map.slug}/auth/eve-token", %{"eve_token" => "tok"})

    assert %{"data" => %{"token" => token}} = json_response(exchange_conn, 200)
    token
  end

  describe "GET /api/maps/:map_identifier/events" do
    test "the static map key gets a well-formed response", %{conn: conn} do
      map = Factory.insert(:map)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/events")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end

    test "a viewer-role eve-token can now read the event feed (view_system, not admin_map)", %{
      conn: conn
    } do
      owner_user = Factory.insert(:user)
      owner = Factory.insert(:character, %{user_id: owner_user.id})
      map = Factory.insert(:map, %{owner_id: owner.id})

      viewer_user = Factory.insert(:user)
      viewer = Factory.insert(:character, %{user_id: viewer_user.id})

      acl = Factory.insert(:access_list, %{owner_id: owner.id})
      Factory.insert(:map_access_list, %{map_id: map.id, access_list_id: acl.id})

      Factory.insert(:access_list_member, %{
        access_list_id: acl.id,
        eve_character_id: viewer.eve_id,
        role: "viewer"
      })

      token = mint_eve_token(conn, map, viewer)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/maps/#{map.slug}/events")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end

    test "an invalid 'since' param is a 400, not a 500", %{conn: conn} do
      map = Factory.insert(:map)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> get(~p"/api/maps/#{map.slug}/events?since=not-a-date")

      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
