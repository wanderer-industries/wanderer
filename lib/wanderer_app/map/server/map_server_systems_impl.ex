defmodule WandererApp.Map.Server.SystemsImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.Server.{Impl}

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

  def init_map_systems(state, [] = _systems), do: state

  def init_map_systems(%{map_id: map_id, rtree_name: rtree_name} = state, systems) do
    systems
    |> Enum.each(fn %{id: system_id, solar_system_id: solar_system_id} = system ->
      @ddrt.insert(
        {solar_system_id, WandererApp.Map.PositionCalculator.get_system_bounding_rect(system)},
        rtree_name
      )

      WandererApp.Cache.put(
        "map_#{map_id}:system_#{system_id}:last_activity",
        DateTime.utc_now(),
        ttl: @system_inactive_timeout
      )
    end)

    state
  end

  def add_system(
        %{map_id: map_id} = state,
        %{
          solar_system_id: solar_system_id
        } = system_info,
        user_id,
        character_id
      ) do
    case map_id |> WandererApp.Map.check_location(%{solar_system_id: solar_system_id}) do
      {:ok, _location} ->
        state |> _add_system(system_info, user_id, character_id)

      {:error, :already_exists} ->
        state
    end
  end

  def cleanup_systems(%{map_id: map_id} = state) do
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

          no_active_connections? and no_active_characters?
        else
          false
        end
      end)
      |> Enum.map(& &1.solar_system_id)

    case expired_systems |> Enum.empty?() do
      false ->
        state |> delete_systems(expired_systems, nil, nil)

      _ ->
        state
    end
  end

  def update_system_name(
        state,
        update
      ),
      do: state |> update_system(:update_name, [:name], update)

  def update_system_description(
        state,
        update
      ),
      do: state |> update_system(:update_description, [:description], update)

  def update_system_status(
        state,
        update
      ),
      do: state |> update_system(:update_status, [:status], update)

  def update_system_tag(
        state,
        update
      ),
      do: state |> update_system(:update_tag, [:tag], update)

  def update_system_temporary_name(
        state,
        update
      ) do
    state |> update_system(:update_temporary_name, [:temporary_name], update)
  end

  def update_system_owner(state, update) do
    state
    |> update_system(:update_owner, [:owner_type, :owner_id], update)
  end

  def update_system_locked(
        state,
        update
      ),
      do: state |> update_system(:update_locked, [:locked], update)

  def update_system_labels(
        state,
        update
      ),
      do: state |> update_system(:update_labels, [:labels], update)

  def update_system_linked_sig_eve_id(
        state,
        update
      ),
      do: state |> update_system(:update_linked_sig_eve_id, [:linked_sig_eve_id], update)

  def update_system_position(
        %{rtree_name: rtree_name} = state,
        update
      ),
      do:
        state
        |> update_system(
          :update_position,
          [:position_x, :position_y],
          update,
          fn updated_system ->
            @ddrt.update(
              updated_system.solar_system_id,
              WandererApp.Map.PositionCalculator.get_system_bounding_rect(updated_system),
              rtree_name
            )
          end
        )

  def add_hub(
        %{map_id: map_id} = state,
        hub_info
      ) do
    with :ok <- WandererApp.Map.add_hub(map_id, hub_info),
         {:ok, hubs} = map_id |> WandererApp.Map.list_hubs(),
         {:ok, _} <-
           WandererApp.MapRepo.update_hubs(map_id, hubs) do
      Impl.broadcast!(map_id, :update_map, %{hubs: hubs})
      state
    else
      error ->
        Logger.error("Failed to add hub: #{inspect(error, pretty: true)}")
        state
    end
  end

  def remove_hub(
        %{map_id: map_id} = state,
        hub_info
      ) do
    with :ok <- WandererApp.Map.remove_hub(map_id, hub_info),
         {:ok, hubs} = map_id |> WandererApp.Map.list_hubs(),
         {:ok, _} <-
           WandererApp.MapRepo.update_hubs(map_id, hubs) do
      Impl.broadcast!(map_id, :update_map, %{hubs: hubs})
      state
    else
      error ->
        Logger.error("Failed to remove hub: #{inspect(error, pretty: true)}")
        state
    end
  end

  def delete_systems(
        %{map_id: map_id, rtree_name: rtree_name} = state,
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

    solar_system_ids_to_remove =
      filtered_ids
      |> Enum.map(fn {solar_system_id, _} -> solar_system_id end)

    system_ids_to_remove =
      filtered_ids
      |> Enum.map(fn {_, system_id} -> system_id end)

    connections_to_remove =
      solar_system_ids_to_remove
      |> Enum.map(fn solar_system_id ->
        WandererApp.Map.find_connections(map_id, solar_system_id)
      end)
      |> List.flatten()
      |> Enum.uniq_by(& &1.id)

    :ok = WandererApp.Map.remove_connections(map_id, connections_to_remove)
    :ok = WandererApp.Map.remove_systems(map_id, solar_system_ids_to_remove)

    solar_system_ids_to_remove
    |> Enum.each(fn solar_system_id ->
      map_id
      |> WandererApp.MapSystemRepo.remove_from_map(solar_system_id)
      |> case do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.error("Failed to remove system from map: #{inspect(error, pretty: true)}")
          :ok
      end
    end)

    connections_to_remove
    |> Enum.each(fn connection ->
      Logger.debug(fn -> "Removing connection from map: #{inspect(connection)}" end)
      WandererApp.MapConnectionRepo.destroy(map_id, connection)
    end)

    solar_system_ids_to_remove
    |> Enum.map(fn solar_system_id ->
      WandererApp.Api.MapSystemSignature.by_linked_system_id!(solar_system_id)
    end)
    |> List.flatten()
    |> Enum.uniq_by(& &1.system_id)
    |> Enum.each(fn s ->
      {:ok, %{system: system}} = s |> Ash.load([:system])
      Ash.destroy!(s)

      Impl.broadcast!(map_id, :signatures_updated, system.solar_system_id)
    end)

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
      WandererApp.Map.Server.update_system_linked_sig_eve_id(map_id, %{
        solar_system_id: linked_system_id,
        linked_sig_eve_id: nil
      })
    end)

    @ddrt.delete(solar_system_ids_to_remove, rtree_name)

    Impl.broadcast!(map_id, :remove_connections, connections_to_remove)
    Impl.broadcast!(map_id, :systems_removed, solar_system_ids_to_remove)

    case not is_nil(user_id) do
      true ->
        {:ok, _} =
          WandererApp.User.ActivityTracker.track_map_event(:systems_removed, %{
            character_id: character_id,
            user_id: user_id,
            map_id: map_id,
            solar_system_ids: solar_system_ids_to_remove
          })

        :telemetry.execute(
          [:wanderer_app, :map, :systems, :remove],
          %{count: solar_system_ids_to_remove |> Enum.count()}
        )

        :ok

      _ ->
        :ok
    end

    state
  end

  def maybe_add_system(map_id, location, old_location, rtree_name, map_opts)
      when not is_nil(location) do
    case WandererApp.Map.check_location(map_id, location) do
      {:ok, location} ->
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
            :ok

          _ ->
            {:ok, solar_system_info} =
              WandererApp.CachedInfo.get_system_static_info(location.solar_system_id)

            WandererApp.MapSystemRepo.create(%{
              map_id: map_id,
              solar_system_id: location.solar_system_id,
              name: solar_system_info.solar_system_name,
              position_x: position.x,
              position_y: position.y
            })
            |> case do
              {:ok, new_system} ->
                @ddrt.insert(
                  {new_system.solar_system_id,
                   WandererApp.Map.PositionCalculator.get_system_bounding_rect(new_system)},
                  rtree_name
                )

                WandererApp.Cache.put(
                  "map_#{map_id}:system_#{new_system.id}:last_activity",
                  DateTime.utc_now(),
                  ttl: @system_inactive_timeout
                )

                WandererApp.Map.add_system(map_id, new_system)
                Impl.broadcast!(map_id, :add_system, new_system)

                :ok

              error ->
                Logger.warning("Failed to create system: #{inspect(error, pretty: true)}")
                :ok
            end
        end

      error ->
        Logger.debug("Skip adding system: #{inspect(error, pretty: true)}")
        :ok
    end
  end

  def maybe_add_system(_map_id, _location, _old_location, _rtree_name, _map_opts), do: :ok

  defp _add_system(
         %{map_id: map_id, map_opts: map_opts, rtree_name: rtree_name} = state,
         %{
           solar_system_id: solar_system_id,
           coordinates: coordinates
         } = system_info,
         user_id,
         character_id
       ) do
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

    {:ok, system} =
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
            |> WandererApp.MapSystemRepo.update_visible(%{visible: true})
          end

        _ ->
          {:ok, solar_system_info} =
            WandererApp.CachedInfo.get_system_static_info(solar_system_id)

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
      end

    :ok = map_id |> WandererApp.Map.add_system(system)

    WandererApp.Cache.put(
      "map_#{map_id}:system_#{system.id}:last_activity",
      DateTime.utc_now(),
      ttl: @system_inactive_timeout
    )

    Impl.broadcast!(map_id, :add_system, system)

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:system_added, %{
        character_id: character_id,
        user_id: user_id,
        map_id: map_id,
        solar_system_id: solar_system_id
      })

    state
  end

  defp calc_new_system_position(map_id, old_location, rtree_name, opts),
    do:
      {:ok,
       map_id
       |> WandererApp.Map.find_system_by_location(old_location)
       |> WandererApp.Map.PositionCalculator.get_new_system_position(rtree_name, opts)}

  defp update_system(
         %{map_id: map_id} = state,
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

      state
    else
      error ->
        Logger.error("Failed to update system: #{inspect(error, pretty: true)}")
        state
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
  end
end
