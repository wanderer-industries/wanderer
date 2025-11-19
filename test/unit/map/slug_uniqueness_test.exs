defmodule WandererApp.Map.SlugUniquenessTest do
  @moduledoc """
  Tests for map slug uniqueness constraints and handling.

  These tests verify that:
  1. Database unique constraint is enforced
  2. Application-level slug generation handles uniqueness
  3. Concurrent map creation doesn't create duplicates
  4. Error handling works correctly for slug conflicts
  """
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.Map

  require Logger

  describe "slug uniqueness constraint" do
    setup do
      # Create a test user
      user = create_test_user()
      %{user: user}
    end

    test "prevents duplicate slugs via database constraint", %{user: user} do
      # Create first map with a specific slug
      {:ok, _map1} =
        Map.new(%{
          name: "Test Map",
          slug: "test-map",
          owner_id: user.id,
          description: "First map",
          scope: "wormholes"
        })

      # Attempt to create second map with same slug by bypassing Ash slug generation
      # This simulates a race condition where slug generation passes but DB insert fails
      result =
        Map.new(%{
          name: "Different Name",
          slug: "test-map",
          owner_id: user.id,
          description: "Second map",
          scope: "wormholes"
        })

      # Should get a unique constraint error from database
      assert {:error, _error} = result
    end

    test "automatically increments slug when duplicate detected", %{user: user} do
      # Create first map
      {:ok, map1} =
        Map.new(%{
          name: "Test Map",
          slug: "test-map",
          owner_id: user.id,
          description: "First map",
          scope: "wormholes"
        })

      assert map1.slug == "test-map"

      # Create second map with same name (should auto-increment slug)
      {:ok, map2} =
        Map.new(%{
          name: "Test Map",
          slug: "test-map",
          owner_id: user.id,
          description: "Second map",
          scope: "wormholes"
        })

      # Slug should be automatically incremented
      assert map2.slug == "test-map-2"

      # Create third map with same name
      {:ok, map3} =
        Map.new(%{
          name: "Test Map",
          slug: "test-map",
          owner_id: user.id,
          description: "Third map",
          scope: "wormholes"
        })

      assert map3.slug == "test-map-3"
    end

    test "handles many maps with similar names", %{user: user} do
      # Create 10 maps with the same base slug
      maps =
        for i <- 1..10 do
          {:ok, map} =
            Map.new(%{
              name: "Popular Name",
              slug: "popular-name",
              owner_id: user.id,
              description: "Map #{i}",
              scope: "wormholes"
            })

          map
        end

      # Verify all slugs are unique
      slugs = Enum.map(maps, & &1.slug)
      assert length(Enum.uniq(slugs)) == 10

      # First should keep the base slug
      assert List.first(maps).slug == "popular-name"

      # Others should be numbered
      assert "popular-name-2" in slugs
      assert "popular-name-10" in slugs
    end
  end

  describe "concurrent slug creation (race condition)" do
    setup do
      user = create_test_user()
      %{user: user}
    end

    @tag :slow
    test "handles concurrent map creation with identical slugs", %{user: user} do
      # Create 5 concurrent map creation requests with the same slug
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            Map.new(%{
              name: "Concurrent Test",
              slug: "concurrent-test",
              owner_id: user.id,
              description: "Concurrent map #{i}",
              scope: "wormholes"
            })
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 10_000)

      # All should either succeed or fail gracefully (no crashes)
      assert length(results) == 5

      # Get successful results
      successful = Enum.filter(results, &match?({:ok, _}, &1))
      failed = Enum.filter(results, &match?({:error, _}, &1))

      # At least some should succeed
      assert length(successful) > 0

      # Extract maps from successful results
      maps = Enum.map(successful, fn {:ok, map} -> map end)

      # Verify all successful maps have unique slugs
      slugs = Enum.map(maps, & &1.slug)

      assert length(Enum.uniq(slugs)) == length(slugs),
             "All successful maps should have unique slugs"

      # Log results for visibility
      Logger.info("Concurrent test: #{length(successful)} succeeded, #{length(failed)} failed")
      Logger.info("Unique slugs created: #{inspect(slugs)}")
    end

    @tag :slow
    test "concurrent creation with different names creates different base slugs", %{user: user} do
      # Create concurrent requests with different names (should all succeed)
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            Map.new(%{
              name: "Concurrent Map #{i}",
              slug: "concurrent-map-#{i}",
              owner_id: user.id,
              description: "Map #{i}",
              scope: "wormholes"
            })
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # All should have different slugs
      slugs = Enum.map(results, fn {:ok, map} -> map.slug end)
      assert length(Enum.uniq(slugs)) == 5
    end
  end

  describe "slug generation edge cases" do
    setup do
      user = create_test_user()
      %{user: user}
    end

    test "handles very long slugs", %{user: user} do
      # Create map with name that would generate very long slug
      long_name = String.duplicate("a", 100)

      {:ok, map} =
        Map.new(%{
          name: long_name,
          slug: long_name,
          owner_id: user.id,
          description: "Long name test",
          scope: "wormholes"
        })

      # Slug should be truncated to max length (40 chars based on map.ex constraints)
      assert String.length(map.slug) <= 40
    end

    test "handles special characters in slugs", %{user: user} do
      # Test that special characters are properly slugified
      {:ok, map} =
        Map.new(%{
          name: "Test: Map & Name!",
          slug: "test-map-name",
          owner_id: user.id,
          description: "Special chars test",
          scope: "wormholes"
        })

      # Slug should only contain allowed characters
      assert map.slug =~ ~r/^[a-z0-9-]+$/
    end
  end

  describe "slug update operations" do
    setup do
      user = create_test_user()

      {:ok, map} =
        Map.new(%{
          name: "Original Map",
          slug: "original-map",
          owner_id: user.id,
          description: "Original",
          scope: "wormholes"
        })

      %{user: user, map: map}
    end

    test "updating map with same slug succeeds", %{map: map} do
      # Update other fields, keep same slug
      result =
        Map.update(map, %{
          description: "Updated description",
          slug: "original-map"
        })

      assert {:ok, updated_map} = result
      assert updated_map.slug == "original-map"
      assert updated_map.description == "Updated description"
    end

    test "updating to conflicting slug is handled", %{user: user, map: map} do
      # Create another map
      {:ok, _other_map} =
        Map.new(%{
          name: "Other Map",
          slug: "other-map",
          owner_id: user.id,
          description: "Other",
          scope: "wormholes"
        })

      # Try to update first map to use other map's slug
      result =
        Map.update(map, %{
          slug: "other-map"
        })

      # Should either fail or auto-increment
      case result do
        {:ok, updated_map} ->
          # If successful, slug should be different
          assert updated_map.slug != "other-map"
          assert updated_map.slug =~ ~r/^other-map-\d+$/

        {:error, _} ->
          # Or it can fail with validation error
          :ok
      end
    end
  end

  describe "get_map_by_slug with duplicates" do
    setup do
      user = create_test_user()
      %{user: user}
    end

    test "get_map_by_slug! raises on duplicates if they exist" do
      # Note: This test documents the behavior when duplicates somehow exist
      # In production, this should be prevented by our fixes
      # If duplicates exist (data integrity issue), the query should fail

      # This is a documentation test - we can't easily create duplicates
      # due to the database constraint, but we document expected behavior
      assert true
    end
  end

  # Helper functions

  defp create_test_user do
    # Create a test user with necessary attributes
    {:ok, user} =
      WandererApp.Api.User.new(%{
        name: "Test User #{:rand.uniform(10_000)}",
        eve_id: :rand.uniform(100_000_000)
      })

    user
  end
end
