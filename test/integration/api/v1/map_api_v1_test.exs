defmodule WandererAppWeb.Integration.Api.V1.MapApiV1Test do
  @moduledoc """
  Integration tests for the v1 Maps API endpoint.

  Tests the security-critical GET /api/v1/maps endpoint to ensure:
  - Users can only see maps they own or have access to via ACLs
  - Map tokens properly scope the response to authorized maps
  - No unauthorized access to other users' maps
  """

  use WandererAppWeb.ConnCase, async: false

  import WandererAppWeb.Factory

  describe "GET /api/v1/maps - security and filtering" do
    setup do
      # Create two separate users
      user1 = insert(:user)
      user2 = insert(:user)

      character1 = insert(:character, %{user_id: user1.id})
      character2 = insert(:character, %{user_id: user2.id})

      # User1 owns two maps
      map1 = insert(:map, %{owner_id: character1.id, name: "User1 Map 1"})
      map2 = insert(:map, %{owner_id: character1.id, name: "User1 Map 2"})

      # User2 owns one map
      map3 = insert(:map, %{owner_id: character2.id, name: "User2 Map"})

      # Create an ACL and share map2 with character2
      acl = insert(:access_list, %{owner_id: character1.id, name: "Shared ACL"})

      insert(:access_list_member, %{
        access_list_id: acl.id,
        eve_character_id: character2.eve_id
      })

      insert(:map_access_list, %{
        map_id: map2.id,
        access_list_id: acl.id
      })

      %{
        user1: user1,
        user2: user2,
        character1: character1,
        character2: character2,
        map1: map1,
        map2: map2,
        map3: map3,
        acl: acl
      }
    end

    test "returns only the specific map for single map tokens", %{map1: map1, map2: map2} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map1.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => maps} = json_response(conn, 200)

      # Should see ONLY map1 (the map associated with this token)
      map_ids = Enum.map(maps, & &1["id"])
      assert length(map_ids) == 1
      assert map1.id in map_ids
      refute map2.id in map_ids
    end

    test "does not return other maps when using single map token", %{
      map1: map1,
      map2: map2,
      map3: map3
    } do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map1.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => maps} = json_response(conn, 200)

      # Should ONLY see map1 (the map associated with this token)
      # Should NOT see map2 (even though owned by same user) or map3 (owned by user2)
      map_ids = Enum.map(maps, & &1["id"])
      assert length(map_ids) == 1
      assert map1.id in map_ids
      refute map2.id in map_ids
      refute map3.id in map_ids
    end

    test "single map token returns only that map, not ACL shared maps", %{
      map2: map2,
      map3: map3,
      character2: character2
    } do
      # Use map3's token (owned by user2/character2)
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map3.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => maps} = json_response(conn, 200)

      # With single map token scoping, should ONLY see map3
      # Should NOT see map2 (even though shared via ACL) because token is scoped to map3
      map_ids = Enum.map(maps, & &1["id"])
      assert length(map_ids) == 1
      assert map3.id in map_ids
      refute map2.id in map_ids

      # Verify it's the correct map
      assert hd(maps)["attributes"]["name"] == "User2 Map"
    end

    test "does not return deleted maps", %{map1: map1, character1: character1} do
      # Mark map1 as deleted
      {:ok, _} =
        WandererApp.Api.Map.mark_as_deleted(map1, actor: character1)

      # Create a new map for the API key
      active_map = insert(:map, %{owner_id: character1.id, name: "Active Map"})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{active_map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => maps} = json_response(conn, 200)

      # Should only see active_map (the map associated with this token)
      # Should not see the deleted map1
      map_ids = Enum.map(maps, & &1["id"])
      assert length(map_ids) == 1
      refute map1.id in map_ids
      assert active_map.id in map_ids
    end

    test "returns correct map attributes", %{map1: map1} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map1.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => [map_data]} = json_response(conn, 200)

      # Verify standard JSON:API structure
      assert map_data["type"] == "maps"
      assert map_data["id"] == map1.id
      assert map_data["attributes"]["name"] == map1.name
      assert map_data["attributes"]["slug"] == map1.slug
    end

    test "returns 401 for invalid token" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid-token")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert json_response(conn, 401)
    end

    test "returns 401 for missing authorization header" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/maps - ACL filtering edge cases" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      # Create another character for the same user
      character2 = insert(:character, %{user_id: user.id})

      map1 = insert(:map, %{owner_id: character.id, name: "Primary Map"})

      # Create an ACL that includes character2 (not character1)
      acl = insert(:access_list, %{owner_id: character.id, name: "Alt Character ACL"})

      insert(:access_list_member, %{
        access_list_id: acl.id,
        eve_character_id: character2.eve_id
      })

      # Create a map shared with character2
      other_user = insert(:user)
      other_character = insert(:character, %{user_id: other_user.id})
      shared_map = insert(:map, %{owner_id: other_character.id, name: "Shared Map"})

      insert(:map_access_list, %{
        map_id: shared_map.id,
        access_list_id: acl.id
      })

      %{
        user: user,
        character: character,
        character2: character2,
        map1: map1,
        shared_map: shared_map
      }
    end

    test "single map token does not return maps shared with user's alternate characters", %{
      map1: map1,
      shared_map: shared_map
    } do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map1.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => maps} = json_response(conn, 200)

      # With single map token scoping, only the token's map is returned
      # NOT other maps shared with alternate characters
      map_ids = Enum.map(maps, & &1["id"])
      assert length(map_ids) == 1
      assert map1.id in map_ids
      refute shared_map.id in map_ids
    end
  end

  describe "GET /api/v1/maps - corporation and alliance ACLs" do
    setup do
      user = insert(:user)

      character =
        insert(:character, %{
          user_id: user.id,
          corporation_id: 98_000_001,
          corporation_name: "Test Corporation",
          corporation_ticker: "TEST"
        })

      # Update alliance info separately
      {:ok, character} =
        character
        |> Ash.Changeset.for_update(:update_alliance, %{
          alliance_id: 99_000_001,
          alliance_name: "Test Alliance",
          alliance_ticker: "TSTA"
        })
        |> Ash.update()

      map = insert(:map, %{owner_id: character.id, name: "My Map"})

      # Create another user's map shared via corporation ACL
      other_user = insert(:user)
      other_character = insert(:character, %{user_id: other_user.id})
      corp_shared_map = insert(:map, %{owner_id: other_character.id, name: "Corp Map"})

      corp_acl = insert(:access_list, %{owner_id: other_character.id, name: "Corp ACL"})

      insert(:access_list_member, %{
        access_list_id: corp_acl.id,
        eve_corporation_id: "98000001"
      })

      insert(:map_access_list, %{
        map_id: corp_shared_map.id,
        access_list_id: corp_acl.id
      })

      # Create another map shared via alliance ACL
      alliance_shared_map = insert(:map, %{owner_id: other_character.id, name: "Alliance Map"})

      alliance_acl = insert(:access_list, %{owner_id: other_character.id, name: "Alliance ACL"})

      insert(:access_list_member, %{
        access_list_id: alliance_acl.id,
        eve_alliance_id: "99000001"
      })

      insert(:map_access_list, %{
        map_id: alliance_shared_map.id,
        access_list_id: alliance_acl.id
      })

      %{
        map: map,
        corp_shared_map: corp_shared_map,
        alliance_shared_map: alliance_shared_map
      }
    end

    test "single map token does not return corporation ACL shared maps", %{
      map: map,
      corp_shared_map: corp_shared_map
    } do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => maps} = json_response(conn, 200)

      # With single map token scoping, only the token's map is returned
      # NOT other maps shared via ACL
      map_ids = Enum.map(maps, & &1["id"])
      assert length(map_ids) == 1
      assert map.id in map_ids
      refute corp_shared_map.id in map_ids
    end

    test "single map token does not return alliance ACL shared maps", %{
      map: map,
      alliance_shared_map: alliance_shared_map
    } do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("content-type", "application/vnd.api+json")

      conn = get(conn, "/api/v1/maps")

      assert %{"data" => maps} = json_response(conn, 200)

      # With single map token scoping, only the token's map is returned
      # NOT other maps shared via ACL
      map_ids = Enum.map(maps, & &1["id"])
      assert length(map_ids) == 1
      assert map.id in map_ids
      refute alliance_shared_map.id in map_ids
    end
  end
end
