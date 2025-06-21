defmodule WandererAppWeb.Helpers.PaginationHelpers do
  @moduledoc """
  Helper functions for implementing pagination in API controllers.

  Provides consistent pagination logic across all endpoints that return
  large result sets.
  """

  alias WandererAppWeb.Validations.ApiValidations

  @doc """
  Apply pagination to an Ash query.

  Returns {:ok, {results, pagination_meta}} or {:error, changeset}
  """
  def paginate_query(query, params, api_module) do
    with {:ok, %{page: page, page_size: page_size}} <- ApiValidations.validate_pagination(params) do
      offset = (page - 1) * page_size

      # Get total count first
      total_count =
        query
        |> api_module.count!()

      # Calculate total pages
      total_pages = div(total_count + page_size - 1, page_size)

      # Get paginated results
      results =
        query
        |> Ash.Query.offset(offset)
        |> Ash.Query.limit(page_size)
        |> api_module.read!()

      pagination_meta = %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: total_pages
      }

      {:ok, {results, pagination_meta}}
    end
  end

  @doc """
  Apply pagination to a list of results (for non-Ash queries).

  Returns {:ok, {paginated_results, pagination_meta}} or {:error, changeset}
  """
  def paginate_list(items, params) when is_list(items) do
    with {:ok, %{page: page, page_size: page_size}} <- ApiValidations.validate_pagination(params) do
      total_count = length(items)
      total_pages = div(total_count + page_size - 1, page_size)

      offset = (page - 1) * page_size

      paginated_items =
        items
        |> Enum.drop(offset)
        |> Enum.take(page_size)

      pagination_meta = %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: total_pages
      }

      {:ok, {paginated_items, pagination_meta}}
    end
  end

  @doc """
  Format paginated response with data and metadata.
  """
  def format_paginated_response(data, pagination_meta) do
    %{
      data: data,
      pagination: pagination_meta
    }
  end

  @doc """
  Add pagination links to conn for API discoverability.
  """
  def add_pagination_headers(conn, %{page: page, total_pages: total_pages} = _meta, base_url) do
    links = build_pagination_links(page, total_pages, base_url)

    conn
    |> Plug.Conn.put_resp_header("x-page", to_string(page))
    |> Plug.Conn.put_resp_header("x-total-pages", to_string(total_pages))
    |> maybe_add_link_header(links)
  end

  defp build_pagination_links(page, total_pages, base_url) do
    links = []

    # First page
    links = if page > 1, do: [{"first", "#{base_url}?page=1"} | links], else: links

    # Previous page
    links = if page > 1, do: [{"prev", "#{base_url}?page=#{page - 1}"} | links], else: links

    # Next page
    links =
      if page < total_pages, do: [{"next", "#{base_url}?page=#{page + 1}"} | links], else: links

    # Last page
    links =
      if page < total_pages,
        do: [{"last", "#{base_url}?page=#{total_pages}"} | links],
        else: links

    Enum.reverse(links)
  end

  defp maybe_add_link_header(conn, []), do: conn

  defp maybe_add_link_header(conn, links) do
    link_header =
      links
      |> Enum.map(fn {rel, url} -> "<#{url}>; rel=\"#{rel}\"" end)
      |> Enum.join(", ")

    Plug.Conn.put_resp_header(conn, "link", link_header)
  end
end
