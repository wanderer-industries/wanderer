defmodule WandererAppWeb.CharactersTrackingLive do
  use WandererAppWeb, :live_view

  require Logger

  alias WandererApp.Character.TrackingUtils

  @impl true
  def mount(_params, _session, socket) do
    {:ok, maps} = WandererApp.Maps.get_available_maps(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(
       all_tracked: nil,
       characters: [],
       selected_map: nil,
       selected_map_slug: nil,
       maps: maps |> Enum.sort_by(& &1.name, :asc)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    # Unsubscribe from previous map if any
    socket = maybe_unsubscribe_from_map(socket)

    socket
    |> assign(:active_page, :characters_tracking)
    |> assign(:page_title, "Characters Tracking")
    |> assign(selected_map: nil, selected_map_slug: nil)
  end

  defp apply_action(
         %{assigns: %{current_user: current_user, maps: maps}} = socket,
         :characters,
         %{"slug" => map_slug} = _params
       ) do
    selected_map = maps |> Enum.find(&(&1.slug == map_slug))

    # Unsubscribe from previous map and subscribe to new one
    socket = maybe_unsubscribe_from_map(socket)
    socket = maybe_subscribe_to_map(socket, selected_map)

    socket
    |> assign(:active_page, :characters_tracking)
    |> assign(:page_title, "Characters Tracking")
    |> assign(
      selected_map: selected_map,
      selected_map_slug: map_slug
    )
    |> assign_async(:characters, fn ->
      WandererApp.Maps.load_characters(selected_map, current_user.id)
    end)
  end

  # Subscribe to map PubSub channel to receive ACL update notifications
  defp maybe_subscribe_to_map(socket, nil), do: socket

  defp maybe_subscribe_to_map(socket, %{id: map_id}) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WandererApp.PubSub, map_id)
    end

    socket
  end

  # Unsubscribe from previous map's PubSub channel
  defp maybe_unsubscribe_from_map(%{assigns: %{selected_map: nil}} = socket), do: socket

  defp maybe_unsubscribe_from_map(%{assigns: %{selected_map: %{id: map_id}}} = socket) do
    Phoenix.PubSub.unsubscribe(WandererApp.PubSub, map_id)
    socket
  end

  defp maybe_unsubscribe_from_map(socket), do: socket

  @impl true
  def handle_event("select_map_" <> map_slug, _, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/tracking/#{map_slug}")}
  end

  @impl true
  def handle_event("toggle_track_" <> character_id, _, socket) do
    handle_event("toggle_track", %{"character_id" => character_id}, socket)
  end

  @impl true
  def handle_event(
        "toggle_track",
        %{"character_id" => character_id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    selected_map = socket.assigns.selected_map
    %{result: characters} = socket.assigns.characters

    case characters |> Enum.find(&(&1.id == character_id)) do
      %{tracked: current_tracked, eve_id: eve_id} ->
        # Use TrackingUtils.update_tracking to properly set/unset the tracking_start_time
        # cache key, which is required for the character to appear in get_tracked_character_ids
        case TrackingUtils.update_tracking(
               selected_map.id,
               eve_id,
               current_user.id,
               not current_tracked,
               self(),
               false
             ) do
          {:ok, _tracking_data, _event} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Failed to toggle tracking for character #{character_id} on map #{selected_map.id}: #{inspect(reason)}"
            )
        end

      nil ->
        Logger.warning(
          "Character #{character_id} not found in available characters for map #{selected_map.id}"
        )
    end

    {:noreply,
     socket
     |> assign_async(:characters, fn ->
       WandererApp.Maps.load_characters(selected_map, current_user.id)
     end)}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  # Handle ACL members changed event - reload characters list
  @impl true
  def handle_info(
        %{event: :acl_members_changed},
        %{assigns: %{selected_map: selected_map, current_user: current_user}} = socket
      )
      when not is_nil(selected_map) do
    {:noreply,
     socket
     |> assign_async(:characters, fn ->
       WandererApp.Maps.load_characters(selected_map, current_user.id)
     end)}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}
end
