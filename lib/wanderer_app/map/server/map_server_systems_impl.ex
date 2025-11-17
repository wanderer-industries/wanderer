defmodule WandererApp.Map.Server.SystemsImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.CacheRTree
  alias WandererApp.Map.Server.Impl

  @spatial_index Application.compile_env(:wanderer_app, :spatial_index_module, CacheRTree)
  @cached_info Application.compile_env(:wanderer_app, :cached_info)
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
      @spatial_index.insert(
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
        opts
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
        } = comment_info,
        user_id,
        character_id
      ) do
    system =
      WandererApp.Map.find_system_by_location(map_id, %{
        solar_system_id: solar_system_id |> String.to_integer()
      })

    {:ok, comment} =
      WandererApp.MapSystemCommentRepo.create(%{
        system_id: system.id,
        character_id: character_id,
        text: text
      })

    comment =
      comment
      |> Ash.load!([:character, :system])

    Impl.broadcast!(map_id, :system_comment_added, %{
      solar_system_id: solar_system_id,
      comment: comment
    })
  end

  def remove_system_comment(
        map_id,
        comment_id,
        user_id,
        character_id
      ) do
    {:ok, %{system: system} = comment} =
      WandererApp.MapSystemCommentRepo.get_by_id(comment_id)

    :ok = WandererApp.MapSystemCommentRepo.destroy(comment)

    Impl.broadcast!(map_id, :system_comment_removed, %{
      solar_system_id: system.solar_system_id,
      comment_id: comment_id
    })
  end

  def cleanup_systems(map_id) do
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
            @spatial_index.update(
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
        {:ok, result} ->
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
        :ok = WandererApp.MapConnectionRepo.destroy(map_id, connection)
        :ok = WandererApp.Map.remove_connection(map_id, connection)
      rescue
        e ->
          Logger.error("Failed to remove connection: #{inspect(e)}")
      end
    end)
  end

  defp cleanup_linked_signatures(map_id, removed_solar_system_ids) do
    removed_solar_system_ids
    |> Enum.map(fn solar_system_id ->
      WandererApp.Api.MapSystemSignature.by_linked_system_id!(solar_system_id)
    end)
    |> List.flatten()
    |> Enum.uniq_by(& &1.system_id)
    |> Enum.each(fn s ->
      try do
        {:ok, %{eve_id: eve_id, system: system}} = s |> Ash.load([:system])
        :ok = Ash.destroy!(s)

        Logger.warning(
          "[cleanup_linked_signatures] for system #{system.solar_system_id}: #{inspect(eve_id)}"
        )
      rescue
        e ->
          Logger.error("Failed to cleanup linked signature: #{inspect(e)}")
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

  def maybe_add_system(map_id, location, old_location, map_opts)
      when not is_nil(location) do
    case WandererApp.Map.check_location(map_id, location) do
      {:ok, location} ->
        rtree_name = "rtree_#{map_id}"

        {:ok, position} = calc_new_system_position(map_id, old_location, rtree_name, map_opts)

        case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(
               map_id,
               location.solar_system_id
             ) do
          {:ok, existing_system} when not is_nil(existing_system) ->
            update_attrs = %{
              position_x: position.x,
              position_y: position.y,
              labels: existing_system.labels,
              tag: nil,
              temporary_name: nil,
              linked_sig_eve_id: nil
            }

            updated_system =
              case WandererApp.MapSystemRepo.update_position_and_attributes(
                     existing_system,
                     update_attrs,
                     map_opts: map_opts
                   ) do
                {:ok, updated_system} ->
                  updated_system

                {:error, changeset} ->
                  Logger.error(
                    "[MapServerSystemsImpl] Failed to update system position and attributes",
                    map_id: map_id,
                    system_id: existing_system.id,
                    error: inspect(changeset.errors)
                  )

                  existing_system
              end

            @spatial_index.insert(
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

            :ok

          _ ->
            case @cached_info.get_system_static_info(location.solar_system_id) do
              {:ok, solar_system_info} when not is_nil(solar_system_info) ->
                WandererApp.MapSystemRepo.create(%{
                  map_id: map_id,
                  solar_system_id: location.solar_system_id,
                  name: solar_system_info.solar_system_name,
                  position_x: position.x,
                  position_y: position.y
                })
                |> case do
                  {:ok, new_system} ->
                    # Insert into spatial index
                    @spatial_index.insert(
                      {new_system.solar_system_id,
                       WandererApp.Map.PositionCalculator.get_system_bounding_rect(%{
                         position_x: position.x,
                         position_y: position.y
                       })},
                      rtree_name
                    )

                    WandererApp.Cache.put(
                      "map_#{map_id}:system_#{new_system.id}:last_activity",
                      DateTime.utc_now(),
                      ttl: @system_inactive_timeout
                    )

                    :ok

                  error ->
                    Logger.warning("Failed to create system: #{inspect(error, pretty: true)}")
                    :ok
                end

              error ->
                Logger.warning(
                  "Failed to get system static info: #{inspect(error, pretty: true)}"
                )

                {:error, :system_info_not_found}
            end
        end

      error ->
        Logger.debug(fn -> "Skip adding system: #{inspect(error, pretty: true)}" end)
        :ok
    end
  end

  def maybe_add_system(_map_id, _location, _old_location, _map_opts), do: :ok

  defp do_add_system(
         map_id,
         %{
           solar_system_id: solar_system_id,
           coordinates: coordinates
         } = system_info,
         user_id,
         character_id
       ) do
    extra_info = system_info |> Map.get(:extra_info)
    rtree_name = "rtree_#{map_id}"
    {:ok, %{map_opts: map_opts}} = WandererApp.Map.get_map_state(map_id)

    %{"x" => x, "y" => y} =
      coordinates
      |> case do
        %{"x" => x, "y" => y} ->
          %{"x" => x, "y" => y}

        _ ->
          %{x: x, y: y} =
            WandererApp.Map.PositionCalculator.get_new_system_position(nil, rtree_name, map_opts)

          %{"x" => x, "y" => y}
      end

    result =
      case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id) do
        {:ok, existing_system} when not is_nil(existing_system) ->
          use_old_coordinates = Map.get(system_info, :use_old_coordinates, false)

          if use_old_coordinates do
            @spatial_index.insert(
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
            @spatial_index.insert(
              {solar_system_id,
               WandererApp.Map.PositionCalculator.get_system_bounding_rect(%{
                 position_x: x,
                 position_y: y
               })},
              rtree_name
            )

            update_attrs = %{
              position_x: x,
              position_y: y,
              labels: existing_system.labels,
              tag: nil,
              temporary_name: nil,
              linked_sig_eve_id: nil
            }

            updated_system =
              case WandererApp.MapSystemRepo.update_position_and_attributes(
                     existing_system,
                     update_attrs,
                     map_opts: map_opts
                   ) do
                {:ok, system} ->
                  system

                {:error, changeset} ->
                  Logger.error(
                    "[MapServerSystemsImpl] Failed to update system position and attributes",
                    map_id: map_id,
                    system_id: existing_system.id,
                    error: inspect(changeset.errors)
                  )

                  existing_system
              end

            {:ok, maybe_update_extra_info(updated_system, extra_info)}
          end

        _ ->
          case @cached_info.get_system_static_info(solar_system_id) do
            {:ok, solar_system_info} when not is_nil(solar_system_info) ->
              @spatial_index.insert(
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

            _ ->
              Logger.warning(
                "[MapServerSystemsImpl] Failed to get system static info, using default name",
                map_id: map_id,
                solar_system_id: solar_system_id
              )

              # Use a default name if static info isn't available
              @spatial_index.insert(
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
                name: "System #{solar_system_id}",
                position_x: x,
                position_y: y
              })
          end
      end

    case result do
      {:ok, system} ->
        WandererApp.Cache.put(
          "map_#{map_id}:system_#{system.id}:last_activity",
          DateTime.utc_now(),
          ttl: @system_inactive_timeout
        )

        {:ok, _} =
          WandererApp.User.ActivityTracker.track_map_event(:system_added, %{
            character_id: character_id,
            user_id: user_id,
            map_id: map_id,
            solar_system_id: solar_system_id
          })

        :ok

      {:error, changeset} ->
        Logger.error(
          "[MapServerSystemsImpl] Failed to add system",
          map_id: map_id,
          solar_system_id: solar_system_id,
          error: inspect(changeset.errors)
        )

        {:error, changeset}
    end
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
         %{status: old_status} = system,
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
         %{tag: old_tag} = system,
         tag
       )
       when not is_nil(tag) and old_tag != tag do
    {:ok, updated_system} =
      system
      |> WandererApp.MapSystemRepo.update_tag(%{tag: tag})

    updated_system
  end

  defp maybe_update_tag(system, _tag), do: system

  defp maybe_update_temporary_name(
         %{temporary_name: old_temporary_name} = system,
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
  end
end
