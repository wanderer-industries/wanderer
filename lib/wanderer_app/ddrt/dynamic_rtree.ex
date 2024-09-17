defmodule DDRT.DynamicRtree do
  use GenServer, restart: :transient
  use DDRT.DynamicRtreeImpl

  @type tree_init :: [
          name: GenServer.name(),
          crdt: module(),
          conf: tree_config()
        ]

  @type tree_config :: [
          name: GenServer.name(),
          width: integer(),
          type: module(),
          verbose: boolean(),
          seed: integer(),
          mode: ddrt_mode()
        ]

  @type ddrt_mode :: :standalone | :distributed
  @type coord_range :: {number(), number()}
  @type bounding_box :: list(coord_range())
  @type id :: number() | String.t()
  @type leaf :: {id(), bounding_box()}
  @type member :: GenServer.name() | {GenServer.name(), node()}

  @callback delete(ids :: id() | [id()], name :: GenServer.name()) ::
              {:ok, map()} | {:badtree, map()}
  @callback insert(leaves :: leaf() | [leaf()], name :: GenServer.name()) ::
              {:ok, map()} | {:badtree, map()}
  @callback metadata(name :: GenServer.name()) :: map()
  @callback pquery(box :: bounding_box(), depth :: integer(), name :: GenServer.name()) ::
              {:ok, [id()]} | {:badtree, map()}
  @callback query(box :: bounding_box(), name :: GenServer.name()) ::
              {:ok, [id()]} | {:badtree, map()}
  @callback update(
              ids :: id(),
              box :: bounding_box() | {bounding_box(), bounding_box()},
              name :: GenServer.name()
            ) :: {:ok, map()} | {:badtree, map()}
  @callback bulk_update(leaves :: [leaf()], name :: GenServer.name()) ::
              {:ok, map()} | {:badtree, map()}
  @callback new(opts :: Keyword.t(), name :: GenServer.name()) :: {:ok, map()}
  @callback tree(name :: GenServer.name()) :: map()
  @callback set_members(name :: GenServer.name(), [member()]) :: :ok

  @doc false
  defmacro doc_referral({name, arity}) do
    "See `DDRT.DynamicRtree.#{name}/#{arity}` for documentation and usage examples."
  end

  defmacro __using__(_) do
    quote do
      alias DDRT.DynamicRtree
      @behaviour DynamicRtree

      @doc unquote(doc_referral({:delete, 2}))
      defdelegate delete(ids, name), to: DynamicRtree

      @doc unquote(doc_referral({:insert, 2}))
      defdelegate insert(leaves, name), to: DynamicRtree

      @doc unquote(doc_referral({:metadata, 1}))
      defdelegate metadata(name), to: DynamicRtree

      @doc unquote(doc_referral({:pquery, 3}))
      defdelegate pquery(box, depth, name), to: DynamicRtree

      @doc unquote(doc_referral({:query, 2}))
      defdelegate query(box, name), to: DynamicRtree

      @doc unquote(doc_referral({:update, 3}))
      defdelegate update(ids, box, name), to: DynamicRtree

      @doc unquote(doc_referral({:bulk_update, 2}))
      defdelegate bulk_update(leaves, name), to: DynamicRtree

      @doc unquote(doc_referral({:new, 2}))
      defdelegate new(opts, name), to: DynamicRtree

      @doc unquote(doc_referral({:tree, 1}))
      defdelegate tree(name), to: DynamicRtree

      @doc unquote(doc_referral({:set_members, 2}))
      defdelegate set_members(name, members), to: DynamicRtree
    end
  end

  defstruct metadata: nil,
            tree: nil,
            listeners: [],
            crdt: nil,
            name: nil

  @moduledoc """
  Use this module if you're interested in creating an R-Tree optimized to run on a single machine. If you'd instead like to run a distributed R-Tree on a cluster of Elixir nodes, use the `DDRT` module.
  """

  @doc """
  These are all of the possible configuration parameters for `opts` and their default values:

  - **name**: The name of the DDRT process. Defaults to `DDRT`
  - **width**: The max number of children a node may have. Defaults to `6`
  - **verbose**: allows `Logger` to report console logs. (Also decreases performance). Defaults to `false`.
  - **seed**: Sets the seed value for the pseudo-random number generator which generates the unique IDs for each node in the tree. This is a deterministic process; so the same seed value will guarantee the same pseudo-random unique IDs being generated for your tree in the same order each time. Defaults to `0`
  """
  @spec start_link(opts :: tree_init()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    name = Keyword.get(opts, :name, DDRT)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    conf = filter_conf(opts[:conf])
    {t, meta} = tree_new(conf)
    listeners = Node.list()

    t =
      if %{metadata: meta} |> is_distributed? do
        DeltaCrdt.set_neighbours(opts[:crdt], Enum.map(Node.list(), fn x -> {opts[:crdt], x} end))

        crdt_value = DeltaCrdt.to_map(opts[:crdt])
        :net_kernel.monitor_nodes(true, node_type: :visible)
        if crdt_value != %{}, do: reconstruct_from_crdt(crdt_value, t), else: t
      else
        t
      end

    {:ok,
     %__MODULE__{
       name: opts[:name],
       metadata: meta,
       tree: t,
       listeners: listeners,
       crdt: opts[:crdt]
     }}
  end

  @opt_values %{
    type: [Map, MerkleMap],
    mode: [:standalone, :distributed]
  }

  @defopts [
    width: 6,
    type: Map,
    mode: :standalone,
    verbose: false,
    seed: 0
  ]

  @spec new(opts :: Keyword.t(), name :: GenServer.name()) :: {:ok, map()}
  def new(opts \\ @defopts, name \\ DDRT) when is_list(opts) do
    GenServer.call(name, {:new, opts})
  end

  @spec insert(leaves :: leaf() | [leaf()], name :: GenServer.name()) ::
          {:ok, map()} | {:badtree, map()}
  def insert(_a, name \\ DDRT)

  @doc """
    Insert `leaves` into the r-tree with process with name `name`

    Returns `{:ok,map()}`

  ## Parameters

    - `leaves`: the data to insert.
    - `name`: the r-tree name where you want to insert.

  ## Examples

    Individual insertion:

    ```
    iex> DynamicRtree.insert({"Griffin", [{4,5},{6,7}]}, :my_rtree)
    iex> DynamicRtree.insert({"Parker", [{14,15},{16,17}]}, :my_rtree)

    {:ok,
    %{
     43143342109176739 => {["Parker", "Griffin"], nil, [{4, 15}, {6, 17}]},
     :root => 43143342109176739,
     :ticket => [19125803434255161 | 82545666616502197],
     "Griffin" => {:leaf, 43143342109176739, [{4, 5}, {6, 7}]},
     "Parker" => {:leaf, 43143342109176739, [{14, 15}, {16, 17}]}
    }}
    ```

    Bulk Insertion:

    ```
    iex> DynamicRtree.insert([{"Griffin", [{4,5},{6,7}]}, {"Parker", [{14,15},{16,17}]}], :my_rtree)

    {:ok,
    %{
     43143342109176739 => {["Parker", "Griffin"], nil, [{4, 15}, {6, 17}]},
     :root => 43143342109176739,
     :ticket => [19125803434255161 | 82545666616502197],
     "Griffin" => {:leaf, 43143342109176739, [{4, 5}, {6, 7}]},
     "Parker" => {:leaf, 43143342109176739, [{14, 15}, {16, 17}]}
    }}
    ```
  """

  def insert(leaves, name) when is_list(leaves) do
    GenServer.call(name, {:bulk_insert, leaves}, :infinity)
  end

  def insert(leaf, name) do
    GenServer.call(name, {:insert, leaf}, :infinity)
  end

  @doc """
    Query to get every leaf id overlapped by `box`.

    Returns `[id's]`.

  ## Examples

      iex> DynamicRtree.query([{0,7},{4,8}],:my_rtree)
      {:ok, ["Griffin"]}

  """

  @spec query(box :: bounding_box(), name :: GenServer.name()) ::
          {:ok, [id()]} | {:badtree, map()}
  def query(box, name \\ DDRT) do
    GenServer.call(name, {:query, box})
  end

  @doc """
    Query to get every node id overlapped by `box` at the defined `depth`.

    Returns `[id's]`.
  """

  @spec pquery(box :: bounding_box(), depth :: integer(), name :: GenServer.name()) ::
          {:ok, [id()]} | {:badtree, map()}
  def pquery(box, depth, name \\ DDRT) do
    GenServer.call(name, {:query_depth, {box, depth}})
  end

  @spec delete(ids :: id() | [id()], name :: GenServer.name()) ::
          {:ok, map()} | {:badtree, map()}
  def delete(_a, name \\ DDRT)

  @doc """
  Delete the leaves with the given `ids`.

  Returns `{:ok,map()}`

  ## Parameters

    - `ids`: Id or list of Id that you want to delete.
    - `name`: the name of the rtree process.

  ## Examples
    Individual deletion:

    ```
    iex> DynamicRtree.delete("Griffin",:my_rtree)
    iex> DynamicRtree.delete("Parker",:my_rtree)
    ```

    Bulk Deletion:

    ```
    iex> DynamicRtree.delete(["Griffin","Parker"],:my_rtree)
    ```
  """

  def delete(ids, name) when is_list(ids) do
    GenServer.call(name, {:bulk_delete, ids}, :infinity)
  end

  def delete(id, name) do
    GenServer.call(name, {:delete, id})
  end

  @doc """
  Update a bunch of r-tree leaves to the new bounding boxes defined.

  Returns `{:ok,map()}`

  ## Examples

  ```
  iex> DynamicRtree.bulk_update([{"Griffin",[{0,1},{0,1}]},{"Parker",[{10,11},{10,11}]}],:my_rtree)

  {:ok,
  %{
   43143342109176739 => {["Parker", "Griffin"], nil, [{0, 11}, {0, 11}]},
   :root => 43143342109176739,
   :ticket => [19125803434255161 | 82545666616502197],
   "Griffin" => {:leaf, 43143342109176739, [{0, 1}, {0, 1}]},
   "Parker" => {:leaf, 43143342109176739, [{10, 11}, {10, 11}]}
  }}
  ```
  """
  @spec bulk_update(leaves :: [leaf()], name :: GenServer.name()) ::
          {:ok, map()} | {:badtree, map()}
  def bulk_update(updates, name \\ DDRT) when is_list(updates) do
    GenServer.call(name, {:bulk_update, updates}, :infinity)
  end

  @doc """
  Update a single leaf bounding box

  Returns `{:ok,map()}`

  ## Examples
  ```
  iex> DynamicRtree.update({"Griffin",[{0,1},{0,1}]},:my_rtree)

  {:ok,
  %{
   43143342109176739 => {["Parker", "Griffin"], nil, [{0, 11}, {0, 11}]},
   :root => 43143342109176739,
   :ticket => [19125803434255161 | 82545666616502197],
   "Griffin" => {:leaf, 43143342109176739, [{0, 1}, {0, 1}]},
   "Parker" => {:leaf, 43143342109176739, [{10, 11}, {16, 17}]}
  }}
  ```
  """

  @spec update(
          ids :: id(),
          box :: bounding_box() | {bounding_box(), bounding_box()},
          name :: GenServer.name()
        ) :: {:ok, map()} | {:badtree, map()}
  def update(id, update, name \\ DDRT) do
    GenServer.call(name, {:update, {id, update}})
  end

  @doc """
  Get the r-tree metadata

  Returns `map()`

  ## Examples

      iex> DynamicRtree.metadata(:my_rtree)

      %{
        params: %{mode: :standalone, seed: 0, type: Map, verbose: false, width: 6},
        seeding: %{
          bits: 58,
          jump: #Function<3.53802439/1 in :rand.mk_alg/1>,
          next: #Function<0.53802439/1 in :rand.mk_alg/1>,
          type: :exrop,
          uniform: #Function<1.53802439/1 in :rand.mk_alg/1>,
          uniform_n: #Function<2.53802439/2 in :rand.mk_alg/1>,
          weak_low_bits: 1
        }
      }


  """
  @spec metadata(name :: GenServer.name()) :: map()
  def metadata(name \\ DDRT)

  def metadata(name) do
    GenServer.call(name, :metadata)
  end

  @doc """
  Get the r-tree representation

  Returns `map()`

  ## Examples

  ```
  iex> DynamicRtree.metadata(:my_rtree)

  %{
    43143342109176739 => {["Parker", "Griffin"], nil, [{0, 11}, {0, 11}]},
    :root => 43143342109176739,
    :ticket => [19125803434255161 | 82545666616502197],
    "Griffin" => {:leaf, 43143342109176739, [{0, 1}, {0, 1}]},
    "Parker" => {:leaf, 43143342109176739, [{10, 11}, {10, 11}]}
  }
  ```

  """
  @spec tree(name :: GenServer.name()) :: map()
  def tree(name \\ DDRT)

  def tree(name) do
    GenServer.call(name, :tree)
  end

  @doc """
  Set the members of the `DDRT` cluster.

  `members` should be in the format `{GenServer.name(), node()}`.

  ## Examples

  ```
  DDRT.set_members(DDRT, [{DDRT.A, :yournode@foreignhost}, {DDRT.B, :yournode@foreignhost}])
  ```

  """
  @spec set_members(name :: GenServer.name(), [member()]) :: :ok
  def set_members(name, members) do
    :ok = GenServer.call(name, {:set_members, members})
    :ok
  end

  def merge_diffs(_a, name \\ DDRT)
  @doc false
  def merge_diffs(diffs, name) do
    send(name, {:merge_diff, diffs})
  end

  ## PRIVATE METHODS

  defp fully_qualified_name({_name, _node} = fq_pair), do: fq_pair

  defp fully_qualified_name(name) do
    {name, Node.self()}
  end

  defp is_distributed?(state) do
    state.metadata[:params][:mode] == :distributed
  end

  defp constraints() do
    %{
      width: fn v -> v > 0 end,
      type: fn v -> v in (@opt_values |> Map.get(:type)) end,
      mode: fn v -> v in (@opt_values |> Map.get(:mode)) end,
      verbose: fn v -> is_boolean(v) end,
      seed: fn v -> is_integer(v) end
    }
  end

  defp filter_conf(opts) do
    # set default :mode to :standalone
    opts = Keyword.put_new(opts, :mode, :standalone)

    new_opts =
      case opts[:mode] do
        :distributed -> Keyword.put(opts, :type, MerkleMap)
        _ -> opts
      end

    good_keys =
      new_opts
      |> Keyword.keys()
      |> Enum.filter(fn k ->
        constraints() |> Map.has_key?(k) and constraints()[k].(new_opts[k])
      end)

    good_keys
    |> Enum.reduce(@defopts, fn k, acc ->
      acc |> Keyword.put(k, new_opts[k])
    end)
  end

  defp get_rbundle(state) do
    meta = state.metadata
    params = meta.params

    %{
      tree: state.tree,
      width: params[:width],
      verbose: params[:verbose],
      type: params[:type],
      seeding: meta[:seeding]
    }
  end

  @impl true
  def handle_call({:set_members, members}, _from, state) do
    self_crdt =
      Module.concat([state.name, Crdt])
      |> fully_qualified_name()

    member_crdts =
      members
      |> Enum.map(&fully_qualified_name(&1))
      |> Enum.map(fn {pname, node} ->
        {Module.concat([pname, Crdt]), node}
      end)

    result = DeltaCrdt.set_neighbours(self_crdt, member_crdts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:new, config}, _from, state) do
    conf = config |> filter_conf
    {t, meta} = tree_new(conf)
    {:reply, {:ok, t}, %__MODULE__{state | metadata: meta, tree: t}}
  end

  @impl true
  def handle_call({:insert, leaf}, _from, state) do
    r =
      {_atom, t} =
      case state.tree do
        nil -> {:badtree, state.tree}
        _ -> {:ok, get_rbundle(state) |> tree_insert(leaf)}
      end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree, t)
      sync_crdt(diffs, state.crdt)
    end

    {:reply, r, %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:bulk_insert, leaves}, _from, state) do
    r =
      {_atom, t} =
      case state.tree do
        nil ->
          {:badtree, state.tree}

        _ ->
          final_rbundle =
            leaves
            |> Enum.reduce(get_rbundle(state), fn l, acc ->
              %{acc | tree: acc |> tree_insert(l)}
            end)

          {:ok, final_rbundle.tree}
      end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree, t)
      sync_crdt(diffs, state.crdt)
    end

    {:reply, r, %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:query, box}, _from, state) do
    r =
      {_atom, _t} =
      case state.tree do
        nil -> {:badtree, state.tree}
        _ -> {:ok, get_rbundle(state) |> tree_query(box)}
      end

    {:reply, r, state}
  end

  @impl true
  def handle_call({:query_depth, {box, depth}}, _from, state) do
    r =
      {_atom, _t} =
      case state.tree do
        nil -> {:badtree, state.tree}
        _ -> {:ok, get_rbundle(state) |> tree_query(box, depth)}
      end

    {:reply, r, state}
  end

  @impl true
  def handle_call({:delete, id}, _from, state) do
    r =
      {_atom, t} =
      case state.tree do
        nil -> {:badtree, state.tree}
        _ -> {:ok, get_rbundle(state) |> tree_delete(id)}
      end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree, t)
      sync_crdt(diffs, state.crdt)
    end

    {:reply, r, %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:bulk_delete, ids}, _from, state) do
    r =
      {_atom, t} =
      case state.tree do
        nil ->
          {:badtree, state.tree}

        _ ->
          final_rbundle =
            ids
            |> Enum.reduce(get_rbundle(state), fn id, acc ->
              %{acc | tree: acc |> tree_delete(id)}
            end)

          {:ok, final_rbundle.tree}
      end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree, t)
      sync_crdt(diffs, state.crdt)
    end

    {:reply, r, %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:update, {id, update}}, _from, state) do
    r =
      {_atom, t} =
      case state.tree do
        nil -> {:badtree, state.tree}
        _ -> {:ok, get_rbundle(state) |> tree_update_leaf(id, update)}
      end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree, t)
      sync_crdt(diffs, state.crdt)
    end

    {:reply, r, %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call({:bulk_update, updates}, _from, state) do
    r =
      {_atom, t} =
      case state.tree do
        nil ->
          {:badtree, state.tree}

        _ ->
          final_rbundle =
            updates
            |> Enum.reduce(get_rbundle(state), fn {id, update} = _u, acc ->
              %{acc | tree: acc |> tree_update_leaf(id, update)}
            end)

          {:ok, final_rbundle.tree}
      end

    if is_distributed?(state) do
      diffs = tree_diffs(state.tree, t)
      sync_crdt(diffs, state.crdt)
    end

    {:reply, r, %__MODULE__{state | tree: t}}
  end

  @impl true
  def handle_call(:metadata, _from, state) do
    {:reply, state.metadata, state}
  end

  @impl true
  def handle_call(:tree, _from, state) do
    {:reply, state.tree, state}
  end

  # Distributed things

  @impl true
  def handle_info({:merge_diff, diff}, state) do
    new_tree =
      diff
      |> Enum.reduce(state.tree, fn x, acc ->
        case x do
          {:add, k, v} -> acc |> MerkleMap.put(k, v)
          {:remove, k} -> acc |> MerkleMap.delete(k)
        end
      end)

    {:noreply, %__MODULE__{state | tree: new_tree}}
  end

  def handle_info({:nodeup, _node, _opts}, state) do
    DeltaCrdt.set_neighbours(state.crdt, Enum.map(Node.list(), fn x -> {state.crdt, x} end))
    {:noreply, %__MODULE__{state | listeners: Node.list()}}
  end

  def handle_info({:nodedown, _node, _opts}, state) do
    DeltaCrdt.set_neighbours(state.crdt, Enum.map(Node.list(), fn x -> {state.crdt, x} end))
    {:noreply, %__MODULE__{state | listeners: Node.list()}}
  end

  @doc false
  def sync_crdt(diffs, crdt) when length(diffs) > 0 do
    diffs
    |> Enum.each(fn {k, v} ->
      if v do
        DeltaCrdt.put(crdt, k, v)
      else
        DeltaCrdt.delete(crdt, k)
      end
    end)
  end

  @doc false
  def sync_crdt(_diffs, _crdt) do
  end

  @doc false
  def reconstruct_from_crdt(map, t) do
    map
    |> Enum.reduce(t, fn {x, y}, acc ->
      acc |> MerkleMap.put(x, y)
    end)
  end

  @doc false
  def tree_diffs(old_tree, new_tree) when not is_nil(old_tree) and not is_nil(new_tree) do
    case MerkleMap.diff_keys(
           old_tree |> MerkleMap.update_hashes(),
           new_tree |> MerkleMap.update_hashes()
         ) do
      {:ok, keys} -> keys |> Enum.map(fn x -> {x, new_tree |> MerkleMap.get(x)} end)
      _ -> []
    end
  end

  def tree_diffs(_old_tree, _new_tree), do: []
end
