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
      %{solar_system_source: 1, solar_system_target: 2},
      %{solar_system_source: 1, solar_system_target: 3}
    ]

    updated_systems = PositionCalculator.layout_systems(systems, connections, [])

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
end
