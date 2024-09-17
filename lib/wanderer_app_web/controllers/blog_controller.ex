defmodule WandererAppWeb.BlogController do
  use WandererAppWeb, :controller

  alias WandererApp.Blog
  require Logger

  def index(conn, _params) do
    invite_token = conn.query_params["invite"]

    invite_token_valid =
      case WandererApp.Env.invites() do
        true ->
          case invite_token do
            nil -> false
            token -> WandererApp.Cache.lookup!("invite_#{token}", false)
          end

        _ ->
          true
      end

    posts = Blog.all_posts()

    render(conn, "index.html",
      posts: posts,
      invite_token: invite_token || "",
      invite_token_valid: invite_token_valid
    )
  end

  def list(conn, params) do
    tags = Blog.all_tags()

    {posts, selected_tag} =
      params
      |> case do
        %{"tag" => tag} -> {Blog.get_by_tag(tag), tag}
        _ -> {Blog.all_posts(), nil}
      end

    render(conn, "list.html",
      posts: posts,
      tags: tags,
      selected_tag: selected_tag
    )
  end

  def show(conn, %{"slug" => slug}) do
    post = Blog.get_by_id!(slug)

    if post do
      render(conn, "show.html", post: post)
    else
      conn
      |> put_status(:not_found)
    end
  end

  def contacts(conn, _params) do
    render(conn, "contacts.html")
  end

  def changelog(conn, _params) do
    [file] = WandererApp.Changelog.all_files()
    render(conn, "changelog.html", file: file)
  end

  def license(conn, _params) do
    render(conn, "license.html")
  end
end
