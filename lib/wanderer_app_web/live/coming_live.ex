defmodule WandererAppWeb.ComingLive do
  use WandererAppWeb, :live_view

  require Logger

  @impl true
  def mount(_params, %{"user_id" => user_id} = _session, socket) when not is_nil(user_id) do
    {:ok, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:active_page, :index)
    |> assign(:page_title, "Coming Soon")
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex grid grid-flow-row gap-2 p-3 h-full w-full pl-20">
      <main class="w-full shadow-sm rounded-lg shadow col-span-2 lg:col-span-1 overflow-auto p-3">
        <dotlottie-player
          src="/lottie/coming_soon.lottie"
          background="transparent"
          speed="1"
          style="width: 100%; height: 100%"
          direction="1"
          playMode="normal"
          loop
          autoplay
        >
        </dotlottie-player>
      </main>
    </div>
    """
  end
end
