defmodule WandererApp.Behaviours.SpatialIndex do
  @moduledoc """
  Behaviour for spatial index (R-tree) implementations.

  This allows runtime polymorphism between production (CacheRTree) and
  test implementations (mocked via Mox or simple in-memory versions).

  ## Implementations

  - `WandererApp.Map.CacheRTree` - Production cache-based R-tree
  - Test mocks configured via `:spatial_index_module` application config

  ## Usage

  The spatial index module is configured at runtime and injected into
  components that need spatial queries (e.g., UpdateCoordinator).

  ### Configuration

      # config/runtime.exs
      config :wanderer_app,
        spatial_index_module: WandererApp.Map.CacheRTree

      # config/test.exs
      config :wanderer_app,
        spatial_index_module: Test.SpatialIndexMock

  ### Example

      # Get configured module
      @spatial_index_module Application.compile_env(:wanderer_app, :spatial_index_module)

      # Use in code
      @spatial_index_module.insert({system_id, bounding_box}, "rtree_map_123")
      {:ok, ids} = @spatial_index_module.query(search_box, "rtree_map_123")

  ## Data Types

  - `id()` - System identifier (integer or string)
  - `bounding_box()` - List of coordinate ranges: `[{x_min, x_max}, {y_min, y_max}]`
  - `leaf()` - A leaf node: `{id(), bounding_box()}`
  """

  @type id :: number() | String.t()
  @type coord_range :: {number(), number()}
  @type bounding_box :: list(coord_range())
  @type leaf :: {id(), bounding_box()}

  @doc """
  Initialize a spatial index tree with the given name and configuration.

  ## Parameters

  - `name` - Name of the R-tree instance (e.g., "rtree_map_123")
  - `config` - Configuration map (implementation-specific)

  ## Returns

  - `:ok` - Success
  - `{:error, term()}` - Error with reason

  ## Examples

      iex> init_tree("rtree_map_123", %{width: 150, verbose: false})
      :ok
  """
  @callback init_tree(String.t(), map()) :: :ok | {:error, term()}

  @doc """
  Insert one or more leaves into the spatial index.

  ## Parameters

  - `leaf_or_leaves` - Single `{id, bounding_box}` tuple or list of tuples
  - `name` - Name of the R-tree instance (e.g., "rtree_map_123")

  ## Returns

  - `{:ok, map()}` - Success (map structure varies by implementation)
  - `{:error, term()}` - Error with reason

  ## Examples

      iex> insert({30000142, [{100, 230}, {50, 84}]}, "rtree_map_123")
      {:ok, %{}}

      iex> insert([
      ...>   {30000142, [{100, 230}, {50, 84}]},
      ...>   {30000143, [{250, 380}, {100, 134}]}
      ...> ], "rtree_map_123")
      {:ok, %{}}
  """
  @callback insert(leaf() | list(leaf()), String.t()) :: {:ok, map()} | {:error, term()}

  @doc """
  Update a leaf's bounding box in the spatial index.

  ## Parameters

  - `id` - ID of the leaf to update
  - `box_or_tuple` - Either a new `bounding_box` or `{old_box, new_box}` tuple
  - `name` - Name of the R-tree instance

  ## Returns

  - `{:ok, map()}` - Success
  - `{:error, term()}` - Error with reason

  ## Examples

      # Update with new box only (implementation looks up old box)
      iex> update(30000142, [{150, 280}, {200, 234}], "rtree_map_123")
      {:ok, %{}}

      # Update with explicit old and new box (more efficient)
      iex> update(30000142, {[{100, 230}, {50, 84}], [{150, 280}, {200, 234}]}, "rtree_map_123")
      {:ok, %{}}
  """
  @callback update(id(), bounding_box() | {bounding_box(), bounding_box()}, String.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Delete one or more leaves from the spatial index.

  ## Parameters

  - `id_or_ids` - Single ID or list of IDs to remove
  - `name` - Name of the R-tree instance

  ## Returns

  - `{:ok, map()}` - Success
  - `{:error, term()}` - Error with reason

  ## Examples

      iex> delete(30000142, "rtree_map_123")
      {:ok, %{}}

      iex> delete([30000142, 30000143], "rtree_map_123")
      {:ok, %{}}
  """
  @callback delete(id() | list(id()), String.t()) :: {:ok, map()} | {:error, term()}

  @doc """
  Query for all leaves intersecting a bounding box.

  ## Parameters

  - `bounding_box` - Query bounding box `[{x_min, x_max}, {y_min, y_max}]`
  - `name` - Name of the R-tree instance

  ## Returns

  - `{:ok, list(id())}` - List of IDs intersecting the query box
  - `{:error, term()}` - Error with reason

  ## Examples

      iex> query([{200, 330}, {90, 124}], "rtree_map_123")
      {:ok, [30000143]}

      iex> query([{0, 50}, {0, 50}], "rtree_map_123")
      {:ok, []}
  """
  @callback query(bounding_box(), String.t()) :: {:ok, list(id())} | {:error, term()}
end
