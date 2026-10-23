defmodule WandererApp.Map.Layout do
  @moduledoc false

  @node_width 130
  @node_height 34
  @edge_routing "orthogonal"
  @position_update_concurrency 8
  @position_update_timeout_ms 10_000

  def run(map_id, settings) when is_binary(map_id), do: run_layout(map_id, settings)

  def run(%{id: map_id}, settings), do: run_layout(map_id, settings)

  defp run_layout(map_id, settings) do
    with {:ok, systems} <- WandererApp.MapSystemRepo.get_visible_by_map(map_id),
         {:ok, connections} <- WandererApp.MapConnectionRepo.get_by_map(map_id),
         request = build_request(systems, connections, settings),
         {:ok, result} <- WandererApp.LayoutServiceClient.layout(request),
         :ok <- apply_positions(map_id, Map.get(result, "nodes", [])) do
      {:ok, result}
    end
  end

  def apply_positions(map_id, nodes) do
    results =
      nodes
      |> Enum.flat_map(&position_update/1)
      |> Task.async_stream(
        &update_system_position(map_id, &1),
        max_concurrency: @position_update_concurrency,
        ordered: false,
        timeout: @position_update_timeout_ms,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    with {:ok, updated_systems} <- collect_updated_systems(results) do
      WandererApp.Map.Server.Impl.broadcast!(map_id, :update_systems, updated_systems)
      :ok
    end
  end

  @doc false
  def build_request(systems, connections, settings) do
    system_ids = MapSet.new(systems, & &1.solar_system_id)

    connections =
      Enum.filter(connections, fn connection ->
        MapSet.member?(system_ids, connection.solar_system_source) and
          MapSet.member?(system_ids, connection.solar_system_target)
      end)

    {ranks, oriented_connections, parents} = build_forest(systems, connections, settings)
    layout_names = build_layout_names(systems, ranks, parents, settings)
    spacing = layout_spacing(settings)

    %{
      nodes: Enum.map(systems, &build_node(&1, ranks, layout_names)),
      edges: Enum.map(oriented_connections, &build_edge/1),
      options: %{
        engine: settings["engine"],
        direction: settings["direction"],
        routing: @edge_routing,
        includeEdgeRoutes: false,
        spacing: %{
          nodeSpacing: spacing.node,
          layerSpacing: spacing.layer,
          edgeSpacing: spacing.edge
        },
        ordering: %{
          by: service_order_by(settings["orderBy"]),
          direction: settings["orderDirection"],
          locale: settings["locale"],
          policy: settings["orderPolicy"]
        },
        groups: settings["groups"],
        stability: %{
          preservePreviousPositions: settings["preservePreviousPositions"]
        }
      }
    }
  end

  defp layout_spacing(%{"direction" => direction} = settings) when direction in ["TB", "BT"] do
    %{
      node: settings["verticalNodeSpacing"],
      layer: settings["verticalLayerSpacing"],
      edge: settings["verticalEdgeSpacing"]
    }
  end

  defp layout_spacing(settings) do
    %{
      node: settings["horizontalNodeSpacing"],
      layer: settings["horizontalLayerSpacing"],
      edge: settings["horizontalEdgeSpacing"]
    }
  end

  defp build_node(system, ranks, layout_names) do
    id = to_string(system.solar_system_id)

    node = %{
      id: id,
      name: Map.fetch!(layout_names, system.solar_system_id),
      width: @node_width,
      height: @node_height,
      previousPosition: %{
        x: system.position_x || 0,
        y: system.position_y || 0
      },
      pinned: false
    }

    case Map.fetch(ranks, system.solar_system_id) do
      {:ok, rank} -> Map.put(node, :rank, rank)
      :error -> node
    end
  end

  defp build_edge(connection) do
    source = to_string(connection.solar_system_source)
    target = to_string(connection.solar_system_target)

    %{
      id: "#{source}_#{target}",
      source: source,
      target: target
    }
  end

  defp build_forest(systems, connections, settings) do
    systems_by_id = Map.new(systems, &{&1.solar_system_id, &1})
    order = ordered_ids(systems, settings)
    order_index = order |> Enum.with_index() |> Map.new()
    adjacency = build_adjacency(systems, connections)

    components =
      order
      |> connected_components(adjacency)
      |> Enum.sort_by(&component_sort_key(&1, systems_by_id, order_index))

    {ranks, _tree_pairs, root_owners, parents} =
      components
      |> Enum.reduce(
        {%{}, MapSet.new(), %{}, %{}},
        fn component, {ranks, tree_pairs, root_owners, parents} ->
          roots = component_roots(component, systems_by_id, order_index)

          {component_ranks, component_pairs, component_root_owners, component_parents} =
            breadth_first_forest(roots, adjacency, order_index)

          {
            Map.merge(ranks, component_ranks),
            MapSet.union(tree_pairs, component_pairs),
            Map.merge(root_owners, component_root_owners),
            Map.merge(parents, component_parents)
          }
        end
      )

    oriented =
      connections
      |> Enum.filter(&same_root_chain?(&1, root_owners))
      |> Enum.map(&orient_connection(&1, ranks, order_index))

    {ranks, oriented, parents}
  end

  defp ordered_ids(systems, settings) do
    direction = settings["orderDirection"]

    systems
    |> Enum.sort_by(&system_sort_key(&1, settings), sort_direction(direction))
    |> Enum.map(& &1.solar_system_id)
  end

  defp system_sort_key(system, %{"orderBy" => "added-at"}),
    do: {inserted_at_key(system), system.solar_system_id}

  defp system_sort_key(system, %{"orderBy" => "id"}),
    do: {system.solar_system_id}

  defp system_sort_key(system, %{"orderBy" => "previous-order", "direction" => direction})
       when direction in ["TB", "BT"],
       do: {system.position_x || 0, system.solar_system_id}

  defp system_sort_key(system, %{"orderBy" => "previous-order"}),
    do: {system.position_y || 0, system.solar_system_id}

  defp system_sort_key(system, _settings),
    do: {system.name |> to_string() |> String.downcase(), system.solar_system_id}

  defp sort_direction("desc"), do: :desc
  defp sort_direction(_direction), do: :asc

  defp build_adjacency(systems, connections) do
    adjacency = Map.new(systems, &{&1.solar_system_id, MapSet.new()})

    Enum.reduce(connections, adjacency, fn connection, result ->
      result
      |> Map.update!(
        connection.solar_system_source,
        &MapSet.put(&1, connection.solar_system_target)
      )
      |> Map.update!(
        connection.solar_system_target,
        &MapSet.put(&1, connection.solar_system_source)
      )
    end)
  end

  defp connected_components(order, adjacency) do
    {components, _visited} =
      Enum.reduce(order, {[], MapSet.new()}, fn id, {components, visited} ->
        if MapSet.member?(visited, id) do
          {components, visited}
        else
          {component, visited} = collect_component([id], adjacency, visited, [])
          {[Enum.reverse(component) | components], visited}
        end
      end)

    Enum.reverse(components)
  end

  defp collect_component([], _adjacency, visited, component), do: {component, visited}

  defp collect_component([id | pending], adjacency, visited, component) do
    if MapSet.member?(visited, id) do
      collect_component(pending, adjacency, visited, component)
    else
      neighbours = adjacency |> Map.fetch!(id) |> MapSet.to_list()

      collect_component(neighbours ++ pending, adjacency, MapSet.put(visited, id), [
        id | component
      ])
    end
  end

  defp component_roots(component, systems_by_id, order_index) do
    roots =
      component
      |> Enum.filter(fn id ->
        status = systems_by_id |> Map.fetch!(id) |> Map.get(:status)
        is_integer(status) and status != 0
      end)
      |> Enum.sort_by(&Map.fetch!(order_index, &1))

    case roots do
      [] -> [Enum.min_by(component, &Map.fetch!(order_index, &1))]
      roots -> roots
    end
  end

  defp component_sort_key(component, systems_by_id, order_index) do
    component
    |> component_roots(systems_by_id, order_index)
    |> List.first()
    |> then(&Map.fetch!(order_index, &1))
  end

  defp inserted_at_key(%{inserted_at: %DateTime{} = value}),
    do: DateTime.to_unix(value, :microsecond)

  defp inserted_at_key(%{inserted_at: %NaiveDateTime{} = value}),
    do: value |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:microsecond)

  defp inserted_at_key(_system), do: 0

  defp service_order_by("added-at"), do: "name"
  defp service_order_by(value), do: value

  defp build_layout_names(systems, ranks, parents, %{"orderBy" => "added-at"}) do
    systems
    |> Enum.sort_by(&{Map.get(ranks, &1.solar_system_id, -1), &1.solar_system_id})
    |> Enum.reduce(%{}, fn system, names ->
      id = system.solar_system_id
      segment = layout_order_segment(system)

      name =
        case Map.get(parents, id) do
          nil -> segment
          parent_id -> "#{Map.fetch!(names, parent_id)}/#{segment}"
        end

      Map.put(names, id, name)
    end)
  end

  defp build_layout_names(systems, _ranks, _parents, _settings),
    do: Map.new(systems, &{&1.solar_system_id, &1.name || to_string(&1.solar_system_id)})

  defp layout_order_segment(system) do
    timestamp = inserted_at_key(system) |> Integer.to_string() |> String.pad_leading(20, "0")
    "#{timestamp}:#{system.solar_system_id}"
  end

  defp breadth_first_forest(roots, adjacency, order_index) do
    initial_ranks = Map.new(roots, &{&1, 0})
    initial_root_owners = Map.new(roots, &{&1, &1})
    initial_parents = Map.new(roots, &{&1, nil})

    breadth_first_forest(
      Enum.map(roots, &{&1, 0}),
      adjacency,
      order_index,
      initial_ranks,
      MapSet.new(),
      initial_root_owners,
      initial_parents
    )
  end

  defp breadth_first_forest(
         [],
         _adjacency,
         _order_index,
         ranks,
         tree_pairs,
         root_owners,
         parents
       ),
       do: {ranks, tree_pairs, root_owners, parents}

  defp breadth_first_forest(
         [{id, rank} | queue],
         adjacency,
         order_index,
         ranks,
         tree_pairs,
         root_owners,
         parents
       ) do
    neighbours =
      adjacency
      |> Map.fetch!(id)
      |> Enum.reject(&Map.has_key?(ranks, &1))
      |> Enum.sort_by(&Map.fetch!(order_index, &1))

    next_rank = rank + 1
    ranks = Enum.reduce(neighbours, ranks, &Map.put(&2, &1, next_rank))
    tree_pairs = Enum.reduce(neighbours, tree_pairs, &MapSet.put(&2, ordered_pair(id, &1)))
    root_owner = Map.fetch!(root_owners, id)
    root_owners = Enum.reduce(neighbours, root_owners, &Map.put(&2, &1, root_owner))
    parents = Enum.reduce(neighbours, parents, &Map.put(&2, &1, id))
    queue = queue ++ Enum.map(neighbours, &{&1, next_rank})

    breadth_first_forest(
      queue,
      adjacency,
      order_index,
      ranks,
      tree_pairs,
      root_owners,
      parents
    )
  end

  defp same_root_chain?(connection, root_owners) do
    source_root = Map.get(root_owners, connection.solar_system_source)
    target_root = Map.get(root_owners, connection.solar_system_target)

    not is_nil(source_root) and source_root == target_root
  end

  defp ordered_pair(left, right) when left <= right, do: {left, right}
  defp ordered_pair(left, right), do: {right, left}

  defp orient_connection(connection, ranks, order_index) do
    source = connection.solar_system_source
    target = connection.solar_system_target
    source_key = {Map.get(ranks, source, 0), Map.fetch!(order_index, source)}
    target_key = {Map.get(ranks, target, 0), Map.fetch!(order_index, target)}

    if source_key <= target_key do
      connection
    else
      %{connection | solar_system_source: target, solar_system_target: source}
    end
  end

  defp position_update(%{"id" => id, "x" => x, "y" => y})
       when is_binary(id) and is_number(x) and is_number(y) do
    case Integer.parse(id) do
      {solar_system_id, ""} ->
        [
          %{
            solar_system_id: solar_system_id,
            position_x: round(x),
            position_y: round(y)
          }
        ]

      _ ->
        []
    end
  end

  defp position_update(_node), do: []

  defp update_system_position(map_id, update),
    do: WandererApp.Map.Server.update_system_position_silently(map_id, update)

  defp collect_updated_systems(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, system}}, {:ok, systems} ->
        {:cont, {:ok, [system | systems]}}

      {:ok, {:error, reason}}, _acc ->
        {:halt, {:error, reason}}

      {:exit, reason}, _acc ->
        {:halt, {:error, reason}}

      unexpected, _acc ->
        {:halt, {:error, unexpected}}
    end)
    |> case do
      {:ok, systems} -> {:ok, Enum.reverse(systems)}
      error -> error
    end
  end
end
