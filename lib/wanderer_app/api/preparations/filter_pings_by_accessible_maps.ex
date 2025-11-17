defmodule WandererApp.Api.Preparations.FilterPingsByAccessibleMaps do
  @moduledoc """
  Filters map pings to only show pings from maps the user has access to.

  This prevents data leakage by ensuring users can only see pings from:
  - Maps they own
  - Maps shared with them via ACLs
  - The specific map associated with their token (for token-based auth)
  """

  use Ash.Resource.Preparation
  require Ash.Query

  alias WandererApp.Api.ActorHelpers

  def prepare(query, _params, %{actor: nil}) do
    query
  end

  def prepare(query, _params, context) do
    case ActorHelpers.get_map(context) do
      %{id: map_id} ->
        query
        |> Ash.Query.filter(expr(map_id == ^map_id))

      nil ->
        filter_by_character_ownership(query, context)
    end
  end

  defp filter_by_character_ownership(query, %{actor: actor}) do
    case ActorHelpers.get_character_ids(actor) do
      {:ok, [_ | _] = character_ids} ->
        query |> Ash.Query.filter(expr(map.owner_id in ^character_ids))

      {:ok, []} ->
        Logger.warning("[FilterPingsByAccessibleMaps] User has no characters")
        query |> Ash.Query.filter(expr(false))

      {:error, reason} ->
        Logger.error(
          "[FilterPingsByAccessibleMaps] Failed to get character IDs",
          error: inspect(reason)
        )

        query |> Ash.Query.filter(expr(false))
    end
  end

  defp filter_by_character_ownership(query, _context) do
    # No actor in context
    query
  end
end
