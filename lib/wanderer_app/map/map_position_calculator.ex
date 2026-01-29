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

  # Layout systems

  def layout_systems(systems, connections, opts) do
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

    # 1. Identify all roots for each component
    all_roots = components
      |> Enum.flat_map(&find_roots(&1, system_props))
      |> Enum.uniq()
      |> Enum.sort_by(&get_system_name(Map.get(system_props, &1)))

    all_roots_set = MapSet.new(all_roots)

    # 2. Pre-calculate root claims using Priority-based expansion (Oldest connections first)
    {root_claims, tree_edge_ids} = build_root_claims(all_roots_set, undirected_adj, connections)

    # 3. Build tree adjacency list for traversal to ensure naming/positioning strictly follow tree logic
    tree_adj = connections
      |> Enum.reduce(%{}, fn conn, acc ->
        if MapSet.member?(tree_edge_ids, conn.id) do
          s = conn.solar_system_source
          t = conn.solar_system_target
          acc
          |> Map.update(s, [t], &[t | &1])
          |> Map.update(t, [s], &[s | &1])
        else
          acc
        end
      end)

    # 4. Layout each root sequentially
    layout_type = (opts |> Keyword.get(:layout, "left_to_right")) |> String.to_atom()

    {final_positions, hierarchical_names, _next_breadth, _visited} = all_roots
      |> Enum.reduce({%{}, %{}, 0.0, MapSet.new()}, fn root_id, {pos_acc, name_acc, cur_breadth, visited_acc} ->
        if MapSet.member?(visited_acc, root_id) do
          {pos_acc, name_acc, cur_breadth, visited_acc}
        else
          {start_x, start_y} = case layout_type do
            :top_to_bottom -> {cur_breadth, 0.0}
            _ -> {0.0, cur_breadth}
          end

          # Recursive layout starting from this root, strictly following its claimed tree edges
          {subtree_pos, subtree_names, subtree_breadth, new_visited} = do_recursive_layout(root_id, start_x, start_y, tree_adj, system_props, visited_acc, root_claims, "0", layout_type)

          # Use a larger margin between root subtrees
          margin = case layout_type do
            :top_to_bottom -> @m_x * 3
            _ -> @m_y * 3
          end

          {Map.merge(pos_acc, subtree_pos), Map.merge(name_acc, subtree_names), cur_breadth + subtree_breadth + margin, new_visited}
        end
      end)

    # 5. Detect special connections (cross-list or cycle) and affected systems
    {special_conn_ids, affected_roots} = connections
      |> Enum.reduce({[], MapSet.new()}, fn conn, {ids_acc, roots_acc} ->
        if not MapSet.member?(tree_edge_ids, conn.id) do
          # This is a special connection (cycle or cross-list)
          root_s = Map.get(root_claims, conn.solar_system_source)
          root_t = Map.get(root_claims, conn.solar_system_target)

          new_roots_acc = roots_acc
          new_roots_acc = if root_s, do: MapSet.put(new_roots_acc, root_s), else: new_roots_acc
          new_roots_acc = if root_t, do: MapSet.put(new_roots_acc, root_t), else: new_roots_acc

          Logger.info("[PositionCalculator] Special connection detected (Cycle/Cross-List): #{get_system_name(system_props[conn.solar_system_source])} <-> #{get_system_name(system_props[conn.solar_system_target])}. Skipping affected components.")
          {[conn.id | ids_acc], new_roots_acc}
        else
          {ids_acc, roots_acc}
        end
      end)

    # Find all systems that belong to any affected root subtree
    skipped_system_ids = root_claims
      |> Enum.filter(fn {_, root_id} -> MapSet.member?(affected_roots, root_id) end)
      |> Enum.map(fn {sid, _} -> sid end)
      |> MapSet.new()

    updated_systems = systems
      |> Enum.map(fn %{solar_system_id: id} = system ->
        is_skipped = MapSet.member?(skipped_system_ids, id)
        system = if is_skipped do
          # Skip: keep original positions
          system
        else
          {x, y} = Map.get(final_positions, id, {float(system.position_x), float(system.position_y)})
          %{system | position_x: round(x), position_y: round(y)}
        end

        # Always attach the hierarchical name if it was calculated AND not skipped
        case Map.get(hierarchical_names, id) do
          h_name when not is_nil(h_name) and not is_skipped -> Map.put(system, :hierarchical_name, h_name)
          _ -> system
        end
      end)

    {updated_systems, special_conn_ids}
  end

  defp find_roots(component_ids, system_props) do
    component_systems = Enum.map(component_ids, &Map.get(system_props, &1))
    locked_roots = component_systems
      |> Enum.filter(&Map.get(&1, :locked, false))
      |> Enum.map(& &1.solar_system_id)

    if Enum.empty?(locked_roots) do
      # Fallback: take alphabetical first according to criteria
      component_systems
      |> Enum.sort_by(&get_system_name/1)
      |> List.first()
      |> Map.get(:solar_system_id)
      |> List.wrap()
    else
      locked_roots
    end
  end

  defp get_system_name(nil), do: ""
  defp get_system_name(system) do
    Map.get(system, :name) || Map.get(system, :temporary_name) || (system.solar_system_id |> Integer.to_string())
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


  defp do_recursive_layout(id, x, y, adj, system_props, visited, root_claims, path, layout \\ :left_to_right) do
    if MapSet.member?(visited, id) do
      {%{}, %{}, 0.0, visited}
    else
      system = Map.get(system_props, id)

      # Determine actual axes based on orientation
      {actual_x, actual_y} = case layout do
        :top_to_bottom ->
          ay = if Map.get(system, :locked, false) and path != "0", do: float(system.position_y), else: y
          {x, ay}
        _ ->
          ax = if Map.get(system, :locked, false) and path != "0", do: float(system.position_x), else: x
          {ax, y}
      end

      visited = MapSet.put(visited, id)

      # Determine current root for this node
      root_id = Map.get(root_claims, id)

      # Follow neighbors that belong to the SAME root claim and are not yet visited
      # (adj already only contains tree edges)
      children = Map.get(adj, id, [])
        |> Enum.filter(&(Map.get(root_claims, &1) == root_id))
        |> Enum.reject(&MapSet.member?(visited, &1))
        |> Enum.sort_by(&get_system_name(Map.get(system_props, &1)))

      current_name_map = %{id => path}

      if Enum.empty?(children) do
        branch_breadth = case layout do
          :top_to_bottom -> float(@w)
          _ -> float(@h)
        end
        {%{id => {actual_x, actual_y}}, current_name_map, branch_breadth, visited}
      else
        # Layout children sequentially based on orientation
        {children_pos, children_names, total_children_breadth, new_visited} = children
           |> Enum.with_index(1)
           |> Enum.reduce({%{}, %{}, 0.0, visited}, fn {child_id, index}, {acc_pos, acc_names, acc_b, acc_visited} ->
             child_path = if path == "0", do: "#{index}", else: "#{path}-#{index}"

             {child_x, child_y} = case layout do
               :top_to_bottom -> {actual_x + acc_b, actual_y + @h + @m_y}
               _ -> {actual_x + @w + @m_x, actual_y + acc_b}
             end

             {c_pos, c_names, c_b, c_v} = do_recursive_layout(child_id, child_x, child_y, adj, system_props, acc_visited, root_claims, child_path, layout)

             step_margin = case layout do
               :top_to_bottom -> @m_x
               _ -> @m_y
             end

             {Map.merge(acc_pos, c_pos), Map.merge(acc_names, c_names), acc_b + c_b + step_margin, c_v}
           end)

        margin_correction = case layout do
          :top_to_bottom -> @m_x
          _ -> @m_y
        end

        total_children_breadth = if total_children_breadth > 0, do: total_children_breadth - margin_correction, else: 0.0

        node_pos = %{id => {actual_x, actual_y}}
        node_breadth = case layout do
          :top_to_bottom -> float(@w)
          _ -> float(@h)
        end

        result_breadth = Enum.max([node_breadth, total_children_breadth])

        {Map.merge(node_pos, children_pos), Map.merge(current_name_map, children_names), result_breadth, new_visited}
      end
    end
  end

  defp build_root_claims(all_roots_set, adj, connections) do
    # Map connections to neutral keys {s, t} for quick age lookup
    conn_map = connections
      |> Enum.flat_map(fn c ->
        s = c.solar_system_source
        t = c.solar_system_target
        key = if s < t, do: {s, t}, else: {t, s}
        [{key, c}]
      end)
      |> Map.new()

    initial_claims = all_roots_set |> MapSet.to_list() |> Enum.map(&{&1, &1}) |> Map.new()

    # Priority-based search frontier
    # We sort all roots by name to have deterministic start
    sorted_roots = all_roots_set |> MapSet.to_list() |> Enum.sort_by(& Integer.to_string(&1))

    initial_frontier = sorted_roots
      |> Enum.flat_map(fn rid ->
        Map.get(adj, rid, [])
        |> Enum.reject(&Map.has_key?(initial_claims, &1))
        |> Enum.map(fn neighbor_id ->
          key = if rid < neighbor_id, do: {rid, neighbor_id}, else: {neighbor_id, rid}
          conn = Map.get(conn_map, key)

          inserted_at = Map.get(conn, :inserted_at) || ~U[2099-01-01 00:00:00Z]
          sort_key = {inserted_at, Map.get(conn, :id, "")}
          {sort_key, neighbor_id, rid, conn.id}
        end)
      end)

    do_build_claims(initial_frontier, adj, conn_map, initial_claims, MapSet.new())
  end

  # Simple priority-based expansion search
  defp do_build_claims([], _adj, _conn_map, claims, tree_edge_ids), do: {claims, tree_edge_ids}
  defp do_build_claims(frontier, adj, conn_map, claims, tree_edge_ids) do
    # Sort frontier by sort_key (age ASC, then ID ASC)
    [{_key, node_id, root_id, conn_id} | rest_frontier] = Enum.sort_by(frontier, fn {k, _, _, _} -> k end)

    if Map.has_key?(claims, node_id) do
      do_build_claims(rest_frontier, adj, conn_map, claims, tree_edge_ids)
    else
      new_claims = Map.put(claims, node_id, root_id)
      new_tree_edge_ids = MapSet.put(tree_edge_ids, conn_id)

      # Add neighbors to frontier
      new_neighbors = Map.get(adj, node_id, [])
        |> Enum.reject(&Map.has_key?(new_claims, &1))
        |> Enum.map(fn neighbor_id ->
          key = if node_id < neighbor_id, do: {node_id, neighbor_id}, else: {neighbor_id, node_id}
          conn = Map.get(conn_map, key)

          inserted_at = Map.get(conn, :inserted_at) || ~U[2099-01-01 00:00:00Z]
          sort_key = {inserted_at, Map.get(conn, :id, "")}
          {sort_key, neighbor_id, root_id, conn.id}
        end)

      do_build_claims(rest_frontier ++ new_neighbors, adj, conn_map, new_claims, new_tree_edge_ids)
    end
  end

  defp float(v) when is_integer(v), do: v * 1.0
  defp float(v), do: v
end
