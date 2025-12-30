defmodule WandererApp.Map.Server.SystemsImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.Server.Impl
  alias WandererApp.Map.Server.SignaturesImpl

  @ddrt Application.compile_env(:wanderer_app, :ddrt)
  @system_auto_expire_minutes 15
  @system_inactive_timeout :timer.minutes(15)

  def init_last_activity_cache(map_id, systems_last_activity) do
    systems_last_activity
    |> Enum.each(fn {system_id, last_activity} ->
      WandererApp.Cache.put(
        "map_#{map_id}:system_#{system_id}:last_activity",
        last_activity,
        ttl: @system_inactive_timeout
      )
    end)
  end

  def init_map_systems(_map_id, [] = _systems), do: :ok

  def init_map_systems(map_id, systems) do
    systems
    |> Enum.each(fn %{id: system_id, solar_system_id: solar_system_id} = system ->
      @ddrt.insert(
        {solar_system_id, WandererApp.Map.PositionCalculator.get_system_bounding_rect(system)},
        "rtree_#{map_id}"
      )

      WandererApp.Cache.put(
        "map_#{map_id}:system_#{system_id}:last_activity",
        DateTime.utc_now(),
        ttl: @system_inactive_timeout
      )
    end)
  end

  def add_system(
        map_id,
        %{
          solar_system_id: solar_system_id
        } = system_info,
        user_id,
        character_id,
        _opts
      ) do
    map_id
    |> WandererApp.Map.check_location(%{solar_system_id: solar_system_id})
    |> case do
      {:ok, _location} ->
        do_add_system(map_id, system_info, user_id, character_id)

      {:error, :already_exists} ->
        :ok
    end
  end

  def paste_systems(
        map_id,
        systems,
        user_id,
        character_id,
        opts
      ) do
    systems
    |> Enum.each(fn %{
                      "id" => solar_system_id,
                      "position" => coordinates
                    } = system ->
      solar_system_id = solar_system_id |> String.to_integer()

      case map_id |> WandererApp.Map.check_location(%{solar_system_id: solar_system_id}) do
        {:ok, _location} ->
          if opts |> Keyword.get(:add_not_existing, true) do
            do_add_system(
              map_id,
              %{solar_system_id: solar_system_id, coordinates: coordinates, extra_info: system},
              user_id,
              character_id
            )
          else
            :ok
          end

        {:error, :already_exists} ->
          if opts |> Keyword.get(:update_existing, false) do
            :ok
          else
            :ok
          end
      end
    end)
  end

  def add_system_comment(
        map_id,
        %{
          solar_system_id: solar_system_id,
          text: text
        } = _comment_info,
        _user_id,
        character_id
      ) do
    system =
      WandererApp.Map.find_system_by_location(map_id, %{
        solar_system_id: solar_system_id
      })

    {:ok, comment} =
      WandererApp.MapSystemCommentRepo.create(%{
        system_id: system.id,
        character_id: character_id,
        text: text
      })

    comment =
      comment
      |> Ash.load!([:character])

    Impl.broadcast!(map_id, :system_comment_added, %{
      solar_system_id: solar_system_id,
      comment: comment
    })
  end

  def remove_system_comment(
        map_id,
        comment_id,
        _user_id,
        _character_id
      ) do
    {:ok, %{system_id: system_id} = comment} =
      WandererApp.MapSystemCommentRepo.get_by_id(comment_id)

    {:ok, system} = WandererApp.Api.MapSystem.by_id(system_id)

    :ok = WandererApp.MapSystemCommentRepo.destroy(comment)

    Impl.broadcast!(map_id, :system_comment_removed, %{
      solar_system_id: system.solar_system_id,
      comment_id: comment_id
    })
  end

  def cleanup_systems(map_id) do
    # Defensive check: Skip cleanup if cache appears invalid
    # This prevents incorrectly deleting systems when cache is empty due to
    # race conditions during map restart or cache corruption
    case WandererApp.Map.get_map(map_id) do
      {:error, :not_found} ->
        Logger.warning(
          "[cleanup_systems] Skipping map #{map_id} - cache miss detected, " <>
            "map data not found in cache"
        )

        :telemetry.execute(
          [:wanderer_app, :map, :cleanup_systems, :cache_miss],
          %{system_time: System.system_time()},
          %{map_id: map_id}
        )

        :ok

      {:ok, _map} ->
        do_cleanup_systems(map_id)
    end
  end

  defp do_cleanup_systems(map_id) do
    expired_systems =
      map_id
      |> WandererApp.Map.list_systems!()
      |> Enum.filter(fn %{
                          id: system_id,
                          visible: system_visible,
                          locked: system_locked,
                          solar_system_id: solar_system_id
                        } = _system ->
        last_updated_time =
          WandererApp.Cache.get("map_#{map_id}:system_#{system_id}:last_activity")

        if system_visible and not system_locked and
             (is_nil(last_updated_time) or
                DateTime.diff(DateTime.utc_now(), last_updated_time, :minute) >=
                  @system_auto_expire_minutes) do
          no_active_connections? =
            map_id
            |> WandererApp.Map.find_connections(solar_system_id)
            |> Enum.empty?()

          no_active_characters? =
            map_id |> WandererApp.Map.get_system_characters(solar_system_id) |> Enum.empty?()

          no_active_pings? =
            map_id |> WandererApp.MapPingsRepo.get_by_map_and_system!(system_id) |> Enum.empty?()

          no_active_connections? and no_active_characters? and no_active_pings?
        else
          false
        end
      end)
      |> Enum.map(& &1.solar_system_id)

    if expired_systems |> Enum.empty?() |> Kernel.not() do
      delete_systems(map_id, expired_systems, nil, nil)
    end
  end

  def update_system_name(
        map_id,
        update
      ),
      do: update_system(map_id, :update_name, [:name], update)

  def update_system_description(
        map_id,
        update
      ),
      do: update_system(map_id, :update_description, [:description], update)

  def update_system_status(
        map_id,
        update
      ),
      do: update_system(map_id, :update_status, [:status], update)

  def update_system_tag(
        map_id,
        update
      ),
      do: update_system(map_id, :update_tag, [:tag], update)

  def update_system_temporary_name(
        map_id,
        update
      ),
      do: update_system(map_id, :update_temporary_name, [:temporary_name], update)

  def update_system_custom_name(
        map_id,
        update
      ),
      do: update_system(map_id, :update_custom_name, [:custom_name], update)

  def update_system_locked(
        map_id,
        update
      ),
      do: update_system(map_id, :update_locked, [:locked], update)

  def update_system_labels(
        map_id,
        update
      ),
      do: update_system(map_id, :update_labels, [:labels], update)

  def update_system_linked_sig_eve_id(
        map_id,
        update
      ),
      do: update_system(map_id, :update_linked_sig_eve_id, [:linked_sig_eve_id], update)

  def update_system_position(
        map_id,
        update
      ),
      do:
        update_system(
          map_id,
          :update_position,
          [:position_x, :position_y],
          update,
          fn updated_system ->
            @ddrt.update(
              updated_system.solar_system_id,
              WandererApp.Map.PositionCalculator.get_system_bounding_rect(updated_system),
              "rtree_#{map_id}"
            )
          end
        )

  def add_hub(
        map_id,
        hub_info
      ) do
    with :ok <- WandererApp.Map.add_hub(map_id, hub_info),
         {:ok, hubs} = map_id |> WandererApp.Map.list_hubs(),
         {:ok, _} <-
           WandererApp.MapRepo.update_hubs(map_id, hubs) do
      Impl.broadcast!(map_id, :update_map, %{hubs: hubs})
    else
      error ->
        Logger.error("Failed to add hub: #{inspect(error, pretty: true)}")
        :ok
    end
  end

  def remove_hub(
        map_id,
        hub_info
      ) do
    with :ok <- WandererApp.Map.remove_hub(map_id, hub_info),
         {:ok, hubs} = map_id |> WandererApp.Map.list_hubs(),
         {:ok, _} <-
           WandererApp.MapRepo.update_hubs(map_id, hubs) do
      Impl.broadcast!(map_id, :update_map, %{hubs: hubs})
    else
      error ->
        Logger.error("Failed to remove hub: #{inspect(error, pretty: true)}")
        :ok
    end
  end

  def delete_systems(
        map_id,
        removed_ids,
        user_id,
        character_id
      ) do
    filtered_ids =
      removed_ids
      |> Enum.map(fn solar_system_id ->
        WandererApp.Map.find_system_by_location(map_id, %{solar_system_id: solar_system_id})
      end)
      |> Enum.filter(fn system -> not is_nil(system) && not system.locked end)
      |> Enum.map(&{&1.solar_system_id, &1.id})

    filtered_ids
    |> Enum.each(fn {solar_system_id, system_id} ->
      map_id
      |> WandererApp.MapSystemRepo.remove_from_map(solar_system_id)
      |> case do
        {:ok, _result} ->
          :ok = WandererApp.Map.remove_system(map_id, solar_system_id)
          @ddrt.delete([solar_system_id], "rtree_#{map_id}")
          Impl.broadcast!(map_id, :systems_removed, [solar_system_id])

          # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
          Logger.debug(fn ->
            "SystemsImpl.delete_systems calling ExternalEvents.broadcast for map #{map_id}, system: #{solar_system_id}"
          end)

          # For consistency, include basic fields even for deleted systems
          WandererApp.ExternalEvents.broadcast(map_id, :deleted_system, %{
            solar_system_id: solar_system_id,
            # System is deleted, name not available
            name: nil,
            position_x: nil,
            position_y: nil
          })

          track_systems_removed(map_id, user_id, character_id, [solar_system_id])
          remove_system_connections(map_id, [solar_system_id])

          try do
            cleanup_linked_signatures(map_id, [solar_system_id])
          rescue
            e ->
              Logger.error("Failed to cleanup linked signature: #{inspect(e)}")
          end

          try do
            cleanup_linked_system_sig_eve_ids(map_id, [system_id])
          rescue
            e ->
              Logger.error("Failed to cleanup system linked sig eve ids: #{inspect(e)}")
          end

          :ok

        {:error, error} ->
          Logger.error("Failed to remove system from map: #{inspect(error, pretty: true)}")
          :ok
      end
    end)
  end

  defp track_systems_removed(map_id, user_id, character_id, removed_solar_system_ids)
       when not is_nil(user_id) and not is_nil(character_id) do
    WandererApp.User.ActivityTracker.track_map_event(:systems_removed, %{
      character_id: character_id,
      user_id: user_id,
      map_id: map_id,
      solar_system_ids: removed_solar_system_ids
    })
    |> case do
      {:ok, _} -> :ok
      error -> Logger.error("Failed to track systems removed: #{inspect(error)}")
    end
  end

  defp track_systems_removed(_map_id, _user_id, _character_id, _removed_solar_system_ids), do: :ok

  defp remove_system_connections(map_id, solar_system_ids_to_remove) do
    connections_to_remove =
      solar_system_ids_to_remove
      |> Enum.map(fn solar_system_id ->
        WandererApp.Map.find_connections(map_id, solar_system_id)
      end)
      |> List.flatten()
      |> Enum.uniq_by(& &1.id)

    connections_to_remove
    |> Enum.each(fn connection ->
      try do
        Logger.debug(fn -> "Removing connection from map: #{inspect(connection)}" end)

        # Audit logging for cascade deletion (no user/character context)
        WandererApp.User.ActivityTracker.track_map_event(:map_connection_removed, %{
          character_id: nil,
          user_id: nil,
          map_id: map_id,
          solar_system_source_id: connection.solar_system_source,
          solar_system_target_id: connection.solar_system_target
        })

        :ok = WandererApp.MapConnectionRepo.destroy(map_id, connection)
        :ok = WandererApp.Map.remove_connection(map_id, connection)
        Impl.broadcast!(map_id, :remove_connections, [connection])
      rescue
        e ->
          Logger.error("Failed to remove connection: #{inspect(e)}")
      end
    end)
  end

  # When destination systems are deleted, unlink signatures instead of destroying them.
  # This preserves the user's scan data while removing the stale link.
  defp cleanup_linked_signatures(map_id, removed_solar_system_ids) do
    # Group signatures by their source system for efficient broadcasting
    signatures_by_system =
      removed_solar_system_ids
      |> Enum.flat_map(fn solar_system_id ->
        WandererApp.Api.MapSystemSignature.by_linked_system_id!(solar_system_id)
      end)
      |> Enum.uniq_by(& &1.id)
      |> Enum.group_by(fn sig -> sig.system_id end)

    signatures_by_system
    |> Enum.each(fn {_system_id, signatures} ->
      signatures
      |> Enum.each(fn sig ->
        try do
          {:ok, %{eve_id: eve_id, system: system}} = sig |> Ash.load([:system])

          # Clear the linked_system_id instead of destroying the signature
          # Use the wrapper to log unlink operations
          case SignaturesImpl.update_signature_linked_system(sig, %{
                 linked_system_id: nil
               }) do
            {:ok, _updated_sig} ->
              case system do
                nil ->
                  Logger.debug(fn ->
                    "[cleanup_linked_signatures] signature #{eve_id} unlinked (parent system already deleted)"
                  end)

                %{solar_system_id: solar_system_id} ->
                  Logger.debug(fn ->
                    "[cleanup_linked_signatures] unlinked signature #{eve_id} in system #{solar_system_id}"
                  end)

                  # Audit logging for cascade unlink (no user/character context)
                  WandererApp.User.ActivityTracker.track_map_event(:signatures_unlinked, %{
                    character_id: nil,
                    user_id: nil,
                    map_id: map_id,
                    solar_system_id: solar_system_id,
                    signatures: [eve_id]
                  })
              end

            {:error, error} ->
              Logger.error(
                "[cleanup_linked_signatures] Failed to unlink signature #{sig.eve_id}: #{inspect(error)}"
              )
          end
        rescue
          e ->
            Logger.error("Failed to cleanup linked signature: #{inspect(e)}")
        end
      end)

      # Broadcast once per source system after all its signatures are processed
      case List.first(signatures) do
        %{system: %{solar_system_id: solar_system_id}} ->
          Impl.broadcast!(map_id, :signatures_updated, solar_system_id)

        _ ->
          # Try to get the system info if not preloaded
          case List.first(signatures) |> Ash.load([:system]) do
            {:ok, %{system: %{solar_system_id: solar_system_id}}} ->
              Impl.broadcast!(map_id, :signatures_updated, solar_system_id)

            _ ->
              :ok
          end
      end
    end)
  end

  defp cleanup_linked_system_sig_eve_ids(map_id, system_ids_to_remove) do
    linked_system_ids =
      system_ids_to_remove
      |> Enum.map(fn system_id ->
        WandererApp.Api.MapSystemSignature.by_system_id!(system_id)
        |> Enum.filter(fn s -> not is_nil(s.linked_system_id) end)
        |> Enum.map(fn s -> s.linked_system_id end)
      end)
      |> List.flatten()
      |> Enum.uniq()

    linked_system_ids
    |> Enum.each(fn linked_system_id ->
      update_system(map_id, :update_linked_sig_eve_id, [:linked_sig_eve_id], %{
        solar_system_id: linked_system_id,
        linked_sig_eve_id: nil
      })
    end)
  end

  def maybe_add_system(map_id, location, old_location, map_opts, scopes \\ nil)

  def maybe_add_system(map_id, location, old_location, map_opts, scopes)
      when not is_nil(location) do
    alias WandererApp.Map.Server.ConnectionsImpl

    # Check if the system matches the map's configured scopes before adding
    should_add =
      case scopes do
        nil ->
          true

        [] ->
          true

        scopes when is_list(scopes) ->
          # First check: does the location directly match scopes?
          if ConnectionsImpl.can_add_location(scopes, location.solar_system_id) do
            true
          else
            # Second check: wormhole border behavior
            # If :wormholes scope is enabled AND old_location is a wormhole,
            # allow this system to be added as a border system (so you can see
            # where your wormhole exits to)
            wormhole_border_from_wh_space =
              :wormholes in scopes and
                not is_nil(old_location) and
                ConnectionsImpl.can_add_location([:wormholes], old_location.solar_system_id)

            # Third check: k-space wormhole connection
            # If :wormholes scope is enabled AND there's no stargate between the systems,
            # this is a wormhole connection through k-space - add both systems
            kspace_wormhole_connection =
              :wormholes in scopes and
                not is_nil(old_location) and
                not is_nil(old_location.solar_system_id) and
                ConnectionsImpl.is_kspace_wormhole_connection?(
                  old_location.solar_system_id,
                  location.solar_system_id
                )

            wormhole_border_from_wh_space or kspace_wormhole_connection
          end
      end

    if should_add do
      do_add_system_from_location(map_id, location, old_location, map_opts)
    else
      # System filtered out by scope settings - this is expected behavior
      :ok
    end
  end

  def maybe_add_system(_map_id, _location, _old_location, _map_opts, _scopes), do: :ok

  defp do_add_system_from_location(map_id, location, old_location, map_opts) do
    :telemetry.execute(
      [:wanderer_app, :map, :system_addition, :start],
      %{system_time: System.system_time()},
      %{
        map_id: map_id,
        solar_system_id: location.solar_system_id,
        from_system: old_location && old_location.solar_system_id
      }
    )

    case WandererApp.Map.check_location(map_id, location) do
      {:ok, location} ->
        rtree_name = "rtree_#{map_id}"

        {:ok, position} = calc_new_system_position(map_id, old_location, rtree_name, map_opts)

        case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(
               map_id,
               location.solar_system_id
             ) do
          {:ok, existing_system} when not is_nil(existing_system) ->
            updated_system =
              existing_system
              |> WandererApp.MapSystemRepo.update_position!(%{
                position_x: position.x,
                position_y: position.y
              })
              |> WandererApp.MapSystemRepo.cleanup_labels!(map_opts)
              |> WandererApp.MapSystemRepo.update_visible!(%{visible: true})
              |> WandererApp.MapSystemRepo.cleanup_tags!()
              |> WandererApp.MapSystemRepo.cleanup_temporary_name!()
              |> WandererApp.MapSystemRepo.cleanup_linked_sig_eve_id!()

            @ddrt.insert(
              {existing_system.solar_system_id,
               WandererApp.Map.PositionCalculator.get_system_bounding_rect(%{
                 position_x: position.x,
                 position_y: position.y
               })},
              rtree_name
            )

            WandererApp.Cache.put(
              "map_#{map_id}:system_#{updated_system.id}:last_activity",
              DateTime.utc_now(),
              ttl: @system_inactive_timeout
            )

            WandererApp.Map.add_system(map_id, updated_system)

            Impl.broadcast!(map_id, :add_system, updated_system)

            # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
            WandererApp.ExternalEvents.broadcast(map_id, :add_system, %{
              solar_system_id: updated_system.solar_system_id,
              name: updated_system.name,
              position_x: updated_system.position_x,
              position_y: updated_system.position_y
            })

            :telemetry.execute(
              [:wanderer_app, :map, :system_addition, :complete],
              %{system_time: System.system_time()},
              %{
                map_id: map_id,
                solar_system_id: updated_system.solar_system_id,
                system_id: updated_system.id,
                operation: :update_existing
              }
            )

            :ok

          _ ->
            WandererApp.CachedInfo.get_system_static_info(location.solar_system_id)
            |> case do
              {:ok, solar_system_info} ->
                # Use upsert instead of create - handles race conditions gracefully
                # visible: true ensures previously-deleted systems become visible again
                WandererApp.MapSystemRepo.upsert(%{
                  map_id: map_id,
                  solar_system_id: location.solar_system_id,
                  name: solar_system_info.solar_system_name,
                  position_x: position.x,
                  position_y: position.y,
                  visible: true
                })
                |> case do
                  {:ok, system} ->
                    # System was either created or updated - both cases are success
                    @ddrt.insert(
                      {system.solar_system_id,
                       WandererApp.Map.PositionCalculator.get_system_bounding_rect(system)},
                      rtree_name
                    )

                    WandererApp.Cache.put(
                      "map_#{map_id}:system_#{system.id}:last_activity",
                      DateTime.utc_now(),
                      ttl: @system_inactive_timeout
                    )

                    WandererApp.Map.add_system(map_id, system)
                    Impl.broadcast!(map_id, :add_system, system)

                    # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
                    WandererApp.ExternalEvents.broadcast(map_id, :add_system, %{
                      solar_system_id: system.solar_system_id,
                      name: system.name,
                      position_x: system.position_x,
                      position_y: system.position_y
                    })

                    :telemetry.execute(
                      [:wanderer_app, :map, :system_addition, :complete],
                      %{system_time: System.system_time()},
                      %{
                        map_id: map_id,
                        solar_system_id: system.solar_system_id,
                        system_id: system.id,
                        operation: :upsert
                      }
                    )

                    :ok

                  {:error, error} = result ->
                    Logger.warning(
                      "[CharacterTracking] Failed to upsert system #{location.solar_system_id} on map #{map_id}: #{inspect(error, pretty: true)}"
                    )

                    :telemetry.execute(
                      [:wanderer_app, :map, :system_addition, :error],
                      %{system_time: System.system_time()},
                      %{
                        map_id: map_id,
                        solar_system_id: location.solar_system_id,
                        error: error,
                        reason: :db_upsert_failed
                      }
                    )

                    result

                  error ->
                    Logger.warning(
                      "[CharacterTracking] Failed to upsert system #{location.solar_system_id} on map #{map_id}: #{inspect(error, pretty: true)}"
                    )

                    :telemetry.execute(
                      [:wanderer_app, :map, :system_addition, :error],
                      %{system_time: System.system_time()},
                      %{
                        map_id: map_id,
                        solar_system_id: location.solar_system_id,
                        error: error,
                        reason: :db_upsert_failed_unexpected
                      }
                    )

                    {:error, error}
                end

              {:error, error} = result ->
                Logger.warning(
                  "[CharacterTracking] Failed to add system #{inspect(location.solar_system_id)} on map #{map_id}: #{inspect(error, pretty: true)}"
                )

                :telemetry.execute(
                  [:wanderer_app, :map, :system_addition, :error],
                  %{system_time: System.system_time()},
                  %{
                    map_id: map_id,
                    solar_system_id: location.solar_system_id,
                    error: error,
                    reason: :db_upsert_failed
                  }
                )

                result

              error ->
                Logger.warning(
                  "[CharacterTracking] Failed to add system #{inspect(location.solar_system_id)} on map #{map_id}: #{inspect(error, pretty: true)}"
                )

                :telemetry.execute(
                  [:wanderer_app, :map, :system_addition, :error],
                  %{system_time: System.system_time()},
                  %{
                    map_id: map_id,
                    solar_system_id: location.solar_system_id,
                    error: error,
                    reason: :db_upsert_failed_unexpected
                  }
                )

                {:error, error}
            end
        end

      error ->
        Logger.debug(fn -> "Skip adding system: #{inspect(error, pretty: true)}" end)
        :ok
    end
  end

  defp do_add_system(
         map_id,
         %{
           solar_system_id: solar_system_id,
           coordinates: coordinates
         } = system_info,
         user_id,
         character_id
       ) do
    # Verify the map exists in the database before attempting to create a system
    # This prevents foreign key constraint errors when tests roll back transactions
    with {:ok, _map} <- WandererApp.MapRepo.get(map_id),
         {:ok, %{map_opts: map_opts}} <- WandererApp.Map.get_map_state(map_id) do
      extra_info = system_info |> Map.get(:extra_info)
      rtree_name = "rtree_#{map_id}"

      %{"x" => x, "y" => y} =
        coordinates
        |> case do
          %{"x" => x, "y" => y} ->
            %{"x" => x, "y" => y}

          _ ->
            %{x: x, y: y} =
              WandererApp.Map.PositionCalculator.get_new_system_position(
                nil,
                rtree_name,
                map_opts
              )

            %{"x" => x, "y" => y}
        end

      system_result =
        case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id) do
          {:ok, existing_system} when not is_nil(existing_system) ->
            use_old_coordinates = Map.get(system_info, :use_old_coordinates, false)

            if use_old_coordinates do
              @ddrt.insert(
                {solar_system_id,
                 WandererApp.Map.PositionCalculator.get_system_bounding_rect(%{
                   position_x: existing_system.position_x,
                   position_y: existing_system.position_y
                 })},
                rtree_name
              )

              existing_system
              |> WandererApp.MapSystemRepo.update_visible(%{visible: true})
            else
              @ddrt.insert(
                {solar_system_id,
                 WandererApp.Map.PositionCalculator.get_system_bounding_rect(%{
                   position_x: x,
                   position_y: y
                 })},
                rtree_name
              )

              existing_system
              |> WandererApp.MapSystemRepo.update_position!(%{position_x: x, position_y: y})
              |> WandererApp.MapSystemRepo.cleanup_labels!(map_opts)
              |> WandererApp.MapSystemRepo.cleanup_tags!()
              |> WandererApp.MapSystemRepo.cleanup_temporary_name!()
              |> WandererApp.MapSystemRepo.cleanup_linked_sig_eve_id!()
              |> maybe_update_extra_info(extra_info)
              |> WandererApp.MapSystemRepo.update_visible(%{visible: true})
            end

          _ ->
            case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
              {:ok, solar_system_info} ->
                @ddrt.insert(
                  {solar_system_id,
                   WandererApp.Map.PositionCalculator.get_system_bounding_rect(%{
                     position_x: x,
                     position_y: y
                   })},
                  rtree_name
                )

                WandererApp.MapSystemRepo.create(%{
                  map_id: map_id,
                  solar_system_id: solar_system_id,
                  name: solar_system_info.solar_system_name,
                  position_x: x,
                  position_y: y
                })

              {:error, reason} ->
                Logger.error(
                  "Failed to get system static info for #{solar_system_id}: #{inspect(reason)}"
                )

                {:error, :system_info_not_found}
            end
        end

      case system_result do
        {:ok, system} ->
          :ok = WandererApp.Map.add_system(map_id, system)

          WandererApp.Cache.put(
            "map_#{map_id}:system_#{system.id}:last_activity",
            DateTime.utc_now(),
            ttl: @system_inactive_timeout
          )

          Impl.broadcast!(map_id, :add_system, system)

          # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
          Logger.debug(fn ->
            "SystemsImpl.do_add_system calling ExternalEvents.broadcast for map #{map_id}, system: #{solar_system_id}"
          end)

          WandererApp.ExternalEvents.broadcast(map_id, :add_system, %{
            solar_system_id: system.solar_system_id,
            position_x: system.position_x,
            position_y: system.position_y
          })

          track_add_system(map_id, user_id, character_id, system.solar_system_id)

          :ok

        {:error, reason} = error ->
          Logger.error(
            "Failed to add system #{solar_system_id} to map #{map_id}: #{inspect(reason)}"
          )

          error
      end
    else
      {:error, :not_found} ->
        Logger.debug(fn ->
          "Cannot add system #{solar_system_id} to map #{map_id}: map does not exist in database"
        end)

        {:error, :map_not_found}

      error ->
        Logger.error("Failed to verify map #{map_id} exists: #{inspect(error)}")
        {:error, :map_verification_failed}
    end
  end

  defp track_add_system(map_id, user_id, character_id, solar_system_id) do
    WandererApp.User.ActivityTracker.track_map_event(:system_added, %{
      character_id: character_id,
      user_id: user_id,
      map_id: map_id,
      solar_system_id: solar_system_id
    })
  end

  defp maybe_update_extra_info(system, nil), do: system

  defp maybe_update_extra_info(
         system,
         %{
           "description" => description,
           "labels" => labels,
           "name" => name,
           "status" => status,
           "tag" => tag,
           "temporary_name" => temporary_name
         }
       ) do
    system
    |> maybe_update_name(name)
    |> maybe_update_description(description)
    |> maybe_update_labels(labels)
    |> maybe_update_status(status)
    |> maybe_update_tag(tag)
    |> maybe_update_temporary_name(temporary_name)
  end

  defp maybe_update_description(
         %{description: old_description} = system,
         description
       )
       when not is_nil(description) and old_description != description do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_description(%{description: description})

    updated_system
  end

  defp maybe_update_description(system, _description), do: system

  defp maybe_update_name(
         %{name: old_name} = system,
         name
       )
       when not is_nil(name) and old_name != name do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_name(%{name: name})

    updated_system
  end

  defp maybe_update_name(system, _name), do: system

  defp maybe_update_labels(
         %{name: old_labels} = system,
         labels
       )
       when not is_nil(labels) and old_labels != labels do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_labels(%{labels: labels})

    updated_system
  end

  defp maybe_update_labels(
         %{labels: old_labels} = system,
         labels
       )
       when not is_nil(labels) and old_labels != labels do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_labels(%{labels: labels})

    updated_system
  end

  defp maybe_update_labels(system, _labels), do: system

  defp maybe_update_status(
         %{name: old_status} = system,
         status
       )
       when not is_nil(status) and old_status != status do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_status(%{status: status})

    updated_system
  end

  defp maybe_update_status(system, _status), do: system

  defp maybe_update_tag(
         %{name: old_tag} = system,
         tag
       )
       when not is_nil(tag) and old_tag != tag do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_tag(%{tag: tag})

    updated_system
  end

  defp maybe_update_tag(system, _labels), do: system

  defp maybe_update_temporary_name(
         %{name: old_temporary_name} = system,
         temporary_name
       )
       when not is_nil(temporary_name) and old_temporary_name != temporary_name do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_temporary_name(%{temporary_name: temporary_name})

    updated_system
  end

  defp maybe_update_temporary_name(system, _temporary_name),
    do: system

  defp calc_new_system_position(map_id, old_location, rtree_name, opts),
    do:
      {:ok,
       map_id
       |> WandererApp.Map.find_system_by_location(old_location)
       |> WandererApp.Map.PositionCalculator.get_new_system_position(rtree_name, opts)}

  defp update_system(
         map_id,
         update_method,
         attributes,
         update,
         callback_fn \\ nil
       ) do
    with :ok <- WandererApp.Map.update_system_by_solar_system_id(map_id, update),
         {:ok, system} <-
           WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(
             map_id,
             update.solar_system_id
           ),
         {:ok, update_map} <- Impl.get_update_map(update, attributes) do
      {:ok, updated_system} =
        apply(WandererApp.MapSystemRepo, update_method, [
          system,
          update_map
        ])

      if not is_nil(callback_fn) do
        callback_fn.(updated_system)
      end

      update_map_system_last_activity(map_id, updated_system)
    else
      {:error, error} ->
        Logger.error("Failed to update system: #{inspect(error, pretty: true)}")
        :ok

      error ->
        Logger.error("Failed to update system: #{inspect(error, pretty: true)}")
        :ok
    end
  end

  defp update_map_system_last_activity(
         map_id,
         updated_system
       ) do
    WandererApp.Cache.put(
      "map_#{map_id}:system_#{updated_system.id}:last_activity",
      DateTime.utc_now(),
      ttl: @system_inactive_timeout
    )

    Impl.broadcast!(map_id, :update_system, updated_system)

    # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
    # This may fail if the relay is not available (e.g., in tests), which is fine
    WandererApp.ExternalEvents.broadcast(map_id, :system_metadata_changed, %{
      system_id: updated_system.id,
      solar_system_id: updated_system.solar_system_id,
      name: updated_system.name,
      temporary_name: updated_system.temporary_name,
      labels: updated_system.labels,
      description: updated_system.description,
      status: updated_system.status,
      locked: updated_system.locked,
      position_x: updated_system.position_x,
      position_y: updated_system.position_y
    })

    :ok
  end
end
