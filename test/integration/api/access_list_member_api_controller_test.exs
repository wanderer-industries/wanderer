defmodule WandererAppWeb.AccessListMemberAPIControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererApp.Factory
  import Mox

  setup :verify_on_exit!

  describe "POST /api/acls/:acl_id/members (create)" do
    setup :setup_map_authentication

    test "creates a character member", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Mock ESI character info lookup
      expect(WandererApp.Esi.Mock, :get_character_info, fn "12345678" ->
        {:ok, %{"name" => "Test Character"}}
      end)

      member_params = %{
        "member" => %{
          "eve_character_id" => "12345678",
          "role" => "viewer"
        }
      }

      conn = post(conn, ~p"/api/acls/#{acl.id}/members", member_params)

      assert %{
               "data" => %{
                 "id" => id,
                 "name" => "Test Character",
                 "role" => "viewer",
                 "eve_character_id" => "12345678"
               }
             } = json_response(conn, 200)

      assert id != nil
    end

    test "creates a corporation member", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Mock ESI corporation info lookup
      expect(WandererApp.Esi.Mock, :get_corporation_info, fn "98765432" ->
        {:ok, %{"name" => "Test Corporation"}}
      end)

      member_params = %{
        "member" => %{
          "eve_corporation_id" => "98765432",
          "role" => "viewer"
        }
      }

      conn = post(conn, ~p"/api/acls/#{acl.id}/members", member_params)

      assert %{
               "data" => %{
                 "name" => "Test Corporation",
                 "role" => "viewer",
                 "eve_corporation_id" => "98765432"
               }
             } = json_response(conn, 200)
    end

    test "creates an alliance member", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Mock ESI alliance info lookup
      expect(WandererApp.Esi.Mock, :get_alliance_info, fn "11111111" ->
        {:ok, %{"name" => "Test Alliance"}}
      end)

      member_params = %{
        "member" => %{
          "eve_alliance_id" => "11111111",
          "role" => "viewer"
        }
      }

      conn = post(conn, ~p"/api/acls/#{acl.id}/members", member_params)

      assert %{
               "data" => %{
                 "name" => "Test Alliance",
                 "role" => "viewer",
                 "eve_alliance_id" => "11111111"
               }
             } = json_response(conn, 200)
    end

    test "prevents corporation members from having admin/manager roles", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      member_params = %{
        "member" => %{
          "eve_corporation_id" => "98765432",
          "role" => "admin"
        }
      }

      conn = post(conn, ~p"/api/acls/#{acl.id}/members", member_params)

      assert %{
               "error" => "Corporation members cannot have an admin or manager role"
             } = json_response(conn, 400)
    end

    test "prevents alliance members from having admin/manager roles", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      member_params = %{
        "member" => %{
          "eve_alliance_id" => "11111111",
          "role" => "manager"
        }
      }

      conn = post(conn, ~p"/api/acls/#{acl.id}/members", member_params)

      assert %{
               "error" => "Alliance members cannot have an admin or manager role"
             } = json_response(conn, 400)
    end

    test "requires one of eve_character_id, eve_corporation_id, or eve_alliance_id", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      member_params = %{
        "member" => %{
          "role" => "viewer"
        }
      }

      conn = post(conn, ~p"/api/acls/#{acl.id}/members", member_params)

      assert %{
               "error" =>
                 "Missing one of eve_character_id, eve_corporation_id, or eve_alliance_id in payload"
             } = json_response(conn, 400)
    end

    test "handles ESI lookup failures", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Mock ESI character info lookup failure
      expect(WandererApp.Esi.Mock, :get_character_info, fn "99999999" ->
        {:error, "Character not found"}
      end)

      member_params = %{
        "member" => %{
          "eve_character_id" => "99999999",
          "role" => "viewer"
        }
      }

      conn = post(conn, ~p"/api/acls/#{acl.id}/members", member_params)

      assert %{
               "error" => error_msg
             } = json_response(conn, 400)

      assert error_msg =~ "Entity lookup failed"
    end
  end

  describe "PUT /api/acls/:acl_id/members/:member_id (update_role)" do
    setup :setup_map_authentication

    test "updates character member role", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      member =
        Factory.insert(:access_list_member, %{
          access_list_id: acl.id,
          name: "Test Character",
          role: "viewer",
          eve_character_id: "12345678"
        })

      update_params = %{
        "member" => %{
          "role" => "manager"
        }
      }

      conn = put(conn, ~p"/api/acls/#{acl.id}/members/12345678", update_params)

      assert %{
               "data" => %{
                 "id" => ^member.id,
                 "role" => "manager",
                 "eve_character_id" => "12345678"
               }
             } = json_response(conn, 200)
    end

    test "prevents updating corporation member to admin role", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      Factory.insert(:access_list_member, %{
        access_list_id: acl.id,
        name: "Test Corporation",
        role: "viewer",
        eve_corporation_id: "98765432"
      })

      update_params = %{
        "member" => %{
          "role" => "admin"
        }
      }

      conn = put(conn, ~p"/api/acls/#{acl.id}/members/98765432", update_params)

      assert %{
               "error" => "Corporation members cannot have an admin or manager role"
             } = json_response(conn, 400)
    end

    test "returns 404 for non-existent member", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      update_params = %{
        "member" => %{
          "role" => "manager"
        }
      }

      conn = put(conn, ~p"/api/acls/#{acl.id}/members/99999999", update_params)

      assert %{
               "error" => "Membership not found for given ACL and external id"
             } = json_response(conn, 404)
    end

    test "works with corporation member by corporation ID", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      member =
        Factory.insert(:access_list_member, %{
          access_list_id: acl.id,
          name: "Test Corporation",
          role: "viewer",
          eve_corporation_id: "98765432"
        })

      update_params = %{
        "member" => %{
          # Same role, but valid for corporation
          "role" => "viewer"
        }
      }

      conn = put(conn, ~p"/api/acls/#{acl.id}/members/98765432", update_params)

      assert %{
               "data" => %{
                 "id" => ^member.id,
                 "role" => "viewer",
                 "eve_corporation_id" => "98765432"
               }
             } = json_response(conn, 200)
    end
  end

  describe "DELETE /api/acls/:acl_id/members/:member_id (delete)" do
    setup :setup_map_authentication

    test "deletes a character member", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      member =
        Factory.insert(:access_list_member, %{
          access_list_id: acl.id,
          name: "Test Character",
          role: "viewer",
          eve_character_id: "12345678"
        })

      conn = delete(conn, ~p"/api/acls/#{acl.id}/members/12345678")

      assert %{"ok" => true} = json_response(conn, 200)

      # Verify member was deleted
      assert {:ok, []} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id == ^member.id)
               |> WandererApp.Api.read()
    end

    test "deletes a corporation member", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      member =
        Factory.insert(:access_list_member, %{
          access_list_id: acl.id,
          name: "Test Corporation",
          role: "viewer",
          eve_corporation_id: "98765432"
        })

      conn = delete(conn, ~p"/api/acls/#{acl.id}/members/98765432")

      assert %{"ok" => true} = json_response(conn, 200)

      # Verify member was deleted
      assert {:ok, []} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id == ^member.id)
               |> WandererApp.Api.read()
    end

    test "returns 404 for non-existent member", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      conn = delete(conn, ~p"/api/acls/#{acl.id}/members/99999999")

      assert %{
               "error" => "Membership not found for given ACL and external id"
             } = json_response(conn, 404)
    end

    test "deletes only the member from the specified ACL", %{conn: conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl1 = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL 1"})
      acl2 = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL 2"})

      # Same character in two different ACLs
      member1 =
        Factory.insert(:access_list_member, %{
          access_list_id: acl1.id,
          name: "Test Character",
          role: "viewer",
          eve_character_id: "12345678"
        })

      member2 =
        Factory.insert(:access_list_member, %{
          access_list_id: acl2.id,
          name: "Test Character",
          role: "admin",
          eve_character_id: "12345678"
        })

      conn = delete(conn, ~p"/api/acls/#{acl1.id}/members/12345678")

      assert %{"ok" => true} = json_response(conn, 200)

      # Verify only member1 was deleted
      assert {:ok, []} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id == ^member1.id)
               |> WandererApp.Api.read()

      assert {:ok, [_]} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id == ^member2.id)
               |> WandererApp.Api.read()
    end
  end
end
