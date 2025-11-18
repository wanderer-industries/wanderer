defmodule WandererApp.Repositories.MapContextHelper do
  @moduledoc """
  Helper for providing map context to Ash actions from internal callers.

  When InjectMapFromActor is used, internal callers (map duplication, seeds, etc.)
  need a way to provide map context without going through token auth.
  This helper creates a minimal map struct for the context.
  """

  @doc """
  Build Ash context options from attributes containing map_id.

  Returns a keyword list suitable for passing to Ash actions.
  If attrs contains :map_id, creates a context with a minimal map struct.
  If no map_id present, returns an empty list.

  ## Examples

      iex> MapContextHelper.build_context(%{map_id: "123", name: "System"})
      [context: %{map: %{id: "123"}}]

      iex> MapContextHelper.build_context(%{name: "System"})
      []

      iex> MapContextHelper.build_context(%{map_id: nil, name: "System"})
      []
  """
  def build_context(attrs) when is_map(attrs) do
    case Map.get(attrs, :map_id) do
      nil -> []
      map_id -> [context: %{map: %{id: map_id}}]
    end
  end

  @doc """
  Wraps an Ash action call with map context.

  Deprecated: Use `build_context/1` instead for a simpler API.

  ## Examples

      # Deprecated callback-based approach
      MapContextHelper.with_map_context(%{map_id: "123", name: "System"}, fn attrs, context ->
        WandererApp.Api.MapSystem.create(attrs, context)
      end)

      # Preferred approach using build_context/1
      context = MapContextHelper.build_context(attrs)
      WandererApp.Api.MapSystem.create(attrs, context)
  """
  @deprecated "Use build_context/1 instead"
  def with_map_context(attrs, fun) when is_map(attrs) and is_function(fun, 2) do
    context = build_context(attrs)
    fun.(attrs, context)
  end
end
