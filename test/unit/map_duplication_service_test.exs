defmodule WandererApp.MapDuplicationServiceTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.Api.Map
  alias WandererApp.Map.Operations.Duplication

  import WandererAppWeb.Factory

  describe "map duplication service - basic functionality" do
    setup do
      owner = insert(:character)

      source_map =
        insert(:map, %{
          name: "Original Map",
          description: "Test map for duplication",
          owner_id: owner.id,
          scope: :wormholes,
          only_tracked_characters: false
        })

      %{owner: owner, source_map: source_map}
    end

    test "duplicates basic map successfully", %{owner: owner, source_map: source_map} do
      # Create the target map first
      target_map =
        insert(:map, %{
          name: "Duplicated Map",
          description: "Copy of original",
          owner_id: owner.id
        })

      result =
        Duplication.duplicate_map(
          source_map.id,
          target_map,
          copy_acls: false,
          copy_user_settings: false,
          copy_signatures: false
        )

      assert {:ok, duplicated_map} = result
      assert duplicated_map.name == "Duplicated Map"
      assert duplicated_map.description == "Copy of original"
      assert duplicated_map.id == target_map.id
      assert duplicated_map.id != source_map.id
      assert duplicated_map.owner_id == owner.id
    end

    test "successfully duplicates with valid parameters", %{owner: owner, source_map: source_map} do
      # Create a valid target map
      target_map =
        insert(:map, %{
          name: "Valid Duplication",
          description: "Test successful duplication",
          owner_id: owner.id
        })

      result = Duplication.duplicate_map(source_map.id, target_map)

      # Should succeed
      assert {:ok, duplicated_map} = result
      assert duplicated_map.id == target_map.id
    end

    test "handles non-existent source map", %{owner: owner} do
      non_existent_id = Ecto.UUID.generate()

      target_map =
        insert(:map, %{
          name: "Test Map",
          owner_id: owner.id
        })

      result = Duplication.duplicate_map(non_existent_id, target_map)

      assert {:error, {:not_found, _message}} = result
    end

    @tag :skip
    test "preserves original map unchanged", %{owner: owner, source_map: source_map} do
      original_name = source_map.name
      original_description = source_map.description
      original_scope = source_map.scope

      target_map =
        insert(:map, %{
          name: "The Copy",
          owner_id: owner.id
        })

      {:ok, _duplicated_map} = Duplication.duplicate_map(source_map.id, target_map, [])

      # Reload source map to verify it's unchanged
      {:ok, reloaded_source} = Map.by_id(source_map.id)
      assert reloaded_source.name == original_name
      assert reloaded_source.description == original_description
      assert reloaded_source.scope == original_scope
      assert reloaded_source.owner_id == source_map.owner_id
    end

    test "generates unique slugs for duplicated maps", %{owner: owner, source_map: source_map} do
      # Create first duplicate
      target_map1 =
        insert(:map, %{
          name: "Unique Copy 1",
          owner_id: owner.id
        })

      {:ok, duplicate1} = Duplication.duplicate_map(source_map.id, target_map1, [])

      # Create second duplicate  
      target_map2 =
        insert(:map, %{
          name: "Unique Copy 2",
          owner_id: owner.id
        })

      {:ok, duplicate2} = Duplication.duplicate_map(source_map.id, target_map2, [])

      # All maps should have different slugs
      assert source_map.slug != duplicate1.slug
      assert source_map.slug != duplicate2.slug
      assert duplicate1.slug != duplicate2.slug
    end

    test "current user becomes owner of duplicated map", %{source_map: source_map} do
      # Create a different user who will do the duplication
      other_user = insert(:character)

      target_map =
        insert(:map, %{
          name: "New Owner Map",
          owner_id: other_user.id
        })

      result = Duplication.duplicate_map(source_map.id, target_map, [])

      assert {:ok, duplicated_map} = result
      assert duplicated_map.owner_id == other_user.id
      assert duplicated_map.owner_id != source_map.owner_id
    end

    test "respects copy options - minimal copy", %{owner: owner, source_map: source_map} do
      target_map =
        insert(:map, %{
          name: "Minimal Copy",
          owner_id: owner.id
        })

      # Test copying with no extras
      result =
        Duplication.duplicate_map(
          source_map.id,
          target_map,
          copy_acls: false,
          copy_user_settings: false,
          copy_signatures: false
        )

      assert {:ok, duplicated_map} = result
      assert duplicated_map.name == "Minimal Copy"
    end

    test "handles empty maps correctly", %{owner: owner} do
      empty_map =
        insert(:map, %{
          name: "Empty Map",
          description: "No systems or connections",
          owner_id: owner.id
        })

      target_map =
        insert(:map, %{
          name: "Copy of Empty",
          owner_id: owner.id
        })

      result = Duplication.duplicate_map(empty_map.id, target_map, [])

      assert {:ok, duplicated_map} = result
      assert duplicated_map.name == "Copy of Empty"
      assert duplicated_map.id == target_map.id
      assert duplicated_map.id != empty_map.id
    end
  end

  describe "error handling" do
    setup do
      owner = insert(:character)
      source_map = insert(:map, %{name: "Error Test Map", owner_id: owner.id})
      %{owner: owner, source_map: source_map}
    end

    test "handles valid names gracefully", %{owner: owner, source_map: source_map} do
      # Create map with valid name and test duplication
      target_map =
        insert(:map, %{
          # Valid minimum name
          name: "abc",
          owner_id: owner.id
        })

      result = Duplication.duplicate_map(source_map.id, target_map, [])
      assert {:ok, _duplicated_map} = result
    end

    test "handles invalid source map ID format", %{owner: owner} do
      target_map =
        insert(:map, %{
          name: "Valid Name",
          owner_id: owner.id
        })

      result = Duplication.duplicate_map("invalid-uuid", target_map, [])
      assert {:error, _reason} = result
    end
  end
end
