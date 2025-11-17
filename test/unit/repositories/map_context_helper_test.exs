defmodule WandererApp.Repositories.MapContextHelperTest do
  use WandererApp.DataCase, async: true

  alias WandererApp.Repositories.MapContextHelper

  describe "with_map_context/2" do
    test "creates minimal map struct and removes map_id from attrs" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      attrs = %{map_id: map.id, name: "Test System", solar_system_id: 30_000_142}

      result =
        MapContextHelper.with_map_context(attrs, fn attrs_received, context ->
          # Verify map_id removed from attrs
          refute Map.has_key?(attrs_received, :map_id)

          # Verify minimal map struct in context (only has :id field)
          assert context.map.id == map.id
          assert context.map == %{id: map.id}

          # Verify other attrs preserved
          assert attrs_received.name == "Test System"
          assert attrs_received.solar_system_id == 30_000_142

          {:ok, :success}
        end)

      assert result == {:ok, :success}
    end

    test "returns error when map_id is not a string" do
      # Invalid map_id type
      attrs = %{map_id: 12345, name: "Test"}

      result =
        MapContextHelper.with_map_context(attrs, fn _, _ ->
          flunk("Callback should not be called with invalid map_id")
        end)

      # Should return an error for invalid map_id type
      assert {:error, {:invalid_map_id, 12345}} = result
    end

    test "passes through when no map_id in attrs" do
      attrs = %{name: "Test", solar_system_id: 30_000_142}

      result =
        MapContextHelper.with_map_context(attrs, fn attrs_received, context ->
          assert attrs_received == attrs
          assert context == %{}
          {:ok, :no_map_context}
        end)

      assert result == {:ok, :no_map_context}
    end

    test "preserves error from callback" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      attrs = %{map_id: map.id, name: "Test"}

      result =
        MapContextHelper.with_map_context(attrs, fn _, _ ->
          {:error, :callback_error}
        end)

      assert result == {:error, :callback_error}
    end

    test "works with actual MapSystem.create" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      attrs = %{
        map_id: map.id,
        solar_system_id: 30_000_142,
        name: "Test System",
        position_x: 100,
        position_y: 200
      }

      result =
        MapContextHelper.with_map_context(attrs, fn attrs_without_map_id, context ->
          WandererApp.Api.MapSystem.create(attrs_without_map_id, context: context)
        end)

      assert {:ok, system} = result
      assert system.map_id == map.id
      assert system.solar_system_id == 30_000_142
      assert system.position_x == 100
      assert system.position_y == 200
    end
  end

  describe "with_map_context!/2" do
    test "raises on invalid map_id type" do
      # Invalid map_id type (not a string)
      attrs = %{map_id: 12345, name: "Test"}

      assert_raise RuntimeError, ~r/Invalid map_id/, fn ->
        MapContextHelper.with_map_context!(attrs, fn _, _ -> {:ok, :unreachable} end)
      end
    end

    test "returns result directly on success with {:ok, value}" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      attrs = %{map_id: map.id, name: "Test"}

      result =
        MapContextHelper.with_map_context!(attrs, fn _, _ ->
          {:ok, :success}
        end)

      assert result == {:ok, :success}
    end

    test "returns struct directly when callback returns struct" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      map = insert(:map, owner_id: character.id)

      attrs = %{
        map_id: map.id,
        solar_system_id: 30_000_142,
        name: "Test System",
        position_x: 100,
        position_y: 200
      }

      system =
        MapContextHelper.with_map_context!(attrs, fn attrs_without_map_id, context ->
          WandererApp.Api.MapSystem.create!(attrs_without_map_id, context: context)
        end)

      assert system.__struct__ == WandererApp.Api.MapSystem
      assert system.map_id == map.id
      assert system.solar_system_id == 30_000_142
    end

    test "works with no map_id" do
      attrs = %{name: "Test", solar_system_id: 30_000_142}

      result =
        MapContextHelper.with_map_context!(attrs, fn attrs_received, context ->
          assert attrs_received == attrs
          assert context == %{}
          {:ok, :no_map}
        end)

      assert result == {:ok, :no_map}
    end
  end
end
