defmodule WandererAppWeb.Components do
  @moduledoc """
  Phoenix headless components for pagination and sortable tables with `AshPagify`.

  ## Introduction

  Please refere to the _Usage_ section in `AshPagify` for more information.

  This module provides two components: `AshPagify.Components.Pagination` and
  `AshPagify.Components.Table`. The components are designed to work with
  `AshPagify` and `Ash.Resource` structs. They are by default unstyled components
  which add basic classes and attributes to the elements they render. However,
  you can customize the components by passing options.

  Further, `AshPagify.Components` provides helper functions to build paths for
  pagination and sorting links. The paths are built based on the current query
  parameters and the new parameters that are passed to the function.

  ## Customization

  The default classes, attributes, texts and symbols can be overridden by
  passing the `opts` assign. Since you probably will use the same `opts` in all
  your templates, you can globally configure an `opts` provider function for
  each component.

  The functions have to return the options as a keyword list. The overrides
  are deep-merged into the default options.

      defmodule MyAppWeb.CoreComponents do
        use Phoenix.Component

        def pagination_opts do
           [
            ellipsis_attrs: [class: "ellipsis"],
            ellipsis_content: "‥",
            next_link_attrs: [class: "next"],
            next_link_content: next_icon(),
            page_links: {:ellipsis, 7},
            pagination_link_aria_label: &"\#{&1}ページ目へ",
            previous_link_attrs: [class: "prev"],
            previous_link_content: previous_icon()
          ]
        end

        defp next_icon do
          assigns = %{}

          ~H\"""
          <i class="fas fa-chevron-right"/>
          \"""
        end

        defp previous_icon do
          assigns = %{}

          ~H\"""
          <i class="fas fa-chevron-left"/>
          \"""
        end

        def table_opts do
          [
            container: true,
            container_attrs: [class: "table-container"],
            no_results_content: no_results_content(),
            table_attrs: [class: "table"]
          ]
        end

        defp no_results_content do
          assigns = %{}

          ~H\"""
          <p>Nothing found.</p>
          \"""
        end
      end

  Refer to `t:pagination_option/0` and `t:table_option/0` for a list of
  available options and defaults.

  Once you have defined these functions, you can reference them with a
  module/function tuple in `config/config.exs`.

  ```elixir
  config :ash_pagify,
    pagination: [opts: {MyAppWeb.CoreComponents, :pagination_opts}],
    table: [opts: {MyAppWeb.CoreComponents, :table_opts}]
  ```

  ## Hiding default parameters

  Default values for scoping, pagination and ordering are omitted from the query
  parameters. AshPagify.Components function will pick up the default values
  from the `Ash.Resource` specifications.

  ## Links

  Links are generated with `Phoenix.Component.link/1`. This will
  lead to `<a>` tags with `data-phx-link` and `data-phx-link-state` attributes,
  which will be ignored outside of LiveViews and LiveComponents.

  When used within a LiveView or LiveComponent, you will need to handle the new
  params in the `c:Phoenix.LiveView.handle_params/3` callback of your LiveView
  module.

  ## Using JS commands

  You can pass a `Phoenix.LiveView.JS` command as `on_paginate` and `on_sort`
  attributes.

  If used with the `path` attribute, the URL will be patched _and_ the given
  JS command will be executed.

  If used without the `path` attribute, you will need to include a `push`
  command to trigger an event when a pagination or sort link is clicked.

  You can set a different target by assigning a `:target`. The value
  will be used as the `phx-target` attribute.

      <AshPagify.Components.table
        items={@items}
        meta={@meta}
        on_sort={JS.push("sort-posts")}
        target={@myself}
      />

      <AshPagify.Components.pagination
        meta={@meta}
        on_paginate={JS.push("paginate-posts")}
        target={@myself}
      />

  You will need to handle the event in the `c:Phoenix.LiveView.handle_event/3`
  or `c:Phoenix.LiveComponent.handle_event/3` callback of your
  LiveView or LiveComponent module. The event name will be the one you set with
  the `:event` option.

      @impl true
      def handle_event("paginate-posts", %{"offset" => offset}, socket) do
        ash_pagify = AshPagify.set_offset(socket.assigns.meta.ash_pagify, offset)

        with {:ok, {posts, meta}} <- Post.list_posts(ash_pagify) do
          {:noreply, assign(socket, posts: posts, meta: meta)}
        end
      end

      @impl true
      def handle_event("sort-posts", %{"order" => order}, socket) do
        ash_pagify = AshPagify.push_order(socket.assigns.meta.ash_pagify, order)

        with {:ok, {posts, meta}} <- Post.list_posts(ash_pagify) do
          {:noreply, assign(socket, posts: posts, meta: meta)}
        end
      end
  """

  use Phoenix.Component

  alias WandererAppWeb.Components.Pagination
  alias AshPagify.Components.Table
  alias AshPagify.Error.Components.PathOrJSError
  alias AshPagify.Meta
  alias AshPagify.Misc
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Rendered
  alias Plug.Conn.Query

  @typedoc """
  Defines the available options for `AshPagify.Components.pagination/1`.

  - `:current_link_attrs` - The attributes for the link to the current page.
    Default: `#{inspect(Pagination.default_opts()[:current_link_attrs])}`.
  - `:disabled_class` - The class which is added to disabled links. Default:
    `#{inspect(Pagination.default_opts()[:disabled_class])}`.
  - `:ellipsis_attrs` - The attributes for the `<span>` that wraps the
    ellipsis.
    Default: `#{inspect(Pagination.default_opts()[:ellipsis_attrs])}`.
  - `:ellipsis_content` - The content for the ellipsis element.
    Default: `#{inspect(Pagination.default_opts()[:ellipsis_content])}`.
  - `:next_link_attrs` - The attributes for the link to the next page.
    Default: `#{inspect(Pagination.default_opts()[:next_link_attrs])}`.
  - `:next_link_content` - The content for the link to the next page.
    Default: `#{inspect(Pagination.default_opts()[:next_link_content])}`.
  - `:page_links` - Specifies how many page links should be rendered.
    Default: `#{inspect(Pagination.default_opts()[:page_links])}`.
    - `:all` - Renders all page links.
    - `{:ellipsis, n}` - Renders `n` page links. Renders ellipsis elements if
      there are more pages than displayed.
    - `:hide` - Does not render any page links.
  - `:pagination_link_aria_label` - 1-arity function that takes a page number
    and returns an aria label for the corresponding page link.
    Default: `&"Go to page \#{&1}"`.
  - `:pagination_link_attrs` - The attributes for the pagination links.
    Default: `#{inspect(Pagination.default_opts()[:pagination_link_attrs])}`.
  - `:previous_link_attrs` - The attributes for the link to the previous page.
    Default: `#{inspect(Pagination.default_opts()[:previous_link_attrs])}`.
  - `:previous_link_content` - The content for the link to the previous page.
    Default: `#{inspect(Pagination.default_opts()[:previous_link_content])}`.
  - `:wrapper_attrs` - The attributes for the `<nav>` element that wraps the
    pagination links.
    Default: `#{inspect(Pagination.default_opts()[:wrapper_attrs])}`.
  """
  @type pagination_option ::
          {:current_link_attrs, keyword}
          | {:disabled_class, String.t()}
          | {:ellipsis_attrs, keyword}
          | {:ellipsis_content, Phoenix.HTML.safe() | binary}
          | {:next_link_attrs, keyword}
          | {:next_link_content, Phoenix.HTML.safe() | binary}
          | {:page_links, :all | :hide | {:ellipsis, pos_integer}}
          | {:pagination_link_aria_label, (pos_integer -> binary)}
          | {:pagination_link_attrs, keyword}
          | {:previous_link_attrs, keyword}
          | {:previous_link_content, Phoenix.HTML.safe() | binary}
          | {:wrapper_attrs, keyword}

  @typedoc """
  Defines the available types for the `path` attribute of `AshPagify.Components.pagination/1`.
  """
  @type pagination_path ::
          String.t()
          | {module(), atom(), [any()]}
          | {function, [any]}
          | (keyword -> String.t())

  @typedoc """
  Defines the available options for `AshPagify.Components.table/1`.

  - `:container` - Wraps the table in a `<div>` if `true`.
    Default: `#{inspect(Table.default_opts()[:container])}`.
  - `:container_attrs` - The attributes for the table container.
    Default: `#{inspect(Table.default_opts()[:container_attrs])}`.
  - `:no_results_content` - Any content that should be rendered if there are no
    results. Default: `<p>No results.</p>`.
  - `:loading_content` - Any content that should be rendered while the table is
    loading. Default: `<p>Loading...</p>`.
  - `:loading_items` - The number of items that are displayed while the table is
    loading. Default: `#{inspect(Table.default_opts()[:loading_items])}`.
  - `:error_content` - Any content that should be rendered if there is an error.
    Default: `<p>Something went wrong.</p>`.
  - `:table_attrs` - The attributes for the `<table>` element.
    Default: `#{inspect(Table.default_opts()[:table_attrs])}`.
  - `:th_wrapper_attrs` - The attributes for the `<span>` element that wraps the
    header link and the order direction symbol.
    Default: `#{inspect(Table.default_opts()[:th_wrapper_attrs])}`.
  - `:symbol_asc` - The symbol that is used to indicate that the column is
    sorted in ascending order.
    Default: `#{inspect(Table.default_opts()[:symbol_asc])}`.
  - `:symbol_attrs` - The attributes for the `<span>` element that wraps the
    order direction indicator in the header columns.
    Default: `#{inspect(Table.default_opts()[:symbol_attrs])}`.
  - `:symbol_desc` - The symbol that is used to indicate that the column is
    sorted in ascending order.
    Default: `#{inspect(Table.default_opts()[:symbol_desc])}`.
  - `:symbol_unsorted` - The symbol that is used to indicate that the column is
    not sorted. Default: `#{inspect(Table.default_opts()[:symbol_unsorted])}`.
  - `:tbody_attrs`: Attributes to be added to the `<tbody>` tag within the
    `<table>`. Default: `#{inspect(Table.default_opts()[:tbody_attrs])}`.
  - `:tbody_td_attrs`: Attributes to be added to each `<td>` tag within the
    `<tbody>`. Default: `#{inspect(Table.default_opts()[:tbody_td_attrs])}`.
  - `:thead_attrs`: Attributes to be added to the `<thead>` tag within the
    `<table>`. Default: `#{inspect(Table.default_opts()[:thead_attrs])}`.
  - `:tbody_tr_attrs`: Attributes to be added to each `<tr>` tag within the
    `<tbody>`. A function with arity of 1 may be passed to dynamically generate
    the attrs based on row data.
    Default: `#{inspect(Table.default_opts()[:tbody_tr_attrs])}`.
  - `:thead_th_attrs`: Attributes to be added to each `<th>` tag within the
    `<thead>`. Default: `#{inspect(Table.default_opts()[:thead_th_attrs])}`.
  - `:thead_tr_attrs`: Attributes to be added to each `<tr>` tag within the
    `<thead>`. Default: `#{inspect(Table.default_opts()[:thead_tr_attrs])}`.
  - `:limit_order_by` - Limit the number of applied order_by fields.
    Default: `#{inspect(Table.default_opts()[:limit_order_by])}`.
  """
  @type table_option ::
          {:container, boolean}
          | {:container_attrs, keyword}
          | {:no_results_content, Phoenix.HTML.safe() | binary}
          | {:loading_content, Phoenix.HTML.safe() | binary}
          | {:loading_items, number}
          | {:error_content, Phoenix.HTML.safe() | binary}
          | {:symbol_asc, Phoenix.HTML.safe() | binary}
          | {:symbol_attrs, keyword}
          | {:symbol_desc, Phoenix.HTML.safe() | binary}
          | {:symbol_unsorted, Phoenix.HTML.safe() | binary}
          | {:table_attrs, keyword}
          | {:tbody_attrs, keyword}
          | {:thead_attrs, keyword}
          | {:tbody_td_attrs, keyword}
          | {:tbody_tr_attrs, keyword | (any -> keyword)}
          | {:th_wrapper_attrs, keyword}
          | {:thead_th_attrs, keyword}
          | {:thead_tr_attrs, keyword}
          | {:limit_order_by, pos_integer}

  @doc """
  Generates a pagination element.

  ## Examples

      <AshPagify.Components.pagination
        meta={@meta}
        path={~p"/posts"}
      />

      <AshPagify.Components.pagination
        meta={@meta}
        path={{Routes, :post_path, [@socket, :index]}}
      />

  ## Page link options

  By default, page links for all pages are shown. You can limit the number of
  page links or disable them altogether by passing the `:page_links` option.

  - `:all`: Show all page links.
  - `:hide`: Don't show any page links. Only the previous/next links will be
    shown.
  - `{:ellipsis, x}`: Limits the number of page links. The first and last page
    are always displayed. The `x` refers to the number of additional page links
    to show (default n=4).
  """
  @spec pagination(map()) :: Rendered.t()

  attr :meta, Meta,
    required: true,
    doc: """
    The meta information of the query as returned by the `AshPagify` query functions
    """

  attr :path, :any,
    default: nil,
    doc: """
    If set, the current view is patched with updated query parameters when a
    pagination link is clicked. In case the `on_paginate` attribute is set as
    well, the URL is patched _and_ the given command is executed.

    The value must be either a URI string (Phoenix verified route), an MFA or FA
    tuple (Phoenix route helper), or a 1-ary path builder function. See
    `AshPagify.Components.build_path/3` for details.
    """

  attr :on_paginate, JS,
    default: nil,
    doc: """
    A `Phoenix.LiveView.JS` command that is triggered when a pagination link is
    clicked.

    If used without the `path` attribute, you should include a `push` operation
    to handle the event with the `handle_event` callback.

        <.pagination
          meta={@meta}
          on_paginate={
            JS.dispatch("my_app:scroll_to", to: "#post-table") |> JS.push("paginate")
          }
        />

    If used with the `path` attribute, the URL is patched _and_ the given
    JS command is executed.

        <.pagination
          meta={@meta}
          path={~"/posts"}
          on_paginate={JS.dispatch("my_app:scroll_to", to: "#post-table")}
        />

    With the above attributes in place, you can add the following JavaScript to
    your application to scroll to the top of your table whenever a pagination
    link is clicked:

    ```js
    window.addEventListener("my_app:scroll_to", (e) => {
      e.target.scrollIntoView();
    });
    ```

    You can use CSS to scroll to the new position smoothly.

    ```css
    html {
      scroll-behavior: smooth;
    }
    ```
    """

  attr :target, :string,
    default: nil,
    doc: """
    Sets the `phx-target` attribute for the pagination links.
    """

  attr :opts, :list,
    default: [],
    doc: """
    Options to customize the pagination. See
    `t:AshPagify.Components.pagination_option/0`. Note that the options passed to the
    function are deep merged into the default options. Since these options will
    likely be the same for all the tables in a project, it is recommended to
    define them once in a function or set them in a wrapper function as
    described in the `Customization` section of the module documentation.
    """

  def pagination(%{path: nil, on_paginate: nil}) do
    raise PathOrJSError, component: :pagination
  end

  def pagination(%{meta: meta, opts: opts, path: path} = assigns) do
    assigns =
      assigns
      |> assign(:opts, Pagination.merge_opts(opts))
      |> assign(:page_link_helper, Pagination.build_page_link_helper(meta, path))
      |> assign(:path, nil)

    ~H"""
    <nav :if={Pagination.show_pagination?(@meta)} {@opts[:wrapper_attrs]}>
      <.pagination_link
        disabled={!@meta.has_previous_page?}
        disabled_class={@opts[:disabled_class]}
        target={@target}
        offset={@meta.previous_offset}
        path={@page_link_helper.(@meta.previous_offset)}
        on_paginate={@on_paginate}
        {@opts[:previous_link_attrs]}
      >
        <%= @opts[:previous_link_content] %>
      </.pagination_link>
      <.page_links
        :if={@opts[:page_links] != :hide}
        meta={@meta}
        on_paginate={@on_paginate}
        page_link_helper={@page_link_helper}
        opts={@opts}
        target={@target}
      />
      <.pagination_link
        disabled={!@meta.has_next_page?}
        disabled_class={@opts[:disabled_class]}
        target={@target}
        offset={@meta.next_offset}
        path={@page_link_helper.(@meta.next_offset)}
        on_paginate={@on_paginate}
        {@opts[:next_link_attrs]}
      >
        <%= @opts[:next_link_content] %>
      </.pagination_link>
    </nav>
    """
  end

  attr :meta, Meta, required: true
  attr :on_paginate, JS
  attr :page_link_helper, :any, required: true
  attr :target, :string, required: true
  attr :opts, :list, required: true

  defp page_links(%{meta: meta} = assigns) do
    max_pages =
      Pagination.max_pages(assigns.opts[:page_links], assigns.meta.total_pages)

    range =
      first..last//1 =
      Pagination.get_page_link_range(
        meta.current_page,
        max_pages,
        meta.total_pages
      )

    assigns = assign(assigns, first: first, last: last, range: range)

    ~H"""
    <.pagination_link
      :if={@first > 1}
      target={@target}
      offset={0}
      path={@page_link_helper.(0)}
      on_paginate={@on_paginate}
      {Pagination.attrs_for_page_link(1, @meta, @opts)}
    >
      1
    </.pagination_link>

    <span :if={@first > 2} {@opts[:ellipsis_attrs]}><%= @opts[:ellipsis_content] %></span>

    <.pagination_link
      :for={page <- @range}
      target={@target}
      offset={page * @meta.current_limit - @meta.current_limit}
      path={@page_link_helper.(page * @meta.current_limit - @meta.current_limit)}
      on_paginate={@on_paginate}
      {Pagination.attrs_for_page_link(page, @meta, @opts)}
    >
      <%= page %>
    </.pagination_link>

    <span :if={@last < @meta.total_pages - 1} {@opts[:ellipsis_attrs]}>
      <%= @opts[:ellipsis_content] %>
    </span>

    <.pagination_link
      :if={@last < @meta.total_pages}
      target={@target}
      offset={@meta.total_pages * @meta.current_limit - @meta.current_limit}
      path={@page_link_helper.(@meta.total_pages * @meta.current_limit - @meta.current_limit)}
      on_paginate={@on_paginate}
      {Pagination.attrs_for_page_link(@meta.total_pages, @meta, @opts)}
    >
      <%= @meta.total_pages %>
    </.pagination_link>
    """
  end

  attr :path, :string
  attr :on_paginate, JS
  attr :target, :string, required: true
  attr :offset, :integer, required: true
  attr :disabled, :boolean, default: false
  attr :disabled_class, :string
  attr :rest, :global

  slot :inner_block

  defp pagination_link(%{disabled: true, disabled_class: disabled_class} = assigns) do
    rest =
      Map.update(assigns.rest, :class, disabled_class, fn class ->
        [class, disabled_class]
      end)

    assigns = assign(assigns, :rest, rest)

    ~H"""
    <span {@rest} class={@disabled_class}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  defp pagination_link(%{on_paginate: nil, path: path} = assigns) when is_binary(path) do
    ~H"""
    <.link patch={@path} {@rest}>
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  defp pagination_link(%{} = assigns) do
    ~H"""
    <.link
      patch={@path}
      phx-click={@on_paginate}
      phx-target={@target}
      phx-value-offset={@offset}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Generates a table with sortable columns.

  ## Example

  ```elixir
  <AshPagify.Components.table items={@posts} meta={@meta} path={~p"/posts"}>
    <:col :let={post} label="Name" field={:name}><%= post.name %></:col>
    <:col :let={post} label="Author" field={:author}><%= post.author %></:col>
  </AshPagify.Components.table>
  ```
  """
  @spec table_pagify(map) :: Rendered.t()

  attr :id, :string,
    doc: """
    ID used on the table. If not set, an ID is chosen based on the resource
    module derived from the `AshPagify.Meta` struct.

    The ID is necessary in case the table is fed with a LiveView stream.
    """

  attr :items, :list,
    required: true,
    doc: """
    The list of items to be displayed in rows. This is the result list returned
    by the query.
    """

  attr :loading, :boolean,
    default: false,
    doc: """
    If set to `true`, the table will render the `:loading_content` option.
    """

  attr :error, :boolean,
    default: false,
    doc: """
    If set to `true`, the table will render the `:error_content` option.
    """

  attr :meta, Meta,
    default: nil,
    doc: "The `AshPagify.Meta` struct returned by the query function. If omitted
    the table will be rendered without order_by links."

  attr :path, :any,
    default: nil,
    doc: """
    If set, the current view is patched with updated query parameters when a
    header link for sorting is clicked. In case the `on_sort` attribute is
    set as well, the URL is patched _and_ the given JS command is executed.

    The value must be either a URI string (Phoenix verified route), an MFA or FA
    tuple (Phoenix route helper), or a 1-ary path builder function. See
    `AshPagify.Components.build_path/3` for details.
    """

  attr :on_sort, JS,
    default: nil,
    doc: """
    A `Phoenix.LiveView.JS` command that is triggered when a header link for
    sorting is clicked.

    If used without the `path` attribute, you should include a `push` operation
    to handle the event with the `handle_event` callback.

        <.table
          items={@items}
          meta={@meta}
          on_sort={
            JS.dispatch("my_app:scroll_to", to: "#post-table") |> JS.push("sort")
          }
        />

    If used with the `path` attribute, the URL is patched _and_ the given
    JS command is executed.

        <.table
          meta={@meta}
          path={~"/posts"}
          on_sort={JS.dispatch("my_app:scroll_to", to: "#post-table")}
        />
    """

  attr :target, :string,
    default: nil,
    doc: "Sets the `phx-target` attribute for the header links."

  attr :caption_text, :string,
    default: nil,
    doc: "Content for the `<caption>` element."

  attr :opts, :list,
    default: [],
    doc: """
    Keyword list with additional options (see `t:AshPagify.Components.table_option/0`).
    Note that the options passed to the function are deep merged into the
    default options. Since these options will likely be the same for all
    the tables in a project, it is recommended to define them once in a
    function or set them in a wrapper function as described in the `Customization`
    section of the module documentation.
    """

  attr :row_id, :any,
    default: nil,
    doc: """
    Overrides the default function that retrieves the row ID from a stream item.
    """

  attr :row_click, :any,
    default: nil,
    doc: """
    Sets the `phx-click` function attribute for each row `td`. Expects to be a
    function that receives a row item as an argument. This does not add the
    `phx-click` attribute to the `action` slot.

    Example:

    ```elixir
    row_click={&JS.navigate(~p"/users/\#{&1}")}
    ```
    """

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: """
    This function is called on the row item before it is passed to the :col
    and :action slots.
    """

  slot :caption,
    doc: """
    The slot for the table caption. If set, the content of the slot is rendered
    as the content of the `<caption>` element.

    ```elixir
    <:caption>
      <h2>Posts</h2>
    </:caption>
    ```
    """

  slot :col,
    required: true,
    doc: """
    For each column to render, add one `<:col>` element.

    ```elixir
    <:col :let={post} label="Name" field={:name} col_style="width: 20%;">
      <%= post.name %>
    </:col>
    ```

    Any additional assigns will be added as attributes to the `<td>` elements.

    """ do
    attr :label, :any, doc: "The content for the header column."

    attr :field, :atom,
      doc: """
      The field name for sorting. If set and the field is configured as sortable
      in the resource, the column header will be clickable, allowing the user to
      sort by that column. If the field is not marked as sortable or if the
      `field` attribute is omitted or set to `nil` or `false`, the column header
      will not be clickable.
      """

    attr :directions, :any,
      doc: """
      An optional 2-element tuple used for custom ascending and descending sort
      behavior for the column, i.e. `{:asc_nils_last, :desc_nils_first}`
      """

    attr :col_style, :string,
      doc: """
      If set, a `<colgroup>` element is rendered and the value of the
      `col_style` assign is set as `style` attribute for the `<col>` element of
      the respective column. You can set the `width`, `background`, `border`,
      and `visibility` of a column this way.
      """

    attr :col_class, :string,
      doc: """
      If set, a `<colgroup>` element is rendered and the value of the
      `col_class` assign is set as `class` attribute for the `<col>` element of
      the respective column. You can set the `width`, `background`, `border`,
      and `visibility` of a column this way.
      """

    attr :class, :string,
      doc: """
      Additional classes to add to the `<th>` and `<td>` element. Will be merged with the
      `thead_attr_attrs` and `tbody_td_attrs` attributes.
      """

    attr :thead_th_attrs, :list,
      doc: """
      Additional attributes to pass to the `<th>` element as a static keyword
      list. Note that these attributes will override any conflicting
      `thead_th_attrs` that are set at the table level.
      """

    attr :th_wrapper_attrs, :list,
      doc: """
      Additional attributes for the `<span>` element that wraps the
      header link and the order direction symbol. Note that these attributes
      will override any conflicting `th_wrapper_attrs` that are set at the table
      level.
      """

    attr :tbody_td_attrs, :any,
      doc: """
      Additional attributes to pass to the `<td>` element. May be provided as a
      static keyword list, or as a 1-arity function to dynamically generate the
      list using row data. Note that these attributes will override any
      conflicting `tbody_td_attrs` that are set at the table level.
      """
  end

  slot :action,
    doc: """
    The slot for showing user actions in the last table column. These columns
    do not receive the `row_click` attribute.


    ```elixir
    <:action :let={user}>
      <.link navigate={~p"/users/\#{user}"}>Show</.link>
    </:action>
    ```
    """ do
    attr :label, :string, doc: "The content for the header column."

    attr :show, :boolean,
      doc: "Boolean value to conditionally show the column. Defaults to `true`."

    attr :hide, :boolean,
      doc: "Boolean value to conditionally hide the column. Defaults to `false`."

    attr :col_style, :string,
      doc: """
      If set, a `<colgroup>` element is rendered and the value of the
      `col_style` assign is set as `style` attribute for the `<col>` element of
      the respective column. You can set the `width`, `background`, `border`,
      and `visibility` of a column this way.
      """

    attr :col_class, :string,
      doc: """
      If set, a `<colgroup>` element is rendered and the value of the
      `col_class` assign is set as `class` attribute for the `<col>` element of
      the respective column. You can set the `width`, `background`, `border`,
      and `visibility` of a column this way.
      """

    attr :class, :string,
      doc: """
      Additional classes to add to the `<th>` and `<td>` element. Will be merged with the
      `thead_attr_attrs` and `tbody_td_attrs` attributes.
      """

    attr :thead_th_attrs, :list,
      doc: """
      Any additional attributes to pass to the `<th>` as a keyword list.
      """

    attr :tbody_td_attrs, :any,
      doc: """
      Any additional attributes to pass to the `<td>`. Can be a keyword list or
      a function that takes the current row item as an argument and returns a
      keyword list.
      """
  end

  slot :foot,
    doc: """
    You can optionally add a `foot`. The inner block will be rendered inside
    a `tfoot` element.

        <AshPagify.Components.table>
          <:foot>
            <tr><td>Total: <span class="total"><%= @total %></span></td></tr>
          </:foot>
        </AshPagify.Components.table>
    """

  def table_pagify(%{meta: %Meta{}, path: nil, on_sort: nil}) do
    raise PathOrJSError, component: :table
  end

  def table_pagify(%{meta: nil} = assigns) do
    assigns =
      assigns
      |> assign(id: Map.get(assigns, :id, "table"))
      |> assign(meta: %Meta{})
      |> assign(on_sort: %JS{})

    table_pagify(assigns)
  end

  def table_pagify(%{error: true, opts: opts} = assigns) do
    assigns =
      assign(assigns, :opts, Table.merge_opts(opts))

    ~H"""
    {@opts[:error_content]}
    """
  end

  def table_pagify(%{meta: meta, opts: opts} = assigns) do
    assigns =
      assigns
      |> assign(:opts, Table.merge_opts(opts))
      |> assign_new(:id, fn -> table_id(meta.resource) end)

    ~H"""
    <%= if !@loading and empty?(@items) do %>
      {@opts[:no_results_content]}
    <% else %>
      <%= if @opts[:container] do %>
        <div id={@id <> "_container"} {@opts[:container_attrs]}>
          <Table.render
            caption_text={@caption_text}
            caption={@caption}
            col={@col}
            foot={@foot}
            on_sort={@on_sort}
            id={@id}
            items={@items}
            meta={@meta}
            opts={@opts}
            path={@path}
            target={@target}
            row_id={@row_id}
            row_click={@row_click}
            row_item={@row_item}
            action={@action}
            loading={@loading}
          />
        </div>
      <% else %>
        <Table.render
          caption_text={@caption_text}
          caption={@caption}
          col={@col}
          foot={@foot}
          on_sort={@on_sort}
          id={@id}
          items={@items}
          meta={@meta}
          opts={@opts}
          path={@path}
          target={@target}
          row_id={@row_id}
          row_click={@row_click}
          row_item={@row_item}
          action={@action}
          loading={@loading}
        />
      <% end %>
    <% end %>
    """
  end

  defp empty?(items)
  defp empty?([]), do: true
  defp empty?(%Phoenix.LiveView.LiveStream{inserts: [], deletes: []}), do: true
  defp empty?(_), do: false

  defp table_id(nil), do: "sortable_table"

  defp table_id(resource) do
    module_name = resource |> Module.split() |> List.last() |> Macro.underscore()
    module_name <> "_table"
  end

  @doc """
  Converts a AshPagify struct into a keyword list that can be used as a query with
  Phoenix verified routes or route helper functions.

  ## Encoded parameters

  The following parameters are encoded as strings:

  - `:search`
  - `:scopes`
  - `:filter_form`
  - `:order_by`
  - `:limit`
  - `:offset`

  ## Default parameters

  Default parameters for the limit, scopes, filter_form and order parameters
  are omitted. The defaults are determined by calling `AshPagify.Misc.get_option/3`.

  - Pass the `:for` option to pick up the default values from an `Ash.Resource`.
  - If the `Ash.Resource` has no default options set, the function will fall
    back to the application environment.

  ## Encoding queries

  To encode the returned query as a string, you will need to use
  `Plug.Conn.Query.encode/1`. `URI.encode_query/1` does not support bracket
  notation for arrays and maps.

  ## Examples

      iex> to_query(%AshPagify{})
      []

      iex> f = %AshPagify{offset: 40, limit: 20}
      iex> to_query(f)
      [limit: 20, offset: 40]

      iex> f = %AshPagify{offset: 40, limit: 20}
      iex> to_query(f, default_limit: 20)
      [offset: 40]

      iex> f = %AshPagify{order_by: [name: :asc]}
      iex> to_query(f, for: AshPagify.Factory.Post)
      []

      iex> f = %AshPagify{scopes: %{status: :active}}
      iex> to_query(f, for: AshPagify.Factory.Post)
      [scopes: %{status: :active}]

      iex> f = %AshPagify{search: "foo"}
      iex> to_query(f, for: AshPagify.Factory.Post)
      [search: "foo"]

  Encoding the query as a string:

      iex> f = %AshPagify{order_by: [name: :desc, age: :asc]}
      iex> to_query(f)
      [order_by: ["-name", "age"]]
      iex> f |> to_query |> Plug.Conn.Query.encode()
      "order_by[]=-name&order_by[]=age"

      iex> f = %AshPagify{filter_form: %{"field" => "comments_count", "operator" => "gt", "value" => 2}}
      iex> to_query(f)
      [filter_form: %{"field" => "comments_count", "operator" => "gt", "value" => 2}]
      iex> f |> to_query |> Plug.Conn.Query.encode()
      "filter_form[field]=comments_count&filter_form[operator]=gt&filter_form[value]=2"

      iex> f = %AshPagify{scopes: %{status: :active}}
      iex> to_query(f)
      [scopes: %{status: :active}]
      iex> f |> to_query |> Plug.Conn.Query.encode()
      "scopes[status]=active"

      iex> f = %AshPagify{search: "foo"}
      iex> to_query(f)
      [search: "foo"]
      iex> f |> to_query |> Plug.Conn.Query.encode()
      "search=foo"
  """
  @spec to_query(AshPagify.t(), Keyword.t()) :: Keyword.t()
  def to_query(%AshPagify{} = ash_pagify, opts \\ []) do
    default_limit = Misc.get_option(:default_limit, opts)

    default_order = :default_order |> Misc.get_option(opts, nil) |> AshPagify.concat_sort()
    current_order = AshPagify.concat_sort(ash_pagify.order_by)

    []
    |> Misc.maybe_put(:offset, ash_pagify.offset, 0)
    |> Misc.maybe_put(:limit, ash_pagify.limit, default_limit)
    |> Misc.maybe_put(:order_by, current_order, default_order)
    |> Misc.maybe_put(:filter_form, ash_pagify.filter_form)
    |> Misc.maybe_put(:search, ash_pagify.search)
    |> Misc.maybe_put_scopes(ash_pagify, opts)
  end

  @doc """
  Builds a path that includes query parameters for the given `AshPagify` struct
  using the referenced Components path helper function.

  The first argument can be either one of:

  - an MFA tuple (module, function name as atom, arguments)
  - a 2-tuple (function, arguments)
  - a URL string, usually produced with a verified route (e.g. `~p"/some/path"`)
  - a function that takes the AshPagify parameters as a keyword list as an argument

  Default values for `scopes`, `limit` and `order_by` are omitted from the query parameters.
  To pick up the default parameters from an `Ash.Resource`, you need to pass the
  `:for` option. If you pass a `AshPagify.Meta` struct as the second argument,
  these options are retrieved from the struct automatically.

  ## Examples

  ### With a verified route

  The examples below use plain URL strings without the p-sigil, so that the
  doc tests work, but in your application, you can use verified routes or
  anything else that produces a URL.

      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> path = build_path("/posts", ash_pagify)
      iex> %URI{path: parsed_path, query: parsed_query} = URI.parse(path)
      iex> {parsed_path, URI.decode_query(parsed_query)}
      {"/posts", %{"offset" => "20", "limit" => "10"}}

  The AshPagify query parameters will be merged into existing query parameters.

      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> path = build_path("/posts?category=A", ash_pagify)
      iex> %URI{path: parsed_path, query: parsed_query} = URI.parse(path)
      iex> {parsed_path, URI.decode_query(parsed_query)}
      {"/posts", %{"offset" => "20", "limit" => "10", "category" => "A"}}

  ### With an MFA tuple

      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> build_path(
      ...>   {AshPagify.ComponentsTest, :route_helper, [%Plug.Conn{}, :posts]},
      ...>   ash_pagify
      ...> )
      "/posts?limit=10&offset=20"

  ### With a function/arguments tuple

      iex> post_path = fn _conn, :index, query ->
      ...>   "/posts?" <> Plug.Conn.Query.encode(query)
      ...> end
      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> build_path({post_path, [%Plug.Conn{}, :index]}, ash_pagify)
      "/posts?limit=10&offset=20"

  We're defining fake path helpers for the scope of the doctests. In a real
  Phoenix application, you would pass something like
  `{Routes, :post_path, args}` or `{&Routes.post_path/3, args}` as the
  first argument.

  ### Passing a `AshPagify.Meta` struct or a keyword list

  You can also pass a `AshPagify.Meta` struct or a keyword list as the third
  argument.

      iex> post_path = fn _conn, :index, query ->
      ...>   "/posts?" <> Plug.Conn.Query.encode(query)
      ...> end
      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> meta = %AshPagify.Meta{ash_pagify: ash_pagify, resource: AshPagify.Factory.Post}
      iex> build_path({post_path, [%Plug.Conn{}, :index]}, meta)
      "/posts?limit=10&offset=20"
      iex> query_params = to_query(ash_pagify)
      iex> build_path({post_path, [%Plug.Conn{}, :index]}, query_params)
      "/posts?limit=10&offset=20"

  ### Additional path parameters

  If the path helper takes additional path parameters, just add them to the
  second argument.

      iex> user_post_path = fn _conn, :index, id, query ->
      ...>   "/users/\#{id}/posts?" <> Plug.Conn.Query.encode(query)
      ...> end
      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> build_path({user_post_path, [%Plug.Conn{}, :index, 123]}, ash_pagify)
      "/users/123/posts?limit=10&offset=20"

  ### Additional query parameters

  If the last path helper argument is a query parameter list, the AshPagify
  parameters are merged into it.

      iex> post_url = fn _conn, :index, query ->
      ...>   "https://posts.ash_pagify/posts?" <> Plug.Conn.Query.encode(query)
      ...> end
      iex> ash_pagify = %AshPagify{order_by: [name: :desc]}
      iex> build_path({post_url, [%Plug.Conn{}, :index, [user_id: 123]]}, ash_pagify)
      "https://posts.ash_pagify/posts?user_id=123&order_by[]=-name"
      iex> build_path(
      ...>   {post_url,
      ...>    [%Plug.Conn{}, :index, [category: "small", user_id: 123]]},
      ...>   ash_pagify
      ...> )
      "https://posts.ash_pagify/posts?category=small&user_id=123&order_by[]=-name"

  ### Set page as path parameter

  Finally, you can also pass a function that takes the AshPagify parameters as
  a keyword list as an argument. Default values will not be included in the
  parameters passed to the function. You can use this if you need to set some
  of the parameters as path parameters instead of query parameters.

      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> build_path(
      ...>   fn params ->
      ...>     {offset, params} = Keyword.pop(params, :offset)
      ...>     query = Plug.Conn.Query.encode(params)
      ...>     if offset, do: "/posts/page/\#{offset}?\#{query}", else: "/posts?\#{query}"
      ...>   end,
      ...>   ash_pagify
      ...> )
      "/posts/page/20?limit=10"

  Note that in this example, the anonymous function just returns a string. With
  Phoenix 1.7, you will be able to use verified routes.

      build_path(
        fn params ->
          {offset, query} = Keyword.pop(params, :offset)
          if offset, do: ~p"/posts/page/\#{offset}?\#{query}", else: ~p"/posts?\#{query}"
        end,
        ash_pagify
      )

  Note that the keyword list passed to the path builder function is built using
  `Plug.Conn.Query.encode/2`, which means filter_forms are formatted as maps.

  ### Set filter_form value as path parameter
      iex> ash_pagify = %AshPagify{
      ...>   offset: 20,
      ...>   order_by: [:updated_at],
      ...>   filter_form: %{
      ...>     "field" => "author",
      ...>     "operator" => "eq",
      ...>     "value" => "John"
      ...>   }
      ...> }
      iex> build_path(
      ...>   fn params ->
      ...>     {offset, params} = Keyword.pop(params, :offset)
      ...>     filter_form = Keyword.get(params, :filter_form, %{})
      ...>     author = Map.get(filter_form, "value", nil)
      ...>     params = Keyword.put(params, :filter_form, %{})
      ...>     query = Plug.Conn.Query.encode(params)
      ...>
      ...>     case {offset, author} do
      ...>       {nil, nil} -> "/posts?\#{query}"
      ...>       {offset, nil} -> "/posts/page/\#{offset}?\#{query}"
      ...>       {nil, author} -> "/posts/author/\#{author}?\#{query}"
      ...>       {offset, author} -> "/posts/author/\#{author}/page/\#{offset}?\#{query}"
      ...>     end
      ...>   end,
      ...>   ash_pagify
      ...> )
      "/posts/author/John/page/20?order_by[]=updated_at"

  ### If only path is set

  If only the path is set, it is returned as is.

      iex> build_path("/posts", nil)
      "/posts"
  """
  @spec build_path(pagination_path(), Meta.t() | AshPagify.t() | Keyword.t(), Keyword.t()) ::
          String.t()
  def build_path(path, meta_or_ash_pagify_or_params, opts \\ [])

  def build_path(
        path,
        %Meta{ash_pagify: ash_pagify, resource: resource, default_scopes: default_scopes},
        opts
      )
      when is_atom(resource) and resource != nil do
    opts =
      opts
      |> Keyword.put(:for, resource)
      |> Keyword.put(:default_scopes, default_scopes)

    build_path(path, ash_pagify, opts)
  end

  def build_path(path, %AshPagify{} = ash_pagify, opts) do
    build_path(path, to_query(ash_pagify, opts))
  end

  def build_path({module, func, args}, ash_pagify_params, _opts)
      when is_atom(module) and is_atom(func) and is_list(args) and is_list(ash_pagify_params) do
    final_args = build_final_args(args, ash_pagify_params)
    apply(module, func, final_args)
  end

  def build_path({func, args}, ash_pagify_params, _opts)
      when is_function(func) and is_list(args) and is_list(ash_pagify_params) do
    final_args = build_final_args(args, ash_pagify_params)
    apply(func, final_args)
  end

  def build_path(func, ash_pagify_params, _opts)
      when is_function(func, 1) and is_list(ash_pagify_params) do
    func.(ash_pagify_params)
  end

  def build_path(uri, ash_pagify_params, _opts)
      when is_binary(uri) and is_list(ash_pagify_params) do
    ash_pagify_params_map = Map.new(ash_pagify_params)
    build_path(uri, ash_pagify_params_map)
  end

  def build_path(uri, ash_pagify_params, _opts)
      when is_binary(uri) and is_map(ash_pagify_params) do
    uri = URI.parse(uri)

    query =
      (uri.query || "")
      |> Query.decode()
      |> Map.merge(Misc.remove_nil_values(ash_pagify_params))

    query = if query != %{}, do: Query.encode(query)

    uri
    |> Map.put(:query, query)
    |> URI.to_string()
  end

  def build_path(uri, nil, _opts) when is_binary(uri) do
    uri
  end

  defp build_final_args(args, ash_pagify_params) do
    case Enum.reverse(args) do
      [last_arg | rest] when is_list(last_arg) ->
        query_arg = Keyword.merge(last_arg, ash_pagify_params)
        Enum.reverse([query_arg | rest])

      _ ->
        args ++ [ash_pagify_params]
    end
  end

  @doc """
  Wrapper around `build_path/3` that builds a path with the updated scope.

  Examples

      iex> ash_pagify = %AshPagify{offset: 20, limit: 10}
      iex> meta = %AshPagify.Meta{ash_pagify: ash_pagify, resource: AshPagify.Factory.Post}
      iex> build_scope_path("/posts", meta, %{status: :active})
      "/posts?limit=10&scopes[status]=active"
  """
  @spec build_scope_path(pagination_path(), Meta.t() | nil, map(), Keyword.t()) :: String.t()
  def build_scope_path(path, meta, scope, opts \\ [])

  def build_scope_path(
        path,
        %Meta{ash_pagify: ash_pagify, resource: resource, default_scopes: default_scopes},
        scope,
        opts
      )
      when is_atom(resource) and resource != nil do
    opts =
      opts
      |> Keyword.put(:for, resource)
      |> Keyword.put(:default_scopes, default_scopes)

    ash_pagify = AshPagify.set_scope(ash_pagify, scope)

    build_path(path, ash_pagify, opts)
  end

  def build_scope_path(path, nil, scope, opts) do
    build_path(path, [scopes: scope], opts)
  end
end
