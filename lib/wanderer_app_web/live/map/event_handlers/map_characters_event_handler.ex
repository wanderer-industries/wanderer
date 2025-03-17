defmodule WandererAppWeb.MapCharactersEventHandler do
  @moduledoc """
  Handles character-related events and UI interactions for the map live view.
  """
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  def handle_server_event(%{event: :character_added, payload: character}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "character_added",
      character |> map_ui_character()
    )
  end

  def handle_server_event(%{event: :character_removed, payload: character}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "character_removed",
      character |> map_ui_character()
    )
  end

  def handle_server_event(%{event: :character_updated, payload: character}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "character_updated",
      character |> map_ui_character()
    )
  end

  def handle_server_event(
        %{event: :characters_updated},
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    characters =
      map_id
      |> WandererApp.Map.list_characters()
      |> Enum.map(&map_ui_character/1)

    socket
    |> MapEventHandler.push_map_event(
      "characters_updated",
      characters
    )
  end

  def handle_server_event(
        %{event: :present_characters_updated, payload: present_character_eve_ids},
        socket
      ),
      do:
        socket
        |> MapEventHandler.push_map_event(
          "present_characters",
          present_character_eve_ids
        )

  def handle_server_event(
        %{event: :tracking_characters_data, payload: tracking_data},
        socket
      ) do
    socket
    |> MapEventHandler.push_map_event(
      "tracking_characters_data",
      %{characters: tracking_data}
    )
  end

  def handle_server_event(
        %{event: :refresh_user_characters},
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user
          }
        } = socket
      ) do
    # Get tracked characters
    {:ok, map_characters} = WandererApp.Maps.get_tracked_map_characters(map_id, current_user)

    user_character_eve_ids = map_characters |> Enum.map(& &1.eve_id)

    # Update socket assigns but don't affect followed state
    socket
    |> assign(user_characters: user_character_eve_ids)
    |> assign(has_tracked_characters?: has_tracked_characters?(user_character_eve_ids))
    |> MapEventHandler.push_map_event(
      "init",
      %{
        user_characters: user_character_eve_ids,
        reset: false
      }
    )
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  # UI Event Handlers
  def handle_ui_event(
        "getCharacterInfo",
        %{"characterEveId" => character_eve_id},
        socket
      ) do
    {:ok, character} = WandererApp.Character.get_by_eve_id("#{character_eve_id}")

    {:reply, character |> MapEventHandler.map_ui_character_stat(), socket}
  end

  def handle_ui_event(
        "toggle_track",
        %{"character_id" => character_eve_id},
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            only_tracked_characters: only_tracked_characters
          }
        } = socket
      ) do
    case WandererApp.Character.TrackingUtils.toggle_track(map_id, character_eve_id, current_user.id, self()) do
      {:ok, tracking_data} ->
        # If only tracked characters are shown, we might need to refresh the view
        if only_tracked_characters do
          Process.send_after(self(), :not_all_characters_tracked, 10)
        else
          Process.send_after(self(), %{event: :refresh_user_characters}, 10)
        end

        # Send the updated tracking data to the client
        {:noreply,
         socket
         |> MapEventHandler.push_map_event(
           "tracking_characters_data",
           %{characters: tracking_data}
         )}

      {:error, reason} ->
        Logger.error("Failed to toggle track: #{inspect(reason)}")
        {:noreply, socket |> put_flash(:error, "Failed to toggle character tracking")}
    end
  end

  def handle_ui_event(
        "show_tracking",
        _,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    # Create tracking data for characters with access to the map
    case WandererApp.Character.TrackingUtils.build_tracking_data(map_id, current_user.id) do
      {:ok, tracking_data} ->
        {:noreply,
         socket
         |> MapEventHandler.push_map_event(
           "show_tracking",
           %{}
         )
         |> MapEventHandler.push_map_event(
           "tracking_characters_data",
           %{characters: tracking_data}
         )}

      {:error, reason} ->
        Logger.error("Failed to load tracking data: #{inspect(reason)}")
        {:noreply, socket |> put_flash(:error, "Failed to load tracking data")}
    end
  end

  def handle_ui_event(
        "toggle_follow",
        %{"character_id" => clicked_char_id},
        %{assigns: %{current_user: current_user, map_id: map_id}} = socket
      ) do
    case WandererApp.Character.TrackingUtils.toggle_follow(map_id, clicked_char_id, current_user.id, self()) do
      {:ok, tracking_data} ->
        {:noreply,
         socket
         |> MapEventHandler.push_map_event("tracking_characters_data", %{characters: tracking_data})}

      {:error, reason} ->
        Logger.error("Failed to toggle follow: #{inspect(reason)}")
        {:noreply, socket |> put_flash(:error, "Failed to toggle character following")}
    end
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  def has_tracked_characters?([]), do: false
  def has_tracked_characters?(_user_characters), do: true

  def map_ui_character(character),
    do:
      character
      |> Map.take([
        :eve_id,
        :name,
        :online,
        :corporation_id,
        :corporation_name,
        :corporation_ticker,
        :alliance_id,
        :alliance_name
      ])
      |> Map.put(:alliance_ticker, Map.get(character, :alliance_ticker, ""))
      |> Map.put_new(:ship, WandererApp.Character.get_ship(character))
      |> Map.put_new(:location, get_location(character))

  defp get_location(character),
    do: %{solar_system_id: character.solar_system_id, structure_id: character.structure_id}

  @doc """
  Initializes character tracking for a map. This is called when the map is first loaded.
  Returns a tuple with the socket and whether any characters need tracking setup.
  """
  def init_character_tracking(socket, map_id, %{
        current_user: current_user,
        user_permissions: user_permissions
      }) do
    {:ok, character_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)
    {:ok, map} = get_map_with_acls(map_id)

    {:ok, %{characters: characters_with_access}} =
      WandererApp.Maps.load_characters(map, character_settings, current_user.id)

    socket = init_tracking_state(socket, current_user)

    needs_tracking_setup =
      needs_tracking_setup?(
        socket.assigns.only_tracked_characters,
        characters_with_access,
        character_settings,
        user_permissions
      )

    socket
    |> assign(:needs_tracking_setup, needs_tracking_setup)
  end

  defp get_map_with_acls(map_id) do
    with {:ok, map} <- WandererApp.Api.Map.by_id(map_id) do
      {:ok, Ash.load!(map, :acls)}
    end
  end

  def init_tracking_state(socket, current_user) do
    user_character_eve_ids = current_user.characters |> Enum.map(& &1.eve_id)
    has_tracked_characters? = has_tracked_characters?(user_character_eve_ids)

    socket
    |> assign(
      has_tracked_characters?: has_tracked_characters?,
      user_characters: user_character_eve_ids
    )
  end

  def needs_tracking_setup?(
        only_tracked_characters,
        characters,
        character_settings,
        user_permissions
      ) do
    tracked_count =
      characters
      |> Enum.count(fn char ->
        setting = Enum.find(character_settings, &(&1.character_id == char.id))
        setting && setting.tracked
      end)

    untracked_count =
      characters
      |> Enum.count(fn char ->
        setting = Enum.find(character_settings, &(&1.character_id == char.id))
        setting == nil || !setting.tracked
      end)

    user_permissions.track_character &&
      ((untracked_count > 0 && only_tracked_characters) || tracked_count == 0)
  end

  @doc """
  Handles character tracking events during map initialization.
  """
  def handle_tracking_events(socket, map_id, events) do
    events
    |> Enum.reduce(socket, fn event, socket ->
      handle_tracking_event(event, socket, map_id)
    end)
  end

  defp handle_tracking_event({:track_characters, map_characters, track_character}, socket, map_id) do
    :ok = WandererApp.Character.TrackingUtils.track_characters(map_characters, map_id, track_character, self())
    :ok = WandererApp.Character.TrackingUtils.add_characters(map_characters, map_id, track_character)
    socket
  end

  defp handle_tracking_event(:invalid_token_message, socket, _map_id) do
    socket
    |> put_flash(
      :error,
      "One of your characters has expired token. Please refresh it on characters page."
    )
  end

  defp handle_tracking_event(:map_character_limit, socket, _map_id) do
    socket
    |> put_flash(
      :error,
      "Map reached its character limit, your characters won't be tracked. Please contact administrator."
    )
  end

  defp handle_tracking_event(:empty_tracked_characters, socket, _map_id), do: socket
  defp handle_tracking_event(_, socket, _map_id), do: socket

  @doc """
  Gets character settings for a map.
  """
  def get_map_character_settings(map_id) do
    case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
      {:ok, settings} -> {:ok, settings}
      _ -> {:ok, []}
    end
  end

  @doc """
  Gets a list of characters that need tracking setup.
  """
  def get_untracked_characters(characters, character_settings) do
    Enum.filter(characters, fn char ->
      setting = Enum.find(character_settings, &(&1.character_id == char.id))
      is_tracked = setting && setting.tracked
      !is_tracked
    end)
  end

  def handle_activity_data(socket, activity_data) do
    socket
    |> MapEventHandler.push_map_event("character_activity_data", %{
      activity: activity_data,
      loading: false
    })
  end

  def handle_tracking_result(socket, %{type: :character_tracking} = result) do
    socket
    |> MapEventHandler.push_map_event("character_tracking", result)
  end

  def handle_settings_result(socket, %{type: :character_settings} = result) do
    socket
    |> MapEventHandler.push_map_event("character_settings", result)
  end

  def handle_location_result(socket, %{type: :character_location} = result) do
    socket
    |> MapEventHandler.push_map_event("character_location", result)
  end

  def handle_online_result(socket, %{type: :character_online} = result) do
    socket
    |> MapEventHandler.push_map_event("character_online", result)
  end

  def handle_ship_result(socket, %{type: :character_ship} = result) do
    socket
    |> MapEventHandler.push_map_event("character_ship", result)
  end

  def handle_fleet_result(socket, %{type: :character_fleet} = result) do
    socket
    |> MapEventHandler.push_map_event("character_fleet", result)
  end

  def handle_character_result(socket, type, result) do
    case type do
      :character_activity -> handle_activity_data(socket, result)
      :character_tracking -> handle_tracking_result(socket, result)
      :character_settings -> handle_settings_result(socket, result)
      :character_location -> handle_location_result(socket, result)
      :character_online -> handle_online_result(socket, result)
      :character_ship -> handle_ship_result(socket, result)
      :character_fleet -> handle_fleet_result(socket, result)
    end
  end
end
