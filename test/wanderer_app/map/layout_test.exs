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
    "verticalRootSpacing" => 52,
    "horizontalNodeSpacing" => 40,
    "horizontalLayerSpacing" => 80,
    "horizontalEdgeSpacing" => 16,
    "horizontalRootSpacing" => 80,
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

  test "treats a locked system as a root even when it has the default status" do
    systems = [
      system(1, "Home", 8),
      system(2, "Locked", 0) |> Map.merge(%{locked: true, sort_index: 0}),
      system(3, "Child", 0)
    ]

    request = Layout.build_request(systems, [connection(1, 2), connection(2, 3)], @settings)
    nodes = Map.new(request.nodes, &{&1.id, &1})

    assert nodes["1"].rank == 0
    assert nodes["2"].rank == 0
    assert nodes["3"].rank == 1
    assert request.edges == [%{id: "2_3", source: "2", target: "3"}]
  end

  test "packs locked root chains by sort index before home roots" do
    systems = [
      system(1, "Home", 8),
      system(2, "Locked second", 0) |> Map.merge(%{locked: true, sort_index: 1}),
      system(3, "Locked first", 0) |> Map.merge(%{locked: true, sort_index: 0})
    ]

    request = Layout.build_request(systems, [], @settings)

    nodes = [
      result_node(1, 0, 0),
      result_node(2, 400, 0),
      result_node(3, 800, 0)
    ]

    positions =
      nodes
      |> Layout.repack_root_components(request, systems, @settings)
      |> Map.new(&{&1["id"], &1["x"]})

    assert positions["3"] < positions["2"]
    assert positions["2"] < positions["1"]
  end

  test "uses direction-specific spacing between root components" do
    systems = [system(1, "Root A", 1), system(2, "Root B", 1)]
    nodes = [result_node(1, 0, 0), result_node(2, 500, 500)]

    horizontal_settings =
      @settings
      |> Map.put("direction", "LR")
      |> Map.put("horizontalRootSpacing", 10)

    horizontal_request = Layout.build_request(systems, [], horizontal_settings)

    horizontal_positions =
      nodes
      |> Layout.repack_root_components(horizontal_request, systems, horizontal_settings)
      |> Map.new(&{&1["id"], &1})

    assert horizontal_positions["2"]["y"] - horizontal_positions["1"]["y"] == 44

    vertical_settings = Map.put(@settings, "verticalRootSpacing", 15)
    vertical_request = Layout.build_request(systems, [], vertical_settings)

    vertical_positions =
      nodes
      |> Layout.repack_root_components(vertical_request, systems, vertical_settings)
      |> Map.new(&{&1["id"], &1})

    assert vertical_positions["2"]["x"] - vertical_positions["1"]["x"] == 145
  end

  test "selects spacing profile from the layout direction" do
    systems = [system(1, "Root", 1), system(2, "Child", 0)]
    connections = [connection(1, 2)]

    vertical = Layout.build_request(systems, connections, @settings)
    horizontal = Layout.build_request(systems, connections, Map.put(@settings, "direction", "LR"))

    assert vertical.options.spacing == %{nodeSpacing: 24, layerSpacing: 52, edgeSpacing: 12}
    assert horizontal.options.spacing == %{nodeSpacing: 40, layerSpacing: 80, edgeSpacing: 16}
  end

  test "does not send a provisional position for a newly added system" do
    systems = [system(1, "Existing", 1), system(2, "New", 0)]

    request =
      Layout.build_request(systems, [], @settings, new_system_ids: MapSet.new([2]))

    nodes = Map.new(request.nodes, &{&1.id, &1})

    assert nodes["1"].previousPosition == %{x: 10, y: 20}
    refute Map.has_key?(nodes["2"], :previousPosition)
  end

  test "accepts a complete layout result" do
    systems = [system(1, "Root", 1), system(2, "Child", 0)]
    nodes = [result_node(1, 10, 20), result_node(2, 30, 40)]

    assert {:ok, ^nodes} = Layout.validate_result_nodes(%{"nodes" => nodes}, systems)
  end

  test "rejects incomplete, duplicate and malformed layout results" do
    systems = [system(1, "Root", 1), system(2, "Child", 0)]

    assert {:error, :incomplete_layout_result} =
             Layout.validate_result_nodes(%{"nodes" => [result_node(1, 10, 20)]}, systems)

    assert {:error, :invalid_layout_nodes} =
             Layout.validate_result_nodes(
               %{"nodes" => [result_node(1, 10, 20), result_node(1, 30, 40)]},
               systems
             )

    assert {:error, :invalid_layout_nodes} =
             Layout.validate_result_nodes(
               %{"nodes" => [result_node(1, 10, 20), %{"id" => "2", "x" => 30}]},
               systems
             )

    assert {:error, :invalid_layout_result} = Layout.validate_result_nodes(%{}, systems)
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

  test "sorts system classes by space priority and tagged systems first within a class" do
    systems = [
      system(1, "Other", 0) |> Map.merge(%{system_class: 19, tag: nil}),
      system(2, "C4 untagged", 0) |> Map.merge(%{system_class: 4, tag: nil}),
      system(3, "Highsec", 0) |> Map.merge(%{system_class: 7, tag: nil}),
      system(4, "C4 B", 0) |> Map.merge(%{system_class: 4, tag: "B"}),
      system(5, "C4 A", 0) |> Map.merge(%{system_class: 4, tag: "A"}),
      system(6, "C1", 0) |> Map.merge(%{system_class: 1, tag: nil}),
      system(7, "Lowsec", 0) |> Map.merge(%{system_class: 8, tag: nil}),
      system(8, "Nullsec", 0) |> Map.merge(%{system_class: 9, tag: nil}),
      system(9, "C6", 0) |> Map.merge(%{system_class: 6, tag: nil}),
      system(10, "Pochven", 0) |> Map.merge(%{system_class: 25, tag: nil}),
      system(11, "Thera", 0) |> Map.merge(%{system_class: 12, tag: nil})
    ]

    request = Layout.build_request(systems, [], Map.put(@settings, "orderBy", "system-class"))

    ordered_ids =
      request.nodes
      |> Enum.sort_by(& &1.name)
      |> Enum.map(& &1.id)

    assert ordered_ids == ~w(3 7 8 6 5 4 2 9 11 10 1)
  end

  test "sorts tagged systems alphabetically before untagged systems" do
    systems = [
      system(1, "Untagged", 0) |> Map.merge(%{system_class: 1, tag: nil}),
      system(2, "Tag B", 0) |> Map.merge(%{system_class: 6, tag: "B"}),
      system(3, "Tag A", 0) |> Map.merge(%{system_class: 4, tag: "A"})
    ]

    request = Layout.build_request(systems, [], Map.put(@settings, "orderBy", "tag"))

    ordered_ids =
      request.nodes
      |> Enum.sort_by(& &1.name)
      |> Enum.map(& &1.id)

    assert ordered_ids == ~w(3 2 1)
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
      sort_index: nil,
      inserted_at: inserted_at
    }
  end

  defp connection(source, target) do
    %{solar_system_source: source, solar_system_target: target}
  end

  defp result_node(id, x, y), do: %{"id" => to_string(id), "x" => x, "y" => y}
end
