defmodule DDRT.DynamicRtreeImpl do
  alias DDRT.DynamicRtreeImpl.{Node, Utils}

  require Logger
  import IO.ANSI

  # Between 1 y 64800. Bigger value => ^ updates speed, ~v query speed.
  @max_area 20000

  defmacro __using__(_) do
    quote do
      alias DDRT.DynamicRtreeImpl

      @doc false
      defdelegate tree_new(opts), to: DynamicRtreeImpl

      @doc false
      defdelegate tree_insert(tree, leaf), to: DynamicRtreeImpl

      @doc false
      defdelegate tree_query(tree, box), to: DynamicRtreeImpl

      @doc false
      defdelegate tree_query(tree, box, depth), to: DynamicRtreeImpl

      @doc false
      defdelegate tree_delete(tree, id), to: DynamicRtreeImpl

      @doc false
      defdelegate tree_update_leaf(tree, id, update), to: DynamicRtreeImpl
    end
  end

  # PUBLIC METHODS

  def tree_new(opts) do
    {f, s} = :rand.seed(:exrop, opts[:seed])
    {node, new_ticket} = Node.new(f, s)

    tree_init =
      case opts[:type] do
        Map -> %{}
        MerkleMap -> %MerkleMap{}
      end

    tree =
      tree_init
      |> opts[:type].put(:ticket, new_ticket)
      |> opts[:type].put(:root, node)
      |> opts[:type].put(node, {[], nil, [{0, 0}, {0, 0}]})

    {tree, %{params: opts, seeding: f}}
  end

  def tree_insert(rbundle, {id, _box} = leaf) do
    if rbundle.tree |> rbundle[:type].get(id) do
      if rbundle.verbose,
        do:
          Logger.debug(
            cyan() <>
              "[" <>
              green() <>
              "Insertion" <>
              cyan() <>
              "] failed:" <>
              yellow() <>
              " [#{id}] " <>
              cyan() <>
              "already exists at tree." <>
              yellow() <> " [Tip]" <> cyan() <> " use " <> yellow() <> "update_leaf/3"
          )

      rbundle.tree
    else
      path = best_subtree(rbundle, leaf)
      t1 = :os.system_time(:microsecond)

      r =
        insertion(rbundle, path, leaf)
        |> recursive_update(tl(path), leaf, :insertion)

      t2 = :os.system_time(:microsecond)

      if rbundle.verbose,
        do:
          Logger.debug(
            cyan() <>
              "[" <>
              green() <>
              "Insertion" <>
              cyan() <>
              "] success: " <>
              yellow() <>
              "[#{id}]" <> cyan() <> " was inserted at" <> yellow() <> " ['#{hd(path)}']"
          )

      if rbundle.verbose,
        do:
          Logger.info(
            cyan() <>
              "[" <> green() <> "Insertion" <> cyan() <> "] took" <> yellow() <> " #{t2 - t1} µs"
          )

      r
    end
  end

  def tree_query(rbundle, box) do
    t1 = :os.system_time(:microsecond)
    r = find_match_leaves(rbundle, box, [get_root(rbundle)], [], [])
    t2 = :os.system_time(:microsecond)

    if rbundle.verbose,
      do:
        Logger.info(
          cyan() <>
            "[" <>
            color(201) <>
            "Query" <>
            cyan() <>
            "] box " <>
            yellow() <>
            "#{box |> Kernel.inspect()} " <> cyan() <> "took " <> yellow() <> "#{t2 - t1} µs"
        )

    r
  end

  def tree_query(rbundle, box, depth) do
    find_match_depth(rbundle, box, [{get_root(rbundle), 0}], [], depth)
  end

  def tree_delete(rbundle, id) do
    t1 = :os.system_time(:microsecond)

    r =
      if rbundle.tree |> rbundle[:type].get(id) do
        remove(rbundle, id)
      else
        rbundle.tree
      end

    t2 = :os.system_time(:microsecond)

    if rbundle.verbose,
      do:
        Logger.info(
          cyan() <>
            "[" <>
            color(124) <>
            "Delete" <>
            cyan() <>
            "] leaf " <>
            yellow() <> "[#{id}]" <> cyan() <> " took " <> yellow() <> "#{t2 - t1} µs"
        )

    r
  end

  def tree_update_leaf(rbundle, id, {old_box, new_box} = boxes) do
    if rbundle.tree |> rbundle[:type].get(id) do
      t1 = :os.system_time(:microsecond)
      r = update(rbundle, id, boxes)
      t2 = :os.system_time(:microsecond)

      if rbundle.verbose,
        do:
          Logger.info(
            cyan() <>
              "[" <>
              color(195) <>
              "Update" <>
              cyan() <>
              "] " <>
              yellow() <>
              "[#{id}]" <>
              cyan() <>
              " from " <>
              yellow() <>
              "#{old_box |> Kernel.inspect()}" <>
              cyan() <>
              " to " <>
              yellow() <>
              "#{new_box |> Kernel.inspect()}" <>
              cyan() <> " took " <> yellow() <> "#{t2 - t1} µs"
          )

      r
    else
      if rbundle.verbose,
        do:
          Logger.warning(
            cyan() <>
              "[" <>
              color(195) <>
              "Update" <> cyan() <> "] " <> yellow() <> "[#{id}] doesn't exists" <> cyan()
          )

      rbundle.tree
    end
  end

  # You dont need to know old_box but is a BIT slower
  def tree_update_leaf(rbundle, id, new_box) do
    tree_update_leaf(
      rbundle,
      id,
      {rbundle.tree |> rbundle[:type].get(id) |> Utils.tuple_value(:bbox), new_box}
    )
  end

  ### PRIVATE METHODS

  # Helpers
  defp get_root(rbundle) do
    rbundle.tree |> rbundle[:type].get(:root)
  end

  defp is_root?(rbundle, node) do
    get_root(rbundle) == node
  end

  ## Internal actions
  ## Insert

  # triple - S (Structure Swifty Shift)
  defp triple_s(rbundle, old_node, new_node, {id, box}) do
    tuple_entry =
      {old_node_childs_update, _daddy, _bbox} =
      rbundle.tree |> rbundle[:type].get(old_node) |> (fn {n, d, b} -> {n -- [id], d, b} end).()

    tree_update =
      rbundle.tree
      |> rbundle[:type].update!(new_node, fn {ch, d, b} -> {[id] ++ ch, d, b} end)
      |> rbundle[:type].update!(id, fn {ch, _d, b} -> {ch, new_node, b} end)

    if length(old_node_childs_update) > 0 do
      %{rbundle | tree: tree_update |> rbundle[:type].put(old_node, tuple_entry)}
      |> recursive_update(old_node, box, :deletion)
    else
      %{rbundle | tree: tree_update} |> remove(old_node)
    end
  end

  defp insertion(rbundle, branch, {_id, _box} = leaf) do
    tree_update = add_entry(rbundle, hd(branch), leaf)

    childs = tree_update |> rbundle[:type].get(hd(branch)) |> Utils.tuple_value(:childs)

    final_tree =
      if length(childs) > rbundle.width do
        handle_overflow(%{rbundle | tree: tree_update}, branch)
      else
        tree_update
      end

    %{rbundle | tree: final_tree}
  end

  defp add_entry(rbundle, node, {id, box} = _leaf) do
    rbundle.tree
    |> rbundle[:type].update!(node, fn {ch, daddy, b} ->
      {[id] ++ ch, daddy, Utils.combine_multiple([box, b])}
    end)
    |> rbundle[:type].put(id, {:leaf, node, box})
  end

  defp handle_overflow(rbundle, branch) do
    n = hd(branch)
    {node_n, new_node} = split(rbundle, n)
    treeck = rbundle.tree |> rbundle[:type].put(:ticket, new_node.next_ticket)

    if is_root?(rbundle, n) do
      {new_root, ticket} = Node.new(rbundle.seeding, treeck |> rbundle[:type].get(:ticket))
      treeck = treeck |> rbundle[:type].put(:ticket, ticket)
      root_bbox = Utils.combine_multiple([node_n.bbox, new_node.bbox])

      treeck =
        treeck
        |> rbundle[:type].put(new_node.id, {new_node.childs, new_root, new_node.bbox})
        |> rbundle[:type].replace!(node_n.id, {node_n.childs, new_root, node_n.bbox})
        |> rbundle[:type].replace!(:root, new_root)
        |> rbundle[:type].put(new_root, {[node_n.id, new_node.id], nil, root_bbox})

      new_node.childs
      |> Enum.reduce(treeck, fn c, acc ->
        acc |> rbundle[:type].update!(c, fn {ch, _d, b} -> {ch, new_node.id, b} end)
      end)
    else
      parent = hd(tl(branch))

      treeck =
        treeck
        |> rbundle[:type].put(new_node.id, {new_node.childs, parent, new_node.bbox})
        |> rbundle[:type].replace!(node_n.id, {node_n.childs, parent, node_n.bbox})
        |> rbundle[:type].update!(parent, fn {ch, d, b} ->
          {[new_node.id] ++ ch, d, Utils.combine_multiple([b, new_node.bbox])}
        end)

      updated_tree =
        new_node.childs
        |> Enum.reduce(treeck, fn c, acc ->
          acc |> rbundle[:type].update!(c, fn {ch, _d, b} -> {ch, new_node.id, b} end)
        end)

      if length(updated_tree |> rbundle[:type].get(parent) |> elem(0)) > rbundle.width,
        do: handle_overflow(%{rbundle | tree: updated_tree}, tl(branch)),
        else: updated_tree
    end
  end

  defp split(rbundle, node) do
    sorted_nodes =
      rbundle.tree
      |> rbundle[:type].get(node)
      |> Utils.tuple_value(:childs)
      |> Enum.map(fn n ->
        box = rbundle.tree |> rbundle[:type].get(n) |> Utils.tuple_value(:bbox)
        {box |> Utils.middle_value(), n, box}
      end)
      |> Enum.sort()
      |> Enum.map(fn {_x, y, z} -> {y, z} end)

    {n_id, n_bbox} =
      sorted_nodes |> Enum.slice(0..((rbundle.width / 2 - 1) |> Kernel.trunc())) |> Enum.unzip()

    {dn_id, dn_bbox} =
      sorted_nodes
      |> Enum.slice(((rbundle.width / 2) |> Kernel.trunc())..(length(sorted_nodes) - 1))
      |> Enum.unzip()

    {new_node, next_ticket} =
      Node.new(rbundle.seeding, rbundle.tree |> rbundle[:type].get(:ticket))

    n_bounds = n_bbox |> Utils.combine_multiple()
    dn_bounds = dn_bbox |> Utils.combine_multiple()

    {%{id: node, childs: n_id, bbox: n_bounds},
     %{id: new_node, childs: dn_id, bbox: dn_bounds, next_ticket: next_ticket}}
  end

  defp best_subtree(rbundle, leaf) do
    find_best_subtree(rbundle, get_root(rbundle), leaf, [])
  end

  defp find_best_subtree(rbundle, root, {_id, box} = leaf, track) do
    childs = rbundle.tree |> rbundle[:type].get(root) |> Utils.tuple_value(:childs)

    if is_list(childs) and length(childs) > 0 do
      winner = get_best_candidate(rbundle, childs, box)
      new_track = [root] ++ track
      find_best_subtree(rbundle, winner, leaf, new_track)
    else
      if is_atom(childs), do: track, else: [root] ++ track
    end
  end

  defp get_best_candidate(rbundle, candidates, box) do
    win_entry =
      candidates
      |> Enum.reduce_while(%{id: :not_id, cost: :infinity}, fn c, acc ->
        cbox = rbundle.tree |> rbundle[:type].get(c) |> Utils.tuple_value(:bbox)

        if Utils.contained?(cbox, box) do
          {:halt, %{id: c, cost: 0}}
        else
          enlargement = Utils.enlargement_area(cbox, box)

          if enlargement < acc |> Map.get(:cost) do
            {:cont, %{id: c, cost: enlargement}}
          else
            {:cont, acc}
          end
        end
      end)

    win_entry[:id]
  end

  ## Query

  defp find_match_leaves(rbundle, box, dig, leaves, flood) do
    f = hd(dig)
    tail = if length(dig) > 1, do: tl(dig), else: []
    {content, _dad, fbox} = rbundle.tree |> rbundle[:type].get(f)

    {new_dig, new_leaves, new_flood} =
      if Utils.overlap?(fbox, box) do
        if is_atom(content) do
          {tail, [f] ++ leaves, flood}
        else
          if Utils.contained?(box, fbox),
            do: {tail, leaves, [f] ++ flood},
            else: {content ++ tail, leaves, flood}
        end
      else
        {tail, leaves, flood}
      end

    if length(new_dig) > 0 do
      find_match_leaves(rbundle, box, new_dig, new_leaves, new_flood)
    else
      new_leaves ++ explore_flood(rbundle, new_flood)
    end
  end

  defp explore_flood(rbundle, flood) do
    next_floor =
      flood
      |> Enum.flat_map(fn x ->
        case rbundle.tree |> rbundle[:type].get(x) |> Utils.tuple_value(:childs) do
          :leaf -> []
          any -> any
        end
      end)

    if length(next_floor) > 0, do: explore_flood(rbundle, next_floor), else: flood
  end

  defp find_match_depth(rbundle, box, dig, leaves, depth) do
    {f, cdepth} = hd(dig)
    tail = if length(dig) > 1, do: tl(dig), else: []
    {content, _dad, fbox} = rbundle.tree |> rbundle[:type].get(f)

    {new_dig, new_leaves} =
      if Utils.overlap?(fbox, box) do
        if cdepth < depth and is_list(content) do
          childs = content |> Enum.map(fn c -> {c, cdepth + 1} end)
          {childs ++ tail, leaves}
        else
          {tail, [f] ++ leaves}
        end
      else
        {tail, leaves}
      end

    if length(new_dig) > 0,
      do: find_match_depth(rbundle, box, new_dig, new_leaves, depth),
      else: new_leaves
  end

  ## Delete

  defp remove(rbundle, id) do
    {_ch, parent, removed_bbox} = rbundle.tree |> rbundle[:type].get(id)

    if parent do
      tree_updated =
        rbundle.tree
        |> rbundle[:type].delete(id)
        |> rbundle[:type].update!(parent, fn {ch, daddy, b} -> {ch -- [id], daddy, b} end)

      parent_childs = tree_updated |> rbundle[:type].get(parent) |> elem(0)

      if length(parent_childs) > 0 do
        %{rbundle | tree: tree_updated} |> recursive_update(parent, removed_bbox, :deletion)
      else
        remove(%{rbundle | tree: tree_updated}, parent)
      end
    else
      rbundle.tree
      |> rbundle[:type].update!(id, fn {ch, daddy, _b} -> {ch, daddy, [{0, 0}, {0, 0}]} end)
    end
  end

  ## Hard update

  defp update(rbundle, id, {old_box, new_box}) do
    parent = rbundle.tree |> rbundle[:type].get(id) |> Utils.tuple_value(:dad)
    parent_box = rbundle.tree |> rbundle[:type].get(parent) |> Utils.tuple_value(:bbox)

    updated_tree =
      rbundle.tree |> rbundle[:type].update!(id, fn {ch, d, _b} -> {ch, d, new_box} end)

    local_rbundle = %{rbundle | tree: updated_tree}

    if Utils.contained?(parent_box, new_box) do
      if Utils.in_border?(parent_box, old_box) do
        if rbundle.verbose,
          do:
            Logger.debug(
              cyan() <>
                "[" <>
                color(195) <>
                "Update" <>
                cyan() <>
                "] Good case: new box " <>
                yellow() <>
                "(#{new_box |> Kernel.inspect()})" <>
                cyan() <>
                " of " <>
                yellow() <>
                "[#{id}]" <>
                cyan() <>
                " reduce the parent " <> yellow() <> "(['#{parent}'])" <> cyan() <> " box"
            )

        local_rbundle |> recursive_update(parent, old_box, :deletion)
      else
        if rbundle.verbose,
          do:
            Logger.debug(
              cyan() <>
                "[" <>
                color(195) <>
                "Update" <>
                cyan() <>
                "] Best case: new box " <>
                yellow() <>
                "(#{new_box |> Kernel.inspect()})" <>
                cyan() <>
                " of " <>
                yellow() <>
                "[#{id}]" <>
                cyan() <> " was contained by his parent " <> yellow() <> "(['#{parent}'])"
            )

        local_rbundle.tree
      end
    else
      case local_rbundle
           |> node_brothers(parent)
           |> (fn b -> good_slot?(local_rbundle, b, new_box) end).() do
        {new_parent, _new_brothers, _new_parent_box} ->
          if rbundle.verbose,
            do:
              Logger.debug(
                cyan() <>
                  "[" <>
                  color(195) <>
                  "Update" <>
                  cyan() <>
                  "] Neutral case: new box " <>
                  yellow() <>
                  "(#{new_box |> Kernel.inspect()})" <>
                  cyan() <>
                  " of " <>
                  yellow() <>
                  "[#{id}]" <>
                  cyan() <>
                  " increases the parent box but there is an available slot at one uncle " <>
                  yellow() <> "(['#{new_parent}'])"
              )

          triple_s(local_rbundle, parent, new_parent, {id, old_box})

        nil ->
          if Utils.area(parent_box) >= @max_area do
            if rbundle.verbose,
              do:
                Logger.debug(
                  cyan() <>
                    "[" <>
                    color(195) <>
                    "Update" <>
                    cyan() <>
                    "] Worst case: new box " <>
                    yellow() <>
                    "(#{new_box |> Kernel.inspect()})" <>
                    cyan() <>
                    " of " <>
                    yellow() <>
                    "[#{id}]" <>
                    cyan() <>
                    " increases the parent box which was so big " <>
                    yellow() <>
                    "#{((Utils.area(parent_box) |> Kernel.trunc()) / @max_area * 100) |> Kernel.trunc()} %. " <>
                    cyan() <>
                    "So we proceed to delete " <>
                    yellow() <> "[#{id}]" <> cyan() <> " and reinsert at tree"
                )

            local_rbundle |> top_down({id, new_box})
          else
            if rbundle.verbose,
              do:
                Logger.debug(
                  cyan() <>
                    "[" <>
                    color(195) <>
                    "Update" <>
                    cyan() <>
                    "] Bad case: new box " <>
                    yellow() <>
                    "(#{new_box |> Kernel.inspect()})" <>
                    cyan() <>
                    " of " <>
                    yellow() <>
                    "[#{id}]" <>
                    cyan() <>
                    " increases the parent box which isn't that big yet " <>
                    yellow() <>
                    "#{((Utils.area(parent_box) |> Kernel.trunc()) / @max_area * 100) |> Kernel.trunc()} %. " <>
                    cyan() <>
                    "So we proceed to increase parent " <>
                    yellow() <> "(['#{parent}'])" <> cyan() <> " box"
                )

            local_rbundle |> recursive_update(parent, new_box, :insertion)
          end
      end
    end
  end

  ## Common updates

  defp top_down(rbundle, {id, box}) do
    %{rbundle | tree: rbundle |> remove(id)} |> tree_insert({id, box})
  end

  # Recursive bbox updates when you have node path from root (at insertion)
  defp recursive_update(rbundle, path, {_id, box} = leaf, :insertion) when length(path) > 0 do
    {modified, t} = update_node_bbox(rbundle, hd(path), box, :insertion)

    if modified and length(path) > 1,
      do: recursive_update(%{rbundle | tree: t}, tl(path), leaf, :insertion),
      else: rbundle.tree
  end

  # Recursive bbox updates when u dont have node path from root, so you have to query parents map... (at delete)
  defp recursive_update(rbundle, node, box, mode) when is_list(node) |> Kernel.not() do
    {modified, t} = update_node_bbox(rbundle, node, box, mode)
    next = rbundle.tree |> rbundle[:type].get(node) |> Utils.tuple_value(:dad)
    if modified and next, do: recursive_update(%{rbundle | tree: t}, next, box, mode), else: t
  end

  # Typical dumbass safe method
  defp recursive_update(rbundle, _path, _leaf, :insertion) do
    rbundle.tree
  end

  defp update_node_bbox(rbundle, node, the_box, action) do
    node_box = rbundle.tree |> rbundle[:type].get(node) |> Utils.tuple_value(:bbox)

    new_bbox =
      case action do
        :insertion ->
          Utils.combine(node_box, the_box)

        :deletion ->
          if Utils.in_border?(node_box, the_box) do
            rbundle.tree
            |> rbundle[:type].get(node)
            |> Utils.tuple_value(:childs)
            |> Enum.map(fn c ->
              rbundle.tree |> rbundle[:type].get(c) |> Utils.tuple_value(:bbox)
            end)
            |> Utils.combine_multiple()
          else
            node_box
          end
      end

    bbox_mutation(rbundle, node, new_bbox, node_box)
  end

  defp bbox_mutation(rbundle, node, new_bbox, node_box) do
    if new_bbox == node_box do
      {false, rbundle.tree}
    else
      t = rbundle.tree |> rbundle[:type].update!(node, fn {ch, d, _b} -> {ch, d, new_bbox} end)
      {true, t}
    end
  end

  # Return the brothers of the node [{brother_id, brother_childs, brother_box},...]
  defp node_brothers(rbundle, node) do
    parent = rbundle.tree |> rbundle[:type].get(node) |> Utils.tuple_value(:dad)

    rbundle.tree
    |> rbundle[:type].get(parent)
    |> Utils.tuple_value(:childs)
    |> (fn c -> if c, do: c -- [node], else: [] end).()
    |> Enum.map(fn b ->
      tuple = rbundle.tree |> rbundle[:type].get(b)
      {b, tuple |> Utils.tuple_value(:childs), tuple |> Utils.tuple_value(:bbox)}
    end)
  end

  # Find a good slot (at bros/brothers list) for the box, it means that the brother hasnt the max childs and the box is at the limits of his own
  defp good_slot?(rbundle, bros, box) do
    bros
    |> Enum.find(fn {_bid, bchilds, bbox} ->
      length(bchilds) < rbundle.width and Utils.contained?(bbox, box)
    end)
  end
end
