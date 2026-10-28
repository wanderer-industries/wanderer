defmodule WandererAppWeb.Maps.MapSettings.PublicApiTab do
  use WandererAppWeb, :html

  attr :public_api_key, :string, default: nil
  attr :sse_enabled, :boolean, required: true
  attr :sse_can_enable, :boolean, required: true
  attr :sse_unavailable_reason, :string, default: nil

  def content(assigns) do
    ~H"""
    <div class="space-y-4">
      <section class="rounded-sm border border-neutral-700/80 bg-neutral-900/30 p-4">
        <div class="flex items-start justify-between gap-6">
          <div class="min-w-0">
            <h2 class="text-sm font-medium text-neutral-200">Public API key</h2>
            <p class="mt-1 text-sm leading-5 text-neutral-500">
              Use this key to authenticate requests to this map's public API.
            </p>
          </div>

          <.button
            type="button"
            phx-click="generate-map-api-key"
            class="inline-flex shrink-0 items-center justify-center gap-2 !rounded-sm !px-4 !py-2"
          >
            <.icon name="hero-key-solid" class="h-4 w-4 shrink-0" />
            <span>Generate</span>
          </.button>
        </div>

        <div class="mt-4">
          <label for="public-api-key" class="mb-1.5 block text-xs text-neutral-400">API key</label>
          <div class="flex h-9 overflow-hidden rounded-sm border border-neutral-700 bg-neutral-950/60 transition-colors focus-within:border-sky-500">
            <input
              id="public-api-key"
              class={[
                "min-w-0 flex-1 truncate bg-transparent px-3 font-mono text-sm outline-none",
                if(@public_api_key, do: "text-neutral-200", else: "text-neutral-500")
              ]}
              readonly
              type="text"
              value={@public_api_key}
              placeholder="No public API key generated"
            />
            <button
              type="button"
              phx-hook="CopyToClipboard"
              id="copy-map-api-key"
              data-url={@public_api_key}
              disabled={is_nil(@public_api_key)}
              title="Copy API key"
              aria-label="Copy API key"
              class="copy-link inline-flex h-full w-9 shrink-0 items-center justify-center border-l border-neutral-700 text-neutral-400 transition-colors hover:bg-neutral-800 hover:text-sky-300 disabled:cursor-not-allowed disabled:text-neutral-700"
            >
              <.icon name="hero-clipboard-document-solid" class="h-4 w-4" />
            </button>
          </div>
        </div>
      </section>

      <section class="rounded-sm border border-neutral-700/80 bg-neutral-900/30 p-4">
        <div>
          <h3 class="text-sm font-medium text-neutral-200">Server-Sent Events (SSE)</h3>
          <p class="mt-1 text-sm leading-5 text-neutral-500">
            Allow external clients to subscribe to real-time map events.
          </p>
        </div>

        <div class={[
          "mt-3 border-t border-neutral-700/80 pt-1",
          (not @sse_enabled and not @sse_can_enable) && "opacity-60"
        ]}>
          <.input
            id="map-sse-enabled"
            name="sse_enabled"
            type="checkbox"
            label="Enable SSE for this map"
            checked={@sse_enabled}
            disabled={not @sse_enabled and not @sse_can_enable}
            phx-click="toggle-sse"
          />
        </div>

        <div
          :if={not @sse_can_enable}
          class="mt-2 flex items-start gap-2 rounded-sm border border-amber-800/30 bg-amber-950/15 px-3 py-2 text-xs leading-5 text-amber-200/75"
        >
          <.icon name="hero-lock-closed-solid" class="mt-0.5 h-4 w-4 shrink-0" />
          <span>{@sse_unavailable_reason}.</span>
        </div>
      </section>
    </div>
    """
  end
end
