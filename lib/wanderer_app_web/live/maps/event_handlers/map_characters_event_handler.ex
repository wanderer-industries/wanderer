defmodule WandererAppWeb.MapCharactersEventHandler do
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
    {:ok, all_user_characters} = WandererApp.Api.Character.active_by_user(%{user_id: current_user.id})

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
            {:ok, updated_settings} = WandererApp.MapCharacterSettingsRepo.untrack(existing_settings)

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
    {:ok, _all_user_characters} = WandererApp.Api.Character.active_by_user(%{user_id: current_user.id})

    # Get characters that have access to the map using load_characters
    # This will include all characters with access, even if they're not tracked
    {:ok, %{characters: characters_with_access}} =
      WandererApp.Maps.load_characters(map, character_settings, current_user.id)

    # Create tracking data for characters with access to the map
    tracking_data = Enum.map(characters_with_access, fn char ->
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
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user
          }
        } = socket
      ) do
    # Get all user characters
    {:ok, all_user_characters} = WandererApp.Api.Character.active_by_user(%{user_id: current_user.id})

    # Find the character that was clicked
    clicked_char =
      Enum.find(all_user_characters, fn char ->
        "#{char.id}" == "#{clicked_char_id}"
      end)

    if clicked_char do
      # Get existing settings for this character on this map
      case WandererApp.MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id) do
        {:ok, clicked_char_settings} ->
          # Toggle the followed status
          followed = !clicked_char_settings.followed

          # If we're following, unfollow any other character
          if followed do
            # Get all settings for this map
            {:ok, all_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

            # Unfollow any other character
            Enum.each(all_settings, fn s ->
              if s.character_id != clicked_char.id && s.followed do
                WandererApp.MapCharacterSettingsRepo.unfollow(s)
              end
            end)
          end

          # Ensure the character is tracked if we're following it
          if followed && !clicked_char_settings.tracked do
            # Track the character
            {:ok, _clicked_char_settings} = WandererApp.MapCharacterSettingsRepo.track(clicked_char_settings)
          end

          # Update the followed status
          if followed do
            {:ok, _settings} = WandererApp.MapCharacterSettingsRepo.follow(clicked_char_settings)
          else
            {:ok, _settings} = WandererApp.MapCharacterSettingsRepo.unfollow(clicked_char_settings)
          end

        {:error, :not_found} ->
          # Create new settings with tracked=true and followed=true
          {:ok, _new_settings} =
            WandererApp.MapCharacterSettingsRepo.create(%{
              character_id: clicked_char.id,
              map_id: map_id,
              tracked: true,
              followed: true
            })

          # Get all settings for this map
          {:ok, all_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

          # Unfollow any other character
          Enum.each(all_settings, fn s ->
            if s.character_id != clicked_char.id && s.followed do
              WandererApp.MapCharacterSettingsRepo.unfollow(s)
            end
          end)
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
        "refresh_characters",
        _,
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user
          }
        } = socket
      ) do
    # Get the current user's characters
    user_characters = current_user.characters |> Enum.map(& &1.id)

    # Get the tracked characters for this map
    {:ok, tracked_characters} =
      WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_filtered(
        map_id,
        user_characters
      )

    # Format the tracking data for the client
    tracking_data =
      tracked_characters
      |> Enum.map(fn {char, tracked, followed} ->
        %{
          id: char.eve_id,
          name: char.name,
          corporation_ticker: Map.get(char, :corporation_ticker, ""),
          alliance_ticker: Map.get(char, :alliance_ticker, ""),
          portrait_url: EVEUtil.get_portrait_url(char.eve_id),
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
  end

  # Catch-all handler for unmatched events
  def handle_ui_event(event, params, socket) do
    Logger.debug(fn -> "unhandled event in MapCharactersEventHandler: #{inspect(event)} with params: #{inspect(params)}" end)
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

end
