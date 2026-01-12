defmodule WandererApp.Map.PositionCalculator do
  @moduledoc false
  require Logger

  @ddrt Application.compile_env(:wanderer_app, :ddrt)

  # Node height
  @h 34
  # Node weight
  @w 130
  # Nodes margin
  @m_x 50
  @m_y 41

  @start_x 0
  @start_y 0

  def get_system_bounding_rect(%{position_x: x, position_y: y} = _system) do
    [{x, x + @w}, {y, y + @h}]
  end

  def get_system_bounding_rect(_system), do: [{0, 0}, {0, 0}]

  def get_new_system_position(nil, rtree_name, opts) do
    {:ok, {x, y}} = rtree_name |> check_system_available_positions(@start_x, @start_y, 1, opts)
    %{x: x, y: y}
  end

  def get_new_system_position(
        %{position_x: start_x, position_y: start_y} = _old_system,
        rtree_name,
        opts
      ) do
    {:ok, {x, y}} = rtree_name |> check_system_available_positions(start_x, start_y, 1, opts)

    %{x: x, y: y}
  end

  defp check_system_available_positions(_rtree_name, _start_x, _start_y, 100, _opts),
    do: {:ok, {@start_x, @start_y}}

  defp check_system_available_positions(rtree_name, start_x, start_y, level, opts) do
    possible_positions = get_available_positions(level, start_x, start_y, opts)

    case get_available_position(possible_positions, rtree_name) do
      {:ok, nil} ->
        rtree_name |> check_system_available_positions(start_x, start_y, level + 1, opts)

      {:ok, position} ->
        {:ok, position}
    end
  end

  defp get_available_position([], _rtree_name), do: {:ok, nil}

  defp get_available_position([position | rest], rtree_name) do
    if is_available_position(position, rtree_name) do
      {:ok, position}
    else
      get_available_position(rest, rtree_name)
    end
  end

  defp is_available_position({x, y} = _position, rtree_name) do
    case @ddrt.query(get_system_bounding_rect(%{position_x: x, position_y: y}), rtree_name) do
      {:ok, []} ->
        true

      {:ok, _} ->
        false

      _ ->
        true
    end
  end

  def get_available_positions(level, x, y, opts),
    do: adjusted_coordinates(1 + level * 2, x, y, opts)

  defp edge_coordinates(n, _opts) when n > 1 do
    min = -div(n, 2)
    max = div(n, 2)
    # Top edge
    top_edge = for x <- min..max, do: {x, min}
    # Right edge
    right_edge = for y <- min..max, do: {max, y}
    # Bottom edge
    bottom_edge = for x <- max..min, do: {x, max}
    # Left edge
    left_edge = for y <- max..min, do: {min, y}

    # Combine all edges in clockwise order
    (right_edge ++ bottom_edge ++ left_edge ++ top_edge)
    |> Enum.uniq()
  end

  defp sorted_edge_coordinates(n, opts) when n > 1 do
    coordinates = edge_coordinates(n, opts)
    start_index = get_start_index(n, opts[:layout])

    Enum.slice(coordinates, start_index, length(coordinates) - start_index) ++
      Enum.slice(coordinates, 0, start_index)
  end

  defp get_start_index(n, "left_to_right"), do: div(n, 2)

  defp get_start_index(n, "top_to_bottom"), do: div(n, 2) + n - 1

  # Default to left_to_right when layout is nil
  defp get_start_index(n, nil), do: div(n, 2)

  defp adjusted_coordinates(n, start_x, start_y, opts) when n > 1 do
    sorted_coords = sorted_edge_coordinates(n, opts)

    Enum.map(sorted_coords, fn {x, y} ->
      {
        start_x + x * (@w + @m_x),
        start_y + y * (@h + @m_y)
      }
    end)
  end

  def layout_systems(systems, connections, _opts) do
    Logger.info("Layouting systems with #{length(systems)} systems and #{length(connections)} connections")

    system_ids = Enum.map(systems, & &1.solar_system_id)
    system_props = systems |> Enum.map(&{&1.solar_system_id, &1}) |> Map.new()

    # Build undirected adjacency list for component finding and traversal
    undirected_adj = connections
      |> Enum.reduce(%{}, fn %{solar_system_source: s, solar_system_target: t}, acc ->
        if s in system_ids and t in system_ids do
          acc
          |> Map.update(s, [t], &[t | &1])
          |> Map.update(t, [s], &[s | &1])
        else
          acc
        end
      end)

    # Find connected components
    components = find_components(system_ids, undirected_adj)

    # Layout each component sequentially
    {final_positions, _next_y, _visited} = components
      |> Enum.reduce({%{}, 0.0, MapSet.new()}, fn component_ids, {pos_acc, cur_y, visited_acc} ->
        # Find the best root for this component using a heuristic
        root_id = find_best_root(component_ids, connections)

        # Recursive layout starting from this root, using undirected edges to explore the component
        {subtree_pos, subtree_height, new_visited} = do_recursive_layout(root_id, 0.0, cur_y, undirected_adj, system_props, visited_acc)
        # Use a larger margin between components (@m_y * 3)
        {Map.merge(pos_acc, subtree_pos), cur_y + subtree_height + @m_y * 3, new_visited}
      end)

    systems
    |> Enum.map(fn %{solar_system_id: id} = system ->
      {x, y} = Map.get(final_positions, id, {0.0, 0.0})
      %{system | position_x: round(x), position_y: round(y)}
    end)
  end

  defp find_components(ids, adj) do
    ids
    |> Enum.reduce({[], MapSet.new()}, fn id, {components, visited} ->
      if MapSet.member?(visited, id) do
        {components, visited}
      else
        {component, new_visited} = bfs_component(id, adj)
        {[component | components], MapSet.union(visited, new_visited)}
      end
    end)
    |> elem(0)
  end

  defp bfs_component(start_id, adj) do
    queue = :queue.from_list([start_id])
    do_bfs_component(queue, adj, MapSet.new())
  end

  defp do_bfs_component(queue, adj, visited) do
    case :queue.out(queue) do
      {{:value, id}, q} ->
        if MapSet.member?(visited, id) do
          do_bfs_component(q, adj, visited)
        else
          visited = MapSet.put(visited, id)
          neighbors = Map.get(adj, id, [])
          q = Enum.reduce(neighbors, q, &:queue.in(&1, &2))
          do_bfs_component(q, adj, visited)
        end
      {:empty, _} ->
        {MapSet.to_list(visited), visited}
    end
  end

  defp find_best_root(component_ids, connections) do
    component_set = MapSet.new(component_ids)

    # Heuristic: score = out_degree - in_degree
    # We want nodes that are visually "parents" (more outgoing)
    degrees = connections
      |> Enum.filter(&(&1.solar_system_source in component_set and &1.solar_system_target in component_set))
      |> Enum.reduce(%{}, fn %{solar_system_source: s, solar_system_target: t}, acc ->
        acc
        |> Map.update(s, 1, &(&1 + 1))
        |> Map.update(t, -1, &(&1 - 1))
      end)

    component_ids
    |> Enum.sort_by(fn id ->
      score = Map.get(degrees, id, 0)
      # Sort by descending score (higher score is better root)
      {-score, id}
    end)
    |> List.first()
  end

  defp do_recursive_layout(id, x, y, adj, system_props, visited) do
    if MapSet.member?(visited, id) do
      {%{}, 0.0, visited}
    else
      system = Map.get(system_props, id)
      # If locked, use original X, otherwise use calculated X
      actual_x = if Map.get(system, :locked, false), do: float(system.position_x), else: x

      visited = MapSet.put(visited, id)
      # Use the undirected adj but skip already visited nodes (effectively following a spanning tree)
      children = Map.get(adj, id, []) |> Enum.reject(&MapSet.member?(visited, &1))

      if Enum.empty?(children) do
        {%{id => {actual_x, y}}, float(@h), visited}
      else
        # Layout children sequentially below each other
        {children_pos, total_children_height, new_visited} = children
           |> Enum.reduce({%{}, 0.0, visited}, fn child_id, {acc_pos, acc_h, acc_visited} ->
             {c_pos, c_h, c_v} = do_recursive_layout(child_id, actual_x + @w + @m_x, y + acc_h, adj, system_props, acc_visited)
             {Map.merge(acc_pos, c_pos), acc_h + c_h + @m_y, c_v}
           end)

        # Remove trailing margin from total height if we had children
        total_children_height = if total_children_height > 0, do: total_children_height - @m_y, else: 0.0

        # Current node position
        node_pos = %{id => {actual_x, y}}

        # Resulting height is max of node height and total children height
        result_height = Enum.max([float(@h), total_children_height])

        {Map.merge(node_pos, children_pos), result_height, new_visited}
      end
    end
  end

  defp float(v) when is_integer(v), do: v * 1.0
  defp float(v), do: v
end
