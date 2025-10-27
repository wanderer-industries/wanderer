defmodule WandererAppWeb.Nav do
  @moduledoc false

  import Phoenix.LiveView
  use Phoenix.Component

  alias WandererAppWeb.{
    AccessListsLive,
    MapLive,
    MapsLive,
    CharactersLive,
    CharactersTrackingLive
  }

  def on_mount(_scope, _params, _session, socket) do
    show_admin =
      socket.assigns.current_user_role == :admin

    {:cont,
     socket
     |> attach_hook(:active_tab, :handle_params, &set_active_tab/3)
     |> attach_hook(:ping, :handle_event, &handle_event/3)
     |> assign(
       rtt_class: rtt_class(),
       show_admin: show_admin,
       show_sidebar: true,
       map_subscriptions_enabled?: WandererApp.Env.map_subscriptions_enabled?(),
       app_version: WandererApp.Env.vsn()
     )}
  end

  defp handle_event("ping", %{"rtt" => rtt}, socket) do
    {:cont,
     socket
     |> rate_limited_ping_broadcast(socket.assigns.current_user, rtt)
     |> push_event("pong", %{})
     |> assign(:rtt_class, rtt_class(rtt))}
  end

  defp handle_event("toggle_sidebar", _, socket) do
    {:cont, socket |> assign(:show_sidebar, not socket.assigns.show_sidebar)}
  end

  defp handle_event(_, _, socket), do: {:cont, socket}

  defp set_active_tab(_params, _url, socket) do
    active_tab =
      case {socket.view, socket.assigns.live_action} do
        {AccessListsLive, _} ->
          :access_lists

        {MapLive, _} ->
          :map

        {MapsLive, _} ->
          :maps

        {MapAuditLive, _} ->
          :maps

        {CharactersLive, _} ->
          :characters

        {CharactersTrackingLive, _} ->
          :characters_tracking

        {_, _} ->
          nil
      end

    {:cont, socket |> assign(active_tab: active_tab)}
  end

  defp rate_limited_ping_broadcast(socket, %{} = _user, rtt) when is_integer(rtt) do
    now = System.system_time(:millisecond)
    last_ping_at = socket.assigns[:last_ping_at]

    if is_nil(last_ping_at) || now - last_ping_at > 1000 do
      socket |> assign(:last_ping_at, now)
    else
      socket
    end
  end

  defp rate_limited_ping_broadcast(socket, _user, _rtt), do: socket

  defp rtt_class(rtt \\ 0)

  defp rtt_class(rtt) when is_integer(rtt) do
    cond do
      rtt < 100 -> ""
      rtt < 200 -> "text-yellow-500"
      true -> "text-red-500"
    end
  end

  defp rtt_class(_), do: ""
end
