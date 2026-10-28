defmodule WandererAppWeb.Maps.LicenseComponent do
  @moduledoc """
  LiveView component for displaying and managing bot licenses.

  This component is used in the map settings page to:
  - Display license information
  - Copy license key to clipboard
  - Show license status and expiration
  """

  use WandererAppWeb, :live_component
  require Logger

  alias WandererApp.License.LicenseManager

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       show_key: false,
       license: nil,
       loading: true,
       error: nil,
       can_create_license: false,
       license_unavailable_reason: nil
     )}
  end

  @impl true
  def update(%{map_id: map_id} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(loading: true, error: nil)
      |> assign_license_creation_status(map_id)
      |> load_license(map_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_key_visibility", _, socket) do
    {:noreply, assign(socket, show_key: !socket.assigns.show_key)}
  end

  @impl true
  def handle_event("refresh_license", _, socket) do
    {:noreply,
     socket
     |> assign(loading: true, error: nil)
     |> load_license(socket.assigns.map_id)}
  end

  @impl true
  def handle_event("create_license", _, socket) do
    case LicenseManager.create_license_for_map(socket.assigns.map_id) do
      {:ok, license} ->
        {:noreply, assign(socket, license: license, loading: false, error: nil)}

      {:error, :no_active_subscription} ->
        {:noreply,
         assign(socket,
           loading: false,
           can_create_license: false,
           license_unavailable_reason: "An active map subscription is required",
           error: "Cannot create license: Map does not have an active subscription"
         )}

      {:error, reason} ->
        Logger.error("Failed to create license: #{inspect(reason)}")

        {:noreply,
         assign(socket,
           loading: false,
           error: "Failed to create license. Please try again later."
         )}
    end
  end

  defp load_license(socket, map_id) do
    case LicenseManager.get_license_by_map_id(map_id) do
      {:ok, %{license_key: license_key}} ->
        case LicenseManager.validate_license(license_key) do
          {:ok, license} ->
            assign(socket, license: license, loading: false, error: nil)

          {:error, reason} ->
            assign(socket, license: nil, loading: false, error: reason)
        end

      {:error, :license_not_found} ->
        assign(socket, license: nil, loading: false, error: nil)

      {:error, reason} ->
        Logger.error("Failed to load license: #{inspect(reason)}")
        assign(socket, license: nil, loading: false, error: "Failed to load license information")
    end
  end

  defp assign_license_creation_status(socket, map_id) do
    case LicenseManager.license_creation_status(map_id) do
      :ok ->
        assign(socket, can_create_license: true, license_unavailable_reason: nil)

      {:error, :no_active_subscription} ->
        assign(socket,
          can_create_license: false,
          license_unavailable_reason: "An active map subscription is required"
        )
    end
  end

  defp license_status_class(true), do: "mt-1 text-green-300/85"
  defp license_status_class(false), do: "mt-1 text-rose-300/85"

  defp license_expiration(nil), do: "Never"
  defp license_expiration(expire_at), do: Calendar.strftime(expire_at, "%Y-%m-%d")

  @impl true
  def render(assigns) do
    ~H"""
    <section class="license-info rounded-sm border border-neutral-700/80 bg-neutral-900/30 p-4">
      <div>
        <h3 class="text-sm font-medium text-neutral-200">Map license</h3>
        <p class="mt-1 text-sm leading-5 text-neutral-500">
          Manage the license used by bot integrations for this map.
        </p>
      </div>

      <div :if={@loading} class="mt-4 flex justify-center border-t border-neutral-700/80 py-8">
        <div class="h-6 w-6 animate-spin rounded-full border-2 border-neutral-700 border-t-sky-400">
        </div>
      </div>

      <div :if={not @loading} class="mt-4 border-t border-neutral-700/80 pt-4">
        <div
          :if={@error}
          class="mb-4 flex items-start gap-2 rounded-sm border border-rose-800/30 bg-rose-950/15 px-3 py-2 text-xs leading-5 text-rose-200/80"
        >
          <.icon name="hero-exclamation-circle-solid" class="mt-0.5 h-4 w-4 shrink-0" />
          <p>{@error}</p>
        </div>

        <div :if={@license}>
          <label class="mb-1.5 block text-xs text-neutral-400">License key</label>
          <div class="flex h-9 overflow-hidden rounded-sm border border-neutral-700 bg-neutral-950/60">
            <span class="min-w-0 flex-1 truncate px-3 py-2 font-mono text-sm text-neutral-200">
              {if @show_key, do: @license.license_key, else: String.duplicate("*", 16)}
            </span>
            <button
              type="button"
              phx-click="toggle_key_visibility"
              phx-target={@myself}
              title={if @show_key, do: "Hide license key", else: "Show license key"}
              aria-label={if @show_key, do: "Hide license key", else: "Show license key"}
              class="inline-flex h-full w-9 shrink-0 items-center justify-center border-l border-neutral-700 text-neutral-400 transition-colors hover:bg-neutral-800 hover:text-sky-300"
            >
              <.icon
                name={if @show_key, do: "hero-eye-slash-solid", else: "hero-eye-solid"}
                class="h-4 w-4"
              />
            </button>
            <button
              type="button"
              phx-hook="CopyToClipboard"
              id="copy-key"
              class="copy-link inline-flex h-full w-9 shrink-0 items-center justify-center border-l border-neutral-700 text-neutral-400 transition-colors hover:bg-neutral-800 hover:text-sky-300"
              data-url={@license.license_key}
              title="Copy license key"
              aria-label="Copy license key"
            >
              <.icon name="hero-clipboard-document-solid" class="h-4 w-4" />
            </button>
            <button
              type="button"
              phx-click="refresh_license"
              phx-target={@myself}
              title="Refresh license"
              aria-label="Refresh license"
              class="inline-flex h-full w-9 shrink-0 items-center justify-center border-l border-neutral-700 text-neutral-400 transition-colors hover:bg-neutral-800 hover:text-sky-300"
            >
              <.icon name="hero-arrow-path-solid" class="h-4 w-4" />
            </button>
          </div>

          <div class="mt-4 grid gap-3 text-sm sm:grid-cols-2">
            <div class="rounded-sm bg-neutral-950/30 px-3 py-2">
              <span class="text-neutral-500">Status</span>
              <p class={license_status_class(@license.is_valid)}>
                {if @license.is_valid, do: "Active", else: "Inactive"}
              </p>
            </div>
            <div class="rounded-sm bg-neutral-950/30 px-3 py-2">
              <span class="text-neutral-500">Expires</span>
              <p class="mt-1 text-neutral-300">
                {license_expiration(@license.expire_at)}
              </p>
            </div>
          </div>

          <p class="mt-4 text-sm leading-5 text-neutral-500">
            Keep this key secure and do not share it with unauthorized users.
          </p>
        </div>

        <div :if={is_nil(@license)}>
          <div class="flex items-center justify-between gap-6">
            <div class="min-w-0">
              <p class="text-sm font-medium text-neutral-300">No license has been created</p>
              <p class="mt-1 text-sm leading-5 text-neutral-500">
                Create a license to connect bot integrations to this map.
              </p>
            </div>

            <.button
              type="button"
              phx-click="create_license"
              phx-target={@myself}
              disabled={not @can_create_license}
              class="inline-flex shrink-0 items-center justify-center gap-2 !rounded-sm !px-4 !py-2"
            >
              <.icon name="hero-plus-solid" class="h-4 w-4 shrink-0" />
              <span>Create license</span>
            </.button>
          </div>

          <div
            :if={not @can_create_license}
            class="mt-3 flex items-start gap-2 rounded-sm border border-amber-800/30 bg-amber-950/15 px-3 py-2 text-xs leading-5 text-amber-200/75"
          >
            <.icon name="hero-lock-closed-solid" class="mt-0.5 h-4 w-4 shrink-0" />
            <span>{@license_unavailable_reason}.</span>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
