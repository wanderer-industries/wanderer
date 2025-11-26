defmodule WandererApp.Api.Preparations.FilterSystemsByActorMap do
  @moduledoc """
  Ash preparation that filters systems to only those from the actor's map.

  For token-based auth, this ensures the API only returns systems
  from the map associated with the token.
  """

  use Ash.Resource.Preparation

  alias WandererApp.Api.Preparations.FilterByActorMap

  @impl true
  def prepare(query, _opts, context) do
    FilterByActorMap.filter_by_map(query, context, :map_system)
  end
end
