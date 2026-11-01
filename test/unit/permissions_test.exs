defmodule WandererApp.PermissionsTest do
  use ExUnit.Case, async: true

  alias WandererApp.Permissions

  test "an access list owner receives admin permissions" do
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
    assert permissions.delete_map
  end
end
