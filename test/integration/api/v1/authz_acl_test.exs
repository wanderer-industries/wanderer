defmodule WandererAppWeb.Api.V1.AuthzAclTest do
  @moduledoc """
  Authorization matrix for the ACL `/api/v1` resources.

  ACLs are joined to maps through `MapAccessList`, so scoping asks whether a
  join row exists rather than comparing a `map_id` column.

  Status codes differ from the map-owned resources on purpose:

    * Reads are FILTER checks -> an unlinked ACL is invisible: list omits it,
      `GET /:id` is 404.
    * Writes are `forbid_if always()` -> **403**, not 404. ACL administration
      is a session/internal concern; there is no ACL a map token may mutate,
      so even a *linked* ACL rejects token writes.
  """
  use WandererAppWeb.ApiCase, async: false

  require Ash.Query

  setup %{conn: conn} do
    owner = insert(:user)
    char = insert(:character, %{user_id: owner.id})
    map = insert(:map, %{owner_id: char.id})
    linked_acl = insert(:access_list, %{owner_id: char.id})
    insert(:map_access_list, %{map_id: map.id, access_list_id: linked_acl.id})
    linked_member = insert(:access_list_member, %{access_list_id: linked_acl.id})

    other_user = insert(:user)
    other_char = insert(:character, %{user_id: other_user.id})
    other_map = insert(:map, %{owner_id: other_char.id})
    other_acl = insert(:access_list, %{owner_id: other_char.id})
    insert(:map_access_list, %{map_id: other_map.id, access_list_id: other_acl.id})
    other_member = insert(:access_list_member, %{access_list_id: other_acl.id})

    %{
      conn: create_authenticated_conn(conn, map),
      char: char,
      linked_acl: linked_acl,
      other_acl: other_acl,
      linked_member: linked_member,
      other_member: other_member
    }
  end

  defp ids(data), do: Enum.map(data, & &1["id"])

  describe "access_list reads" do
    test "index includes the linked ACL and excludes the unlinked one", ctx do
      data = ctx.conn |> get("/api/v1/access_lists") |> json_response(200) |> Map.get("data")

      assert ctx.linked_acl.id in ids(data)
      refute ctx.other_acl.id in ids(data)
    end

    test "GET linked ACL -> 200 (positive control)", ctx do
      ctx.conn |> get("/api/v1/access_lists/#{ctx.linked_acl.id}") |> json_response(200)
    end

    test "GET unlinked ACL -> 404", ctx do
      ctx.conn |> get("/api/v1/access_lists/#{ctx.other_acl.id}") |> json_response(404)
    end
  end

  describe "access_list writes are forbidden for token actors" do
    test "POST -> 403 and nothing is created", ctx do
      body = %{
        "data" => %{
          "type" => "access_lists",
          "attributes" => %{"name" => "token-made", "owner_id" => ctx.char.id}
        }
      }

      ctx.conn |> post("/api/v1/access_lists", body) |> json_response(403)

      {:ok, rows} =
        WandererApp.Api.AccessList
        |> Ash.Query.filter(name == "token-made")
        |> Ash.read(authorize?: false)

      assert rows == []
    end

    test "PATCH a LINKED ACL -> 403 and name is unchanged", ctx do
      body = %{
        "data" => %{
          "type" => "access_lists",
          "id" => ctx.linked_acl.id,
          "attributes" => %{"name" => "hacked"}
        }
      }

      ctx.conn
      |> patch("/api/v1/access_lists/#{ctx.linked_acl.id}", body)
      |> json_response(403)

      {:ok, reloaded} = Ash.get(WandererApp.Api.AccessList, ctx.linked_acl.id, authorize?: false)
      assert reloaded.name == ctx.linked_acl.name
      refute reloaded.name == "hacked"
    end

    test "DELETE a LINKED ACL -> 403 and row survives", ctx do
      ctx.conn |> delete("/api/v1/access_lists/#{ctx.linked_acl.id}") |> json_response(403)

      # Match the struct: {:ok, _} would also pass if the row had been deleted.
      assert {:ok, %WandererApp.Api.AccessList{}} =
               Ash.get(WandererApp.Api.AccessList, ctx.linked_acl.id, authorize?: false)
    end
  end

  describe "access_list_member" do
    test "index includes the linked member and excludes the unlinked one", ctx do
      data =
        ctx.conn |> get("/api/v1/access_list_members") |> json_response(200) |> Map.get("data")

      assert ctx.linked_member.id in ids(data)
      refute ctx.other_member.id in ids(data)
    end

    test "GET unlinked member -> 404", ctx do
      ctx.conn
      |> get("/api/v1/access_list_members/#{ctx.other_member.id}")
      |> json_response(404)
    end

    test "DELETE a LINKED member -> 403 and row survives", ctx do
      ctx.conn
      |> delete("/api/v1/access_list_members/#{ctx.linked_member.id}")
      |> json_response(403)

      assert {:ok, %WandererApp.Api.AccessListMember{}} =
               Ash.get(WandererApp.Api.AccessListMember, ctx.linked_member.id, authorize?: false)
    end

    test "PATCH role on a LINKED member -> 403", ctx do
      body = %{
        "data" => %{
          "type" => "access_list_members",
          "id" => ctx.linked_member.id,
          "attributes" => %{"role" => "admin"}
        }
      }

      ctx.conn
      |> patch("/api/v1/access_list_members/#{ctx.linked_member.id}", body)
      |> json_response(403)
    end
  end

  describe "internal actors are unaffected by the token policies" do
    test "a trusted User actor can still update an ACL via the bypass", ctx do
      assert {:ok, updated} =
               Ash.update(
                 ctx.linked_acl,
                 %{name: "internal-ok"},
                 actor: %WandererApp.Api.User{id: Ecto.UUID.generate()},
                 authorize?: true
               )

      assert updated.name == "internal-ok"
    end

    test "a trusted User actor can read ACLs that no map links", ctx do
      {:ok, rows} =
        Ash.read(WandererApp.Api.AccessList,
          actor: %WandererApp.Api.User{id: Ecto.UUID.generate()},
          authorize?: true
        )

      assert ctx.other_acl.id in Enum.map(rows, & &1.id)
    end
  end
end
