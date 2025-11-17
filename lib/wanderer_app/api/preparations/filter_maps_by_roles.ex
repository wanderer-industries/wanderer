defmodule WandererApp.Api.Preparations.FilterMapsByRoles do
  @moduledoc false

  use Ash.Resource.Preparation
  require Ash.Query

  alias WandererApp.Api.ActorWithMap

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

  defp filter_membership(query, %ActorWithMap{map: map}) do
    # For single map tokens, only return that specific map
    # This ensures tokens are properly scoped to their map
    query
    |> Ash.Query.filter(id == ^map.id)
  end

  defp filter_membership(query, actor) do
    characters = actor.characters

    character_ids = characters |> Enum.map(& &1.id)
    character_eve_ids = characters |> Enum.map(& &1.eve_id)

    character_corporation_ids =
      characters |> Enum.map(& &1.corporation_id) |> Enum.map(&to_string/1)

    character_alliance_ids = characters |> Enum.map(& &1.alliance_id) |> Enum.map(&to_string/1)

    accessible_acl_ids =
      get_accessible_acl_ids(character_eve_ids, character_corporation_ids, character_alliance_ids)

    # Filter to maps where the user:
    # 1. Owns the map directly (owner_id)
    # 2. Has access via an ACL that the user can access
    query
    |> Ash.Query.filter(
      owner_id in ^character_ids or
        acls.id in ^accessible_acl_ids
    )
  end

  defp get_accessible_acl_ids(
         character_eve_ids,
         character_corporation_ids,
         character_alliance_ids
       ) do
    # Query AccessListMember directly to find ACLs where the character is a member
    # This bypasses Ash's ownership constraints
    import Ecto.Query

    query =
      from m in "access_list_members_v1",
        where:
          m.eve_character_id in ^character_eve_ids or
            m.eve_corporation_id in ^character_corporation_ids or
            m.eve_alliance_id in ^character_alliance_ids,
        select: m.access_list_id,
        distinct: true

    WandererApp.Repo.all(query)
  end
end
