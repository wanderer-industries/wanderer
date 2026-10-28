defmodule WandererAppWeb.Maps.MapSettings.PublicApiTab do
  use WandererAppWeb, :html

  attr :public_api_key, :string, default: nil
  attr :sse_enabled, :boolean, required: true

  def content(assigns) do
    ~H"""
    <div class="p-6">
      <h2 class="mb-4 text-lg font-semibold">Public API</h2>
      <div class="flex w-full flex-col items-start gap-3">
        <input
          :if={@public_api_key}
          class="input input-bordered w-[350px] truncate bg-neutral-800 text-sm text-white"
          readonly
          type="text"
          value={@public_api_key}
        />
        <input
          :if={is_nil(@public_api_key)}
          class="input input-bordered w-[350px] truncate bg-neutral-800 text-sm text-gray-400"
          readonly
          type="text"
          placeholder="No Public API Key yet"
        />
        <div class="flex items-center gap-2">
          <.button type="button" phx-click="generate-map-api-key" class="min-w-[120px]">
            Generate
          </.button>
          <.button
            type="button"
            phx-hook="CopyToClipboard"
            id="copy-map-api-key"
            data-url={@public_api_key}
            disabled={is_nil(@public_api_key)}
          >
            Copy
          </.button>
        </div>
      </div>

      <div class="mt-4 border-t border-stone-700 pt-4">
        <h3 class="mb-3 text-base font-semibold">Server-Sent Events (SSE)</h3>
        <label class="flex cursor-pointer items-center gap-2">
          <input
            type="checkbox"
            class="checkbox checkbox-primary"
            checked={@sse_enabled}
            phx-click="toggle-sse"
          />
          <span>Enable SSE for this map</span>
        </label>
        <p class="mt-2 text-sm text-stone-400">
          When enabled, external clients can subscribe to real-time map events via SSE.
        </p>
      </div>
    </div>
    """
  end
end
