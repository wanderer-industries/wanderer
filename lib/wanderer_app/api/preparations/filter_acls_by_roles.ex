defmodule WandererApp.Api.Preparations.FilterAclsByRoles do
  @moduledoc false

  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _params, %{actor: nil}) do
    query
    |> Ash.Query.load([:owner, :members])
  end

  def prepare(query, _params, %{actor: actor}) do
    query
    |> filter_membership(actor)
    |> Ash.Query.load([:owner, :members])
  end

  defp filter_membership(query, actor) do
    characters = actor.characters

    character_ids = characters |> Enum.map(& &1.id)
    character_eve_ids = characters |> Enum.map(& &1.eve_id)

    Ash.Query.filter(
      query,
      owner_id in ^character_ids or
        (members.eve_character_id in ^character_eve_ids and members.role in [:admin, :manager])
    )
  end
end
