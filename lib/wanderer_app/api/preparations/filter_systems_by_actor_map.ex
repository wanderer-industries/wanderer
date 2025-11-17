defmodule WandererApp.Api.Preparations.FilterSystemsByActorMap do
  @moduledoc """
  Filters map systems based on the actor's map context.

  For token-based authentication (ActorWithMap), this ensures that
  users can ONLY access systems from the map associated with their token.

  This is a critical security control that prevents cross-map data access.
  """

  use Ash.Resource.Preparation
  require Ash.Query
  require Logger

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
        Logger.warning("[FilterSystemsByActorMap] User has no characters")
        query |> Ash.Query.filter(expr(false))

      {:error, reason} ->
        Logger.error(
          "[FilterSystemsByActorMap] Failed to get character IDs",
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
