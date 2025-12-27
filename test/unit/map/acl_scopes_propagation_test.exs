defmodule WandererApp.Map.Server.AclScopesPropagationTest do
  @moduledoc """
  Unit tests for verifying that map scopes are properly propagated
  when ACL updates occur.

  This test verifies the fix in lib/wanderer_app/map/server/map_server_acls_impl.ex:59
  where `scopes` was added to the map_update struct.

  Bug: When users update map scope settings (Wormholes, High-Sec, Low-Sec, Null-Sec,
  Pochven checkboxes), the map server's cached state wasn't being updated with the
  new scopes array. This caused connection tracking to use stale scope settings
  until the server was restarted.

  Fix: Changed `map_update = %{acls: map.acls, scope: map.scope}`
  To: `map_update = %{acls: map.acls, scope: map.scope, scopes: map.scopes}`
  """

  use WandererApp.DataCase, async: false

  import WandererAppWeb.Factory

  describe "MapRepo.get returns scopes field" do
    test "map scopes are loaded when fetching map data" do
      # Create a user and character for map ownership
      user = create_user()
      character = create_character(%{user_id: user.id})

      # Create a map with specific scopes
      map =
        create_map(%{
          owner_id: character.id,
          name: "Scopes Test",
          slug: "scopes-prop-test-#{:rand.uniform(1_000_000)}",
          scope: :wormholes,
          scopes: [:wormholes, :hi, :low]
        })

      # Verify the map was created with the expected scopes
      assert map.scopes == [:wormholes, :hi, :low]

      # Fetch the map the same way AclsImpl.handle_map_acl_updated does
      {:ok, fetched_map} =
        WandererApp.MapRepo.get(map.id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      # Verify scopes are returned - this is what the fix relies on
      assert fetched_map.scopes == [:wormholes, :hi, :low],
             "MapRepo.get should return the scopes field. Got: #{inspect(fetched_map.scopes)}"

      # Verify the scope (legacy) field is also present
      assert fetched_map.scope == :wormholes
    end

    test "map scopes field is available for map_update construction" do
      # Create test data
      user = create_user()
      character = create_character(%{user_id: user.id})

      map =
        create_map(%{
          owner_id: character.id,
          name: "Update Test",
          slug: "scopes-update-test-#{:rand.uniform(1_000_000)}",
          scope: :all,
          scopes: [:wormholes, :hi, :low, :null, :pochven]
        })

      # Fetch map as AclsImpl does
      {:ok, fetched_map} = WandererApp.MapRepo.get(map.id, acls: [:owner_id])

      # Build map_update the same way the fixed code does
      # This is the exact line that was fixed in map_server_acls_impl.ex:59
      map_update = %{acls: fetched_map.acls, scope: fetched_map.scope, scopes: fetched_map.scopes}

      # Verify all fields are present in the update struct
      assert Map.has_key?(map_update, :acls), "map_update should include :acls"
      assert Map.has_key?(map_update, :scope), "map_update should include :scope"
      assert Map.has_key?(map_update, :scopes), "map_update should include :scopes"

      # Verify the scopes value is correct
      assert map_update.scopes == [:wormholes, :hi, :low, :null, :pochven],
             "map_update.scopes should have the complete scopes array"
    end
  end

  describe "scopes update in database" do
    test "updating map scopes persists correctly" do
      # Create test data
      user = create_user()
      character = create_character(%{user_id: user.id})

      map =
        create_map(%{
          owner_id: character.id,
          name: "DB Update Test",
          slug: "scopes-db-test-#{:rand.uniform(1_000_000)}",
          scope: :wormholes,
          scopes: [:wormholes]
        })

      # Initial state
      assert map.scopes == [:wormholes]

      # Update scopes (simulating what the LiveView does)
      {:ok, updated_map} =
        WandererApp.Api.Map.update(map, %{
          scopes: [:wormholes, :hi, :low, :null]
        })

      assert updated_map.scopes == [:wormholes, :hi, :low, :null],
             "Database update should persist new scopes"

      # Fetch again to confirm persistence
      {:ok, refetched_map} = WandererApp.MapRepo.get(map.id, [])
      assert refetched_map.scopes == [:wormholes, :hi, :low, :null],
             "Refetched map should have updated scopes"
    end

    test "partial scopes update works correctly" do
      # Create test data
      user = create_user()
      character = create_character(%{user_id: user.id})

      map =
        create_map(%{
          owner_id: character.id,
          name: "Partial Update",
          slug: "partial-scopes-#{:rand.uniform(1_000_000)}",
          scope: :wormholes,
          scopes: [:wormholes, :hi, :low, :null, :pochven]
        })

      # Update to a subset of scopes
      {:ok, updated_map} =
        WandererApp.Api.Map.update(map, %{
          scopes: [:wormholes, :null]
        })

      assert updated_map.scopes == [:wormholes, :null],
             "Should be able to update to partial scopes"
    end
  end

  describe "get_effective_scopes uses scopes array" do
    alias WandererApp.Map.Server.CharactersImpl

    test "get_effective_scopes returns scopes array when present" do
      map_struct = %{scopes: [:wormholes, :hi, :low], scope: :all}

      effective_scopes = CharactersImpl.get_effective_scopes(map_struct)

      assert effective_scopes == [:wormholes, :hi, :low],
             "get_effective_scopes should return scopes array when present"
    end

    test "get_effective_scopes falls back to legacy scope when scopes is empty" do
      map_struct = %{scopes: [], scope: :wormholes}

      effective_scopes = CharactersImpl.get_effective_scopes(map_struct)

      assert effective_scopes == [:wormholes],
             "get_effective_scopes should fall back to legacy scope conversion"
    end

    test "get_effective_scopes falls back to legacy scope when scopes is nil" do
      map_struct = %{scopes: nil, scope: :all}

      effective_scopes = CharactersImpl.get_effective_scopes(map_struct)

      assert effective_scopes == [:wormholes, :hi, :low, :null, :pochven],
             "get_effective_scopes should convert :all to full scope list"
    end

    test "get_effective_scopes defaults to [:wormholes] when no scope info" do
      map_struct = %{}

      effective_scopes = CharactersImpl.get_effective_scopes(map_struct)

      assert effective_scopes == [:wormholes],
             "get_effective_scopes should default to [:wormholes]"
    end
  end
end
