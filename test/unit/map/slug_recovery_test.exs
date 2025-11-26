defmodule WandererApp.Map.SlugRecoveryTest do
  use WandererApp.DataCase, async: false

  import Mox

  setup :verify_on_exit!

  alias WandererApp.Map.SlugRecovery
  alias WandererApp.Api.Map
  alias WandererApp.Repo

  describe "recover_duplicate_slug/1" do
    test "returns ok when no duplicates exist" do
      # Create a single map
      user = create_test_user()
      {:ok, _map} = create_map(user, "unique-map")

      # Should return ok with no fixes needed
      assert {:ok, result} = SlugRecovery.recover_duplicate_slug("unique-map")
      assert result.fixed_count == 0
      assert result.kept_map_id == nil
    end

    test "returns ok when slug doesn't exist" do
      assert {:ok, result} = SlugRecovery.recover_duplicate_slug("nonexistent-slug")
      assert result.fixed_count == 0
    end

    test "fixes duplicate slugs by renaming newer maps" do
      user = create_test_user()

      # Temporarily drop the unique index to allow duplicate insertion for testing
      drop_unique_index()

      # Create duplicates by directly inserting into database (bypassing Ash validations)
      map1_id = insert_map_directly("duplicate-slug", "Map 1", user.id, false)
      map2_id = insert_map_directly("duplicate-slug", "Map 2", user.id, false)
      map3_id = insert_map_directly("duplicate-slug", "Map 3", user.id, false)

      # Recreate the index after inserting test data (recovery will handle the duplicates)
      # Note: This will fail due to duplicates, which is expected
      try do
        create_unique_index()
      rescue
        _ -> :ok
      end

      # Verify duplicates exist
      assert count_maps_with_slug("duplicate-slug") == 3

      # Run recovery
      assert {:ok, result} = SlugRecovery.recover_duplicate_slug("duplicate-slug")
      assert result.fixed_count == 2
      assert result.kept_map_id == map1_id

      # Verify only one map has original slug (the oldest)
      assert count_maps_with_slug("duplicate-slug") == 1

      # Verify the kept map
      {:ok, kept_map} = Repo.query("SELECT id FROM maps_v1 WHERE slug = $1", ["duplicate-slug"])
      [[kept_id_binary]] = kept_map.rows
      assert Ecto.UUID.load!(kept_id_binary) == map1_id

      # Verify the other maps were renamed with numeric suffixes
      {:ok, map2_result} =
        Repo.query("SELECT slug FROM maps_v1 WHERE id = $1", [Ecto.UUID.dump!(map2_id)])

      [[map2_slug]] = map2_result.rows
      assert map2_slug == "duplicate-slug-2"

      {:ok, map3_result} =
        Repo.query("SELECT slug FROM maps_v1 WHERE id = $1", [Ecto.UUID.dump!(map3_id)])

      [[map3_slug]] = map3_result.rows
      assert map3_slug == "duplicate-slug-3"

      # Recreate index after test
      create_unique_index()
    end

    test "handles deleted maps with duplicate slugs" do
      user = create_test_user()

      # Temporarily drop the unique index
      drop_unique_index()

      # Create duplicates including deleted ones
      map1_id = insert_map_directly("deleted-dup", "Map 1", user.id, false)
      map2_id = insert_map_directly("deleted-dup", "Map 2", user.id, true)
      map3_id = insert_map_directly("deleted-dup", "Map 3", user.id, false)

      assert count_maps_with_slug("deleted-dup") == 3

      # Run recovery - should handle all maps regardless of deleted status
      assert {:ok, result} = SlugRecovery.recover_duplicate_slug("deleted-dup")
      assert result.fixed_count == 2

      # Only one map should have the original slug
      assert count_maps_with_slug("deleted-dup") == 1

      # The oldest (map1) should have kept the slug
      {:ok, kept_map} = Repo.query("SELECT id FROM maps_v1 WHERE slug = $1", ["deleted-dup"])
      [[kept_id_binary]] = kept_map.rows
      assert Ecto.UUID.load!(kept_id_binary) == map1_id

      # Recreate index after test
      create_unique_index()
    end

    test "generates unique slugs when numeric suffixes already exist" do
      user = create_test_user()

      # Temporarily drop the unique index
      drop_unique_index()

      # Create maps with conflicting slugs including numeric suffixes
      map1_id = insert_map_directly("test", "Map 1", user.id, false)
      _map2_id = insert_map_directly("test-2", "Map 2", user.id, false)
      map3_id = insert_map_directly("test", "Map 3", user.id, false)

      # Run recovery on "test"
      assert {:ok, result} = SlugRecovery.recover_duplicate_slug("test")
      assert result.fixed_count == 1

      # Map 3 should get "test-3" since "test-2" is already taken
      {:ok, map3} =
        Repo.query("SELECT slug FROM maps_v1 WHERE id = $1", [Ecto.UUID.dump!(map3_id)])

      assert map3.rows == [["test-3"]]

      # Recreate index after test
      create_unique_index()
    end
  end

  describe "recover_all_duplicates/0" do
    test "finds and fixes all duplicate slugs in database" do
      user = create_test_user()

      # Temporarily drop the unique index
      drop_unique_index()

      # Create multiple sets of duplicates
      insert_map_directly("dup1", "Map 1", user.id, false)
      insert_map_directly("dup1", "Map 2", user.id, false)

      insert_map_directly("dup2", "Map 3", user.id, false)
      insert_map_directly("dup2", "Map 4", user.id, false)
      insert_map_directly("dup2", "Map 5", user.id, false)

      # Create a unique one (should be ignored)
      insert_map_directly("unique", "Unique", user.id, false)

      # Run full recovery
      assert {:ok, stats} = SlugRecovery.recover_all_duplicates()
      assert stats.total_slugs_fixed == 2
      assert stats.total_maps_renamed == 3

      # Verify all duplicates are fixed
      {:ok, result} =
        Repo.query("SELECT slug, COUNT(*) FROM maps_v1 GROUP BY slug HAVING COUNT(*) > 1")

      assert result.rows == []

      # Recreate index after test
      create_unique_index()
    end

    test "returns ok when no duplicates exist" do
      user = create_test_user()

      # Create only unique maps
      insert_map_directly("unique1", "Map 1", user.id, false)
      insert_map_directly("unique2", "Map 2", user.id, false)

      assert {:ok, stats} = SlugRecovery.recover_all_duplicates()
      assert stats.total_slugs_fixed == 0
      assert stats.total_maps_renamed == 0
    end
  end

  describe "verify_unique_index/0" do
    test "returns :exists when index is present" do
      # The index should exist from migrations
      assert {:ok, :exists} = SlugRecovery.verify_unique_index()
    end
  end

  describe "integration with MapRepo.get_map_by_slug_safely/1" do
    test "automatically recovers and retries when duplicates are found" do
      user = create_test_user()

      # Temporarily drop the unique index
      drop_unique_index()

      # Create duplicates
      _map1_id = insert_map_directly("auto-recover", "Map 1", user.id, false)
      _map2_id = insert_map_directly("auto-recover", "Map 2", user.id, false)

      # Verify duplicates exist
      assert count_maps_with_slug("auto-recover") == 2

      # Call get_map_by_slug_safely - should automatically recover and succeed
      assert {:ok, map} = WandererApp.MapRepo.get_map_by_slug_safely("auto-recover")
      assert map.slug == "auto-recover"

      # Verify duplicates were fixed
      assert count_maps_with_slug("auto-recover") == 1

      # Recreate index after test
      create_unique_index()
    end

    test "returns error after failed recovery attempt" do
      # This test simulates a scenario where recovery fails
      # In practice, this would be rare, but we should handle it gracefully

      # Try to get a non-existent slug
      assert {:error, :unknown_error} = WandererApp.MapRepo.get_map_by_slug_safely("nonexistent")
    end
  end

  # Helper functions

  defp create_test_user do
    # Use factory to create character with proper database setup
    # This ensures the character is properly inserted and visible in async tests
    insert(:character)
  end

  defp create_map(user, slug) do
    Map.new(%{
      name: "Test Map",
      slug: slug,
      owner_id: user.id,
      scope: :wormholes
    })
  end

  defp insert_map_directly(slug, name, owner_id, deleted) do
    # Insert directly into database to bypass Ash validations
    # This simulates the duplicate slug scenario that can happen in production

    # Convert UUID string to binary format for PostgreSQL
    owner_id_binary = Ecto.UUID.dump!(owner_id)

    query = """
    INSERT INTO maps_v1 (id, slug, name, owner_id, deleted, scope, inserted_at, updated_at)
    VALUES (gen_random_uuid(), $1, $2, $3, $4, 'wormholes', NOW(), NOW())
    RETURNING id
    """

    {:ok, result} = Repo.query(query, [slug, name, owner_id_binary, deleted])
    [[id]] = result.rows
    # Convert binary UUID back to string for comparisons
    Ecto.UUID.load!(id)
  end

  defp count_maps_with_slug(slug) do
    {:ok, result} = Repo.query("SELECT COUNT(*) FROM maps_v1 WHERE slug = $1", [slug])
    [[count]] = result.rows
    count
  end

  defp drop_unique_index do
    # Drop the unique index to allow duplicate slugs for testing
    Repo.query("DROP INDEX IF EXISTS maps_v1_unique_slug_index", [])
    :ok
  end

  defp create_unique_index do
    # Recreate the unique index (may fail if duplicates exist)
    # Note: Index now applies to all maps, including deleted ones
    Repo.query(
      """
      CREATE UNIQUE INDEX IF NOT EXISTS maps_v1_unique_slug_index
      ON maps_v1 (slug)
      """,
      []
    )

    :ok
  end
end
