defmodule WandererApp.Api.Changes.SlugifyName do
  use Ash.Resource.Change

  alias Ash.Changeset

  @impl true
  @spec change(Changeset.t(), keyword, Change.context()) :: Changeset.t()
  def change(changeset, _options, _context) do
    Changeset.before_action(changeset, &maybe_slugify_name/1)
  end

  defp maybe_slugify_name(changeset) do
    case Changeset.get_attribute(changeset, :slug) do
      slug when is_binary(slug) ->
        Changeset.force_change_attribute(changeset, :slug, Slug.slugify(slug))

      _ ->
        changeset
    end
  end
end
