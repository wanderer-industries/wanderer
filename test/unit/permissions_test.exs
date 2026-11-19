defmodule WandererApp.PermissionsTest do
  use ExUnit.Case, async: true

  alias WandererApp.Permissions

  test "an access list owner receives admin permissions without map deletion" do
    character = %{
      id: "character-id",
      eve_id: "eve-character-id",
      corporation_id: "corporation-id",
      alliance_id: "alliance-id"
    }

    access_list = %{owner_id: character.id, members: []}

    assert [permissions_mask] = Permissions.check_characters_access([character], [access_list])

    permissions = Permissions.get_permissions(permissions_mask)
    assert permissions.admin_map
    assert permissions.manage_map
    refute permissions.delete_map
  end

  test "a direct character block takes precedence over access list ownership" do
    character = %{
      id: "character-id",
      eve_id: "eve-character-id",
      corporation_id: "corporation-id",
      alliance_id: "alliance-id"
    }

    access_list = %{
      owner_id: character.id,
      members: [
        %{
          eve_character_id: character.eve_id,
          eve_corporation_id: nil,
          eve_alliance_id: nil,
          role: :blocked
        }
      ]
    }

    assert [-1] = Permissions.check_characters_access([character], [access_list])
  end

  test "only the map owner permission set includes map deletion" do
    admin_mask = Permissions.role_mask(:admin)

    refute Permissions.get_permissions(admin_mask).delete_map

    owner_permissions =
      Permissions.get_map_permissions(admin_mask, "owner-id", ["owner-id"])

    assert owner_permissions.delete_map
  end
end
