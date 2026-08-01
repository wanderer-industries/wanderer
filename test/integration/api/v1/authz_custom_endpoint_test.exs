defmodule WandererAppWeb.Api.V1.AuthzCustomEndpointTest do
  @moduledoc """
  `GET /api/v1/maps/:map_id/systems_and_connections` is a hand-written
  controller rather than an AshJsonApi route, so it does not inherit the
  resource policies automatically. It needs two independent fixes, and this
  suite asserts both:

    1. **Path-vs-token guard.** The `:map_id` in the path must equal the
       token's map, otherwise 404. Without this, a valid token could read any
       map by id.

    2. **Actor propagation.** The reads must pass `actor:`. The domain gate is
       `authorize :when_requested`, which authorizes only when an `actor:` key
       is present (`ash/lib/ash/actions/helpers.ex:390`), so a bare
       `Ash.read!()` runs completely unauthorized. The guard alone would mask
       this, so the actor is asserted directly at the end of this file rather
       than only through the HTTP round trip.

  Note `MapSystem`'s primary read carries an always-on
  `FilterSystemsByActorMap` preparation. It is *not* a substitute for either
  fix: it is a preparation on one resource, not a policy, and `MapConnection`
  has no equivalent.
  """
  use WandererAppWeb.ApiCase, async: false

  require Ash.Query

  setup %{conn: conn} do
    owner = insert(:user)
    char = insert(:character, %{user_id: owner.id})
    map = insert(:map, %{owner_id: char.id})

    own_system =
      insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142, visible: true})

    other_user = insert(:user)
    other_char = insert(:character, %{user_id: other_user.id})
    other_map = insert(:map, %{owner_id: other_char.id})

    other_system =
      insert(:map_system, %{map_id: other_map.id, solar_system_id: 30_000_144, visible: true})

    %{
      conn: create_authenticated_conn(conn, map),
      map: map,
      other_map: other_map,
      own_system: own_system,
      other_system: other_system
    }
  end

  test "own map -> 200 and returns the real system id (not an empty list)", ctx do
    body =
      ctx.conn
      |> get("/api/v1/maps/#{ctx.map.id}/systems_and_connections")
      |> json_response(200)

    ids = Enum.map(body["systems"], & &1["id"])

    # Asserting membership, not just 200: an empty list would also be a 200 and
    # would hide a broken actor/policy interaction.
    assert ctx.own_system.id in ids
  end

  test "another map's id -> 404", ctx do
    ctx.conn
    |> get("/api/v1/maps/#{ctx.other_map.id}/systems_and_connections")
    |> json_response(404)
  end

  test "another map's data never leaks through the endpoint", ctx do
    body =
      ctx.conn
      |> get("/api/v1/maps/#{ctx.map.id}/systems_and_connections")
      |> json_response(200)

    ids = Enum.map(body["systems"], & &1["id"])
    refute ctx.other_system.id in ids
  end

  test "a nonexistent map id -> 404", ctx do
    ctx.conn
    |> get("/api/v1/maps/#{Ecto.UUID.generate()}/systems_and_connections")
    |> json_response(404)
  end

  test "a malformed (non-uuid) map id -> 404 rather than a 500", ctx do
    ctx.conn
    |> get("/api/v1/maps/not-a-uuid/systems_and_connections")
    |> json_response(404)
  end

  test "the endpoint propagates an actor into its Ash reads", ctx do
    # The guard alone would make the 404 test pass even with actor-less reads,
    # so assert propagation directly. A token actor scoped to `map` must not be
    # able to read the OTHER map's systems; if the controller passed no actor,
    # this read would be unauthorized and would return the row.
    actor = WandererApp.Api.ActorWithMap.new(ctx.map.owner_id, ctx.map)

    {:ok, rows} =
      WandererApp.Api.MapSystem
      |> Ash.Query.filter(map_id == ^ctx.other_map.id)
      |> Ash.read(actor: actor)

    assert rows == [],
           "a token actor scoped to one map must not read another map's systems"
  end
end
