defmodule WandererAppWeb.Api.V1.AuthzUserActivityTest do
  @moduledoc """
  `user_activity` is an audit log spanning all users and maps, with no
  meaningful map-scoped subset, so it is HARD-FORBIDDEN for token actors.

  Every token action must return **403**. This is deliberately not a filter
  check: a filter would yield `200` with an empty list, which would imply the
  endpoint is legitimately available to tokens and would silently start
  leaking if the scoping expression were ever widened.

  A real activity row is seeded so the denial is a genuine assertion rather
  than a vacuous pass over an empty table.
  """
  use WandererAppWeb.ApiCase, async: false

  setup %{conn: conn} do
    owner = insert(:user)
    char = insert(:character, %{user_id: owner.id})
    map = insert(:map, %{owner_id: char.id})

    # entity_type/event_type must be valid enum members (see user_activity.ex:
    # :map and :map_added are valid; :map_created is NOT).
    {:ok, seeded} =
      Ash.create(
        WandererApp.Api.UserActivity,
        %{
          user_id: insert(:user).id,
          entity_type: :map,
          event_type: :map_added,
          entity_id: Ecto.UUID.generate()
        },
        authorize?: false
      )

    %{conn: create_authenticated_conn(conn, map), seeded: seeded}
  end

  test "token list of user_activities -> 403", %{conn: conn} do
    conn |> get("/api/v1/user_activities") |> json_response(403)
  end

  test "token GET of the seeded activity -> 403 (not 404, not empty 200)", %{
    conn: conn,
    seeded: seeded
  } do
    conn |> get("/api/v1/user_activities/#{seeded.id}") |> json_response(403)
  end

  test "the seeded row really exists, so the 403s above are not vacuous", %{seeded: seeded} do
    assert {:ok, %WandererApp.Api.UserActivity{}} =
             Ash.get(WandererApp.Api.UserActivity, seeded.id, authorize?: false)
  end

  test "a trusted internal User actor can still read user_activities", %{seeded: seeded} do
    {:ok, rows} =
      Ash.read(WandererApp.Api.UserActivity,
        actor: %WandererApp.Api.User{id: Ecto.UUID.generate()},
        authorize?: true
      )

    assert seeded.id in Enum.map(rows, & &1.id)
  end
end
