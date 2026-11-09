defmodule WandererApp.Api.InternalAuthzRegressionTest do
  @moduledoc """
  Regression guard for the internal (non-`/api/v1`) callers.

  Every policy added in this branch is fronted by a `MapScoped.trusted()`
  bypass, so plain `User`/`Character` actors must be entirely unaffected. This
  suite exercises the real call sites that pass an `actor:`, so that tightening
  a policy later cannot silently break the app's own code paths.

  Each test names the production call site it mirrors. Where the real caller's
  actor type matters, the test uses the SAME type the caller uses -- notably
  `Map.duplicate`, which the controller invokes with a Character
  (`conn.assigns[:current_character]`, map_api_controller.ex:1276), not a User.
  """
  use WandererApp.DataCase, async: false

  import WandererAppWeb.Factory

  setup do
    user = insert(:user)
    char = insert(:character, %{user_id: user.id})
    map = insert(:map, %{owner_id: char.id})

    # The :available actions run FilterMapsByRoles / FilterAclsByRoles, which
    # read `actor.characters` directly (filter_maps_by_roles.ex:21). Real
    # callers therefore always supply an actor with characters loaded -- e.g.
    # CheckJsonApiAuth does `User.by_id(..., load: :characters)`. Reload the
    # user the same way so this suite exercises the production shape rather
    # than a bare struct with %Ash.NotLoaded{}.
    {:ok, user} = WandererApp.Api.User.by_id(user.id, load: :characters)

    %{user: user, char: char, map: map}
  end

  describe "read actions with internal actors" do
    # maps_live.ex / map_repo.ex pattern.
    test "Map.available works with a User actor", %{user: user} do
      assert {:ok, _} = WandererApp.Api.Map.available(%{}, actor: user)
    end

    test "AccessList.available works with a User actor", %{user: user} do
      assert {:ok, _} = WandererApp.Api.AccessList.available(%{}, actor: user)
    end

    # NOTE: :available is never called with a Character in production --
    # `Maps.get_available_maps/1` and `Acls.get_available_acls/1` are the only
    # callers and both pass a User. FilterMapsByRoles reads `actor.characters`,
    # which a Character struct does not have, so a Character actor here would
    # test a path that does not exist. The Character bypass is covered by the
    # write and duplicate tests below instead.

    # The bypass must let an internal actor see rows regardless of map scope --
    # a token actor would be filtered here.
    test "a User actor reading maps is not map-scoped", %{user: user, map: map} do
      {:ok, maps} = Ash.read(WandererApp.Api.Map, actor: user, authorize?: true)
      assert map.id in Enum.map(maps, & &1.id)
    end

    test "a Character actor reading maps is not map-scoped", %{char: char, map: map} do
      {:ok, maps} = Ash.read(WandererApp.Api.Map, actor: char, authorize?: true)
      assert map.id in Enum.map(maps, & &1.id)
    end
  end

  describe "write actions with internal actors" do
    # map_default_settings is the only resource whose create is guarded by
    # CreateMapMatchesToken while map_id is `allow_nil? false` with no
    # InjectMapFromActor, so it is the most sensitive to changes in that check.
    test "MapDefaultSettings.create works with a Character actor", %{char: char, map: map} do
      assert {:ok, _} =
               WandererApp.Api.MapDefaultSettings.create(
                 %{map_id: map.id, settings: "{}"},
                 actor: char
               )
    end

    test "MapDefaultSettings.update works with a Character actor", %{char: char, map: map} do
      {:ok, existing} =
        WandererApp.Api.MapDefaultSettings.create(
          %{map_id: map.id, settings: "{}"},
          actor: char
        )

      assert {:ok, _} =
               WandererApp.Api.MapDefaultSettings.update(
                 existing,
                 %{settings: ~s({"a":1})},
                 actor: char
               )
    end
  end

  describe "calculations and loads with internal actors" do
    # map_repo.ex:39 / maps_live.ex:734 pattern.
    test "loading :user_permissions with a User actor works", %{user: user, map: map} do
      {:ok, loaded} = WandererApp.Api.Map.by_id(map.id)
      assert {:ok, _} = Ash.load(loaded, :user_permissions, actor: user)
    end
  end

  describe "Map.duplicate" do
    # map_api_controller.ex:1276 passes conn.assigns[:current_character], and
    # the :duplicate action sets owner_id from `context.actor.id`. Map.owner is
    # a belongs_to Character, so a Character actor is the correct (and only
    # FK-valid) actor here. Using a User actor would write a User id into a
    # Character FK.
    test "Map.duplicate works with a Character actor", %{char: char, map: map} do
      assert {:ok, duplicated} =
               WandererApp.Api.Map.duplicate(
                 %{source_map_id: map.id, name: "dup-#{System.unique_integer([:positive])}"},
                 actor: char
               )

      assert duplicated.owner_id == char.id
      refute duplicated.id == map.id
    end
  end
end
