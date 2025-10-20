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
        %{event: :untrack_character, payload: character_id},
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    :ok = WandererApp.Character.TrackingUtils.untrack([%{id: character_id}], map_id, self())
    socket
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
        %{event: :refresh_user_characters},
        %{
          assigns: %{
            map_id: map_id,
            main_character_eve_id: main_character_eve_id,
            following_character_eve_id: following_character_eve_id,
            current_user: current_user
          }
        } = socket
      ) do
    # Get tracked characters
    {:ok, tracked_characters} = WandererApp.Maps.get_tracked_map_characters(map_id, current_user)

    user_character_eve_ids = tracked_characters |> Enum.map(& &1.eve_id)

    # Update socket assigns but don't affect followed state
    socket
    |> assign(has_tracked_characters?: user_character_eve_ids |> Enum.empty?() |> Kernel.not())
    |> MapEventHandler.push_map_event(
      "map_updated",
      %{
        main_character_eve_id: main_character_eve_id,
        following_character_eve_id: following_character_eve_id,
        user_characters: user_character_eve_ids
      }
    )
  end

  def handle_server_event(%{event: :show_tracking}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "show_tracking",
      %{}
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
        "getCharactersTrackingInfo",
        _event,
        %{
          assigns: %{
            map_id: map_id,
            current_user: %{id: current_user_id}
          }
        } = socket
      ) do
    {:ok, tracking_data} =
      WandererApp.Character.TrackingUtils.build_tracking_data(map_id, current_user_id)

    {:reply, %{data: tracking_data}, socket}
  end

  def handle_ui_event(
        "updateCharacterTracking",
        %{"character_eve_id" => character_eve_id, "track" => track},
        %{
          assigns: %{
            map_id: map_id,
            current_user: %{id: current_user_id},
            only_tracked_characters: only_tracked_characters
          }
        } = socket
      ) do
    case WandererApp.Character.TrackingUtils.update_tracking(
           map_id,
           character_eve_id,
           current_user_id,
           track,
           self(),
           only_tracked_characters
         ) do
      {:ok, tracking_data, event} when not is_nil(tracking_data) ->
        # Send the appropriate event based on the result
        Process.send_after(self(), event, 50)

        # Send the updated tracking data to the client
        {:reply, %{data: tracking_data}, socket}

      {:ok, nil, event} ->
        # Send the appropriate event based on the result
        Process.send_after(self(), event, 50)

        # Send the updated tracking data to the client
        {:reply, %{characters: []}, socket}

      {:error, reason} ->
        Logger.error("Failed to toggle track: #{inspect(reason)}")
        {:noreply, socket |> put_flash(:error, "Failed to toggle character tracking")}
    end
  end

  def handle_ui_event(
        "updateFollowingCharacter",
        %{"character_eve_id" => character_eve_id},
        %{
          assigns: %{
            current_user: %{id: current_user_id},
            map_id: map_id,
            map_user_settings: map_user_settings,
            following_character_eve_id: following_character_eve_id
          }
        } = socket
      )
      when character_eve_id != following_character_eve_id do
    settings =
      case map_user_settings do
        nil -> nil
        %{settings: settings} -> settings
      end

    {:ok, user_settings} =
      WandererApp.MapUserSettingsRepo.create_or_update(map_id, current_user_id, settings)

    {:ok, map_user_settings} =
      user_settings
      |> WandererApp.Api.MapUserSettings.update_following_character(%{
        following_character_eve_id: "#{character_eve_id}"
      })

    {:ok, tracking_data} =
      WandererApp.Character.TrackingUtils.build_tracking_data(map_id, current_user_id)

    Process.send_after(self(), %{event: :refresh_user_characters}, 50)

    {:reply, %{data: tracking_data},
     socket
     |> assign(
       map_user_settings: map_user_settings,
       following_character_eve_id: "#{character_eve_id}"
     )}
  end

  def handle_ui_event(
        "updateMainCharacter",
        %{"character_eve_id" => character_eve_id},
        %{
          assigns: %{
            current_user: %{id: current_user_id, characters: current_user_characters},
            map_id: map_id,
            map_user_settings: map_user_settings,
            main_character_eve_id: main_character_eve_id
          }
        } = socket
      )
      when not is_nil(character_eve_id) and character_eve_id != main_character_eve_id do
    settings =
      case map_user_settings do
        nil -> nil
        %{settings: settings} -> settings
      end

    {:ok, user_settings} =
      WandererApp.MapUserSettingsRepo.create_or_update(map_id, current_user_id, settings)

    case Ash.update(user_settings, %{main_character_eve_id: "#{character_eve_id}"},
           action: :update_main_character
         ) do
      {:ok, map_user_settings} ->
        {:ok, tracking_data} =
          WandererApp.Character.TrackingUtils.build_tracking_data(map_id, current_user_id)

        {main_character_id, main_character_eve_id} =
          WandererApp.Character.TrackingUtils.get_main_character(
            map_user_settings,
            current_user_characters,
            current_user_characters
          )
          |> case do
            {:ok, main_character} when not is_nil(main_character) ->
              {main_character.id, main_character.eve_id}

            _ ->
              {nil, nil}
          end

        Process.send_after(self(), %{event: :refresh_user_characters}, 50)

        {:reply, %{data: tracking_data},
         socket
         |> assign(
           map_user_settings: map_user_settings,
           main_character_id: main_character_id,
           main_character_eve_id: main_character_eve_id
         )}

      {:error, reason} ->
        Logger.error("Failed to update main character: #{inspect(reason)}")
        {:reply, %{error: "Failed to update main character"}, socket}
    end
  end

  def handle_ui_event(
        "startTracking",
        %{"character_eve_id" => character_eve_id},
        %{
          assigns: %{
            map_id: map_id,
            current_user: %{id: current_user_id}
          }
        } = socket
      )
      when not is_nil(character_eve_id) do
    {:ok, character} = WandererApp.Character.get_by_eve_id("#{character_eve_id}")

    WandererApp.Cache.delete("character:#{character.id}:tracking_paused")

    {:noreply, socket}
  end

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

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
      |> Map.put_new(:tracking_paused, character |> Map.get(:tracking_paused, false))

  defp get_location(character),
    do: %{
      solar_system_id: character.solar_system_id,
      structure_id: character.structure_id,
      station_id: character.station_id
    }

  defp get_map_with_acls(map_id) do
    with {:ok, map} <- WandererApp.Api.Map.by_id(map_id) do
      {:ok, Ash.load!(map, :acls)}
    end
  end

  def needs_tracking_setup?(
        only_tracked_characters,
        characters,
        user_permissions
      ) do
    tracked_count =
      characters
      |> Enum.count(fn char ->
        char.tracked
      end)

    untracked_count =
      characters
      |> Enum.count(fn char ->
        !char.tracked
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
    case WandererApp.Character.TrackingUtils.track(
           map_characters,
           map_id,
           track_character,
           self()
         ) do
      :ok ->
        socket

      {:error, reason} ->
        Logger.error("Failed to track characters: #{inspect(reason)}")
        socket
    end
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
  Gets a list of characters that need tracking setup.
  """
  def get_untracked_characters(characters, character_settings) do
    Enum.filter(characters, fn char ->
      setting = Enum.find(character_settings, &(&1.character_id == char.id))
      is_tracked = setting && setting.tracked
      !is_tracked
    end)
  end
end
