defmodule WandererApp.Character.TrackingPermissionFilterTest do
  @moduledoc """
  Tests for the tracking permission filtering in TrackingUtils.

  These tests verify that:
  1. Map owners can always see their characters for tracking
  2. Characters belonging to the same user as the map owner can track
  3. Characters with member/manager/admin ACL roles can track
  4. Characters with viewer ACL role cannot track (filtered out)
  5. Characters added via corporation membership work correctly
  6. Characters added via alliance membership work correctly
  """

  use WandererApp.IntegrationCase, async: false

  import Mox
  import WandererApp.MapTestHelpers

  setup :verify_on_exit!

  @test_character_eve_id_base 2_300_000_000

  setup do
    # Setup system static info cache for test systems
    setup_system_static_info_cache()

    # Setup DDRT (R-tree) mock stubs for system positioning
    setup_ddrt_mocks()

    :ok
  end

  describe "build_tracking_data/2 filters characters by tracking permission" do
    test "map owner can see their character for tracking" do
      # Create owner user and character
      owner_user = create_user(%{name: "Owner User", hash: "owner_hash_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 1}",
          name: "Owner Character",
          user_id: owner_user.id,
          corporation_id: 1_000_000_001,
          corporation_ticker: "OWNR"
        })

      # Create map owned by this character
      map =
        create_map(%{
          name: "Owner Test Map",
          slug: "owner-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Build tracking data
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, owner_user.id)

      # Owner should see their character
      assert length(tracking_data.characters) == 1
      assert hd(tracking_data.characters).character.eve_id == owner_character.eve_id
    end

    test "character belonging to same user as map owner can track" do
      # Create owner user with two characters
      owner_user = create_user(%{name: "Multi Char User", hash: "multi_hash_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 10}",
          name: "Owner Main",
          user_id: owner_user.id,
          corporation_id: 1_000_000_010,
          corporation_ticker: "MAIN"
        })

      alt_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 11}",
          name: "Owner Alt",
          user_id: owner_user.id,
          corporation_id: 1_000_000_011,
          corporation_ticker: "ALT"
        })

      # Create map owned by the main character
      map =
        create_map(%{
          name: "Multi Char Test Map",
          slug: "multi-char-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add alt character (even though same user, we need ACL for load_characters)
      acl = create_access_list(owner_character.id, %{name: "Test ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_character_id: alt_character.eve_id,
        name: alt_character.name,
        role: :viewer
      })

      # Clear map characters cache to pick up new ACL
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, owner_user.id)

      # Both characters should be visible (owner + same user)
      character_eve_ids = Enum.map(tracking_data.characters, & &1.character.eve_id)
      assert owner_character.eve_id in character_eve_ids
      assert alt_character.eve_id in character_eve_ids
    end

    test "character with member role can track" do
      # Create map owner
      owner_user = create_user(%{name: "Map Owner", hash: "map_owner_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 20}",
          name: "Map Owner Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_020,
          corporation_ticker: "OWN"
        })

      # Create member user and character
      member_user = create_user(%{name: "Member User", hash: "member_hash_#{unique_id()}"})

      member_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 21}",
          name: "Member Character",
          user_id: member_user.id,
          corporation_id: 1_000_000_021,
          corporation_ticker: "MEMB"
        })

      # Create map
      map =
        create_map(%{
          name: "Member Test Map",
          slug: "member-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add member character with :member role
      acl = create_access_list(owner_character.id, %{name: "Member ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_character_id: member_character.eve_id,
        name: member_character.name,
        role: :member
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for member user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, member_user.id)

      # Member should see their character
      assert length(tracking_data.characters) == 1
      assert hd(tracking_data.characters).character.eve_id == member_character.eve_id
    end

    test "character with viewer role cannot track (filtered out)" do
      # Create map owner
      owner_user = create_user(%{name: "Map Owner V", hash: "map_owner_v_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 30}",
          name: "Map Owner V Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_030,
          corporation_ticker: "OWNV"
        })

      # Create viewer user and character
      viewer_user = create_user(%{name: "Viewer User", hash: "viewer_hash_#{unique_id()}"})

      viewer_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 31}",
          name: "Viewer Character",
          user_id: viewer_user.id,
          corporation_id: 1_000_000_031,
          corporation_ticker: "VIEW"
        })

      # Create map
      map =
        create_map(%{
          name: "Viewer Test Map",
          slug: "viewer-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add viewer character with :viewer role
      acl = create_access_list(owner_character.id, %{name: "Viewer ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_character_id: viewer_character.eve_id,
        name: viewer_character.name,
        role: :viewer
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for viewer user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, viewer_user.id)

      # Viewer should NOT see their character (filtered out due to no track_character permission)
      assert length(tracking_data.characters) == 0
    end

    test "character with manager role can track" do
      # Create map owner
      owner_user = create_user(%{name: "Map Owner M", hash: "map_owner_m_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 40}",
          name: "Map Owner M Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_040,
          corporation_ticker: "OWNM"
        })

      # Create manager user and character
      manager_user = create_user(%{name: "Manager User", hash: "manager_hash_#{unique_id()}"})

      manager_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 41}",
          name: "Manager Character",
          user_id: manager_user.id,
          corporation_id: 1_000_000_041,
          corporation_ticker: "MNGR"
        })

      # Create map
      map =
        create_map(%{
          name: "Manager Test Map",
          slug: "manager-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add manager character with :manager role
      acl = create_access_list(owner_character.id, %{name: "Manager ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_character_id: manager_character.eve_id,
        name: manager_character.name,
        role: :manager
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for manager user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, manager_user.id)

      # Manager should see their character
      assert length(tracking_data.characters) == 1
      assert hd(tracking_data.characters).character.eve_id == manager_character.eve_id
    end

    test "character with admin role can track" do
      # Create map owner
      owner_user = create_user(%{name: "Map Owner A", hash: "map_owner_a_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 50}",
          name: "Map Owner A Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_050,
          corporation_ticker: "OWNA"
        })

      # Create admin user and character
      admin_user = create_user(%{name: "Admin User", hash: "admin_hash_#{unique_id()}"})

      admin_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 51}",
          name: "Admin Character",
          user_id: admin_user.id,
          corporation_id: 1_000_000_051,
          corporation_ticker: "ADMN"
        })

      # Create map
      map =
        create_map(%{
          name: "Admin Test Map",
          slug: "admin-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add admin character with :admin role
      acl = create_access_list(owner_character.id, %{name: "Admin ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_character_id: admin_character.eve_id,
        name: admin_character.name,
        role: :admin
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for admin user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, admin_user.id)

      # Admin should see their character
      assert length(tracking_data.characters) == 1
      assert hd(tracking_data.characters).character.eve_id == admin_character.eve_id
    end

    test "character added via corporation membership with member role can track" do
      # Create map owner
      owner_user = create_user(%{name: "Map Owner Corp", hash: "map_owner_corp_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 60}",
          name: "Map Owner Corp Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_060,
          corporation_ticker: "OWNC"
        })

      # Create corp member user and character
      corp_member_user =
        create_user(%{name: "Corp Member User", hash: "corp_member_hash_#{unique_id()}"})

      # This character's corporation will be added to ACL
      test_corp_id = 1_000_000_061

      corp_member_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 61}",
          name: "Corp Member Character",
          user_id: corp_member_user.id,
          corporation_id: test_corp_id,
          corporation_ticker: "CORP"
        })

      # Create map
      map =
        create_map(%{
          name: "Corp Test Map",
          slug: "corp-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add corporation with :member role
      acl = create_access_list(owner_character.id, %{name: "Corp ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_corporation_id: "#{test_corp_id}",
        name: "Test Corporation",
        role: :member
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for corp member user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, corp_member_user.id)

      # Corp member should see their character
      assert length(tracking_data.characters) == 1
      assert hd(tracking_data.characters).character.eve_id == corp_member_character.eve_id
    end

    test "character added via corporation membership with viewer role cannot track" do
      # Create map owner
      owner_user =
        create_user(%{name: "Map Owner Corp V", hash: "map_owner_corp_v_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 70}",
          name: "Map Owner Corp V Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_070,
          corporation_ticker: "OWCV"
        })

      # Create corp viewer user and character
      corp_viewer_user =
        create_user(%{name: "Corp Viewer User", hash: "corp_viewer_hash_#{unique_id()}"})

      test_corp_id = 1_000_000_071

      corp_viewer_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 71}",
          name: "Corp Viewer Character",
          user_id: corp_viewer_user.id,
          corporation_id: test_corp_id,
          corporation_ticker: "CRPV"
        })

      # Create map
      map =
        create_map(%{
          name: "Corp Viewer Test Map",
          slug: "corp-viewer-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add corporation with :viewer role
      acl = create_access_list(owner_character.id, %{name: "Corp Viewer ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_corporation_id: "#{test_corp_id}",
        name: "Test Corporation Viewer",
        role: :viewer
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for corp viewer user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, corp_viewer_user.id)

      # Corp viewer should NOT see their character
      assert length(tracking_data.characters) == 0
    end

    test "character added via alliance membership with member role can track" do
      # Create map owner
      owner_user =
        create_user(%{name: "Map Owner Alliance", hash: "map_owner_alliance_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 80}",
          name: "Map Owner Alliance Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_080,
          corporation_ticker: "OWNA"
        })

      # Create alliance member user and character
      alliance_member_user =
        create_user(%{name: "Alliance Member User", hash: "alliance_member_hash_#{unique_id()}"})

      test_alliance_id = 99_000_001

      alliance_member_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 81}",
          name: "Alliance Member Character",
          user_id: alliance_member_user.id,
          corporation_id: 1_000_000_081,
          corporation_ticker: "ALLY",
          alliance_id: test_alliance_id,
          alliance_ticker: "ALLI"
        })

      # Create map
      map =
        create_map(%{
          name: "Alliance Test Map",
          slug: "alliance-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add alliance with :member role
      acl = create_access_list(owner_character.id, %{name: "Alliance ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_alliance_id: "#{test_alliance_id}",
        name: "Test Alliance",
        role: :member
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for alliance member user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, alliance_member_user.id)

      # Alliance member should see their character
      assert length(tracking_data.characters) == 1
      assert hd(tracking_data.characters).character.eve_id == alliance_member_character.eve_id
    end

    test "empty characters list when user has no characters with access" do
      # Create map owner
      owner_user =
        create_user(%{name: "Map Owner Empty", hash: "map_owner_empty_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 90}",
          name: "Map Owner Empty Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_090,
          corporation_ticker: "OWNE"
        })

      # Create user with no ACL access
      no_access_user =
        create_user(%{name: "No Access User", hash: "no_access_hash_#{unique_id()}"})

      _no_access_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 91}",
          name: "No Access Character",
          user_id: no_access_user.id,
          corporation_id: 1_000_000_091,
          corporation_ticker: "NONE"
        })

      # Create map
      map =
        create_map(%{
          name: "No Access Test Map",
          slug: "no-access-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Don't add any ACL for the no_access_user

      # Build tracking data for no_access_user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, no_access_user.id)

      # No characters should be visible
      assert length(tracking_data.characters) == 0
    end

    test "blocked character cannot track" do
      # Create map owner
      owner_user =
        create_user(%{name: "Map Owner Blocked", hash: "map_owner_blocked_#{unique_id()}"})

      owner_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 100}",
          name: "Map Owner Blocked Char",
          user_id: owner_user.id,
          corporation_id: 1_000_000_100,
          corporation_ticker: "OWNB"
        })

      # Create blocked user and character
      blocked_user = create_user(%{name: "Blocked User", hash: "blocked_hash_#{unique_id()}"})

      blocked_character =
        create_character(%{
          eve_id: "#{@test_character_eve_id_base + 101}",
          name: "Blocked Character",
          user_id: blocked_user.id,
          corporation_id: 1_000_000_101,
          corporation_ticker: "BLKD"
        })

      # Create map
      map =
        create_map(%{
          name: "Blocked Test Map",
          slug: "blocked-test-#{unique_id()}",
          owner_id: owner_character.id,
          scope: :all
        })

      # Create ACL and add blocked character with :blocked role
      acl = create_access_list(owner_character.id, %{name: "Blocked ACL #{unique_id()}"})
      create_map_access_list(map.id, acl.id)

      create_access_list_member(acl.id, %{
        eve_character_id: blocked_character.eve_id,
        name: blocked_character.name,
        role: :blocked
      })

      # Clear map characters cache
      WandererApp.Cache.delete("map_characters-#{map.id}")

      # Build tracking data for blocked user
      {:ok, tracking_data} =
        WandererApp.Character.TrackingUtils.build_tracking_data(map.id, blocked_user.id)

      # Blocked character should NOT see their character
      assert length(tracking_data.characters) == 0
    end
  end

  # Helper to generate unique IDs
  defp unique_id, do: System.unique_integer([:positive])
end
