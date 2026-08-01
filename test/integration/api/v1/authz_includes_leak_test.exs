defmodule WandererAppWeb.Api.V1.AuthzIncludesLeakTest do
  @moduledoc """
  `include=` traverses relationships, which is the one path that can reach a
  resource without going through its own route. These tests assert that a
  token cannot use an include to read across map boundaries, and that no
  sensitive attribute is serialized through one.

  Two facts about this API discovered while writing these tests, both of which
  shape the assertions below:

    * `WandererApp.Api.Character` is NOT an AshJsonApi resource (it has only
      `extensions: [AshCloak]`). So `?include=owner` on a map emits a resource
      identifier with `"type": null` and an EMPTY attributes object -- no
      Character field is serialized at all. The negative assertion is therefore
      about attributes being absent, not about the type name.
    * Tokens can still see `owner_id` as a plain attribute of the map they own.
      That is the map's own column, not a traversal, and is not a leak.

  The highest-risk include is `map_system.includes([:map])`: a system carries a
  `map` relationship, so an include there is a direct route from a row to its
  parent map. Since reads are filter-scoped, a foreign system is invisible in
  the first place, which is what the traversal tests confirm.
  """
  use WandererAppWeb.ApiCase, async: false

  @sensitive ~w(access_token refresh_token api_key public_api_key hash)

  setup %{conn: conn} do
    owner = insert(:user)
    char = insert(:character, %{user_id: owner.id})
    map = insert(:map, %{owner_id: char.id})
    own_system = insert(:map_system, %{map_id: map.id, solar_system_id: 30_000_142})

    other_user = insert(:user)
    other_char = insert(:character, %{user_id: other_user.id})
    other_map = insert(:map, %{owner_id: other_char.id})
    other_system = insert(:map_system, %{map_id: other_map.id, solar_system_id: 30_000_144})

    %{
      conn: create_authenticated_conn(conn, map),
      map: map,
      char: char,
      own_system: own_system,
      other_map: other_map,
      other_system: other_system
    }
  end

  defp sensitive_keys_in(payload) do
    payload
    |> List.wrap()
    |> Enum.flat_map(fn resource ->
      attrs = resource["attributes"] || %{}
      Enum.filter(@sensitive, &Map.has_key?(attrs, &1))
    end)
  end

  test "include=owner leaks no sensitive Character attribute", ctx do
    body =
      ctx.conn
      |> get("/api/v1/maps/#{ctx.map.slug}?include=owner")
      |> json_response(200)

    included = body["included"] || []

    # Positive control: the include actually resolved to the owner, so the
    # negative assertion below is not passing over an empty list.
    assert Enum.any?(included, &(&1["id"] == ctx.char.id)),
           "expected the owner #{ctx.char.id} in included, got #{inspect(included)}"

    assert sensitive_keys_in(included) == [],
           "sensitive attributes leaked through include=owner: #{inspect(included)}"
  end

  test "the map payload itself exposes no sensitive attribute", ctx do
    body =
      ctx.conn
      |> get("/api/v1/maps/#{ctx.map.slug}")
      |> json_response(200)

    assert sensitive_keys_in([body["data"]]) == [],
           "sensitive attributes leaked on the map itself: #{inspect(body["data"])}"
  end

  test "a foreign system cannot be reached, so its map include cannot be traversed", ctx do
    # map_system includes([:map]); if a foreign system were readable, this
    # would hand back another map's record.
    ctx.conn
    |> get("/api/v1/map_systems/#{ctx.other_system.id}?include=map")
    |> json_response(404)
  end

  test "listing systems with include=map never yields a foreign map", ctx do
    body =
      ctx.conn
      |> get("/api/v1/map_systems?include=map")
      |> json_response(200)

    included_ids = Enum.map(body["included"] || [], & &1["id"])
    system_ids = Enum.map(body["data"] || [], & &1["id"])

    # Positive control: the own system is present, so the refutations below are
    # not vacuous.
    assert ctx.own_system.id in system_ids
    refute ctx.other_system.id in system_ids
    refute ctx.other_map.id in included_ids

    assert sensitive_keys_in(body["included"] || []) == [],
           "sensitive attributes leaked through include=map"
  end

  test "include=acls never yields an ACL linked to another map", ctx do
    other_acl = insert(:access_list, %{owner_id: ctx.map.owner_id})
    insert(:map_access_list, %{map_id: ctx.other_map.id, access_list_id: other_acl.id})

    body =
      ctx.conn
      |> get("/api/v1/maps/#{ctx.map.slug}?include=acls")
      |> json_response(200)

    included_ids = Enum.map(body["included"] || [], & &1["id"])
    refute other_acl.id in included_ids
  end
end
