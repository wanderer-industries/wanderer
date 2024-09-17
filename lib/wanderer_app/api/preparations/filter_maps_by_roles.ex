defmodule WandererApp.Api.Preparations.FilterMapsByRoles do
  @moduledoc false

  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _params, %{actor: nil}) do
    query
    |> Ash.Query.filter(expr(deleted == false))
    |> Ash.Query.load([:owner, :acls])
  end

  def prepare(query, _params, %{actor: actor}) do
    query
    |> Ash.Query.filter(expr(deleted == false))
    |> filter_membership(actor)
    |> Ash.Query.load([:owner, :acls])
  end

  defp filter_membership(query, actor) do
    characters = actor.characters

    character_ids = characters |> Enum.map(& &1.id)
    character_eve_ids = characters |> Enum.map(& &1.eve_id)

    character_corporation_ids =
      characters |> Enum.map(& &1.corporation_id) |> Enum.map(&to_string/1)

    character_alliance_ids = characters |> Enum.map(& &1.alliance_id) |> Enum.map(&to_string/1)

    query
    |> Ash.Query.filter(
      owner_id in ^character_ids or
        (acls.owner_id in ^character_ids or
           acls.members.eve_character_id in ^character_eve_ids or
           acls.members.eve_corporation_id in ^character_corporation_ids or
           acls.members.eve_alliance_id in ^character_alliance_ids)
    )
  end
end
