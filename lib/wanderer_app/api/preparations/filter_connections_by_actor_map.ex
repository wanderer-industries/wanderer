defmodule WandererApp.Api.Preparations.FilterConnectionsByActorMap do
  @moduledoc """
  Ash preparation that filters connections to only those from the actor's map.

  For token-based auth, this ensures the API only returns connections
  from the map associated with the token.
  """

  use Ash.Resource.Preparation

  alias WandererApp.Api.Preparations.FilterByActorMap

  @impl true
  def prepare(query, _opts, context) do
    FilterByActorMap.filter_by_map(query, context, :map_connection)
  end
end
