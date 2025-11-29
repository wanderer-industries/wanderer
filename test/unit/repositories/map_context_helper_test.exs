defmodule WandererApp.Repositories.MapContextHelperTest do
  # Pure unit tests - no database or external dependencies
  use ExUnit.Case, async: true

  alias WandererApp.Repositories.MapContextHelper

  describe "build_context/1" do
    test "creates context with map when map_id present" do
      attrs = %{map_id: "map-123", name: "Test"}

      result = MapContextHelper.build_context(attrs)

      assert result == [context: %{map: %{id: "map-123"}}]
    end

    test "returns empty list when no map_id" do
      attrs = %{name: "Test"}

      result = MapContextHelper.build_context(attrs)

      assert result == []
    end

    test "returns empty list for nil map_id" do
      attrs = %{map_id: nil, name: "Test"}

      result = MapContextHelper.build_context(attrs)

      assert result == []
    end

    test "preserves map_id value exactly" do
      attrs = %{map_id: "uuid-value-123", other: "data"}

      result = MapContextHelper.build_context(attrs)

      assert result == [context: %{map: %{id: "uuid-value-123"}}]
    end
  end

  describe "with_map_context/2 (deprecated)" do
    test "creates context with map when map_id present" do
      attrs = %{map_id: "map-123", name: "Test"}

      result =
        MapContextHelper.with_map_context(attrs, fn received_attrs, context ->
          {received_attrs, context}
        end)

      {_attrs, context} = result
      assert context == [context: %{map: %{id: "map-123"}}]
    end

    test "calls function without context when no map_id" do
      attrs = %{name: "Test"}

      result =
        MapContextHelper.with_map_context(attrs, fn received_attrs, context ->
          {received_attrs, context}
        end)

      {_attrs, context} = result
      assert context == []
    end

    test "passes through attrs unchanged" do
      attrs = %{map_id: "map-123", name: "Test", value: 42}

      result =
        MapContextHelper.with_map_context(attrs, fn received_attrs, _context ->
          received_attrs
        end)

      assert result == attrs
    end

    test "handles nil map_id" do
      attrs = %{map_id: nil, name: "Test"}

      result =
        MapContextHelper.with_map_context(attrs, fn received_attrs, context ->
          {received_attrs, context}
        end)

      {_attrs, context} = result
      assert context == []
    end
  end
end
