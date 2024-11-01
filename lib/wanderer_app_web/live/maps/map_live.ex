defmodule WandererAppWeb.MapLive do
  use WandererAppWeb, :live_view
  use LiveViewEvents

  require Logger

  @impl true
  def mount(%{"slug" => map_slug} = _params, _session, socket) when is_connected?(socket) do
    Process.send_after(self(), %{event: :load_map}, Enum.random(10..500))

    {:ok,
     socket
     |> assign(
       map_slug: map_slug,
       map_loaded?: false,
       server_online: false,
       selected_subscription: nil,
       user_permissions: nil
     )
     |> push_event("js-exec", %{
       to: "#map-loader",
       attr: "data-loading",
       timeout: 2000
     })}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       map_slug: nil,
       map_loaded?: false,
       server_online: false,
       selected_subscription: nil,
       user_permissions: nil
     )}
  end

  @impl true
  def handle_params(params, _url, socket),
    do: {:noreply, apply_action(socket, socket.assigns.live_action, params)}

  @impl true
  def handle_info(
        {"change_map", map_slug},
        %{assigns: %{map_id: map_id}} = socket
      ) do
    Phoenix.PubSub.unsubscribe(WandererApp.PubSub, map_id)
    {:noreply, socket |> push_navigate(to: ~p"/#{map_slug}")}
  end

  @impl true
  def handle_info(:character_token_invalid, socket),
    do:
      {:noreply,
       socket
       |> put_flash(
         :error,
         "One of your characters has expired token. Please refresh it on characters page."
       )}

  def handle_info(:no_access, socket),
    do:
      {:noreply,
       socket
       |> put_flash(:error, "You don't have an access to this map.")
       |> push_navigate(to: ~p"/maps")}

  def handle_info(:no_permissions, socket),
    do:
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permissions to use this map.")
       |> push_navigate(to: ~p"/maps")}

  def handle_info(:not_all_characters_tracked, %{assigns: %{map_slug: map_slug}} = socket),
    do:
      {:noreply,
       socket
       |> put_flash(
         :error,
         "You should enable tracking for all characters that have access to this map first!"
       )
       |> push_navigate(to: ~p"/tracking/#{map_slug}")}

  @impl true
  def handle_info(info, socket),
    do:
      {:noreply,
       socket
       |> WandererAppWeb.MapEventHandler.handle_event(info)}

  @impl true
  def handle_event(event, body, socket),
    do: WandererAppWeb.MapEventHandler.handle_ui_event(event, body, socket)

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:active_page, :map)
  end

  defp apply_action(socket, :add_system, _params) do
    socket
    |> assign(:active_page, :map)
    |> assign(:page_title, "Add System")
    |> assign(:add_system_form, to_form(%{"system_id" => nil}))
  end

  def character_item(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="avatar">
        <div class="rounded-md w-12 h-12">
          <img src={member_icon_url(@character.eve_id)} alt={@character.name} />
        </div>
      </div>
      <%= @character.name %>
    </div>
    """
  end
end
