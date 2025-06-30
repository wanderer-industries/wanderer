defmodule WandererAppWeb.MapCharactersEventHandler do
  @moduledoc """
  Handles character-related events and UI interactions for the map live view.
  """
  use WandererAppWeb, :live_component
  use Phoenix.Component
  require Logger

  alias WandererAppWeb.{MapEventHandler, MapCoreEventHandler}

  @refresh_delay 100
  # Rate limiting: 5 minutes in milliseconds
  @clear_all_cooldown 5 * 60 * 1000

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

  def handle_server_event(%{event: :ready_characters_updated, payload: payload}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "ready_characters_updated",
      payload
    )
  end

  def handle_server_event(%{event: :all_ready_characters_cleared, payload: payload}, socket) do
    socket
    |> MapEventHandler.push_map_event(
      "all_ready_characters_cleared",
      payload
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
    case WandererApp.Character.TrackingUtils.build_tracking_data(map_id, current_user_id) do
      {:ok, tracking_data} ->
        {:reply, %{data: tracking_data}, socket}

      {:error, reason} ->
        Logger.error("Failed to build tracking data: #{inspect(reason)}")

        {:reply, %{data: %{characters: [], main: nil, following: nil, ready_characters: []}},
         socket}
    end
  end

  def handle_ui_event(
        "getAllReadyCharacters",
        _event,
        %{
          assigns: %{
            map_id: map_id
          }
        } = socket
      ) do
    try do
      case build_all_ready_characters_data(map_id) do
        {:ok, ready_characters_data} ->
          {:reply, %{data: ready_characters_data}, socket}

        {:error, reason} ->
          Logger.error("Failed to build all ready characters data: #{inspect(reason)}")
          {:reply, %{data: %{characters: []}}, socket}
      end
    rescue
      error ->
        Logger.error("Exception in getAllReadyCharacters: #{inspect(error)}")
        {:reply, %{data: %{characters: []}}, socket}
    catch
      :exit, reason ->
        Logger.error("Exit in getAllReadyCharacters: #{inspect(reason)}")
        {:reply, %{data: %{characters: []}}, socket}
    end
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

    {:ok, map_user_settings} =
      user_settings
      |> WandererApp.Api.MapUserSettings.update_main_character(%{
        main_character_eve_id: "#{character_eve_id}"
      })

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
  end

  def handle_ui_event(
        "updateReadyCharacters",
        %{"ready_character_eve_ids" => ready_character_eve_ids},
        %{assigns: %{map_id: map_id, current_user: %{id: current_user_id}}} = socket
      ) do
    # Not a clear all operation, proceed normally
    perform_update_ready_characters(
      ready_character_eve_ids,
      map_id,
      current_user_id,
      socket,
      false
    )
  end

  def handle_ui_event(
        "clearAllReadyCharacters",
        _event,
        %{assigns: %{map_id: map_id, current_user: %{id: current_user_id}}} = socket
      ) do
    # Check rate limiting for clear all operation
    case check_clear_all_rate_limit(map_id) do
      {:ok, remaining_cooldown} when remaining_cooldown > 0 ->
        {:reply,
         %{
           error: "rate_limited",
           message: "Clear all function is on cooldown",
           remaining_cooldown: remaining_cooldown
         }, socket}

      {:ok, _} ->
        # Rate limit passed, continue with the operation
        perform_clear_all_ready_characters(map_id, current_user_id, socket)

      {:error, reason} ->
        Logger.error("Rate limit check failed: #{inspect(reason)}")
        {:reply, %{error: "internal_error", message: "Failed to check rate limit"}, socket}
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

  # Private functions

  defp perform_clear_all_ready_characters(map_id, current_user_id, socket) do
    try do
      # Get all user settings for this map
      import Ecto.Query

      user_settings_query =
        from(settings in "map_user_settings_v1",
          where: settings.map_id == type(^map_id, :binary_id),
          select: %{
            id: settings.id,
            map_id: settings.map_id,
            user_id: settings.user_id,
            ready_characters: settings.ready_characters,
            settings: settings.settings,
            main_character_eve_id: settings.main_character_eve_id,
            following_character_eve_id: settings.following_character_eve_id,
            hubs: settings.hubs
          }
        )

      map_user_settings = WandererApp.Repo.all(user_settings_query)

      # Clear ready characters for all users
      results =
        Enum.map(map_user_settings, fn user_setting ->
          # Load the user setting as an Ash resource using by_user_id
          case WandererApp.Api.MapUserSettings.by_user_id(
                 user_setting.map_id,
                 user_setting.user_id
               ) do
            {:ok, ash_user_setting} ->
              case WandererApp.Api.MapUserSettings.update_ready_characters(ash_user_setting, %{
                     ready_characters: []
                   }) do
                {:ok, _updated_settings} ->
                  :ok

                {:error, reason} ->
                  Logger.error(
                    "Failed to clear ready characters for user #{user_setting.user_id}: #{inspect(reason)}"
                  )

                  {:error, reason}
              end

            {:error, reason} ->
              Logger.error(
                "Failed to load user setting for map #{user_setting.map_id} user #{user_setting.user_id}: #{inspect(reason)}"
              )

              {:error, reason}
          end
        end)

      # Check if all operations succeeded
      failed_operations = Enum.filter(results, &(&1 != :ok))

      if Enum.empty?(failed_operations) do
        # Set rate limit for clear all operation
        set_clear_all_rate_limit(map_id)

        # Broadcast to all users that ready characters have been cleared
        WandererAppWeb.Endpoint.broadcast!(
          "map:#{map_id}",
          "all_ready_characters_cleared",
          %{
            cleared_by_user_id: current_user_id
          }
        )

        # Build and return updated tracking data for current user
        {:ok, tracking_data} =
          WandererApp.Character.TrackingUtils.build_tracking_data(map_id, current_user_id)

        # Send characters_updated event to update all character data including ready status
        Process.send_after(self(), %{event: :characters_updated}, @refresh_delay + 10)

        {:reply, %{data: tracking_data}, socket}
      else
        Logger.error("Some clear operations failed: #{inspect(failed_operations)}")
        {:reply, %{error: "Failed to clear some ready characters"}, socket}
      end
    rescue
      error ->
        Logger.error("Exception in clear all ready characters: #{inspect(error)}")
        {:reply, %{error: "Internal error while clearing ready characters"}, socket}
    end
  end

  defp perform_update_ready_characters(
         ready_character_eve_ids,
         map_id,
         current_user_id,
         socket,
         is_clear_all
       ) do
    # Validate ready characters exist, are owned by user, and are tracked
    {:ok, valid_ready_characters} =
      validate_ready_characters(map_id, current_user_id, ready_character_eve_ids)

    # Get or create user settings and update ready characters
    {:ok, map_user_settings} = WandererApp.MapUserSettingsRepo.get(map_id, current_user_id)

    result =
      case map_user_settings do
        nil ->
          # Create new settings if none exist, then update with ready characters
          case WandererApp.Api.MapUserSettings.create(%{
                 map_id: map_id,
                 user_id: current_user_id,
                 settings: "{}"
               }) do
            {:ok, new_settings} ->
              # Now update with ready characters
              case WandererApp.Api.MapUserSettings.update_ready_characters(new_settings, %{
                     ready_characters: valid_ready_characters
                   }) do
                {:ok, _updated_settings} ->
                  :ok

                {:error, reason} ->
                  Logger.error(
                    "Failed to update ready characters on new settings: #{inspect(reason)}"
                  )

                  {:error, "Failed to save ready characters"}
              end

            {:error, reason} ->
              Logger.error("Failed to create user settings: #{inspect(reason)}")
              {:error, "Failed to create user settings"}
          end

        existing_settings ->
          # Update existing settings
          case WandererApp.Api.MapUserSettings.update_ready_characters(existing_settings, %{
                 ready_characters: valid_ready_characters
               }) do
            {:ok, _updated_settings} ->
              :ok

            {:error, reason} ->
              Logger.error("Failed to update ready characters: #{inspect(reason)}")
              {:error, "Failed to save ready characters"}
          end
      end

    case result do
      :ok ->
        # If this was a clear all operation, update the rate limit cache
        if is_clear_all do
          set_clear_all_rate_limit(map_id)
        end

        # Broadcast ready status changes to other users in the map
        broadcast_ready_status_change(map_id, current_user_id, valid_ready_characters)

        # Build and return updated tracking data immediately
        {:ok, tracking_data} =
          WandererApp.Character.TrackingUtils.build_tracking_data(map_id, current_user_id)

        # Send characters_updated event to update all character data including ready status
        Process.send_after(self(), %{event: :characters_updated}, @refresh_delay + 10)

        {:reply, %{data: tracking_data}, socket}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  defp check_clear_all_rate_limit(map_id) do
    cache_key = "map:#{map_id}:clear_all_ready_last_used"

    case WandererApp.Cache.get(cache_key) do
      nil ->
        # No previous clear all operation recorded
        {:ok, 0}

      last_clear_time when is_integer(last_clear_time) ->
        current_time = System.system_time(:millisecond)
        time_since_last_clear = current_time - last_clear_time
        remaining_cooldown = max(0, @clear_all_cooldown - time_since_last_clear)
        {:ok, remaining_cooldown}

      _ ->
        # Invalid cache value, treat as no rate limit
        {:ok, 0}
    end
  rescue
    error ->
      Logger.error("Error checking clear all rate limit: #{inspect(error)}")
      {:error, :cache_error}
  end

  defp set_clear_all_rate_limit(map_id) do
    cache_key = "map:#{map_id}:clear_all_ready_last_used"
    current_time = System.system_time(:millisecond)

    # Set with TTL slightly longer than the cooldown to ensure cleanup
    ttl_seconds = div(@clear_all_cooldown, 1000) + 60

    case WandererApp.Cache.put(cache_key, current_time, ttl: ttl_seconds) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to set clear all rate limit: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Error setting clear all rate limit: #{inspect(error)}")
      {:error, :cache_error}
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
        :alliance_name
      ])
      |> Map.put(:alliance_ticker, Map.get(character, :alliance_ticker, ""))
      |> Map.put_new(:ship, WandererApp.Character.get_ship(character))
      |> Map.put_new(:location, get_location(character))
      |> Map.put_new(:tracking_paused, character |> Map.get(:tracking_paused, false))
      |> Map.put_new(:ready, character |> Map.get(:ready, false))

  defp get_location(character),
    do: %{
      solar_system_id: Map.get(character, :solar_system_id),
      structure_id: Map.get(character, :structure_id),
      station_id: Map.get(character, :station_id)
    }

  defp get_map_with_acls(map_id) do
    with {:ok, map} <- WandererApp.Api.Map.by_id(map_id) do
      {:ok, Ash.load!(map, :acls)}
    end
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
    :ok =
      WandererApp.Character.TrackingUtils.track(
        map_characters,
        map_id,
        track_character,
        self()
      )

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
  Gets a list of characters that need tracking setup.
  """
  def get_untracked_characters(characters, character_settings) do
    Enum.filter(characters, fn char ->
      setting = Enum.find(character_settings, &(&1.character_id == char.id))
      is_tracked = setting && setting.tracked
      !is_tracked
    end)
  end

  # Validates that the provided character EVE IDs are valid.
  # Returns {:ok, valid_character_eve_ids} or {:error, reason}.
  defp validate_ready_characters(map_id, current_user_id, ready_character_eve_ids) do
    with {:ok, user_characters_list} <-
           WandererApp.Api.Character.active_by_user(%{user_id: current_user_id}),
         user_character_ids = Enum.map(user_characters_list, & &1.id),
         {:ok, character_settings} <-
           WandererApp.MapCharacterSettingsRepo.get_by_map_filtered(map_id, user_character_ids) do
      # Get valid user character EVE IDs
      user_character_eve_ids = user_characters_list |> Enum.map(& &1.eve_id) |> MapSet.new()

      # Get tracked character IDs
      tracked_character_ids =
        character_settings
        |> Enum.filter(& &1.tracked)
        |> Enum.map(& &1.character_id)
        |> MapSet.new()

      # Find tracked characters that match user characters
      tracked_user_characters =
        user_characters_list
        |> Enum.filter(&MapSet.member?(tracked_character_ids, &1.id))
        |> Enum.map(& &1.eve_id)
        |> MapSet.new()

      # Filter ready characters to only include owned, tracked characters
      valid_ready_characters =
        ready_character_eve_ids
        |> Enum.filter(fn eve_id ->
          MapSet.member?(user_character_eve_ids, eve_id) &&
            MapSet.member?(tracked_user_characters, eve_id)
        end)

      {:ok, valid_ready_characters}
    else
      error ->
        {:error, "Failed to validate characters: #{inspect(error)}"}
    end
  end

  # Broadcasts ready status changes to other users in the map.
  defp broadcast_ready_status_change(map_id, current_user_id, ready_character_eve_ids) do
    # Get current user info for the broadcast
    {:ok, current_user} = WandererApp.Api.User.by_id(current_user_id)

    # Broadcast to all users in the map
    WandererAppWeb.Endpoint.broadcast!(
      "map:#{map_id}",
      "ready_characters_updated",
      %{
        user_id: current_user_id,
        user_name: current_user.name,
        ready_character_eve_ids: ready_character_eve_ids
      }
    )
  end

  # Builds data for all ready characters from all users in the map.
  defp build_all_ready_characters_data(map_id) do
    with {:ok, ready_character_eve_ids} <- get_all_ready_character_eve_ids(map_id),
         {:ok, tracked_characters} <- get_tracked_characters_with_settings(map_id),
         {:ok, filtered_characters} <-
           filter_ready_and_tracked_characters(tracked_characters, ready_character_eve_ids),
         {:ok, enriched_characters} <- enrich_character_data(filtered_characters) do
      {:ok, %{characters: enriched_characters}}
    else
      {:error, reason} ->
        Logger.error("Failed to build ready characters data: #{inspect(reason)}")
        {:ok, %{characters: []}}
    end
  end

  defp get_all_ready_character_eve_ids(map_id) do
    case WandererApp.Api.MapUserSettings.read_by_map(%{map_id: map_id}) do
      {:ok, map_user_settings} ->
        ready_eve_ids =
          map_user_settings
          |> Enum.flat_map(fn settings ->
            case settings.ready_characters do
              nil -> []
              ready_chars when is_list(ready_chars) -> ready_chars
              _ -> []
            end
          end)
          |> MapSet.new()

        {:ok, ready_eve_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_tracked_characters_with_settings(map_id) do
    case WandererApp.Api.MapCharacterSettings.read_by_map(%{map_id: map_id}) do
      {:ok, map_character_settings} ->
        # Load character relationships
        settings_with_chars =
          Enum.map(map_character_settings, fn setting ->
            Ash.load!(setting, :character)
          end)

        {:ok, settings_with_chars}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp filter_ready_and_tracked_characters(settings_with_chars, ready_eve_ids) do
    filtered =
      settings_with_chars
      |> Enum.filter(fn setting ->
        char = setting.character
        # Character must exist, have a user_id, be tracked, and be in ready list
        char != nil &&
          not is_nil(char.user_id) &&
          setting.tracked &&
          MapSet.member?(ready_eve_ids, char.eve_id)
      end)
      |> Enum.map(fn setting -> setting.character end)

    {:ok, filtered}
  end

  defp enrich_character_data(characters) do
    enriched =
      Enum.map(characters, fn char ->
        # Get actual online status
        actual_online =
          case WandererApp.Character.get_character_state(char.id, false) do
            {:ok, %{is_online: is_online}} when not is_nil(is_online) -> is_online
            _ -> Map.get(char, :online, false)
          end

        character_data =
          char
          |> Map.put(:online, actual_online)
          |> map_ui_character()

        %{
          character: character_data,
          tracked: true,
          ready: true
        }
      end)

    {:ok, enriched}
  end
end
