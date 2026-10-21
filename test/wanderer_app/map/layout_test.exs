defmodule WandererApp.Map.LayoutTest do
  use ExUnit.Case, async: true

  alias WandererApp.Map.Layout

  @settings %{
    "engine" => "elk",
    "direction" => "TB",
    "routing" => "orthogonal",
    "nodeSpacing" => 40,
    "layerSpacing" => 80,
    "edgeSpacing" => 16,
    "orderBy" => "name",
    "orderDirection" => "asc",
    "locale" => "en",
    "orderPolicy" => "prefer",
    "groups" => "none",
    "preservePreviousPositions" => false
  }

  test "uses non-default statuses as roots and leaves isolated nodes unranked" do
    systems = [
      system(1, "Root A", 1),
      system(2, "Child", 0),
      system(3, "Root B", 2),
      system(4, "Isolated", 0)
    ]

    connections = [connection(1, 2), connection(2, 3)]
    request = Layout.build_request(systems, connections, Map.put(@settings, "routing", "spline"))
    nodes = Map.new(request.nodes, &{&1.id, &1})

    assert request.options.routing == "orthogonal"
    assert nodes["1"].rank == 0
    assert nodes["3"].rank == 0
    assert nodes["2"].rank == 1
    refute Map.has_key?(nodes["4"], :rank)
    assert request.edges == [%{id: "1_2", source: "1", target: "2"}]
  end

  test "breaks cycles into deterministic levels and orients edges away from roots" do
    systems = [system(1, "Charlie", 0), system(2, "Alpha", 1), system(3, "Bravo", 0)]
    connections = [connection(1, 2), connection(2, 3), connection(3, 1)]
    request = Layout.build_request(systems, connections, @settings)
    ranks = Map.new(request.nodes, &{&1.id, &1.rank})

    assert ranks == %{"1" => 1, "2" => 0, "3" => 1}
    assert length(request.edges) == 2

    assert Enum.all?(request.edges, fn edge ->
             ranks[edge.source] <= ranks[edge.target]
           end)
  end

  test "uses configured sorting to choose a root when no node has a status" do
    systems = [system(1, "Zulu", 0), system(2, "Alpha", 0), system(3, "Bravo", 0)]
    connections = [connection(1, 2), connection(2, 3)]
    request = Layout.build_request(systems, connections, @settings)
    nodes = Map.new(request.nodes, &{&1.id, &1})

    assert nodes["2"].rank == 0
    assert nodes["1"].rank == 1
    assert nodes["3"].rank == 1
  end

  defp system(id, name, status) do
    %{
      solar_system_id: id,
      name: name,
      status: status,
      visible: true,
      position_x: id * 10,
      position_y: id * 20,
      locked: false
    }
  end

  defp connection(source, target) do
    %{solar_system_source: source, solar_system_target: target}
  end
end
