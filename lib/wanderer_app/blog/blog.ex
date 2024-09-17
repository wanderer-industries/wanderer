defmodule WandererApp.Blog do
  alias WandererApp.Blog.Post

  use NimblePublisher,
    build: Post,
    from: Application.app_dir(:wanderer_app, "priv/posts/**/*.md"),
    as: :posts,
    highlighters: [:makeup_elixir, :makeup_erlang]

  # The @posts variable is first defined by NimblePublisher.
  # Let's further modify it by sorting all posts by descending date.
  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  # Let's also get all tags
  @tags @posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  # And finally export them
  def all_posts, do: @posts
  def all_tags, do: @tags

  def recent_posts(count \\ 3) do
    @posts |> Enum.take(count)
  end

  def get_by_id!(id) do
    @posts |> Enum.find(&(&1.id == id))
  end

  def get_by_tag(tag) do
    @posts |> Enum.filter(&(&1.tags |> Enum.member?(tag)))
  end
end
