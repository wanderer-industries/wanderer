defmodule WandererApp.AclsApiTest do
  use WandererApp.ApiCase
  use WandererApp.Test.CrudTestScaffolding

  @moduletag :api

  # Enhanced CRUD operations using scaffolding
  # Note: ACL CRUD endpoints use character authentication, not ACL API key
  test_crud_operations("ACL", "/api/acls", :character, %{
    setup_auth: fn ->
      owner = create_character(%{name: "ACL Owner"})
      acl_data = create_test_acl_with_auth(%{character: owner})
      Map.put(acl_data, :owner, owner) |> Map.put(:character, owner)
    end,
    create_params: fn ->
      %{"acl" => %{"name" => "Test ACL Creation", "description" => "Created via API test"}}
    end,
    update_params: fn ->
      %{"acl" => %{"name" => "Updated ACL Name", "description" => "Updated description"}}
    end,
    invalid_params: fn ->
      %{"acl" => %{"name" => ""}}
    end
  })

  test_validation_scenarios("ACL", "/api/acls", :character, %{
    setup_auth: fn ->
      owner = create_character(%{name: "ACL Owner"})
      acl_data = create_test_acl_with_auth(%{character: owner})
      Map.put(acl_data, :owner, owner) |> Map.put(:character, owner)
    end,
    create_params: fn ->
      %{"acl" => %{"name" => "Valid ACL", "description" => "Valid description"}}
    end,
    invalid_params: fn ->
      %{"acl" => %{"name" => ""}}
    end
  })

  test_authorization_scenarios("ACL", "/api/acls", :character, %{
    setup_auth: fn ->
      owner = create_character(%{name: "ACL Owner"})
      acl_data = create_test_acl_with_auth(%{character: owner})
      Map.put(acl_data, :owner, owner) |> Map.put(:character, owner)
    end,
    create_params: fn ->
      %{"acl" => %{"name" => "Test ACL", "description" => "Test"}}
    end
  })

  test_edge_case_scenarios("ACL", "/api/acls", :character, %{
    setup_auth: fn ->
      owner = create_character(%{name: "ACL Owner"})
      acl_data = create_test_acl_with_auth(%{character: owner})
      Map.put(acl_data, :owner, owner) |> Map.put(:character, owner)
    end,
    create_params: fn ->
      %{"acl" => %{"name" => "Concurrent ACL #{:rand.uniform(10000)}", "description" => "Test"}}
    end,
    update_params: fn ->
      %{"acl" => %{"name" => "Updated Name"}}
    end
  })

  describe "Legacy ACLs API CRUD operations" do
    setup do
      owner = create_character(%{name: "ACL Owner"})
      {:ok, owner: owner}
    end

    test "GET /api/acls/:id - retrieves ACL with valid authentication", %{conn: conn} do
      acl_data = create_test_acl_with_auth()

      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> get("/api/acls/#{acl_data.acl_id}")
        |> assert_success_response(200)

      assert response["data"]["id"] == acl_data.acl_id
      assert response["data"]["name"] == acl_data.acl.name
      assert response["data"]["description"] == acl_data.acl.description
    end

    test "GET /api/acls/:id - returns 401 without authentication", %{conn: conn} do
      acl_data = create_test_acl_with_auth()

      conn
      |> get("/api/acls/#{acl_data.acl_id}")
      |> assert_error_format(401)
    end

    test "GET /api/acls/:id - returns 401 with invalid API key", %{conn: conn} do
      acl_data = create_test_acl_with_auth()

      conn
      |> authenticate_acl("invalid-api-key")
      |> get("/api/acls/#{acl_data.acl_id}")
      |> assert_error_format(401)
    end

    test "POST /api/acls - creates new ACL", %{conn: conn, owner: owner} do
      acl_params = %{
        "name" => "Test ACL Creation",
        "description" => "Created via API test"
      }

      response =
        conn
        |> authenticate_character(owner)
        |> post("/api/acls", acl: acl_params)
        |> assert_success_response(201)

      assert response["data"]["name"] == "Test ACL Creation"
      assert response["data"]["description"] == "Created via API test"
      assert response["data"]["api_key"] != nil
    end

    test "PUT /api/acls/:id - updates ACL details", %{conn: conn} do
      acl_data = create_test_acl_with_auth()

      update_params = %{
        "name" => "Updated ACL Name",
        "description" => "Updated description via API"
      }

      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> put("/api/acls/#{acl_data.acl_id}", acl: update_params)
        |> assert_success_response(200)

      assert response["data"]["name"] == "Updated ACL Name"
      assert response["data"]["description"] == "Updated description via API"
    end
  end

  describe "ACL Members management" do
    setup do
      acl_data = create_test_acl_with_auth()
      {:ok, acl_data: acl_data}
    end

    test "GET /api/acls/:id/members - lists ACL members", %{conn: conn, acl_data: acl_data} do
      # Add some members
      _member1 =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_character_id: "95000001",
          name: "Test Character 1",
          role: "member"
        })

      _member2 =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_corporation_id: "98000001",
          name: "Test Corporation",
          role: "member"
        })

      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> get("/api/acls/#{acl_data.acl_id}/members")
        |> assert_success_response(200)

      assert length(response["data"]) == 2
    end

    test "POST /api/acls/:id/members - adds character member", %{conn: conn, acl_data: acl_data} do
      member_params = %{
        "eve_character_id" => "95000001",
        "role" => "member"
      }

      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> post("/api/acls/#{acl_data.acl_id}/members", member: member_params)
        |> assert_success_response(201)

      assert response["data"]["eve_character_id"] == "95000001"
      # From ESI mock
      assert response["data"]["name"] == "Test Character 95000001"
      assert response["data"]["role"] == "member"
    end

    test "POST /api/acls/:id/members - adds corporation member", %{conn: conn, acl_data: acl_data} do
      member_params = %{
        "eve_corporation_id" => "98000001",
        "role" => "member"
      }

      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> post("/api/acls/#{acl_data.acl_id}/members", member: member_params)
        |> assert_success_response(201)

      assert response["data"]["eve_corporation_id"] == "98000001"
      # From ESI mock
      assert response["data"]["name"] == "Test Corporation 98000001"
      assert response["data"]["role"] == "member"
    end

    test "POST /api/acls/:id/members - adds alliance member", %{conn: conn, acl_data: acl_data} do
      member_params = %{
        "eve_alliance_id" => "99000001",
        "role" => "member"
      }

      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> post("/api/acls/#{acl_data.acl_id}/members", member: member_params)
        |> assert_success_response(201)

      assert response["data"]["eve_alliance_id"] == "99000001"
      # From ESI mock
      assert response["data"]["name"] == "Test Alliance 99000001"
      assert response["data"]["role"] == "member"
    end

    test "PUT /api/acls/:id/members/:member_id - updates member role", %{
      conn: conn,
      acl_data: acl_data
    } do
      member =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_character_id: "95000001",
          name: "Test Character",
          role: "member"
        })

      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> put("/api/acls/#{acl_data.acl_id}/members/#{member.eve_character_id}", %{
          "member" => %{"role" => "admin"}
        })
        |> assert_success_response(200)

      assert response["data"]["role"] == "admin"
    end

    test "DELETE /api/acls/:id/members/:member_id - removes member", %{
      conn: conn,
      acl_data: acl_data
    } do
      member =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_character_id: "95000001",
          name: "Test Character",
          role: "member"
        })

      conn
      |> authenticate_acl(acl_data.api_key)
      |> delete("/api/acls/#{acl_data.acl_id}/members/#{member.eve_character_id}")
      |> assert_success_response(204)

      # Verify member is removed
      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> get("/api/acls/#{acl_data.acl_id}/members")
        |> json_response!(200)

      assert length(response["data"]) == 0
    end

    test "POST /api/acls/:id/members - prevents duplicate members", %{
      conn: conn,
      acl_data: acl_data
    } do
      # Add member first time
      member_params = %{
        "eve_character_id" => "95000001",
        "role" => "member"
      }

      conn
      |> authenticate_acl(acl_data.api_key)
      |> post("/api/acls/#{acl_data.acl_id}/members", member: member_params)
      |> assert_success_response(201)

      # Try to add same member again
      conn
      |> authenticate_acl(acl_data.api_key)
      |> post("/api/acls/#{acl_data.acl_id}/members", member: member_params)
      |> assert_error_format(422)
    end

    test "POST /api/acls/:id/members - validates role restrictions", %{
      conn: conn,
      acl_data: acl_data
    } do
      # Corporations cannot have admin role
      member_params = %{
        "eve_corporation_id" => "98000001",
        "role" => "admin"
      }

      conn
      |> authenticate_acl(acl_data.api_key)
      |> post("/api/acls/#{acl_data.acl_id}/members", member: member_params)
      |> assert_error_format(422)
    end
  end

  describe "ACL validation" do
    setup do
      owner = create_character()
      {:ok, owner: owner}
    end

    test "POST /api/acls - validates required fields", %{conn: conn, owner: owner} do
      # Missing name
      response =
        conn
        |> authenticate_character(owner)
        |> post("/api/acls", acl: %{})
        |> assert_error_format(422)

      assert response["errors"]["name"] != nil
    end

    test "POST /api/acls - validates name length", %{conn: conn, owner: owner} do
      long_name = String.duplicate("a", 256)

      response =
        conn
        |> authenticate_character(owner)
        |> post("/api/acls", acl: %{name: long_name})
        |> assert_error_format(422)

      assert response["errors"]["name"] != nil
    end
  end

  describe "ACL permissions" do
    setup do
      owner = create_character(%{name: "ACL Owner"})
      other_user = create_character(%{name: "Other User"})
      acl_data = create_test_acl_with_auth(%{character: owner})

      {:ok, owner: owner, other_user: other_user, acl_data: acl_data}
    end

    test "owner can update their own ACL", %{conn: conn, owner: owner, acl_data: acl_data} do
      conn
      |> authenticate_character(owner)
      |> put("/api/acls/#{acl_data.acl_id}", acl: %{name: "Owner Updated"})
      |> assert_success_response(200)
    end

    test "API key provides full access to ACL", %{conn: conn, acl_data: acl_data} do
      conn
      |> authenticate_acl(acl_data.api_key)
      |> get("/api/acls/#{acl_data.acl_id}")
      |> assert_success_response(200)
    end
  end

  describe "ACL member filtering" do
    setup do
      acl_data = create_test_acl_with_auth()

      # Create various members
      _char_member =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_character_id: "95000001",
          name: "Character Member",
          role: "admin"
        })

      _corp_member1 =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_corporation_id: "98000001",
          name: "Corp Member 1",
          role: "member"
        })

      _corp_member2 =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_corporation_id: "98000002",
          name: "Corp Member 2",
          role: "manager"
        })

      _alliance_member =
        create_acl_member(%{
          access_list: acl_data.acl,
          eve_alliance_id: "99000001",
          name: "Alliance Member",
          role: "member"
        })

      {:ok, acl_data: acl_data}
    end

    test "GET /api/acls/:id/members - filters by role", %{conn: conn, acl_data: acl_data} do
      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> get("/api/acls/#{acl_data.acl_id}/members", %{"role" => "member"})
        |> json_response!(200)

      assert length(response["data"]) == 2
      assert Enum.all?(response["data"], &(&1["role"] == "member"))
    end

    test "GET /api/acls/:id/members - filters by type", %{conn: conn, acl_data: acl_data} do
      response =
        conn
        |> authenticate_acl(acl_data.api_key)
        |> get("/api/acls/#{acl_data.acl_id}/members", %{"type" => "corporation"})
        |> json_response!(200)

      assert length(response["data"]) == 2
      assert Enum.all?(response["data"], &(&1["eve_corporation_id"] != nil))
    end
  end
end
