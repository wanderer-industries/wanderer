defmodule WandererApp.Api.MapTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.Map

  describe "create action with sse_enabled" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      %{character: character}
    end

    test "allows creating map with sse_enabled false (default)", %{character: character} do
      {:ok, map} =
        Ash.create(Map, %{
          name: "Test Map",
          slug: "test-map-#{System.unique_integer([:positive])}",
          owner_id: character.id
        })

      assert map.sse_enabled == false
    end

    test "allows creating map and then enabling SSE", %{character: character} do
      {:ok, map} =
        Ash.create(Map, %{
          name: "Test Map",
          slug: "test-map-#{System.unique_integer([:positive])}",
          owner_id: character.id
        })

      # Maps are created with sse_enabled false by default
      assert map.sse_enabled == false

      # Should be able to enable SSE
      {:ok, updated_map} = Ash.update(map, %{sse_enabled: true})
      assert updated_map.sse_enabled == true
    end
  end

  describe "update action with sse_enabled" do
    setup do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})
      %{map: map, character: character}
    end

    test "allows enabling SSE on existing map", %{map: map} do
      # Map starts with sse_enabled false
      assert map.sse_enabled == false

      # Enable SSE
      {:ok, updated_map} = Ash.update(map, %{sse_enabled: true})
      assert updated_map.sse_enabled == true
    end

    test "allows disabling SSE on existing map", %{map: map} do
      # First enable SSE
      {:ok, map_with_sse} = Ash.update(map, %{sse_enabled: true})
      assert map_with_sse.sse_enabled == true

      # Then disable it
      {:ok, updated_map} = Ash.update(map_with_sse, %{sse_enabled: false})
      assert updated_map.sse_enabled == false
    end

    test "allows updating other fields when sse_enabled is not changed", %{map: map} do
      # Should be able to update name without touching sse_enabled
      {:ok, updated_map} = Ash.update(map, %{name: "Updated Name"})

      assert updated_map.name == "Updated Name"
      assert updated_map.sse_enabled == false
    end

    test "allows toggling sse_enabled multiple times", %{map: map} do
      # Enable
      {:ok, map1} = Ash.update(map, %{sse_enabled: true})
      assert map1.sse_enabled == true

      # Disable
      {:ok, map2} = Ash.update(map1, %{sse_enabled: false})
      assert map2.sse_enabled == false

      # Enable again
      {:ok, map3} = Ash.update(map2, %{sse_enabled: true})
      assert map3.sse_enabled == true
    end
  end
end
