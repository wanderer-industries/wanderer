defmodule WandererApp.Api.Changes.SlugifyName do
  use Ash.Resource.Change

  alias Ash.Changeset
  require Ash.Query

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

    # Check if the base slug is available
    if slug_available?(base_slug, current_id) do
      base_slug
    else
      # Find the next available slug with a numeric suffix
      find_available_slug(base_slug, current_id, 2)
    end
  end

  defp find_available_slug(base_slug, current_id, n) do
    candidate_slug = "#{base_slug}-#{n}"

    if slug_available?(candidate_slug, current_id) do
      candidate_slug
    else
      find_available_slug(base_slug, current_id, n + 1)
    end
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
      {:ok, []} -> true
      {:ok, _} -> false
      {:error, _} -> false
    end
  end
end
