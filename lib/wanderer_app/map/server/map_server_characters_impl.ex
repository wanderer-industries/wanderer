defmodule WandererApp.Map.Server.CharactersImpl do
  @moduledoc """
  Handles character-related operations for map servers.

  This module manages:
  - Character tracking on maps
  - Permission-based character cleanup
  - Character presence updates

  ## Logging

  This module emits detailed logs for debugging character tracking issues:
  - INFO: Character track/untrack events, permission cleanup results
  - WARNING: Permission failures, unexpected states
  - DEBUG: Detailed permission check results
  """

  require Logger

  alias WandererApp.Map.Server.{Impl, ConnectionsImpl, SystemsImpl}

  def cleanup_characters(map_id) do
    {:ok, invalidate_character_ids} =
      WandererApp.Cache.get_and_remove(
        "map_#{map_id}:invalidate_character_ids",
        []
      )

    if Enum.empty?(invalidate_character_ids) do
      :ok
    else
      Logger.debug(fn ->
        "[CharactersImpl] Running permission cleanup for map #{map_id} - " <>
          "checking #{length(invalidate_character_ids)} characters"
      end)

      {:ok, %{acls: acls}} =
        WandererApp.MapRepo.get(map_id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      process_invalidate_characters(invalidate_character_ids, map_id, acls)
    end
  end

  def track_characters(_map_id, []), do: :ok

  def track_characters(map_id, [character_id | rest]) do
    Logger.debug(fn ->
      "[CharactersImpl] Starting tracking for character #{character_id} on map #{map_id} - " <>
        "reason: character joined presence"
    end)

    track_character(map_id, character_id)
    track_characters(map_id, rest)
  end

  def invalidate_characters(map_id) do
    Task.start_link(fn ->
      character_ids =
        map_id
        |> WandererApp.Map.get_map!()
        |> Map.get(:characters, [])

      if length(character_ids) > 0 do
        Logger.debug(fn ->
          "[CharactersImpl] Scheduling permission check for #{length(character_ids)} characters on map #{map_id}"
        end)
      end

      WandererApp.Cache.insert("map_#{map_id}:invalidate_character_ids", character_ids)

      :ok
    end)
  end

  def untrack_characters(map_id, character_ids) do
    if length(character_ids) > 0 do
      Logger.debug(fn ->
        "[CharactersImpl] Untracking #{length(character_ids)} characters from map #{map_id} - " <>
          "reason: characters no longer in presence_character_ids (grace period expired or user disconnected)"
      end)
    end

    character_ids
    |> Enum.each(fn character_id ->
      character_map_active = is_character_map_active?(map_id, character_id)

      character_map_active
      |> untrack_character(map_id, character_id)
    end)
  end

  defp untrack_character(true, map_id, character_id) do
    Logger.info(fn ->
      "[CharactersImpl] Untracking character #{character_id} from map #{map_id} - " <>
        "character was actively tracking this map"
    end)

    # Emit telemetry for tracking
    :telemetry.execute(
      [:wanderer_app, :character, :tracking, :stopped],
      %{system_time: System.system_time()},
      %{character_id: character_id, map_id: map_id, reason: :presence_expired}
    )

    WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
      map_id: map_id,
      track: false
    })
  end

  defp untrack_character(false, map_id, character_id) do
    Logger.debug(fn ->
      "[CharactersImpl] Skipping untrack for character #{character_id} on map #{map_id} - " <>
        "character was not actively tracking this map"
    end)

    :ok
  end

  defp is_character_map_active?(map_id, character_id) do
    case WandererApp.Character.get_character_state(character_id) do
      {:ok, %{active_maps: active_maps}} ->
        map_id in active_maps

      _ ->
        false
    end
  end

  defp process_invalidate_characters(invalidate_character_ids, map_id, acls) do
    {:ok, %{map: %{owner_id: owner_id}}} = WandererApp.Map.get_map_state(map_id)

    # Option 3: Get owner's user_id to allow all characters from the same user
    owner_user_id = get_owner_user_id(owner_id)

    Logger.debug(fn ->
      "[CharacterCleanup] Map #{map_id} - validating permissions for #{length(invalidate_character_ids)} characters"
    end)

    results =
      invalidate_character_ids
      |> Task.async_stream(
        fn character_id ->
          character_id
          |> WandererApp.Character.get_character()
          |> case do
            {:ok, %{user_id: nil}} ->
              {:remove_character, character_id, :no_user_id}

            {:ok, character} ->
              # Option 3: Check if character belongs to the same user as owner
              is_same_user_as_owner =
                owner_user_id != nil and character.user_id == owner_user_id

              if is_same_user_as_owner do
                # All characters from the map owner's account have full access
                :ok
              else
                [character_permissions] =
                  WandererApp.Permissions.check_characters_access([character], acls)

                map_permissions =
                  WandererApp.Permissions.get_map_permissions(
                    character_permissions,
                    owner_id,
                    [character_id]
                  )

                case map_permissions do
                  %{view_system: false} ->
                    {:remove_character, character_id, :no_view_permission}

                  %{track_character: false} ->
                    {:remove_character, character_id, :no_track_permission}

                  _ ->
                    :ok
                end
              end

            _ ->
              :ok
          end
        end,
        timeout: :timer.seconds(60),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.reduce([], fn
        {:ok, {:remove_character, character_id, reason}}, acc ->
          [{character_id, reason} | acc]

        {:ok, _result}, acc ->
          acc

        {:error, reason}, acc ->
          Logger.error(
            "[CharacterCleanup] Error checking character permissions: #{inspect(reason)}"
          )

          acc
      end)

    case results do
      [] ->
        Logger.debug(fn ->
          "[CharacterCleanup] Map #{map_id} - all #{length(invalidate_character_ids)} characters passed permission check"
        end)

        :ok

      characters_to_remove ->
        # Group by reason for better logging
        by_reason = Enum.group_by(characters_to_remove, fn {_id, reason} -> reason end)

        Enum.each(by_reason, fn {reason, chars} ->
          char_ids = Enum.map(chars, fn {id, _} -> id end)
          reason_str = permission_removal_reason_to_string(reason)

          Logger.debug(fn ->
            "[CharacterCleanup] Map #{map_id} - removing #{length(char_ids)} characters: #{reason_str} - " <>
              "character_ids: #{inspect(char_ids)}"
          end)

          # Emit telemetry for each removal reason
          :telemetry.execute(
            [:wanderer_app, :character, :tracking, :permission_revoked],
            %{count: length(char_ids), system_time: System.system_time()},
            %{map_id: map_id, character_ids: char_ids, reason: reason}
          )
        end)

        character_ids_to_remove = Enum.map(characters_to_remove, fn {id, _} -> id end)

        Logger.debug(fn ->
          "[CharacterCleanup] Map #{map_id} - total #{length(character_ids_to_remove)} characters " <>
            "will be removed due to permission issues (NO GRACE PERIOD)"
        end)

        remove_and_untrack_characters(map_id, character_ids_to_remove)
    end
  end

  defp permission_removal_reason_to_string(:no_user_id),
    do: "no user_id associated with character"

  defp permission_removal_reason_to_string(:no_view_permission), do: "lost view_system permission"

  defp permission_removal_reason_to_string(:no_track_permission),
    do: "lost track_character permission"

  defp permission_removal_reason_to_string(reason), do: "#{inspect(reason)}"

  # Helper to get the owner's user_id for Option 3
  defp get_owner_user_id(nil), do: nil

  defp get_owner_user_id(owner_id) do
    case WandererApp.Character.get_character(owner_id) do
      {:ok, %{user_id: user_id}} -> user_id
      _ -> nil
    end
  end

  defp remove_character(map_id, character_id) do
    Task.start_link(fn ->
      with :ok <- WandererApp.Map.remove_character(map_id, character_id),
           {:ok, character} <- WandererApp.Character.get_map_character(map_id, character_id) do
        # Clean up character-specific cache entries
        WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:solar_system_id")
        WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:station_id")
        WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:structure_id")
        WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:location_updated_at")

        Impl.broadcast!(map_id, :character_removed, character)

        # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
        WandererApp.ExternalEvents.broadcast(map_id, :character_removed, character)

        :telemetry.execute([:wanderer_app, :map, :character, :removed], %{count: 1})

        :ok
      else
        {:error, _error} ->
          :ok
      end
    end)
  end

  defp remove_and_untrack_characters(map_id, character_ids) do
    # Option 4: Enhanced logging for character removal
    Logger.info(fn ->
      "[CharacterCleanup] Map #{map_id} - starting removal of #{length(character_ids)} characters: #{inspect(character_ids)}"
    end)

    # Emit telemetry for monitoring
    :telemetry.execute(
      [:wanderer_app, :map, :characters_cleanup, :removal_started],
      %{character_count: length(character_ids), system_time: System.system_time()},
      %{map_id: map_id, character_ids: character_ids}
    )

    map_id
    |> untrack_characters(character_ids)

    map_id
    |> WandererApp.MapCharacterSettingsRepo.get_by_map_filtered(character_ids)
    |> case do
      {:ok, settings} ->
        settings
        |> Enum.each(fn s ->
          Logger.info(fn ->
            "[CharacterCleanup] Map #{map_id} - destroying settings and removing character #{s.character_id}"
          end)

          WandererApp.MapCharacterSettingsRepo.destroy!(s)
          remove_character(map_id, s.character_id)
        end)

        # Emit telemetry for successful removal
        :telemetry.execute(
          [:wanderer_app, :map, :characters_cleanup, :removal_complete],
          %{removed_count: length(settings), system_time: System.system_time()},
          %{map_id: map_id}
        )

      _ ->
        :ok
    end
  end

  # Calculate optimal concurrency based on character count
  # Scales from base concurrency (32 on 8-core) up to 128 for 300+ characters
  defp calculate_max_concurrency(character_count) do
    base_concurrency = System.schedulers_online() * 4

    cond do
      character_count < 100 -> base_concurrency
      character_count < 200 -> base_concurrency * 2
      character_count < 300 -> base_concurrency * 3
      true -> base_concurrency * 4
    end
  end

  def update_characters(map_id) do
    start_time = System.monotonic_time(:microsecond)

    try do
      {:ok, tracked_character_ids} = WandererApp.Map.get_tracked_character_ids(map_id)

      character_count = length(tracked_character_ids)

      # Emit telemetry for tracking update cycle start
      :telemetry.execute(
        [:wanderer_app, :map, :update_characters, :start],
        %{character_count: character_count, system_time: System.system_time()},
        %{map_id: map_id}
      )

      # Calculate dynamic concurrency based on character count
      max_concurrency = calculate_max_concurrency(character_count)

      updated_characters =
        tracked_character_ids
        |> Task.async_stream(
          fn character_id ->
            # Use batch cache operations for all character tracking data
            process_character_updates_batched(map_id, character_id)
          end,
          timeout: :timer.seconds(15),
          max_concurrency: max_concurrency,
          on_timeout: :kill_task
        )
        |> Enum.reduce([], fn
          {:ok, {:updated, character}}, acc ->
            [character | acc]

          {:ok, _result}, acc ->
            acc

          {:error, reason}, acc ->
            Logger.error("Error in update_characters: #{inspect(reason)}")
            acc
        end)

      unless Enum.empty?(updated_characters) do
        # Broadcast to internal channels
        Impl.broadcast!(map_id, :characters_updated, %{
          characters: updated_characters,
          timestamp: DateTime.utc_now()
        })

        # Broadcast to external event system (webhooks/WebSocket)
        WandererApp.ExternalEvents.broadcast(map_id, :characters_updated, %{
          characters: updated_characters,
          timestamp: DateTime.utc_now()
        })
      end

      # Emit telemetry for successful completion
      duration = System.monotonic_time(:microsecond) - start_time

      :telemetry.execute(
        [:wanderer_app, :map, :update_characters, :complete],
        %{
          duration: duration,
          character_count: character_count,
          updated_count: length(updated_characters),
          system_time: System.system_time()
        },
        %{map_id: map_id}
      )

      :ok
    rescue
      e ->
        # Emit telemetry for error case
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:wanderer_app, :map, :update_characters, :error],
          %{
            duration: duration,
            system_time: System.system_time()
          },
          %{map_id: map_id, error: Exception.message(e)}
        )

        Logger.error("""
        [Map Server] update_characters => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end
  end

  defp calculate_character_state_hash(character) do
    # Hash all trackable fields for quick comparison
    :erlang.phash2(%{
      online: character.online,
      ship: character.ship,
      ship_name: character.ship_name,
      ship_item_id: character.ship_item_id,
      solar_system_id: character.solar_system_id,
      station_id: character.station_id,
      structure_id: character.structure_id,
      alliance_id: character.alliance_id,
      corporation_id: character.corporation_id
    })
  end

  defp process_character_updates_batched(map_id, character_id) do
    # Step 1: Get current character data for hash comparison
    case WandererApp.Character.get_character(character_id) do
      {:ok, character} ->
        new_hash = calculate_character_state_hash(character)
        state_hash_key = "map:#{map_id}:character:#{character_id}:state_hash"

        {:ok, old_hash} = WandererApp.Cache.lookup(state_hash_key, nil)

        if new_hash == old_hash do
          # No changes detected - skip expensive processing (70-90% of cases)
          :no_change
        else
          # Changes detected - proceed with full processing
          process_character_changes(map_id, character_id, character, state_hash_key, new_hash)
        end

      {:error, _error} ->
        :ok
    end
  end

  # Process character changes when hash indicates updates
  defp process_character_changes(map_id, character_id, character, state_hash_key, new_hash) do
    # Step 1: Batch read all cached values for this character
    cache_keys = [
      "map:#{map_id}:character:#{character_id}:online",
      "map:#{map_id}:character:#{character_id}:ship_type_id",
      "map:#{map_id}:character:#{character_id}:ship_name",
      "map:#{map_id}:character:#{character_id}:solar_system_id",
      "map:#{map_id}:character:#{character_id}:station_id",
      "map:#{map_id}:character:#{character_id}:structure_id",
      "map:#{map_id}:character:#{character_id}:location_updated_at",
      "map:#{map_id}:character:#{character_id}:alliance_id",
      "map:#{map_id}:character:#{character_id}:corporation_id"
    ]

    {:ok, cached_values} = WandererApp.Cache.lookup_all(cache_keys)

    # Step 2: Calculate all updates
    {character_updates, cache_updates} =
      calculate_character_updates(map_id, character_id, character, cached_values)

    # Step 3: Update the state hash in cache
    cache_updates = Map.put(cache_updates, state_hash_key, new_hash)

    # Step 4: Batch write all cache updates
    unless Enum.empty?(cache_updates) do
      WandererApp.Cache.insert_all(cache_updates)
    end

    # Step 5: Process update events
    has_updates =
      character_updates
      |> Enum.filter(fn update -> update != :skip end)
      |> Enum.map(fn update ->
        case update do
          {:character_location, location_info, old_location_info} ->
            start_time = System.monotonic_time(:microsecond)

            :telemetry.execute(
              [:wanderer_app, :character, :location_update, :start],
              %{system_time: System.system_time()},
              %{
                character_id: character_id,
                map_id: map_id,
                from_system: old_location_info.solar_system_id,
                to_system: location_info.solar_system_id
              }
            )

            {:ok, map_state} = WandererApp.Map.get_map_state(map_id)

            update_location(
              map_state,
              character_id,
              location_info,
              old_location_info
            )

            duration = System.monotonic_time(:microsecond) - start_time

            :telemetry.execute(
              [:wanderer_app, :character, :location_update, :complete],
              %{duration: duration, system_time: System.system_time()},
              %{
                character_id: character_id,
                map_id: map_id,
                from_system: old_location_info.solar_system_id,
                to_system: location_info.solar_system_id
              }
            )

            :has_update

          {:character_ship, _info} ->
            :has_update

          {:character_online, %{online: online}} ->
            if not online do
              WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:solar_system_id")
            end

            :has_update

          {:character_tracking, _info} ->
            :has_update

          {:character_alliance, _info} ->
            WandererApp.Cache.insert_or_update(
              "map_#{map_id}:invalidate_character_ids",
              [character_id],
              fn ids ->
                [character_id | ids] |> Enum.uniq()
              end
            )

            # Broadcast permission update to trigger LiveView refresh
            broadcast_permission_update(character_id)

            :has_update

          {:character_corporation, _info} ->
            WandererApp.Cache.insert_or_update(
              "map_#{map_id}:invalidate_character_ids",
              [character_id],
              fn ids ->
                [character_id | ids] |> Enum.uniq()
              end
            )

            # Broadcast permission update to trigger LiveView refresh
            broadcast_permission_update(character_id)

            :has_update

          _ ->
            :skip
        end
      end)
      |> Enum.any?(fn result -> result == :has_update end)

    if has_updates do
      case WandererApp.Character.get_map_character(map_id, character_id) do
        {:ok, character} ->
          {:updated, character}

        {:error, _} ->
          :ok
      end
    else
      :ok
    end
  end

  # Calculate all character updates in a single pass
  defp calculate_character_updates(map_id, character_id, character, cached_values) do
    updates = []
    cache_updates = %{}

    # Check each type of update using specialized functions
    {updates, cache_updates} =
      check_online_update(map_id, character_id, character, cached_values, updates, cache_updates)

    {updates, cache_updates} =
      check_ship_update(map_id, character_id, character, cached_values, updates, cache_updates)

    {updates, cache_updates} =
      check_location_update(
        map_id,
        character_id,
        character,
        cached_values,
        updates,
        cache_updates
      )

    {updates, cache_updates} =
      check_alliance_update(
        map_id,
        character_id,
        character,
        cached_values,
        updates,
        cache_updates
      )

    {updates, cache_updates} =
      check_corporation_update(
        map_id,
        character_id,
        character,
        cached_values,
        updates,
        cache_updates
      )

    {updates, cache_updates}
  end

  # Check for online status changes
  defp check_online_update(map_id, character_id, character, cached_values, updates, cache_updates) do
    online_key = "map:#{map_id}:character:#{character_id}:online"
    old_online = Map.get(cached_values, online_key)

    if character.online != old_online do
      {
        [{:character_online, %{online: character.online}} | updates],
        Map.put(cache_updates, online_key, character.online)
      }
    else
      {updates, cache_updates}
    end
  end

  # Check for ship changes
  defp check_ship_update(map_id, character_id, character, cached_values, updates, cache_updates) do
    ship_type_key = "map:#{map_id}:character:#{character_id}:ship_type_id"
    ship_name_key = "map:#{map_id}:character:#{character_id}:ship_name"
    old_ship_type_id = Map.get(cached_values, ship_type_key)
    old_ship_name = Map.get(cached_values, ship_name_key)

    if character.ship != old_ship_type_id or character.ship_name != old_ship_name do
      {
        [
          {:character_ship,
           %{
             ship: character.ship,
             ship_name: character.ship_name,
             ship_item_id: character.ship_item_id
           }}
          | updates
        ],
        cache_updates
        |> Map.put(ship_type_key, character.ship)
        |> Map.put(ship_name_key, character.ship_name)
      }
    else
      {updates, cache_updates}
    end
  end

  # Check for location changes with race condition detection
  defp check_location_update(
         map_id,
         character_id,
         character,
         cached_values,
         updates,
         cache_updates
       ) do
    solar_system_key = "map:#{map_id}:character:#{character_id}:solar_system_id"
    station_key = "map:#{map_id}:character:#{character_id}:station_id"
    structure_key = "map:#{map_id}:character:#{character_id}:structure_id"
    location_timestamp_key = "map:#{map_id}:character:#{character_id}:location_updated_at"

    old_solar_system_id = Map.get(cached_values, solar_system_key)
    old_station_id = Map.get(cached_values, station_key)
    old_structure_id = Map.get(cached_values, structure_key)
    old_timestamp = Map.get(cached_values, location_timestamp_key)

    if character.solar_system_id != old_solar_system_id ||
         character.structure_id != old_structure_id ||
         character.station_id != old_station_id do
      # Race condition detection
      {:ok, current_cached_timestamp} =
        WandererApp.Cache.lookup(location_timestamp_key)

      race_detected =
        !is_nil(old_timestamp) && !is_nil(current_cached_timestamp) &&
          old_timestamp != current_cached_timestamp

      if race_detected do
        Logger.warning(
          "[CharacterTracking] Race condition detected for character #{character_id} on map #{map_id}: " <>
            "cache was modified between read (#{inspect(old_timestamp)}) and write (#{inspect(current_cached_timestamp)})"
        )

        :telemetry.execute(
          [:wanderer_app, :character, :location_update, :race_condition],
          %{system_time: System.system_time()},
          %{
            character_id: character_id,
            map_id: map_id,
            old_system: old_solar_system_id,
            new_system: character.solar_system_id,
            old_timestamp: old_timestamp,
            current_timestamp: current_cached_timestamp
          }
        )
      end

      now = DateTime.utc_now()

      {
        [
          {:character_location,
           %{
             solar_system_id: character.solar_system_id,
             structure_id: character.structure_id,
             station_id: character.station_id
           }, %{solar_system_id: old_solar_system_id}}
          | updates
        ],
        cache_updates
        |> Map.put(solar_system_key, character.solar_system_id)
        |> Map.put(station_key, character.station_id)
        |> Map.put(structure_key, character.structure_id)
        |> Map.put(location_timestamp_key, now)
      }
    else
      {updates, cache_updates}
    end
  end

  # Check for alliance changes
  defp check_alliance_update(
         map_id,
         character_id,
         character,
         cached_values,
         updates,
         cache_updates
       ) do
    alliance_key = "map:#{map_id}:character:#{character_id}:alliance_id"
    old_alliance_id = Map.get(cached_values, alliance_key)

    if character.alliance_id != old_alliance_id do
      {
        [{:character_alliance, %{alliance_id: character.alliance_id}} | updates],
        Map.put(cache_updates, alliance_key, character.alliance_id)
      }
    else
      {updates, cache_updates}
    end
  end

  # Check for corporation changes
  defp check_corporation_update(
         map_id,
         character_id,
         character,
         cached_values,
         updates,
         cache_updates
       ) do
    corporation_key = "map:#{map_id}:character:#{character_id}:corporation_id"
    old_corporation_id = Map.get(cached_values, corporation_key)

    if character.corporation_id != old_corporation_id do
      {
        [{:character_corporation, %{corporation_id: character.corporation_id}} | updates],
        Map.put(cache_updates, corporation_key, character.corporation_id)
      }
    else
      {updates, cache_updates}
    end
  end

  defp update_location(
         _state,
         _character_id,
         _location,
         %{solar_system_id: nil}
       ),
       do: :ok

  defp update_location(
         %{map: map, map_id: map_id, map_opts: map_opts} =
           _state,
         character_id,
         location,
         old_location
       ) do
    scopes = get_effective_scopes(map)

    is_valid =
      ConnectionsImpl.is_connection_valid(
        scopes,
        old_location.solar_system_id,
        location.solar_system_id
      )

    Logger.debug(
      "[CharacterTracking] update_location: map=#{map_id}, " <>
        "from=#{old_location.solar_system_id}, to=#{location.solar_system_id}, " <>
        "scopes=#{inspect(scopes)}, map.scopes=#{inspect(map[:scopes])}, " <>
        "map.scope=#{inspect(map[:scope])}, is_valid=#{is_valid}"
    )

    case is_valid do
      true ->
        # Connection is valid (at least one system matches scopes)
        # Add systems that match the map's scopes - individual system filtering by maybe_add_system
        case SystemsImpl.maybe_add_system(map_id, location, old_location, map_opts, scopes) do
          :ok ->
            :ok

          {:error, error} ->
            Logger.error(
              "[CharacterTracking] Failed to add new location system #{location.solar_system_id} for character #{character_id} on map #{map_id}: #{inspect(error)}"
            )
        end

        # Add old location system (in case it wasn't on map) - only if it matches scopes
        case SystemsImpl.maybe_add_system(map_id, old_location, location, map_opts, scopes) do
          :ok ->
            :ok

          {:error, error} ->
            Logger.error(
              "[CharacterTracking] Failed to add old location system #{old_location.solar_system_id} for character #{character_id} on map #{map_id}: #{inspect(error)}"
            )
        end

        # Add connection if character is in space
        if is_character_in_space?(location) do
          case ConnectionsImpl.maybe_add_connection(
                 map_id,
                 location,
                 old_location,
                 character_id,
                 false,
                 nil
               ) do
            :ok ->
              :ok

            {:error, error} ->
              Logger.error(
                "[CharacterTracking] Failed to add connection for character #{character_id} on map #{map_id}: #{inspect(error)}"
              )

              :ok
          end
        end

      _ ->
        :ok
    end
  end

  defp is_character_in_space?(%{station_id: station_id, structure_id: structure_id} = _location),
    do: is_nil(structure_id) && is_nil(station_id)

  @doc """
  Get effective scopes from map, with fallback to legacy scope.
  Returns the scopes array that should be used for filtering.
  """
  def get_effective_scopes(%{scopes: scopes}) when is_list(scopes) and scopes != [], do: scopes

  def get_effective_scopes(%{scope: scope}) when is_atom(scope),
    do: legacy_scope_to_scopes(scope)

  def get_effective_scopes(_), do: [:wormholes]

  # Legacy scope to new scopes array conversion
  defp legacy_scope_to_scopes(:wormholes), do: [:wormholes]
  defp legacy_scope_to_scopes(:stargates), do: [:hi, :low, :null, :pochven]
  defp legacy_scope_to_scopes(:all), do: [:wormholes, :hi, :low, :null, :pochven]
  defp legacy_scope_to_scopes(:none), do: []
  defp legacy_scope_to_scopes(_), do: [:wormholes]

  defp add_character(
         map_id,
         %{id: character_id} = map_character,
         track_character
       ) do
    Task.start_link(fn ->
      with :ok <- map_id |> WandererApp.Map.add_character(map_character),
           {:ok, _settings} <-
             WandererApp.MapCharacterSettingsRepo.create(%{
               character_id: character_id,
               map_id: map_id,
               tracked: track_character
             }) do
        Impl.broadcast!(map_id, :character_added, map_character)

        # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
        WandererApp.ExternalEvents.broadcast(map_id, :character_added, map_character)
        :telemetry.execute([:wanderer_app, :map, :character, :added], %{count: 1})
        :ok
      else
        {:error, :not_found} ->
          :ok

        _error ->
          Impl.broadcast!(map_id, :character_added, map_character)

          # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
          WandererApp.ExternalEvents.broadcast(map_id, :character_added, map_character)
          :ok
      end
    end)
  end

  defp track_character(map_id, character_id) do
    {:ok, character} =
      WandererApp.Character.get_character(character_id)

    add_character(map_id, character, true)

    WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
      map_id: map_id,
      track: true
    })
  end

  # Broadcasts permission update to trigger LiveView refresh for the character's user.
  # This is called when a character's corporation or alliance changes, ensuring
  # users are kicked off maps they no longer have access to.
  defp broadcast_permission_update(character_id) do
    case WandererApp.Character.get_character(character_id) do
      {:ok, %{eve_id: eve_id}} when not is_nil(eve_id) ->
        Phoenix.PubSub.broadcast(
          WandererApp.PubSub,
          "character:#{eve_id}",
          :update_permissions
        )

      _ ->
        :ok
    end
  end
end
