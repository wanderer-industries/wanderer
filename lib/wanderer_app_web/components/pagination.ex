defmodule WandererAppWeb.Components.Pagination do
  @moduledoc """
  Pagination component for AshPagify.
  """

  alias WandererAppWeb.Components
  alias AshPagify.Meta
  alias AshPagify.Misc

  @spec default_opts() :: [Components.pagination_option()]
  def default_opts do
    [
      current_link_attrs: [
        class: "pagination-link is-current",
        aria: [current: "page"]
      ],
      disabled_class: "disabled",
      ellipsis_attrs: [class: "pagination-ellipsis"],
      ellipsis_content: Phoenix.HTML.raw("&hellip;"),
      next_link_attrs: [
        aria: [label: "Go to next page"],
        class: "pagination-next"
      ],
      next_link_content: "Next",
      page_links: :all,
      pagination_link_aria_label: &"Go to page #{&1}",
      pagination_link_attrs: [class: "pagination-link"],
      previous_link_attrs: [
        aria: [label: "Go to previous page"],
        class: "pagination-previous"
      ],
      previous_link_content: "Previous",
      wrapper_attrs: [
        class: "pagination",
        role: "navigation",
        aria: [label: "pagination"]
      ]
    ]
  end

  def merge_opts(opts) do
    default_opts()
    |> Misc.list_merge(Misc.global_option(:pagination) || [])
    |> Misc.list_merge(opts)
  end

  def max_pages(:all, total_pages), do: total_pages
  def max_pages(:hide, _), do: 0
  def max_pages({:ellipsis, max_pages}, _), do: max_pages

  def show_pagination(nil), do: false

  def show_pagination?(%Meta{errors: [], total_pages: total_pages}) do
    total_pages > 1
  end

  def show_pagination?(_), do: false

  def get_page_link_range(current_page, max_pages, total_pages) do
    # number of additional pages to show before or after current page
    additional = ceil(max_pages / 2)

    cond do
      max_pages >= total_pages ->
        1..total_pages

      current_page + additional > total_pages ->
        (total_pages - max_pages + 1)..total_pages

      true ->
        first = max(current_page - additional + 1, 1)
        last = min(first + max_pages - 1, total_pages)
        first..last
    end
  end

  @spec build_page_link_helper(Meta.t(), Components.pagination_path()) ::
          (integer() -> String.t() | nil)
  def build_page_link_helper(_meta, nil), do: fn _offset -> nil end

  def build_page_link_helper(%Meta{} = meta, path) do
    query_params = build_query_params(meta)

    fn offset ->
      params = maybe_put_offset(query_params, offset)
      Components.build_path(path, params)
    end
  end

  defp build_query_params(%Meta{} = meta) do
    Components.to_query(meta.ash_pagify, for: meta.resource, default_scopes: meta.default_scopes)
  end

  defp maybe_put_offset(params, 0), do: Keyword.delete(params, :offset)
  defp maybe_put_offset(params, offset), do: Keyword.put(params, :offset, offset)

  def attrs_for_page_link(page, %{current_page: page}, opts) do
    add_page_link_aria_label(opts[:current_link_attrs], page, opts)
  end

  def attrs_for_page_link(page, _meta, opts) do
    add_page_link_aria_label(opts[:pagination_link_attrs], page, opts)
  end

  defp add_page_link_aria_label(attrs, page, opts) do
    aria_label = opts[:pagination_link_aria_label].(page)

    Keyword.update(
      attrs,
      :aria,
      [label: aria_label],
      &Keyword.put(&1, :label, aria_label)
    )
  end
end
