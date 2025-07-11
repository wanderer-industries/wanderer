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
    {:ok, assign(socket, show_key: false, license: nil, loading: true, error: nil)}
  end

  @impl true
  def update(%{map_id: map_id} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(loading: true, error: nil)
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="license-info">
      <h3 class="text-lg font-semibold mb-4">Map License</h3>

      <%= if @loading do %>
        <div class="flex justify-center py-4">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      <% else %>
        <%= if @error do %>
          <div class="border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            <p>{@error}</p>
          </div>
        <% end %>

        <%= if @license do %>
          <div class="mt-4 p-4 border rounded-md">
            <div class="flex justify-between items-center">
              <div class="flex items-center gap-2">
                <span class="font-medium">License Key:</span>
                <span class="font-mono bg-gray-800 px-2 py-1 rounded">
                  {if @show_key,
                    do: @license.license_key,
                    else: "••••••••••••••••"}
                </span>
                <button
                  type="button"
                  phx-click="toggle_key_visibility"
                  phx-target={@myself}
                  class="ml-2 btn"
                >
                  {if @show_key, do: "Hide", else: "Show"}
                </button>
                <.button
                  phx-hook="CopyToClipboard"
                  id="copy-key"
                  class="copy-link btn"
                  data-url={@license.license_key}
                >
                  Copy
                  <div class="absolute w-[100px] !mr-[-170px] link-copied hidden">
                    Key copied
                  </div>
                </.button>
                <button
                  type="button"
                  phx-click="refresh_license"
                  phx-target={@myself}
                  class="ml-2 btn"
                >
                  Refresh
                </button>
              </div>
            </div>

            <div class="mt-3 grid grid-cols-2 gap-2">
              <div>
                <span class="font-medium">Status:</span>
                <span class={(@license.is_valid && "text-green-600") || "text-red-600"}>
                  {(@license.is_valid && "Active") || "Inactive"}
                </span>
              </div>

              <div>
                <span class="font-medium">Expires:</span>
                <span>
                  <%= if @license.expire_at do %>
                    {Calendar.strftime(@license.expire_at, "%Y-%m-%d")}
                  <% else %>
                    Never
                  <% end %>
                </span>
              </div>
            </div>

            <div class="mt-4 text-sm text-gray-600">
              <p>
                This license key allows you to use bot functionality with your map. Keep it secure and do not share it with unauthorized users.
              </p>
            </div>
          </div>
        <% else %>
          <div class="mt-4 p-4 border rounded-md">
            <p class="mb-4">No license found for this map.</p>

            <button
              type="button"
              phx-click="create_license"
              phx-target={@myself}
              class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded"
            >
              Create License
            </button>

            <div class="mt-4 text-sm text-gray-600">
              <p>
                A license is required to use bot functionality with your map. Creating a license requires an active map subscription.
              </p>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
