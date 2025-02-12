defmodule WandererAppWeb.Layouts do
  use WandererAppWeb, :html

  embed_templates "layouts/*"

  attr :rtt_class, :string

  def ping_container(assigns) do
    ~H"""
    <div
      id="ping-container"
      class={[
        "flex flex-col p-4 items-center absolute bottom-28 left-1 gap-2 tooltip tooltip-right text-gray-400 hover:text-white",
        @rtt_class
      ]}
      phx-hook="Ping"
      phx-update="ignore"
    >
      <.icon name="hero-wifi-solid" class="h-4 w-4" />
    </div>
    """
  end

  attr :app_version, :string

  def new_version_banner(assigns) do
    ~H"""
    <div
      id="new-version-banner"
      phx-hook="NewVersionUpdate"
      phx-update="ignore"
      data-version={@app_version}
      class="!z-1000 hidden absolute top-0 left-0 w-full h-full group items-center fade-in-scale text-white !bg-opacity-70 rounded p-px overflow-hidden flex items-center"
    >
      <div class="hs-overlay-backdrop transition duration absolute left-0 top-0 w-full h-full bg-gray-900 bg-opacity-50 dark:bg-opacity-80 dark:bg-neutral-900">
      </div>
      <div class="absolute top-[50%] left-[50%] translate-x-[-50%] translate-y-[-50%] flex items-center">
        <div class="rounded w-9 h-9 w-[80px] h-[66px] flex items-center justify-center relative z-20">
          <.icon name="hero-chevron-double-right" class="w-9 h-9 mr-[-40px]" />
        </div>
        <div id="refresh-area">
          <.live_component module={WandererAppWeb.MapRefresh} id="map-refresh" />
        </div>

        <div class="rounded h-[66px] flex items-center justify-center relative z-20">
          <div class=" flex items-center w-[200px] h-full">
            <.icon name="hero-chevron-double-left" class="w-9 h-9 mr-[20px]" />
            <div class=" flex flex-col items-center justify-center h-full">
              <div class="text-white text-nowrap text-sm [text-shadow:_0_1px_0_rgb(0_0_0_/_40%)]">
                Update Required
              </div>
              <a
                href="/changelog"
                target="_blank"
                class="text-sm link-secondary [text-shadow:_0_1px_0_rgb(0_0_0_/_40%)]"
              >
                What's new?
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def donate_container(assigns) do
    ~H"""
    <.link
      href="https://www.patreon.com/WandererLtd"
      target="_blank"
      class="flex flex-col p-4 items-center absolute bottom-52 left-1 gap-2 tooltip tooltip-right text-gray-400 hover:text-white"
    >
      <.icon name="hero-banknotes-solid" class="h-4 w-4" />
    </.link>
    """
  end

  def feedback_container(assigns) do
    ~H"""
    <.link
      href="https://discord.gg/cafERvDD2k"
      class="flex flex-col p-4 items-center absolute bottom-40 left-1 gap-2 tooltip tooltip-right text-gray-400 hover:text-white"
    >
      <.icon name="hero-hand-thumb-up-solid" class="h-4 w-4" />
    </.link>
    """
  end

  attr :id, :string
  attr :active_tab, :atom
  attr :show_admin, :boolean
  attr :map_subscriptions_enabled, :boolean

  def sidebar_nav_links(assigns) do
    ~H"""
    <ul class="text-center flex flex-col w-full">
      <div class="dropdown dropdown-right">
        <div tabindex="0" role="button">
          <li class="flex-1 w-full h-14 block text-gray-400 hover:text-white p-3">
            <.icon name="hero-bars-3-solid" class="w-6 h-6" />
          </li>
        </div>
        <ul
          tabindex="0"
          class="menu menu-sm dropdown-content bg-base-100 rounded-box z-[1] mt-3 w-52 p-2 shadow"
        >
          <li><a href="/changelog">Changelog</a></li>
          <li><a href="/news">News</a></li>
          <li><a href="/license">License</a></li>
          <li><a href="/contacts">Contact Us</a></li>
        </ul>
      </div>

      <.nav_link
        href="/last"
        active={@active_tab == :map}
        icon="hero-viewfinder-circle-solid"
        tip="Map"
      />
      <.nav_link href="/maps" active={@active_tab == :maps} icon="hero-map-solid" tip="Maps" />
      <.nav_link
        href="/access-lists"
        active={@active_tab == :access_lists}
        icon="hero-user-group-solid"
        tip="Access Lists"
      />
      <.nav_link
        href="/characters"
        active={@active_tab == :characters}
        icon="hero-user-plus-solid"
        tip="Characters"
      />
      <.nav_link
        href="/tracking"
        active={@active_tab == :characters_tracking}
        icon="hero-signal-solid"
        tip="Characters Tracking"
      />

      <div class="absolute bottom-0 left-0 border-t border-gray-600 dropdown dropdown-right dropdown-end">
        <div tabindex="0" role="button" class="h-full w-full text-gray-400 hover:text-white block p-4">
          <.icon name="hero-user-solid" class="w-6 h-6" />
        </div>
        <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow">
          <li :if={@show_admin}>
            <.link navigate="/admin">
              Admin
            </.link>
          </li>
          <li :if={@show_admin}>
            <.link navigate="/admin/errors">
              Errors
            </.link>
          </li>
          <li :if={@map_subscriptions_enabled}>
            <.link navigate="/profile">
              Profile
            </.link>
          </li>
          <li>
            <.link navigate="/auth/signout">
              Logout
            </.link>
          </li>
        </ul>
      </div>
    </ul>
    """
  end

  attr :href, :string
  attr :active, :boolean, default: false
  attr :class, :string, default: ""
  attr :icon, :string
  attr :tip, :string

  defp nav_link(assigns) do
    ~H"""
    <li class={["flex-1 w-full ", @class]}>
      <div class="tooltip tooltip-right" data-tip={@tip}>
        <.link
          navigate={@href}
          class={[
            "h-full w-full text-gray-400 hover:text-white block p-3",
            classes("border-r-4 text-white border-r-orange-400": @active)
          ]}
          aria-current={if @active, do: "true", else: "false"}
        >
          <.icon name={@icon} class="w-6 h-6" />
        </.link>
      </div>
    </li>
    """
  end
end
