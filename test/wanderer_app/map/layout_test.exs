defmodule WandererApp.Map.LayoutTest do
  use ExUnit.Case, async: true

  alias WandererApp.Map.Layout

  @settings %{
    "engine" => "elk",
    "direction" => "TB",
    "routing" => "orthogonal",
    "verticalNodeSpacing" => 24,
    "verticalLayerSpacing" => 52,
    "verticalEdgeSpacing" => 12,
    "horizontalNodeSpacing" => 40,
    "horizontalLayerSpacing" => 80,
    "horizontalEdgeSpacing" => 16,
    "orderBy" => "name",
    "orderDirection" => "asc",
    "locale" => "en",
    "orderPolicy" => "prefer",
    "groups" => "none",
    "preservePreviousPositions" => false
  }

  test "uses non-default statuses and isolated systems as roots" do
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
    assert nodes["4"].rank == 0

    assert request.edges == [%{id: "1_2", source: "1", target: "2"}]
  end

  test "selects spacing profile from the layout direction" do
    systems = [system(1, "Root", 1), system(2, "Child", 0)]
    connections = [connection(1, 2)]

    vertical = Layout.build_request(systems, connections, @settings)
    horizontal = Layout.build_request(systems, connections, Map.put(@settings, "direction", "LR"))

    assert vertical.options.spacing == %{nodeSpacing: 24, layerSpacing: 52, edgeSpacing: 12}
    assert horizontal.options.spacing == %{nodeSpacing: 40, layerSpacing: 80, edgeSpacing: 16}
  end

  test "does not merge separate root chains through a cross-chain connection" do
    systems = [
      system(1, "Root A", 1),
      system(2, "A1", 0),
      system(3, "A2", 0),
      system(4, "Root B", 2),
      system(5, "B1", 0),
      system(6, "B2", 0)
    ]

    connections = [
      connection(1, 2),
      connection(2, 3),
      connection(4, 5),
      connection(5, 6),
      connection(3, 6)
    ]

    request = Layout.build_request(systems, connections, @settings)
    ranks = Map.new(request.nodes, &{&1.id, &1.rank})
    edge_ids = MapSet.new(request.edges, & &1.id)

    assert ranks == %{"1" => 0, "2" => 1, "3" => 2, "4" => 0, "5" => 1, "6" => 2}
    assert edge_ids == MapSet.new(["1_2", "2_3", "4_5", "5_6"])
  end

  test "breaks cycles into deterministic levels and orients edges away from roots" do
    systems = [system(1, "Charlie", 0), system(2, "Alpha", 1), system(3, "Bravo", 0)]
    connections = [connection(1, 2), connection(2, 3), connection(3, 1)]
    request = Layout.build_request(systems, connections, @settings)
    ranks = Map.new(request.nodes, &{&1.id, &1.rank})

    assert ranks == %{"1" => 1, "2" => 0, "3" => 1}
    assert length(request.edges) == 3

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

  test "keeps descendants grouped by their parent when sorting by added time" do
    systems = [
      system(1, "Root", 1, ~U[2026-01-01 00:00:00Z]),
      system(2, "First branch", 0, ~U[2026-01-02 00:00:00Z]),
      system(3, "Second branch", 0, ~U[2026-01-03 00:00:00Z]),
      system(4, "Later first child", 0, ~U[2026-01-05 00:00:00Z]),
      system(5, "Earlier second child", 0, ~U[2026-01-04 00:00:00Z])
    ]

    settings = Map.put(@settings, "orderBy", "added-at")

    request =
      Layout.build_request(
        systems,
        [connection(1, 2), connection(1, 3), connection(2, 4), connection(3, 5)],
        settings
      )

    names = Map.new(request.nodes, &{&1.id, &1.name})

    assert names["2"] < names["3"]
    assert names["4"] < names["5"]
    assert String.starts_with?(names["4"], names["2"])
    assert String.starts_with?(names["5"], names["3"])
  end

  defp system(id, name, status) do
    system(id, name, status, nil)
  end

  defp system(id, name, status, inserted_at) do
    %{
      solar_system_id: id,
      name: name,
      status: status,
      visible: true,
      position_x: id * 10,
      position_y: id * 20,
      locked: false,
      inserted_at: inserted_at
    }
  end

  defp connection(source, target) do
    %{solar_system_source: source, solar_system_target: target}
  end
end
