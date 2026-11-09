defmodule WandererAppWeb.Maps.MapCardVariants do
  use WandererAppWeb, :html

  @scope_order [:wormholes, :hi, :low, :null, :pochven]
  @scope_images %{
    wormholes:
      "https://wanderer-industries.github.io/wanderer-assets/images/map-scope-cards/wormholes.jpg",
    hi:
      "https://wanderer-industries.github.io/wanderer-assets/images/map-scope-cards/high-sec.webp",
    low:
      "https://wanderer-industries.github.io/wanderer-assets/images/map-scope-cards/low-sec.webp",
    null:
      "https://wanderer-industries.github.io/wanderer-assets/images/map-scope-cards/null-sec.webp",
    pochven:
      "https://wanderer-industries.github.io/wanderer-assets/images/map-scope-cards/pochven.webp"
  }
  @scope_labels %{
    wormholes: "Wormholes",
    hi: "High-Sec",
    low: "Low-Sec",
    null: "Null-Sec",
    pochven: "Pochven"
  }

  attr :map, :any, required: true
  attr :current_user, :any, required: true
  attr :index, :integer, required: true

  def card(assigns) do
    display_scopes = effective_scopes(assigns.map)

    assigns =
      assigns
      |> assign(:display_scopes, display_scopes)
      |> assign(:number, format_card_number(assigns.index))
      |> assign(:scopes_path, scopes_path(display_scopes))

    ~H"""
    <section class="min-w-0">
      <div class="mb-2 flex h-5 items-center gap-2 text-[10px] font-medium uppercase tracking-[0.16em]">
        <span class="text-orange-200">{@number}</span>
        <span class="min-w-0 truncate text-neutral-300" title={@scopes_path}>
          {@scopes_path}
        </span>
        <span class="h-px min-w-4 flex-1 bg-neutral-800" />
      </div>

      <article class="map-card-border-pulse group flex h-56 overflow-hidden rounded border border-dashed border-orange-300/45 bg-neutral-950 shadow-sm shadow-black/30">
        <.map_image
          scopes={@display_scopes}
          class="w-36 shrink-0 border-r border-dashed border-orange-300/35"
          mosaic
        />
        <div class="flex min-w-0 flex-1 flex-col">
          <div class="flex min-h-0 flex-1 flex-col justify-between px-4 py-3">
            <div>
              <.card_heading map={@map} />
              <p
                class="mt-1.5 line-clamp-2 text-xs leading-5 text-neutral-500"
                title={@map.description}
              >
                {@map.description}
              </p>
            </div>
            <.acl_tags map={@map} current_user={@current_user} limit={5} wrap />
          </div>
          <div class="flex h-11 items-center justify-between border-t border-dashed border-orange-300/35 bg-orange-300/[0.04] px-3">
            <.active_count map={@map} />
            <.map_actions
              map={@map}
              current_user={@current_user}
              prefix={"map-card-#{@index}"}
              compact
              borderless
            />
          </div>
        </div>
      </article>
    </section>
    """
  end

  attr :scopes, :list, default: []
  attr :class, :string, default: nil
  attr :gradient, :string, default: "right"
  attr :mosaic, :boolean, default: false

  def map_image(assigns) do
    assigns = assign(assigns, :scope_count, length(assigns.scopes))

    ~H"""
    <div class={["relative overflow-hidden bg-black", @class]}>
      <div
        :if={@mosaic and @scopes != []}
        class={["absolute inset-0 grid", scope_mosaic_class(@scope_count)]}
      >
        <div
          :for={{scope, index} <- Enum.with_index(@scopes)}
          class={[
            "relative min-h-0 min-w-0 overflow-hidden ring-1 ring-inset ring-black/60",
            scope_mosaic_tile_class(@scope_count, index)
          ]}
        >
          <img
            src={scope_image(scope)}
            alt=""
            loading="lazy"
            class={[
              "absolute inset-0 h-full w-full transition duration-300 group-hover:brightness-110",
              scope_image_fit(scope),
              scope_image_position(scope)
            ]}
          />
        </div>
      </div>
      <div :if={not @mosaic and @scopes != []} class="absolute inset-0 flex">
        <div
          :for={scope <- @scopes}
          class="relative min-w-0 flex-1 overflow-hidden border-r border-black/60 last:border-r-0"
        >
          <img
            src={scope_image(scope)}
            alt=""
            loading="lazy"
            class={[
              "absolute inset-0 h-full w-full transition duration-300 group-hover:brightness-110",
              scope_image_fit(scope),
              scope_image_position(scope)
            ]}
          />
        </div>
      </div>
      <div
        :if={@scopes == []}
        class="absolute inset-0 bg-gradient-to-br from-neutral-900 via-black to-neutral-950"
      />
      <span class={[
        "absolute inset-0",
        @gradient == "right" && "bg-gradient-to-r from-black/5 to-neutral-900/80",
        @gradient == "left" && "bg-gradient-to-l from-black/5 to-neutral-900/80",
        @gradient == "poster" &&
          "bg-gradient-to-b from-black/10 via-black/25 to-neutral-950/95",
        @gradient == "panoramic" &&
          "bg-gradient-to-r from-neutral-950/95 via-neutral-950/65 to-black/20"
      ]} />
    </div>
    """
  end

  attr :map, :any, required: true

  def card_heading(assigns) do
    ~H"""
    <div class="flex min-w-0 items-center gap-2">
      <.link
        navigate={~p"/#{@map.slug}"}
        class="block min-w-0 flex-1 truncate text-base font-semibold text-neutral-100 hover:text-orange-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-orange-300"
        title={@map.name}
      >
        {@map.name}
      </.link>
      <.link
        navigate={~p"/#{@map.slug}"}
        class={action_class(false, :open)}
        aria-label={"Open #{@map.name}"}
        title="Open map"
      >
        <.icon name="hero-arrow-top-right-on-square-solid" class="size-3.5" />
      </.link>
    </div>
    """
  end

  attr :map, :any, required: true
  attr :current_user, :any, required: true
  attr :limit, :integer, default: 2
  attr :class, :string, default: nil
  attr :wrap, :boolean, default: false

  def acl_tags(assigns) do
    acl_count = length(assigns.map.acls)
    visible_limit = if acl_count <= assigns.limit + 1, do: acl_count, else: assigns.limit

    assigns =
      assigns
      |> assign(:visible_limit, visible_limit)
      |> assign(:hidden_count, acl_count - visible_limit)

    ~H"""
    <div
      :if={WandererApp.Maps.can_view_acls?(@map, @current_user)}
      class={[
        "flex min-w-0 gap-1.5 overflow-hidden",
        @wrap && "flex-wrap content-start",
        @class
      ]}
    >
      <span :if={@map.acls == []} class="text-xs text-neutral-500">No access lists</span>
      <button
        :for={acl <- Enum.take(@map.acls, @visible_limit)}
        type="button"
        phx-click="open_acl"
        phx-value-data={acl.id}
        class="max-w-28 truncate border border-neutral-700 bg-neutral-950/60 px-1.5 py-0.5 text-left text-[11px] text-neutral-300 transition-colors hover:border-orange-300/50 hover:bg-orange-300/10 hover:text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-orange-300"
        title={acl.name}
      >
        {acl.name}
      </button>
      <span
        :if={@hidden_count > 0}
        class="border border-neutral-700 bg-neutral-950/60 px-1.5 py-0.5 text-[11px] text-neutral-300"
      >
        +{@hidden_count}
      </span>
    </div>
    """
  end

  attr :map, :any, required: true

  def active_count(assigns) do
    assigns =
      assigns
      |> assign(:formatted_count, format_active_count(assigns.map.characters_count))
      |> assign(
        :has_active_characters,
        is_integer(assigns.map.characters_count) and assigns.map.characters_count > 0
      )

    ~H"""
    <span
      class={[
        "inline-flex h-7 items-center text-[10px] font-medium tracking-[0.16em]",
        @has_active_characters && "text-orange-200",
        not @has_active_characters && "text-neutral-500"
      ]}
      title={"#{@map.characters_count} active characters"}
    >
      {@formatted_count}
    </span>
    """
  end

  attr :map, :any, required: true
  attr :class, :string, default: nil
  attr :compact, :boolean, default: false

  def scope_path(assigns) do
    scopes = effective_scopes(assigns.map)

    scopes_path =
      if assigns.compact do
        compact_scopes_path(scopes)
      else
        scopes_path(scopes)
      end

    assigns = assign(assigns, :scopes_path, scopes_path)

    ~H"""
    <span class={@class} title={@scopes_path}>{@scopes_path}</span>
    """
  end

  attr :map, :any, required: true
  attr :current_user, :any, required: true
  attr :prefix, :string, required: true
  attr :compact, :boolean, default: false
  attr :dashed, :boolean, default: false
  attr :borderless, :boolean, default: false

  def map_actions(assigns) do
    ~H"""
    <div class={[
      "flex items-center",
      not @borderless && "bg-neutral-950/60",
      @borderless && "bg-transparent",
      @compact && "h-7",
      not @compact && "h-8",
      @dashed && not @borderless && "border border-dashed border-orange-300/35",
      not @dashed && not @borderless && "border border-neutral-700"
    ]}>
      <button
        :if={WandererApp.Maps.can_edit?(@map, @current_user)}
        id={"#{@prefix}-characters-#{@map.slug}"}
        type="button"
        phx-hook="MapAction"
        data-event="open_characters"
        data-data={@map.slug}
        class={action_class(@compact, :default)}
        aria-label={"Open characters for #{@map.name}"}
        title="Open characters"
      >
        <.icon name="hero-user-group-solid" class="size-3.5" />
      </button>
      <button
        :if={WandererApp.Maps.can_edit?(@map, @current_user)}
        id={"#{@prefix}-audit-#{@map.slug}"}
        type="button"
        phx-hook="MapAction"
        data-event="open_audit"
        data-data={@map.slug}
        class={action_class(@compact, :default)}
        aria-label={"Open access audit for #{@map.name}"}
        title="Access audit"
      >
        <.icon name="hero-key-solid" class="size-3.5" />
      </button>
      <button
        :if={WandererApp.Maps.can_edit?(@map, @current_user)}
        id={"#{@prefix}-settings-#{@map.slug}"}
        type="button"
        phx-hook="MapAction"
        data-event="open_settings"
        data-data={@map.slug}
        class={action_class(@compact, :default)}
        aria-label={"Settings for #{@map.name}"}
        title="Map settings"
      >
        <.icon name="hero-cog-6-tooth-solid" class="size-3.5" />
      </button>
      <button
        :if={WandererApp.Maps.can_edit?(@map, @current_user)}
        id={"#{@prefix}-delete-#{@map.slug}"}
        type="button"
        phx-hook="MapAction"
        data-event="delete"
        data-data={@map.slug}
        data-confirm="Please confirm to delete map!"
        class={action_class(@compact, :delete)}
        aria-label={"Delete #{@map.name}"}
        title="Delete map"
      >
        <.icon name="hero-trash-solid" class="size-3.5" />
      </button>
    </div>
    """
  end

  defp effective_scopes(%{scopes: scopes}) when is_list(scopes) and scopes != [] do
    ordered_scopes(scopes)
  end

  defp effective_scopes(%{scope: scope}) do
    scope
    |> legacy_scope_to_scopes()
    |> ordered_scopes()
  end

  defp effective_scopes(_map), do: [:wormholes]

  defp scope_mosaic_class(1), do: "grid-cols-1 grid-rows-1"
  defp scope_mosaic_class(2), do: "grid-cols-1 grid-rows-2"
  defp scope_mosaic_class(3), do: "grid-cols-2 grid-rows-[2fr_3fr]"
  defp scope_mosaic_class(4), do: "grid-cols-2 grid-rows-2"
  defp scope_mosaic_class(5), do: "grid-cols-2 grid-rows-[4fr_3fr_3fr]"
  defp scope_mosaic_class(_scope_count), do: "grid-cols-1 grid-rows-1"

  defp scope_mosaic_tile_class(3, 0), do: "col-span-2"
  defp scope_mosaic_tile_class(5, 0), do: "col-span-2"
  defp scope_mosaic_tile_class(_scope_count, _index), do: nil

  defp legacy_scope_to_scopes(:wormholes), do: [:wormholes]
  defp legacy_scope_to_scopes(:stargates), do: [:hi, :low, :null]
  defp legacy_scope_to_scopes(:all), do: @scope_order
  defp legacy_scope_to_scopes(:none), do: []
  defp legacy_scope_to_scopes(_scope), do: [:wormholes]

  defp ordered_scopes(scopes), do: Enum.filter(@scope_order, &(&1 in scopes))

  defp scope_label(scope), do: Map.get(@scope_labels, scope, "Unknown")
  defp scope_image(scope), do: Map.get(@scope_images, scope, "/images/all_back.webp")

  defp scope_image_fit(_scope), do: "object-cover"
  defp scope_image_position(:hi), do: "object-[43%_center]"
  defp scope_image_position(:pochven), do: "object-[68%_center]"
  defp scope_image_position(_scope), do: "object-center"

  defp scopes_path([]), do: "No scope"
  defp scopes_path(scopes), do: Enum.map_join(scopes, " / ", &scope_label/1)

  defp compact_scopes_path([]), do: "—"
  defp compact_scopes_path(scopes), do: Enum.map_join(scopes, " / ", &scope_abbreviation/1)

  defp scope_abbreviation(:wormholes), do: "WH"
  defp scope_abbreviation(:hi), do: "HS"
  defp scope_abbreviation(:low), do: "LS"
  defp scope_abbreviation(:null), do: "NS"
  defp scope_abbreviation(:pochven), do: "P"
  defp scope_abbreviation(_scope), do: "?"

  defp format_card_number(index) do
    index
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp format_active_count(count) when is_integer(count) do
    count
    |> Integer.to_string()
    |> String.pad_leading(3, "0")
  end

  defp format_active_count(_count), do: "000"

  defp action_class(compact, type) do
    size_class = if compact, do: "size-6", else: "size-7"

    color_class =
      case type do
        :open -> "text-orange-200 hover:bg-orange-300/15 hover:text-orange-100"
        :delete -> "text-neutral-300 hover:bg-red-400/15 hover:text-red-300"
        :default -> "text-neutral-300 hover:bg-white/[0.08] hover:text-white"
      end

    [
      "flex items-center justify-center transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-orange-300",
      size_class,
      color_class
    ]
  end
end
