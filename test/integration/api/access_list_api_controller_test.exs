defmodule WandererAppWeb.MapAccessListAPIControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererApp.Factory
  alias WandererApp.Api.{AccessList, Character}

  describe "GET /api/map/acls (index)" do
    setup :setup_map_authentication

    test "returns access lists for a map", %{conn: conn, map: map} do
      # Create a character to be the owner
      character = Factory.insert(:character, %{eve_id: "2112073677"})

      # Create access lists
      acl1 =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          name: "Test ACL 1",
          description: "First test ACL"
        })

      acl2 =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          name: "Test ACL 2",
          description: "Second test ACL"
        })

      # Associate ACLs with the map
      Factory.insert(:map_access_list, %{map_id: map.id, access_list_id: acl1.id})
      Factory.insert(:map_access_list, %{map_id: map.id, access_list_id: acl2.id})

      conn = get(conn, ~p"/api/map/acls", %{"slug" => map.slug})

      assert %{"data" => acls} = json_response(conn, 200)
      assert length(acls) == 2

      acl_names = Enum.map(acls, & &1["name"])
      assert "Test ACL 1" in acl_names
      assert "Test ACL 2" in acl_names
    end

    test "returns empty array when no ACLs exist", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/map/acls", %{"slug" => map.slug})
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 404 for non-existent map", %{conn: conn} do
      conn = get(conn, ~p"/api/map/acls", %{"slug" => "non-existent"})
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "accepts map_id parameter", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/map/acls", %{"map_id" => map.id})
      assert %{"data" => _} = json_response(conn, 200)
    end

    test "returns error when both map_id and slug provided", %{conn: conn, map: map} do
      conn = get(conn, ~p"/api/map/acls", %{"map_id" => map.id, "slug" => map.slug})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns error when neither map_id nor slug provided", %{conn: conn} do
      conn = get(conn, ~p"/api/map/acls", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  describe "POST /api/map/acls (create)" do
    setup :setup_map_authentication

    test "creates a new access list", %{conn: conn, map: map} do
      # Create a character to be the owner
      character = Factory.insert(:character, %{eve_id: "2112073677"})

      acl_params = %{
        "acl" => %{
          "owner_eve_id" => character.eve_id,
          "name" => "New ACL",
          "description" => "Test description"
        }
      }

      conn = post(conn, ~p"/api/map/acls?slug=#{map.slug}", acl_params)

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "New ACL",
                 "description" => "Test description",
                 "api_key" => api_key
               }
             } = json_response(conn, 201)

      assert id != nil
      assert api_key != nil

      # Verify ACL was created and associated with map
      {:ok, created_acl} = Ash.get(AccessList, id)
      assert created_acl.name == "New ACL"
    end

    test "validates required fields", %{conn: conn, map: map} do
      invalid_params = %{
        "acl" => %{
          "description" => "Missing required fields"
        }
      }

      conn = post(conn, ~p"/api/map/acls?slug=#{map.slug}", invalid_params)
      assert json_response(conn, 400)
    end

    test "validates owner_eve_id exists", %{conn: conn, map: map} do
      acl_params = %{
        "acl" => %{
          # Non-existent character
          "owner_eve_id" => "99999999",
          "name" => "New ACL"
        }
      }

      conn = post(conn, ~p"/api/map/acls?slug=#{map.slug}", acl_params)
      assert json_response(conn, 400)
    end

    test "requires map_id or slug parameter", %{conn: conn} do
      character = Factory.insert(:character, %{eve_id: "2112073677"})

      acl_params = %{
        "acl" => %{
          "owner_eve_id" => character.eve_id,
          "name" => "New ACL"
        }
      }

      conn = post(conn, ~p"/api/map/acls", acl_params)
      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  describe "GET /api/acls/:id (show)" do
    setup :setup_map_authentication

    test "returns access list details with members", %{conn: conn, map: map} do
      character = Factory.insert(:character, %{eve_id: "2112073677"})

      acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          name: "Test ACL",
          description: "Test description",
          api_key: "test-api-key"
        })

      # Add members to the ACL
      member1 =
        Factory.insert(:access_list_member, %{
          access_list_id: acl.id,
          name: "Member 1",
          role: "character",
          eve_character_id: "1234567"
        })

      member2 =
        Factory.insert(:access_list_member, %{
          access_list_id: acl.id,
          name: "Corp Member",
          role: "corporation",
          eve_corporation_id: "98765"
        })

      conn = get(conn, ~p"/api/acls/#{acl.id}")

      assert %{
               "data" => %{
                 "id" => ^acl.id,
                 "name" => "Test ACL",
                 "description" => "Test description",
                 "api_key" => "test-api-key",
                 "members" => members
               }
             } = json_response(conn, 200)

      assert length(members) == 2
      member_names = Enum.map(members, & &1["name"])
      assert "Member 1" in member_names
      assert "Corp Member" in member_names
    end

    test "returns 404 for non-existent ACL", %{conn: conn} do
      conn = get(conn, ~p"/api/acls/non-existent-id")
      assert json_response(conn, 404)
    end

    test "includes owner information", %{conn: conn} do
      character =
        Factory.insert(:character, %{
          eve_id: "2112073677",
          name: "Test Owner"
        })

      acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          name: "Test ACL"
        })

      conn = get(conn, ~p"/api/acls/#{acl.id}")

      assert %{
               "data" => %{
                 "owner" => %{
                   "id" => ^character.id,
                   "name" => "Test Owner"
                 }
               }
             } = json_response(conn, 200)
    end
  end

  describe "PUT /api/acls/:id (update)" do
    setup :setup_map_authentication

    test "updates access list attributes", %{conn: conn} do
      character = Factory.insert(:character, %{eve_id: "2112073677"})

      acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          name: "Original Name",
          description: "Original description"
        })

      update_params = %{
        "acl" => %{
          "name" => "Updated Name",
          "description" => "Updated description"
        }
      }

      conn = put(conn, ~p"/api/acls/#{acl.id}", update_params)

      assert %{
               "data" => %{
                 "id" => ^acl.id,
                 "name" => "Updated Name",
                 "description" => "Updated description"
               }
             } = json_response(conn, 200)

      # Verify the update persisted
      {:ok, updated_acl} = Ash.get(AccessList, acl.id)
      assert updated_acl.name == "Updated Name"
      assert updated_acl.description == "Updated description"
    end

    test "preserves api_key on update", %{conn: conn} do
      character = Factory.insert(:character, %{eve_id: "2112073677"})

      original_api_key = "original-api-key"

      acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          name: "Test ACL",
          api_key: original_api_key
        })

      update_params = %{
        "acl" => %{
          "name" => "Updated Name"
        }
      }

      conn = put(conn, ~p"/api/acls/#{acl.id}", update_params)

      assert %{
               "data" => %{
                 "api_key" => ^original_api_key
               }
             } = json_response(conn, 200)
    end

    test "returns 404 for non-existent ACL", %{conn: conn} do
      update_params = %{
        "acl" => %{
          "name" => "Updated Name"
        }
      }

      conn = put(conn, ~p"/api/acls/non-existent-id", update_params)
      assert json_response(conn, 404)
    end

    test "validates update parameters", %{conn: conn} do
      character = Factory.insert(:character, %{eve_id: "2112073677"})

      acl =
        Factory.insert(:access_list, %{
          owner_id: character.id,
          name: "Test ACL"
        })

      # Empty name should fail validation
      invalid_params = %{
        "acl" => %{
          "name" => ""
        }
      }

      conn = put(conn, ~p"/api/acls/#{acl.id}", invalid_params)
      assert json_response(conn, 422)
    end
  end
end
