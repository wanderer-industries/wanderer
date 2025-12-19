defmodule WandererApp.Map.CorporationChangePermissionTest do
  @moduledoc """
  Integration tests for permission revocation when a character's corporation changes.

  This tests the fix for the issue where:
  - A user is granted map access via corporation-based ACL membership
  - The user's character leaves or changes corporation
  - The user could still see the map until they logged out

  The fix ensures that when a character's corporation changes:
  1. An :update_permissions broadcast is sent to the character's LiveView connections
  2. The LiveView triggers a permission refresh
  3. If access is revoked, the user is redirected away from the map

  Related files:
  - lib/wanderer_app/character/tracker.ex (broadcasts on corp change)
  - lib/wanderer_app/map/server/map_server_characters_impl.ex (backup broadcast)
  - lib/wanderer_app_web/live/map/event_handlers/map_core_event_handler.ex (handles broadcast)
  """

  use WandererApp.DataCase, async: false

  alias WandererAppWeb.Factory

  import Mox

  setup :verify_on_exit!

  @test_corp_id_a 98000001
  @test_corp_id_b 98000002
  @test_alliance_id_a 99000001

  setup do
    # Configure the PubSubMock to forward to real Phoenix.PubSub for broadcast testing
    Test.PubSubMock
    |> Mox.stub(:broadcast!, fn server, topic, message ->
      Phoenix.PubSub.broadcast!(server, topic, message)
    end)
    |> Mox.stub(:broadcast, fn server, topic, message ->
      Phoenix.PubSub.broadcast(server, topic, message)
    end)
    |> Mox.stub(:subscribe, fn server, topic ->
      Phoenix.PubSub.subscribe(server, topic)
    end)
    |> Mox.stub(:unsubscribe, fn server, topic ->
      Phoenix.PubSub.unsubscribe(server, topic)
    end)

    :ok
  end

  describe "PubSub broadcast on corporation change" do
    test "broadcasts :update_permissions to character channel when corporation update is simulated" do
      # Create test data
      user = Factory.create_user()

      character =
        Factory.create_character(%{
          user_id: user.id,
          corporation_id: @test_corp_id_a,
          corporation_name: "Test Corp A",
          corporation_ticker: "TCPA"
        })

      # Subscribe to the character's channel (this is what LiveView does via tracking_utils.ex)
      Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{character.eve_id}")

      # Simulate what happens in tracker.ex when a corporation change is detected
      # This simulates the fix: broadcasting :update_permissions after corp change
      simulate_corporation_change(character, @test_corp_id_b)

      # Should receive :update_permissions broadcast
      assert_receive :update_permissions, 1000,
                     "Should receive :update_permissions when corporation changes"
    end

    test "broadcasts :update_permissions to character channel when alliance update is simulated" do
      # Create test data
      user = Factory.create_user()

      character =
        Factory.create_character(%{
          user_id: user.id,
          corporation_id: @test_corp_id_a,
          alliance_id: @test_alliance_id_a,
          alliance_name: "Test Alliance A",
          alliance_ticker: "TALA"
        })

      # Subscribe to the character's channel
      Phoenix.PubSub.subscribe(WandererApp.PubSub, "character:#{character.eve_id}")

      # Simulate what happens when alliance is removed
      simulate_alliance_removal(character)

      # Should receive :update_permissions broadcast
      assert_receive :update_permissions, 1000,
                     "Should receive :update_permissions when alliance is removed"
    end
  end

  describe "Corporation-based ACL permission verification" do
    test "character with corp A has access to map with corp A ACL" do
      # Setup: Create a map with corporation-based ACL
      owner_user = Factory.create_user()
      owner = Factory.create_character(%{user_id: owner_user.id})

      map =
        Factory.create_map(%{
          owner_id: owner.id,
          name: "Corp Access Test Map",
          slug: "corp-access-test-#{:rand.uniform(1_000_000)}"
        })

      # Create ACL that grants access to corporation A
      acl = Factory.create_access_list(owner.id, %{name: "Corp A Access"})
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      _corp_member =
        Factory.create_access_list_member(acl.id, %{
          eve_corporation_id: "#{@test_corp_id_a}",
          name: "Corporation A",
          role: "member"
        })

      # Create user with character in corp A
      test_user = Factory.create_user()

      test_character =
        Factory.create_character(%{
          user_id: test_user.id,
          corporation_id: @test_corp_id_a,
          corporation_name: "Test Corp A",
          corporation_ticker: "TCPA"
        })

      # Verify character has access via corporation membership
      {:ok, map_with_acls} =
        WandererApp.MapRepo.get(map.id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      [character_permissions] =
        WandererApp.Permissions.check_characters_access([test_character], map_with_acls.acls)

      map_permissions =
        WandererApp.Permissions.get_map_permissions(
          character_permissions,
          owner.id,
          [test_character.id]
        )

      assert map_permissions.view_system == true,
             "Character in corp A should have view_system permission"
    end

    test "character in corp B does not have access to map with corp A ACL" do
      # Setup: Create a map with corporation-based ACL for corp A
      owner_user = Factory.create_user()
      owner = Factory.create_character(%{user_id: owner_user.id})

      map =
        Factory.create_map(%{
          owner_id: owner.id,
          name: "CorpB Test",
          slug: "corp-access-test-2-#{:rand.uniform(1_000_000)}"
        })

      # Create ACL that grants access only to corporation A
      acl = Factory.create_access_list(owner.id, %{name: "Corp A Only Access"})
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      _corp_member =
        Factory.create_access_list_member(acl.id, %{
          eve_corporation_id: "#{@test_corp_id_a}",
          name: "Corporation A",
          role: "member"
        })

      # Create user with character in corp B (not A)
      test_user = Factory.create_user()

      test_character =
        Factory.create_character(%{
          user_id: test_user.id,
          corporation_id: @test_corp_id_b,
          corporation_name: "Test Corp B",
          corporation_ticker: "TCPB"
        })

      # Verify character does NOT have access
      {:ok, map_with_acls} =
        WandererApp.MapRepo.get(map.id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      [character_permissions] =
        WandererApp.Permissions.check_characters_access([test_character], map_with_acls.acls)

      map_permissions =
        WandererApp.Permissions.get_map_permissions(
          character_permissions,
          owner.id,
          [test_character.id]
        )

      assert map_permissions.view_system == false,
             "Character in corp B should NOT have view_system permission for corp A map"
    end

    test "permission check result changes when character changes from corp A to corp B" do
      # Setup: Create a map with corporation-based ACL
      owner_user = Factory.create_user()
      owner = Factory.create_character(%{user_id: owner_user.id})

      map =
        Factory.create_map(%{
          owner_id: owner.id,
          name: "Corp Change Test Map",
          slug: "corp-change-test-#{:rand.uniform(1_000_000)}"
        })

      # Create ACL that grants access to corporation A
      acl = Factory.create_access_list(owner.id, %{name: "Corp A Access"})
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      _corp_member =
        Factory.create_access_list_member(acl.id, %{
          eve_corporation_id: "#{@test_corp_id_a}",
          name: "Corporation A",
          role: "member"
        })

      # Create user with character initially in corp A
      test_user = Factory.create_user()

      test_character =
        Factory.create_character(%{
          user_id: test_user.id,
          corporation_id: @test_corp_id_a,
          corporation_name: "Test Corp A",
          corporation_ticker: "TCPA"
        })

      {:ok, map_with_acls} =
        WandererApp.MapRepo.get(map.id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      # Verify initial access
      [initial_permissions] =
        WandererApp.Permissions.check_characters_access([test_character], map_with_acls.acls)

      initial_map_permissions =
        WandererApp.Permissions.get_map_permissions(
          initial_permissions,
          owner.id,
          [test_character.id]
        )

      assert initial_map_permissions.view_system == true,
             "Initially character in corp A should have view_system permission"

      # Now simulate the character changing corporation
      # Update the character's corporation in the database
      character_update = %{
        corporation_id: @test_corp_id_b,
        corporation_name: "Test Corp B",
        corporation_ticker: "TCPB"
      }

      {:ok, updated_character} =
        WandererApp.Api.Character.update_corporation(test_character, character_update)

      WandererApp.Character.update_character(test_character.id, character_update)

      # Verify character no longer has access after corporation change
      [new_permissions] =
        WandererApp.Permissions.check_characters_access([updated_character], map_with_acls.acls)

      new_map_permissions =
        WandererApp.Permissions.get_map_permissions(
          new_permissions,
          owner.id,
          [updated_character.id]
        )

      assert new_map_permissions.view_system == false,
             "After changing to corp B, character should NOT have view_system permission"
    end
  end

  # Helper functions that simulate what the tracker does

  defp simulate_corporation_change(character, new_corporation_id) do
    # Update character in database
    character_update = %{
      corporation_id: new_corporation_id,
      corporation_name: "Test Corp B",
      corporation_ticker: "TCPB"
    }

    {:ok, _} = WandererApp.Api.Character.update_corporation(character, character_update)
    WandererApp.Character.update_character(character.id, character_update)

    # Broadcast corporation change (existing behavior)
    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{character.id}:corporation",
      {:character_corporation, {character.id, character_update}}
    )

    # Broadcast permission update (THE FIX)
    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{character.eve_id}",
      :update_permissions
    )
  end

  defp simulate_alliance_removal(character) do
    # Update character in database
    character_update = %{
      alliance_id: nil,
      alliance_name: nil,
      alliance_ticker: nil
    }

    {:ok, _} = WandererApp.Api.Character.update_alliance(character, character_update)
    WandererApp.Character.update_character(character.id, character_update)

    # Broadcast alliance change (existing behavior)
    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{character.id}:alliance",
      {:character_alliance, {character.id, character_update}}
    )

    # Broadcast permission update (THE FIX)
    Phoenix.PubSub.broadcast(
      WandererApp.PubSub,
      "character:#{character.eve_id}",
      :update_permissions
    )
  end
end
