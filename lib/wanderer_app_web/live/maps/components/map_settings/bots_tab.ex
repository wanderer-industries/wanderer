defmodule WandererAppWeb.Maps.MapSettings.BotsTab do
  use WandererAppWeb, :html

  attr :map_id, :string, required: true

  def content(assigns) do
    ~H"""
    <div class="space-y-4">
      <section class="rounded-sm border border-neutral-700/80 bg-neutral-900/30 p-4">
        <div class="flex items-start gap-3">
          <.icon name="hero-puzzle-piece-solid" class="mt-0.5 h-5 w-5 shrink-0 text-sky-400/80" />
          <div class="min-w-0">
            <h2 class="text-sm font-medium text-neutral-200">Bots integration</h2>
            <p class="mt-1 text-sm leading-5 text-neutral-500">
              Connect automated tools and bots to this map using a dedicated license key.
            </p>
          </div>
        </div>

        <ol class="mt-4 grid gap-3 border-t border-neutral-700/80 pt-4 sm:grid-cols-2">
          <li class="flex items-start gap-3 text-sm text-neutral-400">
            <span class="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full border border-neutral-600 text-xs text-neutral-300">
              1
            </span>
            <span>Create a license for a map with an active subscription.</span>
          </li>
          <li class="flex items-start gap-3 text-sm text-neutral-400">
            <span class="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full border border-neutral-600 text-xs text-neutral-300">
              2
            </span>
            <span>Use the license key to authenticate your bot with the API.</span>
          </li>
        </ol>

        <p class="mt-4 text-sm text-neutral-500">
          Read the
          <a href="/license" class="text-sky-400/85 hover:text-sky-300 hover:underline">
            API documentation
          </a>
          for integration details.
        </p>
      </section>

      <.live_component
        module={WandererAppWeb.Maps.LicenseComponent}
        id="license-component"
        map_id={@map_id}
      />
    </div>
    """
  end
end
