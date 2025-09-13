defmodule WandererAppWeb.ServerStatusLive do
  use WandererAppWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    :ok =
      Phoenix.PubSub.subscribe(
        WandererApp.PubSub,
        "server_status"
      )

    {:ok, socket |> assign(server_online: true)}
  end

  @impl true
  def handle_info({:server_status, status}, socket) do
    {:noreply, socket |> assign(server_online: not status.vip)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.server_status online={@server_online} />
    """
  end
end
