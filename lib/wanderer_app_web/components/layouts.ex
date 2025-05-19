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
  attr :enabled, :boolean

  def new_version_banner(assigns) do
    ~H"""
    <div
      id="new-version-banner"
      phx-hook="NewVersionUpdate"
      phx-update="ignore"
      data-version={@app_version}
      data-enabled={Jason.encode!(@enabled)}
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

  def youtube_container(assigns) do
    ~H"""
    <.link
      href="https://www.youtube.com/@wanderer_ltd"
      class="flex flex-col p-4 items-center absolute bottom-52 left-0 gap-2 tooltip tooltip-right text-gray-400 hover:text-white"
    >
      <svg
        width="24px"
        height="24px"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M20.5245 6.00694C20.3025 5.81544 20.0333 5.70603 19.836 5.63863C19.6156 5.56337 19.3637 5.50148 19.0989 5.44892C18.5677 5.34348 17.9037 5.26005 17.1675 5.19491C15.6904 5.06419 13.8392 5 12 5C10.1608 5 8.30956 5.06419 6.83246 5.1949C6.09632 5.26005 5.43231 5.34348 4.9011 5.44891C4.63628 5.50147 4.38443 5.56337 4.16403 5.63863C3.96667 5.70603 3.69746 5.81544 3.47552 6.00694C3.26514 6.18846 3.14612 6.41237 3.07941 6.55976C3.00507 6.724 2.94831 6.90201 2.90314 7.07448C2.81255 7.42043 2.74448 7.83867 2.69272 8.28448C2.58852 9.18195 2.53846 10.299 2.53846 11.409C2.53846 12.5198 2.58859 13.6529 2.69218 14.5835C2.74378 15.047 2.81086 15.4809 2.89786 15.8453C2.97306 16.1603 3.09841 16.5895 3.35221 16.9023C3.58757 17.1925 3.92217 17.324 4.08755 17.3836C4.30223 17.461 4.55045 17.5218 4.80667 17.572C5.32337 17.6733 5.98609 17.7527 6.72664 17.8146C8.2145 17.9389 10.1134 18 12 18C13.8865 18 15.7855 17.9389 17.2733 17.8146C18.0139 17.7527 18.6766 17.6733 19.1933 17.572C19.4495 17.5218 19.6978 17.461 19.9124 17.3836C20.0778 17.324 20.4124 17.1925 20.6478 16.9023C20.9016 16.5895 21.0269 16.1603 21.1021 15.8453C21.1891 15.4809 21.2562 15.047 21.3078 14.5835C21.4114 13.6529 21.4615 12.5198 21.4615 11.409C21.4615 10.299 21.4115 9.18195 21.3073 8.28448C21.2555 7.83868 21.1874 7.42043 21.0969 7.07448C21.0517 6.90201 20.9949 6.72401 20.9206 6.55976C20.8539 6.41236 20.7349 6.18846 20.5245 6.00694Z"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
        <path
          d="M14.5385 11.5L10.0962 14.3578L10.0962 8.64207L14.5385 11.5Z"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </.link>
    """
  end

  def donate_container(assigns) do
    ~H"""
    <.link
      href="https://www.patreon.com/WandererLtd"
      target="_blank"
      class="flex flex-col p-4 items-center absolute bottom-64 left-1 gap-2 tooltip tooltip-right text-gray-400 hover:text-white"
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
