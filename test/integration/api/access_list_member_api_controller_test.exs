defmodule WandererAppWeb.AccessListMemberAPIControllerTest do
  use WandererAppWeb.ApiCase

  alias WandererAppWeb.Factory
  import Mox
  require Ash.Query

  setup :verify_on_exit!

  setup do
    # Ensure we're in global mode and re-setup mocks
    # This ensures all processes can access the mocks
    Mox.set_mox_global()
    WandererApp.Test.Mocks.setup_additional_expectations()

    :ok
  end

  describe "POST /api/acls/:acl_id/members (create)" do
    setup :setup_map_authentication

    test "prevents corporation members from having admin/manager roles", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

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

    test "prevents alliance members from having admin/manager roles", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

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

    test "requires one of eve_character_id, eve_corporation_id, or eve_alliance_id", %{
      conn: _conn
    } do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

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
  end

  describe "PUT /api/acls/:acl_id/members/:member_id (update_role)" do
    setup :setup_map_authentication

    test "updates character member role", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

      member =
        Factory.create_access_list_member(acl.id, %{
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
      member_id = member.id

      assert %{
               "data" => %{
                 "id" => ^member_id,
                 "role" => "manager",
                 "eve_character_id" => "12345678"
               }
             } = json_response(conn, 200)
    end

    test "prevents updating corporation member to admin role", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

      Factory.create_access_list_member(acl.id, %{
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

    test "returns 404 for non-existent member", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

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

    test "works with corporation member by corporation ID", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

      member =
        Factory.create_access_list_member(acl.id, %{
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
      member_id = member.id

      assert %{
               "data" => %{
                 "id" => ^member_id,
                 "role" => "viewer",
                 "eve_corporation_id" => "98765432"
               }
             } = json_response(conn, 200)
    end
  end

  describe "DELETE /api/acls/:acl_id/members/:member_id (delete)" do
    setup :setup_map_authentication

    test "deletes a character member", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

      member =
        Factory.create_access_list_member(acl.id, %{
          name: "Test Character",
          role: "viewer",
          eve_character_id: "12345678"
        })

      conn = delete(conn, ~p"/api/acls/#{acl.id}/members/12345678")

      assert %{"ok" => true} = json_response(conn, 200)

      # Verify member was deleted
      assert {:ok, []} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id: member.id)
               |> Ash.read()
    end

    test "deletes a corporation member", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

      member =
        Factory.create_access_list_member(acl.id, %{
          name: "Test Corporation",
          role: "viewer",
          eve_corporation_id: "98765432"
        })

      conn = delete(conn, ~p"/api/acls/#{acl.id}/members/98765432")

      assert %{"ok" => true} = json_response(conn, 200)

      # Verify member was deleted
      assert {:ok, []} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id: member.id)
               |> Ash.read()
    end

    test "returns 404 for non-existent member", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL"})

      # Create connection with ACL API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl.api_key}")

      conn = delete(conn, ~p"/api/acls/#{acl.id}/members/99999999")

      assert %{
               "error" => "Membership not found for given ACL and external id"
             } = json_response(conn, 404)
    end

    test "deletes only the member from the specified ACL", %{conn: _conn} do
      owner = Factory.insert(:character, %{eve_id: "2112073677"})
      acl1 = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL 1"})
      acl2 = Factory.insert(:access_list, %{owner_id: owner.id, name: "Test ACL 2"})

      # Create connection with ACL1 API key
      conn = build_conn() |> put_req_header("authorization", "Bearer #{acl1.api_key}")

      # Same character in two different ACLs
      member1 =
        Factory.create_access_list_member(acl1.id, %{
          name: "Test Character",
          role: "viewer",
          eve_character_id: "12345678"
        })

      member2 =
        Factory.create_access_list_member(acl2.id, %{
          name: "Test Character",
          role: "admin",
          eve_character_id: "12345678"
        })

      conn = delete(conn, ~p"/api/acls/#{acl1.id}/members/12345678")

      assert %{"ok" => true} = json_response(conn, 200)

      # Verify only member1 was deleted
      assert {:ok, []} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id: member1.id)
               |> Ash.read()

      assert {:ok, [_]} =
               WandererApp.Api.AccessListMember
               |> Ash.Query.filter(id: member2.id)
               |> Ash.read()
    end
  end
end
