defmodule WandererApp.Map.PositionCalculatorTest do
  use ExUnit.Case, async: true
  alias WandererApp.Map.PositionCalculator

  test "layout_systems rearranges systems" do
    systems = [
      %{solar_system_id: 1, position_x: 0, position_y: 0},
      %{solar_system_id: 2, position_x: 10, position_y: 10},
      %{solar_system_id: 3, position_x: -10, position_y: -10}
    ]

    connections = [
      %{id: "1-2", solar_system_source: 1, solar_system_target: 2},
      %{id: "1-3", solar_system_source: 1, solar_system_target: 3}
    ]

    {updated_systems, _cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [])

    assert length(updated_systems) == 3

    # Sort by ID to compare
    updated_1 = Enum.find(updated_systems, & &1.solar_system_id == 1)
    updated_2 = Enum.find(updated_systems, & &1.solar_system_id == 2)
    updated_3 = Enum.find(updated_systems, & &1.solar_system_id == 3)

    # Node 1 is root (layer 0)
    # Node 2 and 3 are in layer 1
    assert updated_1.position_x < updated_2.position_x
    assert updated_1.position_x < updated_3.position_x
    assert updated_2.position_x == updated_3.position_x

    # Vertically centered: node 2 and 3 should be above/below each other
    assert updated_2.position_y != updated_3.position_y
  end

  test "layout_systems prevents overlaps even with locked systems" do
    systems = [
      %{solar_system_id: 1, position_x: 0, position_y: 0, locked: true},
      %{solar_system_id: 2, position_x: 0, position_y: 0, locked: true}, # Locked at same spot!
      %{solar_system_id: 3, position_x: 100, position_y: 100}
    ]

    connections = [
      %{id: "1-3", solar_system_source: 1, solar_system_target: 3}
    ]

    {updated_systems, _cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [])

    # Check for overlaps
    # A system [x, x+130], [y, y+34]
    for s1 <- updated_systems, s2 <- updated_systems, s1.solar_system_id < s2.solar_system_id do
      assert not overlap?(s1, s2), "Systems #{s1.solar_system_id} and #{s2.solar_system_id} overlap"
    end
  end

  defp overlap?(s1, s2) do
    w = 130
    h = 34
    # Horizontal overlap
    x_overlap = s1.position_x < s2.position_x + w and s1.position_x + w > s2.position_x
    # Vertical overlap
    y_overlap = s1.position_y < s2.position_y + h and s1.position_y + h > s2.position_y

    x_overlap and y_overlap
  end

  test "layout_systems correctly handles multiple roots in a component" do
    # System 1 and 2 are connected via 3, both 1 and 2 are locked (roots)
    systems = [
      %{solar_system_id: 1, position_x: 0, position_y: 0, locked: true, name: "A-Root"},
      %{solar_system_id: 2, position_x: 0, position_y: 500, locked: true, name: "B-Root"},
      %{solar_system_id: 3, position_x: 100, position_y: 100, name: "C-Node"}
    ]

    connections = [
      %{id: "1-3", solar_system_source: 1, solar_system_target: 3},
      %{id: "2-3", solar_system_source: 2, solar_system_target: 3}
    ]

    {updated_systems, _cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [])

    updated_1 = Enum.find(updated_systems, & &1.solar_system_id == 1)
    updated_2 = Enum.find(updated_systems, & &1.solar_system_id == 2)

    assert updated_1.position_y == 0
    # Root 2 (B-Root) should be shifted below Root 1's subtree
    assert updated_2.position_y > updated_1.position_y
  end

  test "layout_systems skips layout for systems involved in cross-list connections" do
    # System 1 is root, connected to 3.
    # System 2 is root, connected to 4.
    # Connection (3, 4) is a cross-list connection.
    # Systems 1, 3, 2, 4 should keep original positions because of the bridge.
    systems = [
      %{solar_system_id: 1, position_x: 100, position_y: 100, locked: true, name: "Root-A"},
      %{solar_system_id: 2, position_x: 500, position_y: 500, locked: true, name: "Root-B"},
      %{solar_system_id: 3, position_x: 200, position_y: 200, name: "Node-A3"},
      %{solar_system_id: 4, position_x: 600, position_y: 600, name: "Node-B4"}
    ]

    connections = [
      %{id: "conn-1-3", solar_system_source: 1, solar_system_target: 3},
      %{id: "conn-2-4", solar_system_source: 2, solar_system_target: 4},
      %{id: "cross-bridge", solar_system_source: 3, solar_system_target: 4}
    ]

    {updated_systems, cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [])

    # Either "cross-bridge" or "conn-2-4" (or even "conn-1-3" depending on order)
    # will be detected as cross-list because roots greedily claim nodes.
    assert not Enum.empty?(cross_list_ids)

    for original <- systems do
      updated = Enum.find(updated_systems, & &1.solar_system_id == original.solar_system_id)
      assert updated.position_x == original.position_x
      assert updated.position_y == original.position_y
    end
  end

  test "layout_systems prioritizes older connections for root claims" do
    # Root A connects to S (NEW).
    # Root B connects to S (OLD).
    # S should stay with Root B subtree.
    old_time = ~U[2020-01-01 00:00:00Z]
    new_time = ~U[2024-01-01 00:00:00Z]

    systems = [
      %{solar_system_id: 1, position_x: 0, position_y: 0, locked: true, name: "Root-Hek"},
      %{solar_system_id: 2, position_x: 0, position_y: 500, locked: true, name: "Root-J220546"},
      %{solar_system_id: 3, position_x: 100, position_y: 200, name: "System-S"}
    ]

    connections = [
      %{id: "hek-s", solar_system_source: 1, solar_system_target: 3, inserted_at: new_time},
      %{id: "j-s", solar_system_source: 2, solar_system_target: 3, inserted_at: old_time}
    ]

    {_updated, cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [])

    # "hek-s" should be the cross-list connection because "j-s" was older and claimed S first.
    assert "hek-s" in cross_list_ids
  end

  test "layout_systems treats nil inserted_at as newer than existing connections" do
    old_time = ~U[2020-01-01 00:00:00Z]

    systems = [
      %{solar_system_id: 1, position_x: 0, position_y: 0, locked: true, name: "Root-Hek"},
      %{solar_system_id: 2, position_x: 0, position_y: 500, locked: true, name: "Root-J220546"},
      %{solar_system_id: 3, position_x: 100, position_y: 200, name: "System-S"}
    ]

    connections = [
      %{id: "hek-s", solar_system_source: 1, solar_system_target: 3, inserted_at: nil},
      %{id: "j-s", solar_system_source: 2, solar_system_target: 3, inserted_at: old_time}
    ]

    {_updated, cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [])

    # "hek-s" with nil should be treated as new, so "j-s" (old) wins the claim for S.
    # Therefore, hek-s is the cross-list connection.
    assert "hek-s" in cross_list_ids
  end

  test "layout_systems generates hierarchical names" do
    # Root (1)
    #  -> Child (2)
    #     -> Grandchild (4)
    #  -> Child (3)
    systems = [
      %{solar_system_id: 1, name: "Root", locked: true, position_x: 0, position_y: 0},
      %{solar_system_id: 2, name: "A-Child", position_x: 0, position_y: 0},
      %{solar_system_id: 3, name: "B-Child", position_x: 0, position_y: 0},
      %{solar_system_id: 4, name: "A-Grandchild", position_x: 0, position_y: 0}
    ]

    connections = [
      %{id: "1-2", solar_system_source: 1, solar_system_target: 2, inserted_at: ~U[2020-01-01 00:00:00Z]},
      %{id: "1-3", solar_system_source: 1, solar_system_target: 3, inserted_at: ~U[2020-01-01 00:00:00Z]},
      %{id: "2-4", solar_system_source: 2, solar_system_target: 4, inserted_at: ~U[2020-01-01 00:00:00Z]}
    ]

    {updated_systems, _cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [])

    # Sort children by name: A-Child (index 1), B-Child (index 2)
    # Root -> "0"
    # A-Child -> "1"
    # B-Child -> "2"
    # A-Grandchild -> "1-1"

    s1 = Enum.find(updated_systems, & &1.solar_system_id == 1)
    s2 = Enum.find(updated_systems, & &1.solar_system_id == 2)
    s3 = Enum.find(updated_systems, & &1.solar_system_id == 3)
    s4 = Enum.find(updated_systems, & &1.solar_system_id == 4)

    assert s1.hierarchical_name == "0"
    assert s2.hierarchical_name == "1"
    assert s3.hierarchical_name == "2"
    assert s4.hierarchical_name == "1-1"
  end

  test "layout_systems aligns multiple locked roots to the same X axis" do
    systems = [
      %{solar_system_id: 1, name: "Root-A", locked: true, position_x: 100, position_y: 100},
      %{solar_system_id: 2, name: "Root-B", locked: true, position_x: 500, position_y: 500}
    ]

    # No connections, so they are independent roots
    {updated_systems, _cross_list_ids} = PositionCalculator.layout_systems(systems, [], [])

    s1 = Enum.find(updated_systems, & &1.solar_system_id == 1)
    s2 = Enum.find(updated_systems, & &1.solar_system_id == 2)

    # Both should be forced to X = 0.0 (the root axis)
    assert s1.position_x == 0
    assert s2.position_x == 0
  end

  test "layout_systems top_to_bottom anchors roots to Y axis and arranges children vertically" do
    # Root (1)
    #  -> Child (2)
    systems = [
      %{solar_system_id: 1, name: "Root", locked: true, position_x: 100, position_y: 100},
      %{solar_system_id: 2, name: "Child", position_x: 0, position_y: 0}
    ]

    connections = [
      %{id: "1-2", solar_system_source: 1, solar_system_target: 2, inserted_at: ~U[2020-01-01 00:00:00Z]}
    ]

    # Use top_to_bottom layout
    {updated_systems, _cross_list_ids} = PositionCalculator.layout_systems(systems, connections, [layout: "top_to_bottom"])

    s1 = Enum.find(updated_systems, & &1.solar_system_id == 1)
    s2 = Enum.find(updated_systems, & &1.solar_system_id == 2)

    # Root should be forced to Y = 0
    assert s1.position_y == 0
    # Child should be below root (Y = s1.y + @h + @m_y)
    # @h = 34, @m_y = 41 -> s2.y = 0 + 34 + 41 = 75
    assert s2.position_y == 75
    # Since there's only one root at (0, 0), the child should have same X (0)
    assert s2.position_x == 0
  end

  test "layout_systems detects cycles and excludes affected subtrees from layout" do
    # Root (1) -> Child (2) -> Grandchild (3) -> Root (1) [Cycle]
    systems = [
      %{solar_system_id: 1, name: "Root", locked: true, position_x: 0, position_y: 0},
      %{solar_system_id: 2, name: "Child", position_x: 500, position_y: 500},
      %{solar_system_id: 3, name: "Grandchild", position_x: 1000, position_y: 1000}
    ]

    connections = [
      %{id: "1-2", solar_system_source: 1, solar_system_target: 2, inserted_at: ~U[2020-01-01 00:00:00Z]},
      %{id: "2-3", solar_system_source: 2, solar_system_target: 3, inserted_at: ~U[2020-01-01 00:00:00Z]},
      %{id: "3-1", solar_system_source: 3, solar_system_target: 1, inserted_at: ~U[2020-01-01 00:00:00Z]}
    ]

    {updated_systems, special_ids} = PositionCalculator.layout_systems(systems, connections, [])

    # The 3-1 connection completes the cycle and should be identified as special
    assert "3-1" in special_ids

    # Since the root (1) is part of a special connection, its entire subtree should be skipped
    s1 = Enum.find(updated_systems, & &1.solar_system_id == 1)
    s2 = Enum.find(updated_systems, & &1.solar_system_id == 2)
    s3 = Enum.find(updated_systems, & &1.solar_system_id == 3)

    assert s1.position_x == 0
    assert s1.position_y == 0
    assert s2.position_x == 500
    assert s2.position_y == 500
    assert s3.position_x == 1000
    assert s3.position_y == 1000

    # Ensure hierarchical_name is NOT added when layout is skipped due to cycle
    refute Map.has_key?(s1, :hierarchical_name)
    refute Map.has_key?(s2, :hierarchical_name)
    refute Map.has_key?(s3, :hierarchical_name)
  end
end
