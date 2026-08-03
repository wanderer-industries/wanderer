defmodule WandererApp.Map.IntelSyncValidationTest do
  use WandererApp.DataCase, async: false

  import Mox
  import WandererApp.MapTestHelpers

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()
    setup_ddrt_mocks()

    user = insert(:user)
    character = insert(:character, %{user_id: user.id})
    map_a = insert(:map, %{owner_id: character.id})
    map_b = insert(:map, %{owner_id: character.id})

    # Load user with characters for get_user_role_for_map
    {:ok, user_with_characters} = Ash.load(user, :characters)

    %{
      map_a: map_a,
      map_b: map_b,
      user: user_with_characters,
      character: character
    }
  end

  describe "get_user_role_for_map/2" do
    test "returns :admin for map owner", ctx do
      assert :admin == WandererApp.Maps.get_user_role_for_map(ctx.map_a, ctx.user)
    end

    test "returns nil for unrelated user", ctx do
      other_user = insert(:user)
      {:ok, other_user_with_characters} = Ash.load(other_user, :characters)

      assert nil == WandererApp.Maps.get_user_role_for_map(ctx.map_a, other_user_with_characters)
    end
  end

  describe "MapRepo.set_intel_source_map/2" do
    test "succeeds for valid configuration", ctx do
      {:ok, _updated} = WandererApp.MapRepo.set_intel_source_map(ctx.map_a, ctx.map_b.id)

      # Reload and verify
      {:ok, reloaded} = WandererApp.MapRepo.get(ctx.map_a.id)
      assert reloaded.intel_source_map_id == ctx.map_b.id
    end

    test "can clear the source", ctx do
      # Set it first
      {:ok, _updated} = WandererApp.MapRepo.set_intel_source_map(ctx.map_a, ctx.map_b.id)

      # Reload to get fresh record
      {:ok, map_with_source} = WandererApp.MapRepo.get(ctx.map_a.id)
      assert map_with_source.intel_source_map_id == ctx.map_b.id

      # Clear it
      {:ok, _cleared} = WandererApp.MapRepo.set_intel_source_map(map_with_source, nil)

      # Reload and verify
      {:ok, reloaded} = WandererApp.MapRepo.get(ctx.map_a.id)
      assert reloaded.intel_source_map_id == nil
    end

    test "rejects setting a map as its own intel source", ctx do
      result = WandererApp.MapRepo.set_intel_source_map(ctx.map_a, ctx.map_a.id)
      assert {:error, _} = result
    end

    test "rejects a non-existent map ID as source", ctx do
      fake_id = Ash.UUID.generate()
      result = WandererApp.MapRepo.set_intel_source_map(ctx.map_a, fake_id)
      assert {:error, _} = result
    end
  end
end
