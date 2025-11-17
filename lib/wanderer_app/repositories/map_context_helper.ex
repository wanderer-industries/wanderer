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

  Extracts `map_id` from attrs and provides a minimal map struct
  via context (no database query needed).

  ## Parameters
  - `attrs` - Attributes map (may contain `:map_id`)
  - `callback` - Function accepting `(attrs, context)` and returning Ash result

  ## Returns
  - Result of callback execution

  ## Examples

      # Internal caller - uses minimal map struct
      with_map_context(%{map_id: "abc", name: "Test"}, fn attrs, ctx ->
        MapSystem.create(attrs, context: ctx)
      end)
      # => Creates system with map_id="abc" (no DB query)

      # API endpoint - context already has map (via ActorWithMap)
      # callback receives map from context
  """
  @spec with_map_context(map(), (map(), map() -> term())) ::
          {:ok, term()} | {:error, term()}
  def with_map_context(attrs, callback) when is_function(callback, 2) do
    {map_id, attrs_without_map_id} = Elixir.Map.pop(attrs, :map_id)

    case map_id do
      nil ->
        # No map_id provided - pass through with original attrs
        callback.(attrs, %{})

      map_id_value when is_binary(map_id_value) ->
        # Use minimal map struct - InjectMapFromActor only needs %{id: map_id}
        # No database query needed
        minimal_map = %{id: map_id_value}
        # Pass attrs without map_id (it will be injected from context)
        callback.(attrs_without_map_id, %{map: minimal_map})

      _ ->
        {:error, {:invalid_map_id, map_id}}
    end
  end

  @doc """
  Same as `with_map_context/2` but raises on error.

  Returns the callback result directly. Raises if map_id is invalid,
  not if the callback itself returns an error.

  ## Examples

      with_map_context!(%{map_id: "abc", name: "Test"}, fn attrs, ctx ->
        MapSystem.create!(attrs, context: ctx)
      end)
  """
  @spec with_map_context!(map(), (map(), map() -> term())) :: term()
  def with_map_context!(attrs, callback) when is_function(callback, 2) do
    {map_id, attrs_without_map_id} = Elixir.Map.pop(attrs, :map_id)

    case map_id do
      nil ->
        # No map_id provided - pass through with original attrs
        callback.(attrs, %{})

      map_id_value when is_binary(map_id_value) ->
        # Use minimal map struct - InjectMapFromActor only needs %{id: map_id}
        # No database query needed
        minimal_map = %{id: map_id_value}
        # Pass attrs without map_id (it will be injected from context)
        callback.(attrs_without_map_id, %{map: minimal_map})

      invalid_map_id ->
        raise "Invalid map_id: #{inspect(invalid_map_id)}"
    end
  end
end
