defmodule WandererAppWeb.Maps.MapSettings.BotsTab do
  use WandererAppWeb, :html

  attr :map_id, :string, required: true

  def content(assigns) do
    ~H"""
    <h3 class="mb-2 text-lg font-semibold">Bots Integration</h3>
    <div class="mb-6 rounded-md border p-4">
      <p class="mb-2">
        The bot license allows you to integrate your map with automated tools and bots.
        Here's how to use it:
      </p>
      <ol class="mb-4 list-decimal space-y-2 pl-5">
        <li>Create a license key below (requires an active subscription)</li>
        <li>Use the license key to authenticate your bot with our API</li>
      </ol>
      <p class="text-sm text-gray-600">
        For detailed API documentation, please refer to our <a
          href="/license"
          class="text-blue-600 hover:underline"
        >API documentation</a>.
      </p>
    </div>

    <.live_component
      module={WandererAppWeb.Maps.LicenseComponent}
      id="license-component"
      map_id={@map_id}
    />
    """
  end
end
