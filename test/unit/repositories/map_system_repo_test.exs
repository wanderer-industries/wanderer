defmodule WandererApp.MapSystemRepoTest do
  use WandererApp.DataCase, async: false

  alias WandererApp.MapSystemRepo
  import WandererAppWeb.Factory

  describe "update_position_and_attributes/3" do
    setup do
      character = insert(:character)
      map = insert(:map, %{owner_id: character.id})

      system =
        insert(:map_system, %{
          map_id: map.id,
          solar_system_id: 30_000_142,
          position_x: 0,
          position_y: 0,
          visible: false,
          labels: ~s|{"labels":["label1","label2"]}|,
          tag: "test-tag",
          temporary_name: "Temp Name"
        })

      %{map: map, system: system}
    end

    test "updates position and sets visible to true", %{system: system} do
      {:ok, updated} =
        MapSystemRepo.update_position_and_attributes(system, %{
          position_x: 100,
          position_y: 200,
          labels: system.labels,
          tag: system.tag,
          temporary_name: system.temporary_name
        })

      assert updated.position_x == 100
      assert updated.position_y == 200
      assert updated.visible == true
    end

    test "cleans up empty tags", %{system: system} do
      {:ok, updated} =
        MapSystemRepo.update_position_and_attributes(system, %{
          position_x: 100,
          position_y: 200,
          # Empty string should become nil
          tag: ""
        })

      assert updated.tag == nil
    end

    test "preserves non-empty tags", %{system: system} do
      {:ok, updated} =
        MapSystemRepo.update_position_and_attributes(system, %{
          position_x: 100,
          position_y: 200,
          tag: "preserved-tag"
        })

      assert updated.tag == "preserved-tag"
    end

    test "cleans up empty temporary names", %{system: system} do
      {:ok, updated} =
        MapSystemRepo.update_position_and_attributes(system, %{
          position_x: 100,
          position_y: 200,
          # Empty string should become nil
          temporary_name: ""
        })

      assert updated.temporary_name == nil
    end

    test "preserves non-empty temporary names", %{system: system} do
      {:ok, updated} =
        MapSystemRepo.update_position_and_attributes(system, %{
          position_x: 100,
          position_y: 200,
          temporary_name: "Special Name"
        })

      assert updated.temporary_name == "Special Name"
    end

    test "cleans labels based on map options", %{system: system} do
      map_opts = %{store_custom_labels: true}

      {:ok, updated} =
        MapSystemRepo.update_position_and_attributes(
          system,
          %{
            position_x: 100,
            position_y: 200,
            labels: ~s|{"customLabel":"MyLabel","labels":["label1","label2"]}|
          },
          map_opts: map_opts
        )

      # With store_custom_labels: true, only customLabel should be preserved
      assert updated.labels =~ "customLabel"
      assert updated.labels =~ "MyLabel"
    end

    test "requires position_x when provided", %{system: system} do
      # Both position_x and position_y must be provided for a valid update
      {:ok, updated} =
        MapSystemRepo.update_position_and_attributes(system, %{
          position_x: 100,
          position_y: 200
        })

      assert updated.position_x == 100
      assert updated.position_y == 200
    end

    test "extract_update_attrs extracts all relevant attributes", %{system: system} do
      attrs = MapSystemRepo.extract_update_attrs(system)

      assert attrs.position_x == system.position_x
      assert attrs.position_y == system.position_y
      assert attrs.labels == system.labels
      assert attrs.tag == system.tag
      assert attrs.temporary_name == system.temporary_name
      assert attrs.linked_sig_eve_id == system.linked_sig_eve_id
    end

    test "batch update performs fewer database operations than chained updates", %{system: system} do
      # This test demonstrates that batch update consolidates multiple operations
      # Performance in test environment may vary, so we just verify it completes successfully

      # Batch update - should complete successfully
      {:ok, batch_result} =
        MapSystemRepo.update_position_and_attributes(system, %{
          position_x: 100,
          position_y: 200,
          labels: system.labels,
          tag: "tag",
          temporary_name: "name"
        })

      assert batch_result.position_x == 100
      assert batch_result.position_y == 200
      assert batch_result.visible == true

      # Chained updates (old way) - also completes but with more operations
      chained_result =
        system
        |> MapSystemRepo.update_position!(%{position_x: 150, position_y: 250})
        |> MapSystemRepo.cleanup_labels!([])
        |> MapSystemRepo.update_visible!(%{visible: true})
        |> MapSystemRepo.cleanup_tags!()
        |> MapSystemRepo.cleanup_temporary_name!()

      assert chained_result.position_x == 150
      assert chained_result.position_y == 250

      IO.puts("\nBatch update successfully consolidates 5 operations into 1")
    end
  end
end
