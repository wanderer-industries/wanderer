defmodule WandererApp.Api.Preparations.FilterByActorMap do
  @moduledoc """
  Shared filtering logic for actor map context.

  Filters queries to only return resources belonging to the actor's map.
  Used by preparations for MapSystem, MapConnection, and MapPing resources.
  """

  require Ash.Query

  alias WandererApp.Api.ActorHelpers

  @doc """
  Filter a query by the actor's map context.

  If a map is found in the context, filters the query to only return
  resources where map_id matches. If no map context exists, returns
  a query that will return no results.

  ## Parameters

    * `query` - The Ash query to filter
    * `context` - The Ash context containing actor/map information
    * `resource_name` - Name of the resource for telemetry (atom)

  ## Examples

      iex> query = Ash.Query.new(WandererApp.Api.MapSystem)
      iex> context = %{map: %{id: "map-123"}}
      iex> result = FilterByActorMap.filter_by_map(query, context, :map_system)
      # Returns query filtered by map_id == "map-123"
  """
  def filter_by_map(query, context, resource_name) do
    case ActorHelpers.get_map(context) do
      %{id: map_id} ->
        emit_telemetry(resource_name, map_id)
        Ash.Query.filter(query, map_id == ^map_id)

      nil ->
        emit_telemetry_no_context(resource_name)
        Ash.Query.filter(query, false)

      _other ->
        emit_telemetry_no_context(resource_name)
        Ash.Query.filter(query, false)
    end
  end

  defp emit_telemetry(resource_name, map_id) do
    :telemetry.execute(
      [:wanderer_app, :ash, :preparation, :filter_by_map],
      %{count: 1},
      %{resource: resource_name, map_id: map_id}
    )
  end

  defp emit_telemetry_no_context(resource_name) do
    :telemetry.execute(
      [:wanderer_app, :ash, :preparation, :filter_by_map, :no_context],
      %{count: 1},
      %{resource: resource_name}
    )
  end
end
