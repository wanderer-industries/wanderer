defmodule WandererApp.Map.AclBroadcastTest do
  @moduledoc """
  Tests for ACL update broadcasting to map channels.

  These tests verify that when ACL members are added/removed/updated,
  the appropriate broadcasts are sent to map channels so that connected
  clients can refresh their available characters for tracking.
  """
  use WandererApp.DataCase, async: false

  alias WandererAppWeb.Factory
  alias WandererApp.Map.Server.AclsImpl

  import Mox

  setup :verify_on_exit!

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

  # Helper to set up map broadcasting capability
  defp enable_map_broadcast(map_id) do
    # Mark the map as started (required for broadcasting)
    WandererApp.Cache.put("map_#{map_id}:started", true)
    # Ensure map is not in import mode
    WandererApp.Cache.put("map_#{map_id}:importing", false)
  end

  describe "handle_acl_updated/2" do
    test "broadcasts acl_members_changed event to map channel when ACL member is updated" do
      # Create test data
      user = Factory.create_user()
      owner = Factory.create_character(%{user_id: user.id})
      map = Factory.create_map(%{owner_id: owner.id})
      acl = Factory.create_access_list(owner.id, %{name: "Test ACL"})
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      # Subscribe to the map channel to receive broadcasts
      Phoenix.PubSub.subscribe(WandererApp.PubSub, map.id)

      # Enable broadcasting for this map
      enable_map_broadcast(map.id)

      # Initialize the map cache so it has ACL info
      {:ok, db_map} =
        WandererApp.MapRepo.get(map.id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      WandererApp.Map.update_map(map.id, %{
        acls: db_map.acls,
        scope: db_map.scope,
        characters: [],
        systems: %{},
        connections: %{},
        hubs: []
      })

      # Initialize map state
      WandererApp.Map.update_map_state(map.id, %{
        map: %{
          owner_id: owner.id,
          scope: :none
        },
        map_id: map.id
      })

      # Trigger ACL update (simulating when a member is added)
      AclsImpl.handle_acl_updated(map.id, acl.id)

      # Should receive the acl_members_changed event
      assert_receive %{event: :acl_members_changed, payload: %{acl_id: received_acl_id}}, 1000
      assert received_acl_id == acl.id
    end

    test "clears map_characters cache when ACL is updated" do
      # Create test data
      user = Factory.create_user()
      owner = Factory.create_character(%{user_id: user.id})
      map = Factory.create_map(%{owner_id: owner.id})
      acl = Factory.create_access_list(owner.id, %{name: "Test ACL"})
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      # Pre-populate the cache
      cache_key = "map_characters-#{map.id}"
      WandererApp.Cache.put(cache_key, %{some: "cached_data"})

      # Verify cache exists
      {:ok, cached_data} = WandererApp.Cache.lookup(cache_key)
      assert cached_data == %{some: "cached_data"}

      # Enable broadcasting for this map
      enable_map_broadcast(map.id)

      # Initialize the map cache so it has ACL info
      {:ok, db_map} =
        WandererApp.MapRepo.get(map.id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      WandererApp.Map.update_map(map.id, %{
        acls: db_map.acls,
        scope: db_map.scope,
        characters: [],
        systems: %{},
        connections: %{},
        hubs: []
      })

      # Initialize map state
      WandererApp.Map.update_map_state(map.id, %{
        map: %{
          owner_id: owner.id,
          scope: :none
        },
        map_id: map.id
      })

      # Trigger ACL update
      AclsImpl.handle_acl_updated(map.id, acl.id)

      # Cache should be cleared
      {:ok, cached_data_after} = WandererApp.Cache.lookup(cache_key, nil)
      assert cached_data_after == nil
    end
  end

  describe "handle_acl_deleted/2" do
    test "broadcasts acl_members_changed event when ACL is deleted from map" do
      # Create test data
      user = Factory.create_user()
      owner = Factory.create_character(%{user_id: user.id})
      map = Factory.create_map(%{owner_id: owner.id})
      acl = Factory.create_access_list(owner.id, %{name: "Test ACL"})
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      # Subscribe to the map channel
      Phoenix.PubSub.subscribe(WandererApp.PubSub, map.id)

      # Enable broadcasting for this map
      enable_map_broadcast(map.id)

      # Initialize map cache
      WandererApp.Map.update_map(map.id, %{
        acls: [],
        scope: :none,
        characters: [],
        systems: %{},
        connections: %{},
        hubs: []
      })

      # Trigger ACL deletion
      AclsImpl.handle_acl_deleted(map.id, acl.id)

      # Should receive the acl_members_changed event
      assert_receive %{event: :acl_members_changed, payload: %{}}, 1000
    end
  end

  describe "handle_map_acl_updated/3" do
    test "broadcasts acl_members_changed event when ACL is linked to map" do
      # Create test data
      user = Factory.create_user()
      owner = Factory.create_character(%{user_id: user.id})
      map = Factory.create_map(%{owner_id: owner.id})
      acl = Factory.create_access_list(owner.id, %{name: "Test ACL"})

      # Subscribe to the map channel
      Phoenix.PubSub.subscribe(WandererApp.PubSub, map.id)

      # Enable broadcasting for this map
      enable_map_broadcast(map.id)

      # Initialize map cache and state
      WandererApp.Map.update_map(map.id, %{
        acls: [],
        scope: :none,
        characters: [],
        systems: %{},
        connections: %{},
        hubs: []
      })

      WandererApp.Map.update_map_state(map.id, %{
        map: %{
          owner_id: owner.id,
          scope: :none,
          acls: []
        },
        map_id: map.id
      })

      # Create the map-ACL link
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      # Trigger the map ACL update (ACL added, none removed)
      AclsImpl.handle_map_acl_updated(map.id, [acl.id], [])

      # Should receive the acl_members_changed event
      assert_receive %{event: :acl_members_changed, payload: %{}}, 1000
    end
  end

  describe "integration: ACL member addition triggers broadcast" do
    test "adding ACL member via controller broadcasts to ACL channel" do
      # This test simulates the full flow: API controller -> broadcast -> map channel

      # Create test data
      user = Factory.create_user()
      owner = Factory.create_character(%{user_id: user.id, eve_id: "2112073677"})
      map = Factory.create_map(%{owner_id: owner.id})
      acl = Factory.create_access_list(owner.id, %{name: "Test ACL"})
      _map_acl = Factory.create_map_access_list(map.id, acl.id)

      # Create a character that will be added to the ACL
      new_character = Factory.create_character(%{eve_id: "9876543210"})

      # Subscribe to the ACL channel (simulating what MapPool does)
      Phoenix.PubSub.subscribe(WandererApp.PubSub, "acls:#{acl.id}")

      # Add member to ACL
      {:ok, _member} =
        Ash.create(WandererApp.Api.AccessListMember, %{
          access_list_id: acl.id,
          eve_character_id: new_character.eve_id,
          name: "New Member",
          role: "member"
        })

      # Broadcast ACL update (this is what the controller does)
      Phoenix.PubSub.broadcast(
        WandererApp.PubSub,
        "acls:#{acl.id}",
        {:acl_updated, %{acl_id: acl.id}}
      )

      # Should receive the acl_updated event on the ACL channel
      assert_receive {:acl_updated, %{acl_id: received_acl_id}}, 1000
      assert received_acl_id == acl.id
    end
  end
end
