defmodule WandererAppWeb.MapCharactersEventHandler do
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

  def handle_server_event(event, socket),
    do: MapCoreEventHandler.handle_server_event(event, socket)

  def handle_ui_event(
        "add_character",
        _,
        %{
          assigns: %{
            current_user: current_user,
            map_id: map_id,
            user_permissions: %{track_character: true}
          }
        } = socket
      ) do
    {:ok, character_settings} =
      case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
        {:ok, settings} -> {:ok, settings}
        _ -> {:ok, []}
      end

    {:noreply,
     socket
     |> assign(
       show_tracking?: true,
       character_settings: character_settings
     )
     |> assign_async(:characters, fn ->
       {:ok, map} =
         map_id
         |> WandererApp.MapRepo.get([:acls])

       map
       |> WandererApp.Maps.load_characters(
         character_settings,
         current_user.id
       )
     end)}
  end

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
            character_settings: character_settings,
            current_user: current_user,
            only_tracked_characters: only_tracked_characters
          }
        } = socket
      ) do
    socket =
      case character_settings |> Enum.find(&(&1.character_id == character_id)) do
        nil ->
          {:ok, map_character_settings} =
            WandererApp.MapCharacterSettingsRepo.create(%{
              character_id: character_id,
              map_id: map_id,
              tracked: true
            })

          character = map_character_settings |> Ash.load!(:character) |> Map.get(:character)

          :ok = track_characters([character], map_id, true)
          :ok = add_characters([character], map_id, true)

          socket

        character_setting ->
          case character_setting.tracked do
            true ->
              {:ok, map_character_settings} =
                character_setting
                |> WandererApp.MapCharacterSettingsRepo.untrack()

              character = map_character_settings |> Ash.load!(:character) |> Map.get(:character)

              :ok = untrack_characters([character], map_id)
              :ok = remove_characters([character], map_id)

              if only_tracked_characters do
                Process.send_after(self(), :not_all_characters_tracked, 10)
              end

              socket

            _ ->
              {:ok, map_character_settings} =
                character_setting
                |> WandererApp.MapCharacterSettingsRepo.track()

              character = map_character_settings |> Ash.load!(:character) |> Map.get(:character)

              :ok = track_characters([character], map_id, true)
              :ok = add_characters([character], map_id, true)

              socket
          end
      end

    %{result: characters} = socket.assigns.characters

    {:ok, map_characters} = get_tracked_map_characters(map_id, current_user)

    user_character_eve_ids = map_characters |> Enum.map(& &1.eve_id)

    {:ok, character_settings} =
      case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
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
     |> assign(user_characters: user_character_eve_ids)
     |> assign(has_tracked_characters?: has_tracked_characters?(user_character_eve_ids))
     |> assign(character_settings: character_settings)
     |> assign_async(:characters, fn ->
       {:ok, %{characters: characters}}
     end)
     |> MapEventHandler.push_map_event(
       "init",
       %{
         user_characters: user_character_eve_ids,
         reset: false
       }
     )}
  end

  def handle_ui_event("hide_tracking", _, socket),
    do: {:noreply, socket |> assign(show_tracking?: false)}

  def handle_ui_event(event, body, socket),
    do: MapCoreEventHandler.handle_ui_event(event, body, socket)

  def has_tracked_characters?([]), do: false
  def has_tracked_characters?(_user_characters), do: true

  def get_tracked_map_characters(map_id, current_user) do
    case WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_filtered(
           map_id,
           current_user.characters |> Enum.map(& &1.id)
         ) do
      {:ok, settings} ->
        {:ok,
         settings
         |> Enum.map(fn s -> s |> Ash.load!(:character) |> Map.get(:character) end)}

      _ ->
        {:ok, []}
    end
  end

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
        :alliance_name,
        :alliance_ticker
      ])
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
