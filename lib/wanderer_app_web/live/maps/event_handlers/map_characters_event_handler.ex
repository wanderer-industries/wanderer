defmodule WandererAppWeb.MapCharactersEventHandler do
  @moduledoc """
  Handles character-related events and UI interactions for the map live view.
  """
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}
  alias WandererApp.Utils.EVEUtil

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
        %{event: :character_activity_data, payload: {:activity_data, activity_data}},
        socket
      ) do
    socket
    |> MapEventHandler.push_map_event(
      "character_activity_data",
      %{activity: activity_data, loading: false}
    )
  end

  def handle_server_event(%{event: :character_activity, payload: activity_data}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "character_activity",
      activity_data
    )
  end

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "add_character",
        _,
        socket
      ),
      do: {:noreply, socket |> add_character()}

  def handle_ui_event(
        "add_character",
        _,
        %{
          assigns: %{
            user_permissions: %{track_character: false}
          }
        } = socket
      ),
      do:
        {:noreply,
         socket
         |> put_flash(
           :error,
           "You don't have permissions to track characters. Please contact administrator."
         )}

  def handle_ui_event(
        "toggle_track",
        %{"character-id" => character_id},
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            only_tracked_characters: _only_tracked_characters
          }
        } = socket
      ) do
    # Get all user characters
    {:ok, all_user_characters} =
      WandererApp.Api.Character.active_by_user(%{user_id: current_user.id})

    # Find the character that was clicked
    clicked_char =
      Enum.find(all_user_characters, fn char ->
        "#{char.id}" == "#{character_id}"
      end)

    if clicked_char do
      # Get existing settings for this character on this map
      case WandererApp.MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id) do
        {:ok, existing_settings} ->
          # Toggle the tracked status
          if existing_settings.tracked do
            # Untrack the character
            {:ok, updated_settings} =
              WandererApp.MapCharacterSettingsRepo.untrack(existing_settings)

            # If the character was also followed, unfollow it
            if updated_settings.followed do
              {:ok, _} = WandererApp.MapCharacterSettingsRepo.unfollow(updated_settings)
            end
          else
            # Track the character
            {:ok, _} = WandererApp.MapCharacterSettingsRepo.track(existing_settings)
          end

        {:error, :not_found} ->
          # Create new settings with tracked=true
          {:ok, _} =
            WandererApp.MapCharacterSettingsRepo.create(%{
              character_id: clicked_char.id,
              map_id: map_id,
              tracked: true,
              followed: false
            })
      end

      # Get the map with ACLs
      {:ok, map} = WandererApp.Api.Map.by_id(map_id)
      map = Ash.load!(map, :acls)

      # Get updated settings
      {:ok, updated_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

      # Get characters with access to the map
      {:ok, %{characters: characters_with_access}} =
        WandererApp.Maps.load_characters(map, updated_settings, current_user.id)

      # Build tracking data for all characters with map access
      tracking_data =
        Enum.map(characters_with_access, fn char ->
          # Find settings for this character if they exist
          setting = Enum.find(updated_settings, &(&1.character_id == char.id))
          tracked = if setting, do: setting.tracked, else: false
          followed = if setting, do: setting.followed, else: false

          %{
            id: "#{char.id}",
            name: char.name,
            eve_id: char.eve_id,
            portrait_url: EVEUtil.get_portrait_url(char.eve_id),
            corporation_ticker: char.corporation_ticker,
            alliance_ticker: Map.get(char, :alliance_ticker, ""),
            tracked: tracked,
            followed: followed
          }
        end)

      # Send the updated tracking data to the client
      {:noreply,
       socket
       |> MapEventHandler.push_map_event(
         "tracking_characters_data",
         %{characters: tracking_data}
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_ui_event(
        "show_tracking",
        _,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    # Get character settings for this map
    {:ok, character_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

    # Get the map with ACLs
    {:ok, map} = WandererApp.Api.Map.by_id(map_id)
    map = Ash.load!(map, :acls)

    # Get all user characters
    {:ok, _all_user_characters} =
      WandererApp.Api.Character.active_by_user(%{user_id: current_user.id})

    # Get characters that have access to the map using load_characters
    # This will include all characters with access, even if they're not tracked
    {:ok, %{characters: characters_with_access}} =
      WandererApp.Maps.load_characters(map, character_settings, current_user.id)

    # Create tracking data for characters with access to the map
    tracking_data =
      Enum.map(characters_with_access, fn char ->
        # Find settings for this character if they exist
        setting = Enum.find(character_settings, &(&1.character_id == char.id))
        tracked = if setting, do: setting.tracked, else: false
        followed = if setting, do: setting.followed, else: false

        %{
          id: char.id,
          name: char.name,
          corporation_ticker: char.corporation_ticker,
          alliance_ticker: Map.get(char, :alliance_ticker, ""),
          portrait_url: EVEUtil.get_portrait_url(char.eve_id),
          tracked: tracked,
          followed: followed
        }
      end)

    event_data = %{
      type: "tracking_characters_data",
      body: %{characters: tracking_data}
    }

    socket =
      socket
      |> assign(:show_tracking, true)
      |> push_event("map_event", event_data)

    {:noreply, socket}
  end

  def handle_ui_event(
        "hide_tracking",
        _,
        socket
      ) do
    {:noreply, socket |> assign(:show_tracking, false)}
  end

  def handle_ui_event(
        "toggle_follow",
        %{"character-id" => clicked_char_id},
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    with {:ok, clicked_char} <- find_user_character(current_user, clicked_char_id),
         {:ok, updated_settings} <- toggle_character_follow(map_id, clicked_char),
         {:ok, tracking_data} <- build_tracking_data(map_id, current_user) do
      {:noreply,
       socket
       |> MapEventHandler.push_map_event("tracking_characters_data", %{characters: tracking_data})}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_ui_event(
        "show_activity",
        _,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    socket =
      socket
      |> MapEventHandler.push_map_event(
        "character_activity_data",
        %{activity: [], loading: true}
      )

    task =
      Task.async(fn ->
        try do
          result =
            WandererApp.Utils.CharacterUtil.process_character_activity(map_id, current_user)

          {:activity_data, result}
        rescue
          e ->
            Logger.error("Error processing character activity: #{inspect(e)}")
            Logger.error("#{Exception.format_stacktrace()}")
            {:activity_data, []}
        end
      end)

    {:noreply, socket |> assign(:character_activity_task, task)}
  end

  def handle_ui_event("hide_activity", _, socket),
    do: {:noreply, socket |> assign(show_activity?: false)}

  def handle_ui_event(event, params, socket) do
    Logger.debug(fn ->
      "unhandled event in MapCharactersEventHandler: #{inspect(event)} with params: #{inspect(params)}"
    end)

    {:noreply, socket}
  end

  def add_character(socket), do: socket

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

  def add_characters([], _map_id, _track_character), do: :ok

  def add_characters([character | characters], map_id, track_character) do
    map_id
    |> WandererApp.Map.Server.add_character(character, track_character)

    add_characters(characters, map_id, track_character)
  end

  def remove_characters([], _map_id), do: :ok

  def remove_characters([character | characters], map_id) do
    map_id
    |> WandererApp.Map.Server.remove_character(character.id)

    remove_characters(characters, map_id)
  end

  def untrack_characters(characters, map_id) do
    characters
    |> Enum.each(fn character ->
      WandererAppWeb.Presence.untrack(self(), map_id, character.id)

      WandererApp.Cache.put(
        "#{inspect(self())}_map_#{map_id}:character_#{character.id}:tracked",
        false
      )

      :ok =
        Phoenix.PubSub.unsubscribe(
          WandererApp.PubSub,
          "character:#{character.eve_id}"
        )
    end)
  end

  def track_characters(_, _, false), do: :ok

  def track_characters([], _map_id, _is_track_character?), do: :ok

  def track_characters(
        [character | characters],
        map_id,
        true
      ) do
    track_character(character, map_id)

    track_characters(characters, map_id, true)
  end

  def track_character(
        %{
          id: character_id,
          eve_id: eve_id,
          corporation_id: corporation_id,
          alliance_id: alliance_id
        },
        map_id
      ) do
    WandererAppWeb.Presence.track(self(), map_id, character_id, %{})

    case WandererApp.Cache.lookup!(
           "#{inspect(self())}_map_#{map_id}:character_#{character_id}:tracked",
           false
         ) do
      true ->
        :ok

      _ ->
        :ok =
          Phoenix.PubSub.subscribe(
            WandererApp.PubSub,
            "character:#{eve_id}"
          )

        :ok =
          WandererApp.Cache.put(
            "#{inspect(self())}_map_#{map_id}:character_#{character_id}:tracked",
            true
          )
    end

    case WandererApp.Cache.lookup(
           "#{inspect(self())}_map_#{map_id}:corporation_#{corporation_id}:tracked",
           false
         ) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        :ok =
          Phoenix.PubSub.subscribe(
            WandererApp.PubSub,
            "corporation:#{corporation_id}"
          )

        :ok =
          WandererApp.Cache.put(
            "#{inspect(self())}_map_#{map_id}:corporation_#{corporation_id}:tracked",
            true
          )
    end

    case WandererApp.Cache.lookup(
           "#{inspect(self())}_map_#{map_id}:alliance_#{alliance_id}:tracked",
           false
         ) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        :ok =
          Phoenix.PubSub.subscribe(
            WandererApp.PubSub,
            "alliance:#{alliance_id}"
          )

        :ok =
          WandererApp.Cache.put(
            "#{inspect(self())}_map_#{map_id}:alliance_#{alliance_id}:tracked",
            true
          )
    end

    :ok = WandererApp.Character.TrackerManager.start_tracking(character_id)
  end

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
      load_map_characters(map, character_settings, current_user)

    socket = init_tracking_state(socket, current_user)

    needs_tracking_setup =
      needs_tracking_setup?(characters_with_access, character_settings, user_permissions)

    if needs_tracking_setup do
      show_tracking_dialog(socket, characters_with_access, character_settings)
    else
      {socket, needs_tracking_setup}
    end
  end

  defp get_map_with_acls(map_id) do
    with {:ok, map} <- WandererApp.Api.Map.by_id(map_id) do
      {:ok, Ash.load!(map, :acls)}
    end
  end

  defp load_map_characters(map, character_settings, current_user) do
    WandererApp.Maps.load_characters(map, character_settings, current_user.id)
  end

  defp init_tracking_state(socket, current_user) do
    user_character_eve_ids = current_user.characters |> Enum.map(& &1.eve_id)
    has_tracked_characters? = has_tracked_characters?(user_character_eve_ids)

    socket
    |> assign(
      has_tracked_characters?: has_tracked_characters?,
      user_characters: user_character_eve_ids
    )
  end

  defp needs_tracking_setup?(characters, character_settings, user_permissions) do
    untracked_count =
      characters
      |> Enum.count(fn char ->
        setting = Enum.find(character_settings, &(&1.character_id == char.id))
        not (setting && setting.tracked)
      end)

    untracked_count > 0 && user_permissions.track_character
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
    :ok = track_characters(map_characters, map_id, track_character)
    :ok = add_characters(map_characters, map_id, track_character)
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

  @doc """
  Shows the tracking dialog with the given characters.
  """
  def show_tracking_dialog(socket, characters_with_access, character_settings) do
    tracking_data =
      Enum.map(characters_with_access, fn char ->
        setting = Enum.find(character_settings, &(&1.character_id == char.id))
        tracked = if setting, do: setting.tracked, else: false
        followed = if setting, do: setting.followed, else: false

        %{
          id: char.id,
          name: char.name,
          portrait_url: EVEUtil.get_portrait_url(char.eve_id, 64),
          corporation_ticker: char.corporation_ticker,
          alliance_ticker: Map.get(char, :alliance_ticker, ""),
          tracked: tracked,
          followed: followed
        }
      end)

    socket
    |> push_event("map_event", %{
      type: "show_tracking",
      body: %{}
    })
    |> push_event("map_event", %{
      type: "tracking_characters_data",
      body: %{characters: tracking_data}
    })
    |> assign(:show_tracking, true)
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

  defp find_user_character(current_user, char_id) do
    case Enum.find(current_user.characters, &("#{&1.id}" == "#{char_id}")) do
      nil -> {:error, :character_not_found}
      char -> {:ok, char}
    end
  end

  defp toggle_character_follow(map_id, clicked_char) do
    with {:ok, clicked_char_settings} <-
           WandererApp.MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id),
         {:ok, settings} <- update_follow_status(map_id, clicked_char, clicked_char_settings) do
      {:ok, settings}
    end
  end

  defp update_follow_status(map_id, clicked_char, nil) do
    # Create new settings with tracked=true and followed=true
    WandererApp.MapCharacterSettingsRepo.create(%{
      character_id: clicked_char.id,
      map_id: map_id,
      tracked: true,
      followed: true
    })
  end

  defp update_follow_status(map_id, clicked_char, clicked_char_settings) do
    followed = !clicked_char_settings.followed

    with :ok <- maybe_unfollow_others(map_id, clicked_char.id, followed),
         :ok <- maybe_track_character(clicked_char_settings, followed),
         {:ok, settings} <- update_follow(clicked_char_settings, followed) do
      {:ok, settings}
    end
  end

  defp maybe_unfollow_others(_map_id, _char_id, false), do: :ok

  defp maybe_unfollow_others(map_id, char_id, true) do
    {:ok, all_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

    all_settings
    |> Enum.filter(&(&1.character_id != char_id && &1.followed))
    |> Enum.each(&WandererApp.MapCharacterSettingsRepo.unfollow/1)

    :ok
  end

  defp maybe_track_character(settings, false), do: :ok

  defp maybe_track_character(settings, true) do
    if not settings.tracked do
      {:ok, _} = WandererApp.MapCharacterSettingsRepo.track(settings)
    end

    :ok
  end

  defp update_follow(settings, true), do: WandererApp.MapCharacterSettingsRepo.follow(settings)
  defp update_follow(settings, false), do: WandererApp.MapCharacterSettingsRepo.unfollow(settings)

  defp build_tracking_data(map_id, current_user) do
    with {:ok, map} <- WandererApp.Api.Map.by_id(map_id),
         map <- Ash.load!(map, :acls),
         {:ok, character_settings} <- WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id),
         {:ok, %{characters: characters_with_access}} <-
           WandererApp.Maps.load_characters(map, character_settings, current_user.id) do
      tracking_data =
        Enum.map(characters_with_access, fn char ->
          setting = Enum.find(character_settings, &(&1.character_id == char.id))
          tracked = if setting, do: setting.tracked, else: false
          followed = if setting, do: setting.followed, else: false

          %{
            id: "#{char.id}",
            name: char.name,
            eve_id: char.eve_id,
            portrait_url: EVEUtil.get_portrait_url(char.eve_id),
            corporation_ticker: char.corporation_ticker,
            alliance_ticker: Map.get(char, :alliance_ticker, ""),
            tracked: tracked,
            followed: followed
          }
        end)

      {:ok, tracking_data}
    end
  end
end
