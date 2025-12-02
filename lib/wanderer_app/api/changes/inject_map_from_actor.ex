defmodule WandererApp.Api.Changes.InjectMapFromActor do
  @moduledoc """
  Ash change that injects map_id from the authenticated actor.

  For token-based auth, the map is determined by the API token.
  This change automatically sets map_id, so clients don't need to provide it.
  """

  use Ash.Resource.Change

  alias WandererApp.Api.ActorHelpers

  @impl true
  def change(changeset, _opts, context) do
    case ActorHelpers.get_map(context) do
      %{id: map_id} ->
        Ash.Changeset.force_change_attribute(changeset, :map_id, map_id)

      _other ->
        # nil or unexpected return shape - check for direct map_id
        # Check params (input), arguments, and attributes (in that order)
        map_id =
          Map.get(changeset.params, :map_id) ||
            Ash.Changeset.get_argument(changeset, :map_id) ||
            Ash.Changeset.get_attribute(changeset, :map_id)

        case map_id do
          nil ->
            Ash.Changeset.add_error(changeset,
              field: :map_id,
              message: "map_id is required (provide via token or attribute)"
            )

          _map_id ->
            # map_id provided directly (internal calls, tests)
            changeset
        end
    end
  end
end
