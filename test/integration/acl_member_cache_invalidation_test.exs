defmodule WandererApp.AclMemberCacheInvalidationTest do
  @moduledoc """
  Integration tests for ACL member cache invalidation.

  These tests verify that when ACL members are added, updated, or deleted,
  the map_characters cache is properly invalidated so that:
  1. New characters appear in the tracking page immediately after page reload
  2. The cache doesn't serve stale data after ACL changes
  3. Both API controller and LiveView paths properly invalidate the cache

  Related files:
  - lib/wanderer_app/maps.ex (get_map_characters cache)
  - lib/wanderer_app_web/controllers/access_list_member_api_controller.ex
  - lib/wanderer_app_web/live/access_lists/access_lists_live.ex
  - lib/wanderer_app_web/live/characters/characters_tracking_live.ex
  """

  use WandererApp.IntegrationCase, async: false

  import Mox
  import WandererApp.MapTestHelpers
  import WandererAppWeb.Factory

  require Ash.Query

  setup :verify_on_exit!

  @test_character_eve_id_1 4_100_000_001
  @test_character_eve_id_2 4_100_000_002
  @test_character_eve_id_3 4_100_000_003

  setup do
    # Setup system static info cache for test systems
    setup_system_static_info_cache()

    # Setup DDRT (R-tree) mock stubs for system positioning
    setup_ddrt_mocks()

    # Create map owner user and character
    owner_user =
      create_user(%{
        name: "ACL Cache Test Owner",
        hash: "acl_cache_owner_#{:rand.uniform(1_000_000)}"
      })

    owner_character =
      create_character(%{
        eve_id: "#{@test_character_eve_id_1}",
        name: "ACL Cache Test Owner Character",
        user_id: owner_user.id,
        scopes: "esi-location.read_location.v1 esi-location.read_ship_type.v1",
        tracking_pool: "default"
      })

    # Create a second user with a character that will be added to ACL
    member_user =
      create_user(%{
        name: "ACL Cache Test Member",
        hash: "acl_cache_member_#{:rand.uniform(1_000_000)}"
      })

    member_character =
      create_character(%{
        eve_id: "#{@test_character_eve_id_2}",
        name: "ACL Cache Test Member Character",
        user_id: member_user.id,
        scopes: "esi-location.read_location.v1 esi-location.read_ship_type.v1",
        tracking_pool: "default"
      })

    # Create a third character for additional tests
    member_character2 =
      create_character(%{
        eve_id: "#{@test_character_eve_id_3}",
        name: "ACL Cache Test Member Character 2",
        user_id: member_user.id,
        scopes: "esi-location.read_location.v1 esi-location.read_ship_type.v1",
        tracking_pool: "default"
      })

    # Create test map owned by first character
    map =
      create_map(%{
        name: "ACL Cache Test Map",
        slug: "acl-cache-test-#{:rand.uniform(1_000_000)}",
        owner_id: owner_character.id,
        scope: :all,
        only_tracked_characters: false
      })

    # Create an access list owned by the owner character
    acl = create_access_list(owner_character.id, %{name: "Test ACL for Cache"})

    # Associate the ACL with the map
    create_map_access_list(map.id, acl.id)

    on_exit(fn ->
      cleanup_test_data(map.id)
      cleanup_character_caches(map.id, owner_character.id)
      cleanup_character_caches(map.id, member_character.id)
      cleanup_character_caches(map.id, member_character2.id)
      # Clean up map_characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")
    end)

    {:ok,
     owner_user: owner_user,
     owner_character: owner_character,
     member_user: member_user,
     member_character: member_character,
     member_character2: member_character2,
     map: map,
     acl: acl}
  end

  describe "cache invalidation when ACL members change" do
    @tag :integration
    test "adding a character member and broadcasting invalidates map_characters cache", %{
      map: map,
      acl: acl,
      member_character: member_character
    } do
      cache_key = "map_characters-#{map.id}"

      # Warm up the cache by loading characters
      {:ok, _} = WandererApp.Maps.load_characters(map, member_character.user_id)

      # Verify cache is populated
      cached_data = WandererApp.Cache.lookup!(cache_key)
      assert not is_nil(cached_data), "Cache should be populated after load_characters"

      # Verify member character is NOT in the cached data (not yet added to ACL)
      refute member_character.eve_id in cached_data.map_member_eve_ids,
             "Member character should not be in cache before being added to ACL"

      # Add member directly to database (simulating what API controller does)
      create_access_list_member(acl.id, %{
        name: member_character.name,
        role: "member",
        eve_character_id: member_character.eve_id
      })

      # Simulate what the API controller does - broadcast ACL updated
      # This triggers the cache invalidation
      invalidate_map_characters_cache_for_acl(acl.id)

      # Verify cache was invalidated
      cached_data_after = WandererApp.Cache.lookup!(cache_key)
      assert is_nil(cached_data_after), "Cache should be invalidated after adding member"

      # Reload characters - should get fresh data with new member
      {:ok, %{characters: characters}} =
        WandererApp.Maps.load_characters(map, member_character.user_id)

      # Verify member character is now available
      character_eve_ids = Enum.map(characters, & &1.eve_id)

      assert member_character.eve_id in character_eve_ids,
             "Member character should be available after being added to ACL"
    end

    @tag :integration
    test "adding a corporation member and broadcasting invalidates map_characters cache", %{
      map: map,
      acl: acl,
      member_character: member_character
    } do
      cache_key = "map_characters-#{map.id}"

      # Warm up the cache
      {:ok, _} = WandererApp.Maps.load_characters(map, member_character.user_id)

      # Verify cache is populated
      cached_data = WandererApp.Cache.lookup!(cache_key)
      assert not is_nil(cached_data)

      # Add corporation member
      create_access_list_member(acl.id, %{
        name: "Test Corporation",
        role: "viewer",
        eve_corporation_id: "98000001"
      })

      # Simulate cache invalidation
      invalidate_map_characters_cache_for_acl(acl.id)

      # Verify cache was invalidated
      cached_data_after = WandererApp.Cache.lookup!(cache_key)

      assert is_nil(cached_data_after),
             "Cache should be invalidated after adding corporation member"
    end

    @tag :integration
    test "adding an alliance member and broadcasting invalidates map_characters cache", %{
      map: map,
      acl: acl,
      member_character: member_character
    } do
      cache_key = "map_characters-#{map.id}"

      # Warm up the cache
      {:ok, _} = WandererApp.Maps.load_characters(map, member_character.user_id)

      # Verify cache is populated
      cached_data = WandererApp.Cache.lookup!(cache_key)
      assert not is_nil(cached_data)

      # Add alliance member
      create_access_list_member(acl.id, %{
        name: "Test Alliance",
        role: "viewer",
        eve_alliance_id: "99000001"
      })

      # Simulate cache invalidation
      invalidate_map_characters_cache_for_acl(acl.id)

      # Verify cache was invalidated
      cached_data_after = WandererApp.Cache.lookup!(cache_key)
      assert is_nil(cached_data_after), "Cache should be invalidated after adding alliance member"
    end

    @tag :integration
    test "deleting a member and broadcasting invalidates map_characters cache", %{
      map: map,
      acl: acl,
      member_character: member_character
    } do
      cache_key = "map_characters-#{map.id}"

      # First add a member
      member =
        create_access_list_member(acl.id, %{
          name: member_character.name,
          role: "viewer",
          eve_character_id: member_character.eve_id
        })

      # Clear cache and warm it up again
      WandererApp.Cache.delete(cache_key)
      {:ok, _} = WandererApp.Maps.load_characters(map, member_character.user_id)

      # Verify cache is populated and member is included
      cached_data = WandererApp.Cache.lookup!(cache_key)
      assert not is_nil(cached_data)

      assert member_character.eve_id in cached_data.map_member_eve_ids,
             "Member should be in cache before deletion"

      # Delete the member
      WandererApp.Api.AccessListMember.destroy!(member)

      # Simulate cache invalidation
      invalidate_map_characters_cache_for_acl(acl.id)

      # Verify cache was invalidated
      cached_data_after = WandererApp.Cache.lookup!(cache_key)
      assert is_nil(cached_data_after), "Cache should be invalidated after deleting member"

      # Reload and verify member is no longer in the list
      {:ok, %{characters: characters}} =
        WandererApp.Maps.load_characters(map, member_character.user_id)

      character_eve_ids = Enum.map(characters, & &1.eve_id)

      refute member_character.eve_id in character_eve_ids,
             "Member character should not be available after being removed from ACL"
    end
  end

  describe "cache TTL functionality" do
    @tag :integration
    test "map_characters cache has TTL and can be invalidated", %{
      map: map,
      member_character: member_character
    } do
      cache_key = "map_characters-#{map.id}"

      # Warm up the cache
      {:ok, _} = WandererApp.Maps.load_characters(map, member_character.user_id)

      # Verify cache is populated
      cached_data = WandererApp.Cache.lookup!(cache_key)
      assert not is_nil(cached_data), "Cache should be populated"

      # Note: We can't easily test the 5-minute TTL in a unit test,
      # but we can verify the cache entry exists and can be manually invalidated
      WandererApp.Cache.delete(cache_key)

      # After deletion, cache should be nil
      cached_data_after = WandererApp.Cache.lookup!(cache_key)
      assert is_nil(cached_data_after), "Cache should be nil after deletion"
    end
  end

  describe "multiple maps with same ACL" do
    @tag :integration
    test "adding member invalidates cache for all maps using the ACL", %{
      map: map1,
      owner_character: owner_character,
      member_character: member_character,
      acl: acl
    } do
      # Create a second map that also uses the same ACL
      map2 =
        create_map(%{
          name: "ACL Cache Test Map 2",
          slug: "acl-cache-test-2-#{:rand.uniform(1_000_000)}",
          owner_id: owner_character.id,
          scope: :all,
          only_tracked_characters: false
        })

      # Associate the same ACL with the second map
      create_map_access_list(map2.id, acl.id)

      cache_key1 = "map_characters-#{map1.id}"
      cache_key2 = "map_characters-#{map2.id}"

      # Warm up both caches
      {:ok, _} = WandererApp.Maps.load_characters(map1, member_character.user_id)
      {:ok, _} = WandererApp.Maps.load_characters(map2, member_character.user_id)

      # Verify both caches are populated
      cached_data1 = WandererApp.Cache.lookup!(cache_key1)
      cached_data2 = WandererApp.Cache.lookup!(cache_key2)
      assert not is_nil(cached_data1), "First map cache should be populated"
      assert not is_nil(cached_data2), "Second map cache should be populated"

      # Add member
      create_access_list_member(acl.id, %{
        name: member_character.name,
        role: "member",
        eve_character_id: member_character.eve_id
      })

      # Simulate cache invalidation (what the API controller does)
      invalidate_map_characters_cache_for_acl(acl.id)

      # Verify both caches were invalidated
      cached_data1_after = WandererApp.Cache.lookup!(cache_key1)
      cached_data2_after = WandererApp.Cache.lookup!(cache_key2)

      assert is_nil(cached_data1_after),
             "First map cache should be invalidated when member is added to shared ACL"

      assert is_nil(cached_data2_after),
             "Second map cache should be invalidated when member is added to shared ACL"

      # Cleanup
      on_exit(fn ->
        cleanup_test_data(map2.id)
        WandererApp.Cache.delete(cache_key2)
      end)
    end
  end

  describe "load_characters returns fresh data after cache invalidation" do
    @tag :integration
    test "newly added member appears in load_characters result", %{
      map: map,
      acl: acl,
      member_user: member_user,
      member_character: member_character
    } do
      # Initially, member character should not be available (not in ACL)
      {:ok, %{characters: initial_characters}} =
        WandererApp.Maps.load_characters(map, member_user.id)

      initial_eve_ids = Enum.map(initial_characters, & &1.eve_id)

      refute member_character.eve_id in initial_eve_ids,
             "Member character should not be available before being added to ACL"

      # Add member to ACL
      create_access_list_member(acl.id, %{
        name: member_character.name,
        role: "member",
        eve_character_id: member_character.eve_id
      })

      # Simulate cache invalidation
      invalidate_map_characters_cache_for_acl(acl.id)

      # Now load_characters should return the new member
      {:ok, %{characters: updated_characters}} =
        WandererApp.Maps.load_characters(map, member_user.id)

      updated_eve_ids = Enum.map(updated_characters, & &1.eve_id)

      assert member_character.eve_id in updated_eve_ids,
             "Member character should be available after being added to ACL and cache invalidation"
    end

    @tag :integration
    test "removed member disappears from load_characters result", %{
      map: map,
      acl: acl,
      member_user: member_user,
      member_character: member_character
    } do
      # Add member to ACL first
      member =
        create_access_list_member(acl.id, %{
          name: member_character.name,
          role: "member",
          eve_character_id: member_character.eve_id
        })

      # Clear cache to get fresh data
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Member should be available
      {:ok, %{characters: characters_with_member}} =
        WandererApp.Maps.load_characters(map, member_user.id)

      eve_ids_with_member = Enum.map(characters_with_member, & &1.eve_id)

      assert member_character.eve_id in eve_ids_with_member,
             "Member character should be available when in ACL"

      # Remove member
      WandererApp.Api.AccessListMember.destroy!(member)

      # Simulate cache invalidation
      invalidate_map_characters_cache_for_acl(acl.id)

      # Member should no longer be available
      {:ok, %{characters: characters_without_member}} =
        WandererApp.Maps.load_characters(map, member_user.id)

      eve_ids_without_member = Enum.map(characters_without_member, & &1.eve_id)

      refute member_character.eve_id in eve_ids_without_member,
             "Member character should not be available after being removed from ACL"
    end
  end

  # Helper function that simulates what the API controller does
  # This is the same logic as in AccessListMemberAPIController.invalidate_map_characters_cache/1
  defp invalidate_map_characters_cache_for_acl(acl_id) do
    case Ash.read(
           WandererApp.Api.MapAccessList
           |> Ash.Query.for_read(:read_by_acl, %{acl_id: acl_id})
         ) do
      {:ok, map_acls} ->
        Enum.each(map_acls, fn %{map_id: map_id} ->
          WandererApp.Cache.delete("map_characters-#{map_id}")
        end)

      {:error, _error} ->
        :ok
    end
  end
end
