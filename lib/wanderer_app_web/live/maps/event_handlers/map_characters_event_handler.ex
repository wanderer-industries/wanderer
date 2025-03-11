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

    {:ok, tracking_data} = build_tracking_data(map_id, current_user)

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
        "toggle_track",
        %{"character-id" => character_eve_id},
        %{
          assigns: %{
            map_id: map_id,
            current_user: current_user,
            only_tracked_characters: only_tracked_characters
          }
        } = socket
      ) do
    # First, get all existing settings to preserve states
    {:ok, all_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

    # Save the followed character ID and settings before making any changes
    {followed_character_id, _followed_character_settings} =
      all_settings
      |> Enum.find(& &1.followed)
      |> case do
        nil -> {nil, nil}
        setting -> {setting.character_id, setting}
      end

    # Find the character we're toggling
    with {:ok, character} <-
           WandererApp.Character.find_character_by_eve_id(current_user, character_eve_id),
         {:ok, updated_settings} <-
           toggle_character_tracking(character, map_id, only_tracked_characters) do
      # Get the map with ACLs
      {:ok, map} = WandererApp.Api.Map.by_id(map_id)
      map = Ash.load!(map, :acls)

      # Get characters that have access to the map
      {:ok, %{characters: characters_with_access}} =
        WandererApp.Maps.load_characters(map, all_settings, current_user.id)

      # If there was a followed character before, check if it's still followed
      # Only check if we're not toggling the followed character itself
      if followed_character_id && followed_character_id != character.id do
        # Get the current settings for the followed character
        case WandererApp.MapCharacterSettingsRepo.get_by_map(map_id, followed_character_id) do
          {:ok, current_settings} ->
            # If it's not followed anymore, follow it again
            if !current_settings.followed do
              {:ok, _} = WandererApp.MapCharacterSettingsRepo.follow(current_settings)
            end

          _ ->
            :ok
        end
      end

      {:ok, tracking_data} = build_tracking_data(map_id, current_user)

      {:noreply,
       socket
       |> MapEventHandler.push_map_event(
         "tracking_characters_data",
         %{characters: tracking_data}
       )}
    else
      _ ->
        {:noreply, socket}
    end
  end

  def handle_ui_event(
        "show_tracking",
        _,
        %{assigns: %{map_id: map_id, current_user: current_user}} = socket
      ) do
    # Create tracking data for characters with access to the map
    {:ok, tracking_data} = build_tracking_data(map_id, current_user)

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
  end

  def handle_ui_event(
        "toggle_follow",
        %{"character-id" => clicked_char_id},
        %{assigns: %{current_user: current_user, map_id: map_id}} = socket
      ) do
    # Get all settings before the operation to see the followed state
    {:ok, all_settings_before} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)
    followed_before = all_settings_before |> Enum.find(& &1.followed)

    # Check if the clicked character is already followed
    is_already_followed =
      followed_before && "#{followed_before.character_id}" == "#{clicked_char_id}"

    # Use find_character_by_eve_id from WandererApp.Character
    with {:ok, clicked_char} <-
           WandererApp.Character.find_character_by_eve_id(current_user, clicked_char_id),
         {:ok, _updated_settings} <-
           toggle_character_follow(map_id, clicked_char, is_already_followed) do
      # Get the state after the toggle_character_follow operation
      {:ok, all_settings_after} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

      # Build tracking data
      {:ok, tracking_data} = build_tracking_data(map_id, current_user)

      {:noreply,
       socket
       |> MapEventHandler.push_map_event("tracking_characters_data", %{characters: tracking_data})}
    else
      error ->
        Logger.error("Failed to toggle follow: #{inspect(error)}")
        {:noreply, socket}
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
            WandererApp.Character.Activity.process_character_activity(map_id, current_user)

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

  defp load_map_characters(map, character_settings, current_user) do
    WandererApp.Maps.load_characters(map, character_settings, current_user.id)
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

  defp toggle_character_follow(map_id, clicked_char, is_already_followed) do
    with {:ok, clicked_char_settings} <-
           WandererApp.MapCharacterSettingsRepo.get_by_map(map_id, clicked_char.id) do
      if is_already_followed do
        # If already followed, just unfollow without affecting other characters
        {:ok, updated_settings} =
          WandererApp.MapCharacterSettingsRepo.unfollow(clicked_char_settings)

        {:ok, updated_settings}
      else
        # Normal follow toggle
        {:ok, settings} = update_follow_status(map_id, clicked_char, clicked_char_settings)
        {:ok, settings}
      end
    else
      {:error, :not_found} ->
        # Character not found in settings, create new settings
        update_follow_status(map_id, clicked_char, nil)
    end
  end

  defp update_follow_status(map_id, clicked_char, nil) do
    # Create new settings with tracked=true and followed=true
    # If we're following this character, unfollow all others first
    :ok = maybe_unfollow_others(map_id, clicked_char.id, true)

    result =
      WandererApp.MapCharacterSettingsRepo.create(%{
        character_id: clicked_char.id,
        map_id: map_id,
        tracked: true,
        followed: true
      })

    result
  end

  defp update_follow_status(map_id, clicked_char, clicked_char_settings) do
    # Toggle the followed state
    followed = !clicked_char_settings.followed

    # Only unfollow other characters if we're explicitly following this character
    # This prevents unfollowing other characters when just tracking a character
    if followed do
      # We're following this character, so unfollow all others
      :ok = maybe_unfollow_others(map_id, clicked_char.id, followed)
    end

    # If we're following, make sure the character is also tracked
    :ok = maybe_track_character(clicked_char_settings, followed)

    # Update the follow status
    {:ok, settings} = update_follow(clicked_char_settings, followed)

    {:ok, settings}
  end

  defp maybe_unfollow_others(_map_id, _char_id, false), do: :ok

  defp maybe_unfollow_others(map_id, char_id, true) do
    # This function should only be called when explicitly following a character,
    # not when tracking a character. It unfollows all other characters when
    # setting a character as followed.

    {:ok, all_settings} = WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)

    # Unfollow other characters
    all_settings
    |> Enum.filter(&(&1.character_id != char_id && &1.followed))
    |> Enum.each(fn setting ->
      WandererApp.MapCharacterSettingsRepo.unfollow(setting)
    end)

    :ok
  end

  defp maybe_track_character(_settings, false), do: :ok

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
          # Important: Preserve the followed state
          followed = if setting, do: setting.followed, else: false

          %{
            character: char |> MapEventHandler.map_ui_character_stat(),
            tracked: tracked,
            followed: followed
          }
        end)

      {:ok, tracking_data}
    end
  end

  # Helper function to toggle character tracking
  defp toggle_character_tracking(character, map_id, only_tracked_characters) do
    case WandererApp.MapCharacterSettingsRepo.get_by_map(map_id, character.id) do
      {:ok, existing_settings} ->
        if existing_settings.tracked do
          # Untrack the character
          {:ok, updated_settings} =
            WandererApp.MapCharacterSettingsRepo.untrack(existing_settings)

          :ok = untrack_characters([character], map_id)
          :ok = remove_characters([character], map_id)

          if only_tracked_characters do
            Process.send_after(self(), :not_all_characters_tracked, 10)
          end

          # If the character was followed, we need to unfollow it too
          # But we should NOT unfollow other characters
          if existing_settings.followed do
            {:ok, final_settings} =
              WandererApp.MapCharacterSettingsRepo.unfollow(updated_settings)

            {:ok, final_settings}
          else
            {:ok, updated_settings}
          end
        else
          # Track the character
          {:ok, updated_settings} =
            WandererApp.MapCharacterSettingsRepo.track(existing_settings)

          :ok = track_characters([character], map_id, true)
          :ok = add_characters([character], map_id, true)
          Process.send_after(self(), %{event: :refresh_user_characters}, 10)

          {:ok, updated_settings}
        end

      {:error, :not_found} ->
        # Create new settings
        result =
          WandererApp.MapCharacterSettingsRepo.create(%{
            character_id: character.id,
            map_id: map_id,
            tracked: true,
            followed: false
          })

        result
    end
  end
end
