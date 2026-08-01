defmodule WandererAppWeb.Api.V1.AuthzDefenseInDepthTest do
  @moduledoc """
  These four resources expose no `/api/v1` routes today, but they remain
  reachable as relationship `includes` and would become reachable if a route
  were ever added. The guarantee is therefore enforced at the Ash layer, not
  by the route list staying empty.

  The assertion is deliberately `%Ash.Error.Forbidden{}` **exclusively**, never
  `{:ok, []}`. An empty result would be indistinguishable from a missing
  policy over an empty table, so each resource is seeded with a real row first
  and the denial is required to be an explicit forbid.

  The companion direction matters just as much: the domain gate is
  `authorize :when_requested`, which authorizes only when an `actor:` key is
  present (`ash/lib/ash/actions/helpers.ex:390`). Actor-less internal reads —
  which is how every internal caller of these resources actually reads them —
  must keep working. That is asserted explicitly below.
  """
  use WandererApp.DataCase, async: false

  import WandererAppWeb.Factory

  @zero_op_resources [
    WandererApp.Api.MapSolarSystem,
    WandererApp.Api.MapState,
    WandererApp.Api.ShipTypeInfo,
    WandererApp.Api.User
  ]

  setup do
    owner = insert(:user)
    char = insert(:character, %{user_id: owner.id})
    map = insert(:map, %{owner_id: char.id})

    # Seed one row per resource so every denial below is proven against
    # non-empty data. `owner` already seeds the User row.
    unique = System.unique_integer([:positive])

    {:ok, _solar} =
      Ash.create(
        WandererApp.Api.MapSolarSystem,
        %{
          solar_system_id: 31_000_000 + unique,
          region_id: 10_000_001,
          constellation_id: 20_000_001,
          solar_system_name: "TestSys#{unique}",
          solar_system_name_lc: "testsys#{unique}",
          constellation_name: "TestConst",
          region_name: "TestRegion",
          system_class: 1
        },
        authorize?: false
      )

    {:ok, _state} =
      Ash.create(WandererApp.Api.MapState, %{map_id: map.id}, authorize?: false)

    {:ok, _ship} =
      Ash.create(
        WandererApp.Api.ShipTypeInfo,
        %{
          type_id: 600 + unique,
          group_id: 25,
          group_name: "Frigate",
          name: "TestShip#{unique}"
        },
        authorize?: false
      )

    %{token_actor: WandererApp.Api.ActorWithMap.new(owner, map)}
  end

  test "each zero-op resource is non-empty, so the denials below are not vacuous" do
    for resource <- @zero_op_resources do
      {:ok, rows} = Ash.read(resource, authorize?: false)

      refute rows == [],
             "#{inspect(resource)} is empty -- the Forbidden assertion would be vacuous"
    end
  end

  test "a token actor is forbidden from reading every zero-op resource", %{
    token_actor: actor
  } do
    for resource <- @zero_op_resources do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.read(resource, actor: actor, authorize?: true),
             "expected Forbidden for #{inspect(resource)}"
    end
  end

  test "a trusted internal User actor can still read every zero-op resource" do
    actor = %WandererApp.Api.User{id: Ecto.UUID.generate()}

    for resource <- @zero_op_resources do
      assert {:ok, _rows} = Ash.read(resource, actor: actor, authorize?: true),
             "expected the trusted bypass to allow #{inspect(resource)}"
    end
  end

  test "actor-less internal reads still work (the real internal call path)" do
    # Every internal caller of these resources reads without an actor, e.g.
    # `WandererApp.Api.ShipTypeInfo.read()` in cached_info.ex. Under
    # `authorize :when_requested` that skips authorization entirely. If this
    # ever starts failing, the deny-all policy has broken production reads.
    for resource <- @zero_op_resources do
      assert {:ok, _rows} = Ash.read(resource),
             "actor-less read of #{inspect(resource)} must remain unauthorized-and-allowed"
    end
  end
end
