defmodule WandererApp.Map.Server.CharactersImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.Server.{Impl, ConnectionsImpl, SystemsImpl}

  def add_character(%{map_id: map_id} = state, %{id: character_id} = character, track_character) do
    Task.start_link(fn ->
      with :ok <- map_id |> WandererApp.Map.add_character(character),
           {:ok, _settings} <-
             WandererApp.MapCharacterSettingsRepo.create(%{
               character_id: character_id,
               map_id: map_id,
               tracked: track_character
             }),
           {:ok, character} <- WandererApp.Character.get_character(character_id) do
        Impl.broadcast!(map_id, :character_added, character)

        # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
        WandererApp.ExternalEvents.broadcast(map_id, :character_added, character)
        :telemetry.execute([:wanderer_app, :map, :character, :added], %{count: 1})
        :ok
      else
        {:error, :not_found} ->
          :ok

        _error ->
          {:ok, character} = WandererApp.Character.get_character(character_id)
          Impl.broadcast!(map_id, :character_added, character)

          # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
          WandererApp.ExternalEvents.broadcast(map_id, :character_added, character)
          :ok
      end
    end)

    state
  end

  def remove_character(map_id, character_id) do
    Task.start_link(fn ->
      with :ok <- WandererApp.Map.remove_character(map_id, character_id),
           {:ok, character} <- WandererApp.Character.get_map_character(map_id, character_id) do
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

  def update_tracked_characters(map_id) do
    Task.start_link(fn ->
      {:ok, all_map_tracked_character_ids} =
        map_id
        |> WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_all()
        |> case do
          {:ok, settings} -> {:ok, settings |> Enum.map(&Map.get(&1, :character_id))}
          _ -> {:ok, []}
        end

      {:ok, actual_map_tracked_characters} =
        WandererApp.Cache.lookup("maps:#{map_id}:tracked_characters", [])

      characters_to_remove = actual_map_tracked_characters -- all_map_tracked_character_ids

      WandererApp.Cache.insert_or_update(
        "map_#{map_id}:invalidate_character_ids",
        characters_to_remove,
        fn ids ->
          (ids ++ characters_to_remove) |> Enum.uniq()
        end
      )

      :ok
    end)
  end

  def untrack_characters(map_id, character_ids) do
    character_ids
    |> Enum.each(fn character_id ->
      character_map_active = is_character_map_active?(map_id, character_id)

      character_map_active
      |> untrack_character(map_id, character_id)
    end)
  end

  def untrack_character(true, map_id, character_id) do
    WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
      map_id: map_id,
      track: false
    })
  end

  def untrack_character(_is_character_map_active, _map_id, character_id) do
    :ok
  end

  def is_character_map_active?(map_id, character_id) do
    case WandererApp.Character.get_character_state(character_id) do
      {:ok, %{active_maps: active_maps}} ->
        map_id in active_maps

      _ ->
        false
    end
  end

  def cleanup_characters(map_id, owner_id) do
    {:ok, invalidate_character_ids} =
      WandererApp.Cache.get_and_remove(
        "map_#{map_id}:invalidate_character_ids",
        []
      )

    if Enum.empty?(invalidate_character_ids) do
      :ok
    else
      {:ok, %{acls: acls}} =
        WandererApp.MapRepo.get(map_id,
          acls: [
            :owner_id,
            members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
          ]
        )

      process_invalidate_characters(invalidate_character_ids, map_id, owner_id, acls)
    end
  end

  defp process_invalidate_characters(invalidate_character_ids, map_id, owner_id, acls) do
    invalidate_character_ids
    |> Task.async_stream(
      fn character_id ->
        character_id
        |> WandererApp.Character.get_character()
        |> case do
          {:ok, %{user_id: nil}} ->
            {:remove_character, character_id}

          {:ok, character} ->
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
                {:remove_character, character_id}

              %{track_character: false} ->
                {:remove_character, character_id}

              _ ->
                :ok
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
      {:ok, {:remove_character, character_id}}, acc ->
        [character_id | acc]

      {:ok, _result}, acc ->
        acc

      {:error, reason}, acc ->
        Logger.error("Error in cleanup_characters: #{inspect(reason)}")
        acc
    end)
    |> case do
      [] -> :ok
      character_ids_to_remove -> remove_and_untrack_characters(map_id, character_ids_to_remove)
    end
  end

  defp remove_and_untrack_characters(map_id, character_ids) do
    Logger.debug(fn ->
      "Map #{map_id} - remove and untrack characters #{inspect(character_ids)}"
    end)

    map_id
    |> untrack_characters(character_ids)

    map_id
    |> WandererApp.MapCharacterSettingsRepo.get_by_map_filtered(character_ids)
    |> case do
      {:ok, settings} ->
        settings
        |> Enum.each(fn s ->
          WandererApp.MapCharacterSettingsRepo.destroy!(s)
          remove_character(map_id, s.character_id)
        end)

      _ ->
        :ok
    end
  end

  def track_characters(_map_id, []), do: :ok

  def track_characters(map_id, [character_id | rest]) do
    track_character(map_id, character_id)
    track_characters(map_id, rest)
  end

  def update_characters(%{map_id: map_id} = state) do
    try do
      {:ok, presence_character_ids} =
        WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])

      presence_character_ids
      |> Task.async_stream(
        fn character_id ->
          character_updates =
            maybe_update_online(map_id, character_id) ++
              maybe_update_tracking_status(map_id, character_id) ++
              maybe_update_location(map_id, character_id) ++
              maybe_update_ship(map_id, character_id) ++
              maybe_update_alliance(map_id, character_id) ++
              maybe_update_corporation(map_id, character_id)

          character_updates
          |> Enum.filter(fn update -> update != :skip end)
          |> Enum.map(fn update ->
            update
            |> case do
              {:character_location, location_info, old_location_info} ->
                update_location(
                  character_id,
                  location_info,
                  old_location_info,
                  state
                )

                :broadcast

              {:character_ship, _info} ->
                :broadcast

              {:character_online, _info} ->
                :broadcast

              {:character_tracking, _info} ->
                :broadcast

              {:character_alliance, _info} ->
                WandererApp.Cache.insert_or_update(
                  "map_#{map_id}:invalidate_character_ids",
                  [character_id],
                  fn ids ->
                    [character_id | ids] |> Enum.uniq()
                  end
                )

                :broadcast

              {:character_corporation, _info} ->
                WandererApp.Cache.insert_or_update(
                  "map_#{map_id}:invalidate_character_ids",
                  [character_id],
                  fn ids ->
                    [character_id | ids] |> Enum.uniq()
                  end
                )

                :broadcast

              _ ->
                :skip
            end
          end)
          |> Enum.filter(fn update -> update != :skip end)
          |> Enum.uniq()
          |> Enum.each(fn update ->
            case update do
              :broadcast ->
                update_character(map_id, character_id)

              _ ->
                :ok
            end
          end)

          :ok
        end,
        timeout: :timer.seconds(15),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn
        {:ok, _result} -> :ok
        {:error, reason} -> Logger.error("Error in update_characters: #{inspect(reason)}")
      end)
    rescue
      e ->
        Logger.error("""
        [Map Server] update_characters => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end
  end

  defp update_character(map_id, character_id) do
    {:ok, character} = WandererApp.Character.get_map_character(map_id, character_id)
    Impl.broadcast!(map_id, :character_updated, character)

    # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
    WandererApp.ExternalEvents.broadcast(map_id, :character_updated, character)
  end

  defp update_location(
         character_id,
         location,
         old_location,
         %{map: map, map_id: map_id, rtree_name: rtree_name, map_opts: map_opts} = _state
       ) do
    start_solar_system_id =
      WandererApp.Cache.take("map:#{map_id}:character:#{character_id}:start_solar_system_id")

    case is_nil(old_location.solar_system_id) and
           is_nil(start_solar_system_id) and
           ConnectionsImpl.can_add_location(map.scope, location.solar_system_id) do
      true ->
        :ok = SystemsImpl.maybe_add_system(map_id, location, nil, rtree_name, map_opts)

      _ ->
        if is_nil(start_solar_system_id) || start_solar_system_id == old_location.solar_system_id do
          ConnectionsImpl.is_connection_valid(
            map.scope,
            old_location.solar_system_id,
            location.solar_system_id
          )
          |> case do
            true ->
              :ok =
                SystemsImpl.maybe_add_system(map_id, location, old_location, rtree_name, map_opts)

              :ok =
                SystemsImpl.maybe_add_system(map_id, old_location, location, rtree_name, map_opts)

              if is_character_in_space?(location) do
                :ok =
                  ConnectionsImpl.maybe_add_connection(
                    map_id,
                    location,
                    old_location,
                    character_id,
                    false,
                    nil
                  )
              end

            _ ->
              :ok
          end
        else
          # skip adding connection or system if character just started tracking on the map
          :ok
        end
    end
  end

  defp is_character_in_space?(%{station_id: station_id, structure_id: structure_id} = location) do
    is_nil(structure_id) and is_nil(station_id)
  end

  defp track_character(map_id, character_id) do
    {:ok, character} =
      WandererApp.Character.get_map_character(map_id, character_id, not_present: true)

    WandererApp.Cache.delete("character:#{character.id}:tracking_paused")

    add_character(%{map_id: map_id}, character, true)

    WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
      map_id: map_id,
      track: true,
      track_online: true,
      track_location: true,
      track_ship: true,
      solar_system_id: character.solar_system_id
    })
  end

  defp maybe_update_online(map_id, character_id) do
    with {:ok, old_online} <-
           WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:online"),
         {:ok, %{online: online}} <-
           WandererApp.Character.get_character(character_id) do
      case old_online != online do
        true ->
          WandererApp.Cache.insert(
            "map:#{map_id}:character:#{character_id}:online",
            online
          )

          [{:character_online, %{online: online}}]

        _ ->
          [:skip]
      end
    else
      error ->
        Logger.error("Failed to update online: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp maybe_update_tracking_status(map_id, character_id) do
    with {:ok, old_tracking_paused} <-
           WandererApp.Cache.lookup(
             "map:#{map_id}:character:#{character_id}:tracking_paused",
             false
           ),
         {:ok, tracking_paused} <-
           WandererApp.Cache.lookup("character:#{character_id}:tracking_paused", false) do
      case old_tracking_paused != tracking_paused do
        true ->
          WandererApp.Cache.insert(
            "map:#{map_id}:character:#{character_id}:tracking_paused",
            tracking_paused
          )

          [{:character_tracking, %{tracking_paused: tracking_paused}}]

        _ ->
          [:skip]
      end
    else
      error ->
        Logger.error("Failed to update character_tracking: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp maybe_update_ship(map_id, character_id) do
    with {:ok, old_ship_type_id} <-
           WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:ship_type_id"),
         {:ok, old_ship_name} <-
           WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:ship_name"),
         {:ok, %{ship: ship_type_id, ship_name: ship_name, ship_item_id: ship_item_id}} <-
           WandererApp.Character.get_character(character_id) do
      case old_ship_type_id != ship_type_id or
             old_ship_name != ship_name do
        true ->
          WandererApp.Cache.insert(
            "map:#{map_id}:character:#{character_id}:ship_type_id",
            ship_type_id
          )

          WandererApp.Cache.insert(
            "map:#{map_id}:character:#{character_id}:ship_name",
            ship_name
          )

          [
            {:character_ship,
             %{ship: ship_type_id, ship_name: ship_name, ship_item_id: ship_item_id}}
          ]

        _ ->
          [:skip]
      end
    else
      error ->
        Logger.error("Failed to update ship: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp maybe_update_location(map_id, character_id) do
    {:ok, old_solar_system_id} =
      WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:solar_system_id")

    {:ok, old_station_id} =
      WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:station_id")

    {:ok, old_structure_id} =
      WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:structure_id")

    {:ok, %{solar_system_id: solar_system_id, structure_id: structure_id, station_id: station_id}} =
      WandererApp.Character.get_character(character_id)

    WandererApp.Cache.insert(
      "map:#{map_id}:character:#{character_id}:solar_system_id",
      solar_system_id
    )

    WandererApp.Cache.insert(
      "map:#{map_id}:character:#{character_id}:station_id",
      station_id
    )

    WandererApp.Cache.insert(
      "map:#{map_id}:character:#{character_id}:structure_id",
      structure_id
    )

    if solar_system_id != old_solar_system_id || structure_id != old_structure_id ||
         station_id != old_station_id do
      [
        {:character_location,
         %{
           solar_system_id: solar_system_id,
           structure_id: structure_id,
           station_id: station_id
         }, %{solar_system_id: old_solar_system_id}}
      ]
    else
      [:skip]
    end
  end

  defp maybe_update_alliance(map_id, character_id) do
    with {:ok, old_alliance_id} <-
           WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:alliance_id"),
         {:ok, %{alliance_id: alliance_id}} <-
           WandererApp.Character.get_character(character_id) do
      case old_alliance_id != alliance_id do
        true ->
          WandererApp.Cache.insert(
            "map:#{map_id}:character:#{character_id}:alliance_id",
            alliance_id
          )

          [{:character_alliance, %{alliance_id: alliance_id}}]

        _ ->
          [:skip]
      end
    else
      error ->
        Logger.error("Failed to update alliance: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp maybe_update_corporation(map_id, character_id) do
    with {:ok, old_corporation_id} <-
           WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:corporation_id"),
         {:ok, %{corporation_id: corporation_id}} <-
           WandererApp.Character.get_character(character_id) do
      case old_corporation_id != corporation_id do
        true ->
          WandererApp.Cache.insert(
            "map:#{map_id}:character:#{character_id}:corporation_id",
            corporation_id
          )

          [{:character_corporation, %{corporation_id: corporation_id}}]

        _ ->
          [:skip]
      end
    else
      error ->
        Logger.error("Failed to update corporation: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end
end
