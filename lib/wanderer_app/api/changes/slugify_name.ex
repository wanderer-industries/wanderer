defmodule WandererApp.Api.Changes.SlugifyName do
  @moduledoc """
  Ensures map slugs are unique by:
  1. Slugifying the provided slug/name
  2. Checking for existing slugs (optimization)
  3. Finding next available slug with numeric suffix if needed
  4. Relying on database unique constraint as final arbiter

  Race Condition Mitigation:
  - Optimistic check reduces DB roundtrips for most cases
  - Database unique index ensures no duplicates slip through
  - Proper error messages for constraint violations
  - Telemetry events for monitoring conflicts
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  require Ash.Query
  require Logger

  # Maximum number of attempts to find a unique slug
  @max_attempts 100

  @impl true
  @spec change(Changeset.t(), keyword, Change.context()) :: Changeset.t()
  def change(changeset, _options, _context) do
    Changeset.before_action(changeset, &maybe_slugify_name/1)
  end

  defp maybe_slugify_name(changeset) do
    case Changeset.get_attribute(changeset, :slug) do
      slug when is_binary(slug) ->
        base_slug = Slug.slugify(slug)
        unique_slug = ensure_unique_slug(changeset, base_slug)
        Changeset.force_change_attribute(changeset, :slug, unique_slug)

      _ ->
        changeset
    end
  end

  defp ensure_unique_slug(changeset, base_slug) do
    # Get the current record ID if this is an update operation
    current_id = Changeset.get_attribute(changeset, :id)

    # Check if the base slug is available (optimization to avoid numeric suffixes when possible)
    if slug_available?(base_slug, current_id) do
      base_slug
    else
      # Find the next available slug with a numeric suffix
      find_available_slug(base_slug, current_id, 2)
    end
  end

  defp find_available_slug(base_slug, current_id, n) when n <= @max_attempts do
    candidate_slug = "#{base_slug}-#{n}"

    if slug_available?(candidate_slug, current_id) do
      # Emit telemetry when we had to use a suffix (indicates potential conflict)
      :telemetry.execute(
        [:wanderer_app, :map, :slug_suffix_used],
        %{suffix_number: n},
        %{base_slug: base_slug, final_slug: candidate_slug}
      )

      candidate_slug
    else
      find_available_slug(base_slug, current_id, n + 1)
    end
  end

  defp find_available_slug(base_slug, _current_id, n) when n > @max_attempts do
    # Fallback: use timestamp suffix if we've tried too many numeric suffixes
    # This handles edge cases where many maps have similar names
    timestamp = System.system_time(:millisecond)
    fallback_slug = "#{base_slug}-#{timestamp}"

    Logger.warning(
      "Slug generation exceeded #{@max_attempts} attempts for '#{base_slug}', using timestamp fallback",
      base_slug: base_slug,
      fallback_slug: fallback_slug
    )

    :telemetry.execute(
      [:wanderer_app, :map, :slug_fallback_used],
      %{attempts: n},
      %{base_slug: base_slug, fallback_slug: fallback_slug}
    )

    fallback_slug
  end

  defp slug_available?(slug, current_id) do
    query =
      WandererApp.Api.Map
      |> Ash.Query.filter(slug == ^slug)
      |> then(fn query ->
        # Exclude the current record if this is an update
        if current_id do
          Ash.Query.filter(query, id != ^current_id)
        else
          query
        end
      end)
      |> Ash.Query.limit(1)

    case Ash.read(query) do
      {:ok, []} ->
        true

      {:ok, _existing} ->
        false

      {:error, error} ->
        # Log error but be conservative - assume slug is not available
        Logger.warning("Error checking slug availability",
          slug: slug,
          error: inspect(error)
        )

        false
    end
  end
end
