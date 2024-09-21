defmodule WandererAppWeb.Alerts do
  @moduledoc """
  Component that shows alerts.
  """
  use WandererAppWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     # this function will look and `push_event()` for each existing flash type
     |> trigger_fade_out_flashes(assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div role="alert" data-handle-fadeout-flash={delayed_fade_out_flash()} phx-value-key="info">
        <.flash id="client-info" kind={:info} title="Info!" flash={@view_flash} />
      </div>
      <div role="alert" phx-value-key="error">
        <.flash id="client-error" kind={:error} title="Error!" flash={@view_flash} />
      </div>
      <div role="alert" phx-value-key="warning">
        <.flash id="client-warning" kind={:warning} title="Warning!" flash={@view_flash} />
      </div>
      <div role="alert" phx-value-key="loading" data-handle-fadeout-flash={delayed_fade_out_flash()}>
        <.flash id="client-loading" kind={:loading} title="Loading..." flash={@view_flash} />
      </div>
    </div>
    """
  end

  # depending on how you structured your code, `socket.assigns.flash` might have your flash map.
  # for me I was running this as a component, so it was being passed @flash into `view_flash`.
  defp trigger_fade_out_flashes(socket, %{view_flash: nil} = _assigns), do: socket

  defp trigger_fade_out_flashes(socket, %{view_flash: flash} = _assigns) do
    # push event for each flash type.
    Map.keys(flash)
    |> Enum.reduce(socket, fn flash_key, piped_socket ->
      piped_socket
      |> push_event("fade-out-flash", %{type: flash_key})
    end)
  end

  # use TailwindCSS to wait 2 seconds before starting transition. Afterwards, send event to server to clear out flash.
  # `lv:clear-flash` will use `phx-value-key` attribute in element to remove flash per type.
  def delayed_fade_out_flash() do
    JS.hide(
      transition:
        {"transition-opacity ease-out delay-5000 duration-6000", "opacity-100", "opacity-0"},
      time: 6000
    )
    |> JS.push("lv:clear-flash")
  end
end
