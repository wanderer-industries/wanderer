defmodule WandererAppWeb.CharactersTrackingLive do
  use WandererAppWeb, :live_view

  require Logger

  @impl true
  def mount(_params, %{"user_id" => user_id} = _session, socket) when not is_nil(user_id) do
    {:ok, maps} = WandererApp.Maps.get_available_maps(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(
       all_tracked: nil,
       characters: [],
       selected_map: nil,
       selected_map_slug: nil,
       user_id: user_id,
       maps: maps |> Enum.sort_by(& &1.name, :asc)
     )}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(characters: [], selected_map: nil, maps: [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:active_page, :characters_tracking)
    |> assign(:page_title, "Characters Tracking")
  end

  defp apply_action(socket, :characters, %{"slug" => map_slug} = _params) do
    selected_map = socket.assigns.maps |> Enum.find(&(&1.slug == map_slug))

    {:ok, character_settings} =
      case WandererApp.Api.MapCharacterSettings.read_by_map(%{map_id: selected_map.id}) do
        {:ok, settings} ->
          {:ok, settings}
        _ ->
          {:ok, []}
      end

    user_id = socket.assigns.user_id

    socket
    |> assign(:active_page, :characters_tracking)
    |> assign(:page_title, "Characters Tracking")
    |> assign(
      selected_map: selected_map,
      selected_map_slug: map_slug,
      character_settings: character_settings
    )
    |> assign_async(:characters, fn ->
      WandererApp.Maps.load_characters(selected_map, character_settings, user_id)
    end)
  end

  @impl true
  def handle_event("select_map_" <> map_slug, _, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/tracking/#{map_slug}")}
  end

  @impl true
  def handle_event("toggle_track_" <> character_id, _, socket) do
    handle_event("toggle_track", %{"character-id" => character_id}, socket)
  end

  @impl true
  def handle_event("toggle_track", %{"character-id" => character_id}, socket) do
    selected_map = socket.assigns.selected_map
    character_settings = socket.assigns.character_settings

    case character_settings |> Enum.find(&(&1.character_id == character_id)) do
      nil ->
        WandererApp.Api.MapCharacterSettings.create(%{
          character_id: character_id,
          map_id: selected_map.id,
          tracked: true
        })

        {:noreply, socket}

      character_setting ->
        case character_setting.tracked do
          true ->
            character_setting
            |> WandererApp.Api.MapCharacterSettings.untrack!()

          _ ->
            character_setting
            |> WandererApp.Api.MapCharacterSettings.track!()
        end
    end

    %{result: characters} = socket.assigns.characters

    {:ok, character_settings} =
      case WandererApp.Api.MapCharacterSettings.read_by_map(%{map_id: selected_map.id}) do
        {:ok, settings} -> {:ok, settings}
        _ -> {:ok, []}
      end

    characters =
      characters
      |> Enum.map(fn c ->
        WandererApp.Maps.map_character(
          c,
          character_settings |> Enum.find(&(&1.character_id == c.id))
        )
      end)

    {:noreply,
     socket
     |> assign(character_settings: character_settings)
     |> assign_async(:characters, fn ->
       {:ok, %{characters: characters}}
     end)}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}
end
