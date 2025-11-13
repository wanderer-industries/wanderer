defmodule WandererApp.Repositories.MapContextHelper do
  @moduledoc """
  Shared utilities for managing map context in repository operations.

  Provides dual-path map context injection:
  - **API endpoints**: Context from ActorWithMap (no DB lookup)
  - **Internal callers**: Loads map from database to provide context

  This ensures Ash changes like `InjectMapFromActor` always have
  map context available, regardless of the caller.
  """

  @doc """
  Executes callback with map context.

  Loads map from database if `map_id` is present in attrs,
  removes it from attrs, and passes map via context.

  ## Parameters
  - `attrs` - Attributes map (may contain `:map_id`)
  - `callback` - Function accepting `(attrs, context)` and returning Ash result

  ## Returns
  - Result of callback execution
  - `{:error, reason}` if map not found

  ## Examples

      # Internal caller - loads map
      with_map_context(%{map_id: "abc", name: "Test"}, fn attrs, ctx ->
        MapSystem.create(attrs, context: ctx)
      end)
      # => Creates system with map_id="abc" (loaded from DB)

      # API endpoint - context already has map (via ActorWithMap)
      # callback receives map from context, no DB query
  """
  @spec with_map_context(map(), (map(), map() -> term())) ::
          {:ok, term()} | {:error, term()}
  def with_map_context(attrs, callback) when is_function(callback, 2) do
    # Get map_id from attrs
    {map_id, attrs_without_map_id} = Elixir.Map.pop(attrs, :map_id)

    case map_id do
      nil ->
        # No map_id provided - pass through with original attrs
        callback.(attrs, %{})

      map_id_value ->
        # Load map for context using WandererApp.Api.Map
        case WandererApp.Api.Map.by_id(map_id_value) do
          {:ok, map} ->
            # Pass attrs without map_id (it will be injected from context)
            callback.(attrs_without_map_id, %{map: map})

          {:error, %Ash.Error.Query.NotFound{}} ->
            {:error, {:map_not_found, map_id_value}}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Same as `with_map_context/2` but raises on error when loading the map.

  Returns the callback result directly. Only raises if the map cannot be loaded,
  not if the callback itself returns an error.

  ## Examples

      with_map_context!(%{map_id: "abc", name: "Test"}, fn attrs, ctx ->
        MapSystem.create!(attrs, context: ctx)
      end)
  """
  @spec with_map_context!(map(), (map(), map() -> term())) :: term()
  def with_map_context!(attrs, callback) when is_function(callback, 2) do
    # Get map_id from attrs
    {map_id, attrs_without_map_id} = Elixir.Map.pop(attrs, :map_id)

    case map_id do
      nil ->
        # No map_id provided - pass through with original attrs
        callback.(attrs, %{})

      map_id_value ->
        # Load map for context using WandererApp.Api.Map
        case WandererApp.Api.Map.by_id(map_id_value) do
          {:ok, map} ->
            # Pass attrs without map_id (it will be injected from context)
            callback.(attrs_without_map_id, %{map: map})

          {:error, reason} ->
            raise "Map context error: #{inspect(reason)}"
        end
    end
  end
end
