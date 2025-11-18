defmodule WandererApp.Api.Preparations.FilterPingsByActorMap do
  @moduledoc """
  Ash preparation that filters pings to only those from the actor's map.

  For token-based auth, this ensures the API only returns pings
  from the map associated with the token.
  """

  use Ash.Resource.Preparation

  alias WandererApp.Api.Preparations.FilterByActorMap

  @impl true
  def prepare(query, _opts, context) do
    FilterByActorMap.filter_by_map(query, context, :map_ping)
  end
end
