defmodule WandererAppWeb.Maps.MapSettings.AccessListsTabTest do
  use ExUnit.Case, async: true

  alias WandererAppWeb.Maps.MapSettings.AccessListsTab

  test "a saved third-party access list becomes visible again when selection is reset" do
    third_party_acl = %{id: "third-party", name: "Third party"}

    assert [] = AccessListsTab.visible_access_lists([third_party_acl], [], [])

    assert [^third_party_acl] =
             AccessListsTab.visible_access_lists(
               [third_party_acl],
               [],
               [third_party_acl.id]
             )
  end
end
