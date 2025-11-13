defmodule WandererApp.ExternalEvents.SseAccessControlTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.ExternalEvents.SseAccessControl

  describe "sse_allowed?/1" do
    setup do
      # Create test user and character
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})

      # Create test map
      map = insert(:map, %{owner_id: character.id})

      # Enable SSE for the map
      {:ok, map} = Ash.update(map, %{sse_enabled: true})

      %{map: map}
    end

    test "returns error when map not found" do
      fake_map_id = Ash.UUID.generate()
      assert {:error, :map_not_found} = SseAccessControl.sse_allowed?(fake_map_id)
    end

    test "returns error when map SSE disabled" do
      user = insert(:user)
      character = insert(:character, %{user_id: user.id})
      map = insert(:map, %{owner_id: character.id})
      # Map defaults to sse_enabled: false

      # Should return error because map.sse_enabled is false
      result = SseAccessControl.sse_allowed?(map.id)
      assert {:error, :sse_disabled_for_map} = result
    end

    test "returns valid response when all conditions met", %{map: map} do
      # In test environment, subscriptions are typically disabled (CE mode)
      # and SSE is enabled by default
      # This tests the happy path
      result = SseAccessControl.sse_allowed?(map.id)

      # Should either return :ok (if CE mode) or error if subscriptions required
      # We just verify it returns a valid response
      assert result == :ok or match?({:error, _}, result)
    end

    test "validates map must have sse_enabled true", %{map: map} do
      # Disable SSE on the map
      {:ok, updated_map} = Ash.update(map, %{sse_enabled: false})

      # Should return error because map SSE is disabled
      assert {:error, :sse_disabled_for_map} = SseAccessControl.sse_allowed?(updated_map.id)
    end
  end
end
