defmodule WandererApp.Api.Policies.AclScoped do
  @moduledoc """
  Policy checks scoping `/api/v1` access-list reads to the ACLs linked to an
  `ActorWithMap` token's map.

  ACLs are not owned by a map directly -- they are joined to maps through
  `WandererApp.Api.MapAccessList`. Scoping therefore tests for the *existence*
  of a join row rather than comparing a `map_id` column, which is why these
  checks use `expr(exists(...))` rather than the nested-keyword-list filters in
  `WandererApp.Api.Policies.MapScoped`. A literal `expr` is safe here (the
  relationship path is static and written out in full); the keyword-list
  workaround in `MapScoped` exists only because that module builds paths
  *dynamically* from an opt, which `Ash.Expr.ref/2` cannot do across
  relationships.

  Writes are not scoped by this module. Token actors are forbidden from all
  ACL writes outright (`forbid_if always()` on the resources), since ACL
  administration is a session/internal concern rather than a map-token one.
  """

  defmodule AclInTokenMap do
    @moduledoc """
    Filters access lists down to those linked to the token's map via
    `map_access_lists`.
    """
    use Ash.Policy.FilterCheck
    alias WandererApp.Api.ActorHelpers

    @impl true
    def describe(_), do: "ACL is linked to the token's map"

    @impl true
    def filter(actor, _ctx, _opts) do
      case ActorHelpers.get_map(%{actor: actor}) do
        %{id: map_id} -> expr(exists(map_access_lists, map_id == ^map_id))
        _ -> expr(false)
      end
    end
  end

  defmodule AclMemberInTokenMap do
    @moduledoc """
    Filters access-list members down to those whose parent ACL is linked to
    the token's map.
    """
    use Ash.Policy.FilterCheck
    alias WandererApp.Api.ActorHelpers

    @impl true
    def describe(_), do: "ACL member's ACL is linked to the token's map"

    @impl true
    def filter(actor, _ctx, _opts) do
      case ActorHelpers.get_map(%{actor: actor}) do
        %{id: map_id} -> expr(exists(access_list.map_access_lists, map_id == ^map_id))
        _ -> expr(false)
      end
    end
  end
end
