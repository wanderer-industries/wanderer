defmodule WandererApp.Map.Server.Impl do
  @moduledoc """
  Holds state for a map and exposes an interface to managing the map instance
  """
  require Logger

  @enforce_keys [
    :map_id
  ]

  defstruct [
    :map_id,
    :rtree_name,
    map: nil
  ]

  # @ccp1 -1
  @c1 1
  @c2 2
  @c3 3
  @c4 4
  @c5 5
  @c6 6
  @hs 7
  @ls 8
  @ns 9
  # @ccp2 10
  # @ccp3 11
  @thera 12
  @c13 13
  @sentinel 14
  @baribican 15
  @vidette 16
  @conflux 17
  @redoubt 18
  @a1 19
  @a2 20
  @a3 21
  @a4 22
  @a5 23
  @ccp4 24
  # @pochven 25
  # @zarzakh 10100

  @jita 30_000_142

  @wh_space [
    @c1,
    @c2,
    @c3,
    @c4,
    @c5,
    @c6,
    @c13,
    @thera,
    @sentinel,
    @baribican,
    @vidette,
    @conflux,
    @redoubt
  ]

  @known_space [@hs, @ls, @ns]

  @prohibited_systems [@jita]
  @prohibited_system_classes [
    @a1,
    @a2,
    @a3,
    @a4,
    @a5,
    @ccp4
  ]

  # this class of systems will guaranty that no one real class will take that place
  # @unknown 100_100

  @systems_cleanup_timeout :timer.minutes(30)
  @connections_cleanup_timeout :timer.minutes(2)

  @connection_time_status_eol 1
  @connection_auto_eol_hours 21
  @connection_auto_expire_hours 24
  @system_auto_expire_minutes 15

  @ddrt Application.compile_env(:wanderer_app, :ddrt)
  @logger Application.compile_env(:wanderer_app, :logger)
  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)
  @backup_state_timeout :timer.minutes(1)
  @system_inactive_timeout :timer.minutes(15)
  @connection_eol_expire_timeout :timer.hours(3) + :timer.minutes(30)
  @update_presence_timeout :timer.seconds(1)
  @update_characters_timeout :timer.seconds(1)
  @update_tracked_characters_timeout :timer.seconds(1)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def init(args) do
    map_id = args[:map_id]
    @logger.info("Starting map server for #{map_id}")

    ErrorTracker.set_context(%{map_id: map_id})
    WandererApp.Cache.insert("map_#{map_id}:started", false)

    %{
      map_id: map_id,
      rtree_name: Module.concat([map_id, DDRT.DynamicRtree])
    }
    |> new()
  end

  def load_state(%__MODULE__{map_id: map_id} = state) do
    with {:ok, map} <- WandererApp.MapRepo.get(map_id, [:acls, :characters]),
         {:ok, systems} <- WandererApp.MapSystemRepo.get_visible_by_map(map_id),
         {:ok, connections} <- WandererApp.MapConnectionRepo.get_by_map(map_id),
         {:ok, subscription_settings} <-
           WandererApp.Map.SubscriptionManager.get_active_map_subscription(map_id) do
      state
      |> _init_map(
        map,
        subscription_settings,
        systems,
        connections
      )
      |> _init_map_systems(systems)
      |> _init_map_cache()
    else
      error ->
        @logger.error("Failed to load map state: #{inspect(error, pretty: true)}")
        state
    end
  end

  def start_map(%__MODULE__{map: map, map_id: map_id} = state) do
    with :ok <- _track_acls(map.acls |> Enum.map(& &1.id)) do
      @pubsub_client.subscribe(
        WandererApp.PubSub,
        "maps:#{map_id}"
      )

      Process.send_after(self(), :update_characters, @update_characters_timeout)
      Process.send_after(self(), :update_tracked_characters, 100)
      Process.send_after(self(), :update_presence, @update_presence_timeout)
      Process.send_after(self(), :cleanup_connections, 5000)
      Process.send_after(self(), :cleanup_systems, 10000)
      Process.send_after(self(), :backup_state, @backup_state_timeout)

      WandererApp.Cache.insert("map_#{map_id}:started", true)

      broadcast!(map_id, :map_started)

      :telemetry.execute([:wanderer_app, :map, :started], %{count: 1})

      state
    else
      error ->
        @logger.error("Failed to start map: #{inspect(error, pretty: true)}")
        state
    end
  end

  def stop_map(%{map_id: map_id} = state) do
    @logger.debug(fn -> "Stopping map server for #{map_id}" end)

    WandererApp.Cache.delete("map_#{map_id}:started")

    :telemetry.execute([:wanderer_app, :map, :stopped], %{count: 1})

    state
    |> _maybe_stop_rtree()
  end

  def get_map(%{map: map} = _state), do: {:ok, map}

  def get_characters(%{map_id: map_id} = _state),
    do: {:ok, map_id |> WandererApp.Map.list_characters()}

  def add_character(%{map_id: map_id} = state, %{id: character_id} = character, track_character) do
    with :ok <- map_id |> WandererApp.Map.add_character(character),
         {:ok, _} <-
           WandererApp.MapCharacterSettingsRepo.create(%{
             character_id: character_id,
             map_id: map_id,
             tracked: track_character
           }),
         {:ok, character} <- WandererApp.Character.get_character(character_id) do
      broadcast!(map_id, :character_added, character)

      :telemetry.execute([:wanderer_app, :map, :character, :added], %{count: 1})

      state
    else
      {:error, _error} ->
        state
    end
  end

  def remove_character(%{map_id: map_id} = state, character_id) do
    with :ok <- WandererApp.Map.remove_character(map_id, character_id),
         {:ok, character} <- WandererApp.Character.get_character(character_id) do
      broadcast!(map_id, :character_removed, character)

      :telemetry.execute([:wanderer_app, :map, :character, :removed], %{count: 1})

      state
    else
      {:error, _error} ->
        state
    end
  end

  def untrack_characters(%{map_id: map_id} = state, characters_ids) do
    map_id
    |> _untrack_characters(characters_ids)

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

  def update_system_name(
        state,
        update
      ),
      do: state |> _update_system(:update_name, [:name], update)

  def update_system_description(
        state,
        update
      ),
      do: state |> _update_system(:update_description, [:description], update)

  def update_system_status(
        state,
        update
      ),
      do: state |> _update_system(:update_status, [:status], update)

  def update_system_tag(
        state,
        update
      ),
      do: state |> _update_system(:update_tag, [:tag], update)

  def update_system_locked(
        state,
        update
      ),
      do: state |> _update_system(:update_locked, [:locked], update)

  def update_system_labels(
        state,
        update
      ),
      do: state |> _update_system(:update_labels, [:labels], update)

  def update_system_position(
        %{rtree_name: rtree_name} = state,
        update
      ),
      do:
        state
        |> _update_system(
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
      broadcast!(map_id, :update_map, %{hubs: hubs})
      state
    else
      error ->
        @logger.error("Failed to add hub: #{inspect(error, pretty: true)}")
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
      broadcast!(map_id, :update_map, %{hubs: hubs})
      state
    else
      error ->
        @logger.error("Failed to remove hub: #{inspect(error, pretty: true)}")
        state
    end
  end

  def delete_systems(
        %{map_id: map_id, rtree_name: rtree_name} = state,
        removed_ids,
        user_id,
        character_id
      ) do
    connections_to_remove =
      removed_ids
      |> Enum.map(fn solar_system_id ->
        WandererApp.Map.find_connections(map_id, solar_system_id)
      end)
      |> List.flatten()
      |> Enum.uniq_by(& &1.id)

    :ok = WandererApp.Map.remove_connections(map_id, connections_to_remove)
    :ok = WandererApp.Map.remove_systems(map_id, removed_ids)

    removed_ids
    |> Enum.each(fn solar_system_id ->
      map_id
      |> WandererApp.MapSystemRepo.remove_from_map(solar_system_id)
      |> case do
        {:ok, _} ->
          :ok

        {:error, error} ->
          @logger.error("Failed to remove system from map: #{inspect(error, pretty: true)}")
          :ok
      end
    end)

    connections_to_remove
    |> Enum.each(fn connection ->
      @logger.debug(fn -> "Removing connection from map: #{inspect(connection)}" end)

      connection
      |> WandererApp.MapConnectionRepo.destroy!()
      |> case do
        :ok ->
          :ok

        {:error, error} ->
          @logger.error("Failed to remove connection from map: #{inspect(error, pretty: true)}")
          :ok
      end
    end)

    @ddrt.delete(removed_ids, rtree_name)

    broadcast!(map_id, :remove_connections, connections_to_remove)
    broadcast!(map_id, :systems_removed, removed_ids)

    case not is_nil(user_id) do
      true ->
        :telemetry.execute(
          [:wanderer_app, :map, :systems, :remove],
          %{count: removed_ids |> Enum.count()},
          %{
            character_id: character_id,
            user_id: user_id,
            map_id: map_id,
            solar_system_ids: removed_ids
          }
        )

      _ ->
        :ok
    end

    state
  end

  def add_connection(
        %{map_id: map_id} = state,
        %{
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id
        } = _connection_info
      ) do
    :ok =
      maybe_add_connection(
        map_id,
        %{solar_system_id: solar_system_target_id},
        %{
          solar_system_id: solar_system_source_id
        },
        nil
      )

    state
  end

  def delete_connection(
        %{map_id: map_id} = state,
        %{
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id
        } = _connection_info
      ) do
    :ok =
      maybe_remove_connection(map_id, %{solar_system_id: solar_system_target_id}, %{
        solar_system_id: solar_system_source_id
      })

    state
  end

  def update_connection_time_status(
        %{map_id: map_id} = state,
        connection_update
      ),
      do:
        _update_connection(state, :update_time_status, [:time_status], connection_update, fn
          %{id: connection_id, time_status: time_status} ->
            case time_status == @connection_time_status_eol do
              true ->
                WandererApp.Cache.put(
                  "map_#{map_id}:conn_#{connection_id}:mark_eol_time",
                  DateTime.utc_now(),
                  ttl: @connection_eol_expire_timeout
                )

              _ ->
                WandererApp.Cache.delete("map_#{map_id}:conn_#{connection_id}:mark_eol_time")
            end
        end)

  def update_connection_mass_status(
        state,
        connection_update
      ),
      do: _update_connection(state, :update_mass_status, [:mass_status], connection_update)

  def update_connection_ship_size_type(
        state,
        connection_update
      ),
      do: _update_connection(state, :update_ship_size_type, [:ship_size_type], connection_update)

  def update_connection_locked(
        state,
        connection_update
      ),
      do: _update_connection(state, :update_locked, [:locked], connection_update)

  def import_settings(%{map_id: map_id} = state, settings, user_id) do
    WandererApp.Cache.put(
      "map_#{map_id}:importing",
      true
    )

    state =
      state
      |> _maybe_import_systems(settings, user_id, nil)
      |> _maybe_import_connections(settings, user_id)
      |> _maybe_import_hubs(settings, user_id)

    WandererApp.Cache.take("map_#{map_id}:importing")

    state
  end

  def update_subscription_settings(%{map: map} = state, subscription_settings),
    do: %{
      state
      | map: map |> WandererApp.Map.update_subscription_settings!(subscription_settings)
    }

  def handle_event(:update_characters, %{map_id: map_id} = state) do
    Process.send_after(self(), :update_characters, @update_characters_timeout)

    WandererApp.Cache.lookup!("maps:#{map_id}:tracked_characters", [])
    |> Enum.map(fn character_id ->
      Task.start_link(fn ->
        character_updates =
          _maybe_update_online(map_id, character_id) ++
            _maybe_update_location(map_id, character_id) ++
            _maybe_update_ship(map_id, character_id) ++
            _maybe_update_alliance(map_id, character_id) ++
            _maybe_update_corporation(map_id, character_id)

        character_updates
        |> Enum.filter(fn update -> update != :skip end)
        |> Enum.map(fn update ->
          update
          |> case do
            {:character_location, location_info, old_location_info} ->
              _update_location(
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

            {:character_alliance, _info} ->
              :broadcast

            {:character_corporation, _info} ->
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
              _update_character(map_id, character_id)

            _ ->
              :ok
          end
        end)

        :ok
      end)
    end)

    state
  end

  def handle_event(:update_tracked_characters, %{map_id: map_id} = state) do
    Process.send_after(self(), :update_tracked_characters, @update_tracked_characters_timeout)

    Task.start_link(fn ->
      map_characters =
        map_id
        |> WandererApp.Map.get_map!()
        |> Map.get(:characters, [])

      {:ok, tracked_characters} = WandererApp.Cache.lookup("tracked_characters", [])

      map_tracked_characters =
        map_characters |> Enum.filter(fn character -> character in tracked_characters end)

      WandererApp.Cache.insert("maps:#{map_id}:tracked_characters", map_tracked_characters)

      :ok
    end)

    state
  end

  def handle_event(:update_presence, %{map_id: map_id} = state) do
    Process.send_after(self(), :update_presence, @update_presence_timeout)

    _update_presence(map_id)

    state
  end

  def handle_event(:backup_state, state) do
    Process.send_after(self(), :backup_state, @backup_state_timeout)
    {:ok, _map_state} = state |> _save_map_state()

    state
  end

  def handle_event({:map_acl_updated, added_acls, removed_acls}, %{map: old_map} = state) do
    {:ok, map} = WandererApp.MapRepo.get(old_map.map_id, [:acls])

    _track_acls(added_acls)

    result =
      [added_acls | removed_acls]
      |> List.flatten()
      |> Task.async_stream(
        fn acl_id ->
          _update_acl(acl_id)
        end,
        max_concurrency: 10,
        timeout: :timer.seconds(15)
      )
      |> Enum.reduce(
        %{
          eve_alliance_ids: [],
          eve_character_ids: [],
          eve_corporation_ids: []
        },
        fn result, acc ->
          case result do
            {:ok, val} ->
              {:ok,
               %{
                 eve_alliance_ids: eve_alliance_ids,
                 eve_character_ids: eve_character_ids,
                 eve_corporation_ids: eve_corporation_ids
               }} = val

              %{
                acc
                | eve_alliance_ids: eve_alliance_ids ++ acc.eve_alliance_ids,
                  eve_character_ids: eve_character_ids ++ acc.eve_character_ids,
                  eve_corporation_ids: eve_corporation_ids ++ acc.eve_corporation_ids
              }

            error ->
              @logger.error(
                "Failed to update map #{old_map.map_id} acl: #{inspect(error, pretty: true)}"
              )

              acc
          end
        end
      )

    _broadcast_acl_updates({:ok, result})

    %{state | map: %{old_map | acls: map.acls, scope: map.scope}}
  end

  def handle_event({:acl_updated, %{acl_id: acl_id}}, %{map: map} = state) do
    if map.acls |> Enum.map(& &1.id) |> Enum.member?(acl_id) do
      :ok =
        acl_id
        |> _update_acl()
        |> _broadcast_acl_updates()
    end

    state
  end

  def handle_event(:cleanup_connections, %{map_id: map_id} = state) do
    Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)

    state =
      map_id
      |> WandererApp.Map.list_connections!()
      |> Enum.filter(fn %{
                          inserted_at: inserted_at,
                          solar_system_source: solar_system_source_id,
                          solar_system_target: solar_system_target_id
                        } ->
        DateTime.diff(DateTime.utc_now(), inserted_at, :hour) >=
          @connection_auto_eol_hours and
          _is_connection_valid(
            :wormholes,
            solar_system_source_id,
            solar_system_target_id
          )
      end)
      |> Enum.reduce(state, fn %{
                                 solar_system_source: solar_system_source_id,
                                 solar_system_target: solar_system_target_id
                               },
                               state ->
        state
        |> update_connection_time_status(%{
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id,
          time_status: @connection_time_status_eol
        })
      end)

    state =
      map_id
      |> WandererApp.Map.list_connections!()
      |> Enum.filter(fn %{
                          id: connection_id,
                          inserted_at: inserted_at,
                          solar_system_source: solar_system_source_id,
                          solar_system_target: solar_system_target_id
                        } ->
        connection_mark_eol_time = _get_connection_mark_eol_time(map_id, connection_id)

        reverse_connection =
          WandererApp.Map.get_connection(
            map_id,
            solar_system_target_id,
            solar_system_source_id
          )

        is_connection_exist =
          _is_connection_exist(
            map_id,
            solar_system_source_id,
            solar_system_target_id
          )

        is_connection_valid =
          _is_connection_valid(
            :wormholes,
            solar_system_source_id,
            solar_system_target_id
          )

        not is_connection_exist or
          not is_nil(reverse_connection) or
          (is_connection_valid and
             (DateTime.diff(DateTime.utc_now(), inserted_at, :hour) >=
                @connection_auto_expire_hours or
                DateTime.diff(DateTime.utc_now(), connection_mark_eol_time, :hour) >=
                  @connection_auto_expire_hours - @connection_auto_eol_hours))
      end)
      |> Enum.reduce(state, fn %{
                                 solar_system_source: solar_system_source_id,
                                 solar_system_target: solar_system_target_id
                               },
                               state ->
        state
        |> delete_connection(%{
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id
        })
      end)

    state
  end

  def handle_event(:cleanup_systems, %{map_id: map_id} = state) do
    Process.send_after(self(), :cleanup_systems, @systems_cleanup_timeout)

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

  def handle_event(:subscription_settings_updated, %{map: map, map_id: map_id} = state) do
    {:ok, subscription_settings} =
      WandererApp.Map.SubscriptionManager.get_active_map_subscription(map_id)

    %{
      state
      | map:
          map
          |> WandererApp.Map.update_subscription_settings!(subscription_settings)
    }
  end

  def handle_event({ref, _result}, %{map_id: _map_id} = state) do
    Process.demonitor(ref, [:flush])

    state
  end

  def handle_event(msg, state) do
    @logger.warning("Unhandled event: #{inspect(msg)}")

    state
  end

  def broadcast!(map_id, event, payload \\ nil) do
    if _can_broadcast?(map_id) do
      @pubsub_client.broadcast!(WandererApp.PubSub, map_id, %{event: event, payload: payload})
    end

    :ok
  end

  defp _get_connection_mark_eol_time(map_id, connection_id) do
    case WandererApp.Cache.get("map_#{map_id}:conn_#{connection_id}:mark_eol_time") do
      nil ->
        DateTime.utc_now()

      value ->
        value
    end
  end

  defp _can_broadcast?(map_id),
    do:
      not WandererApp.Cache.lookup!("map_#{map_id}:importing", false) and
        WandererApp.Cache.lookup!("map_#{map_id}:started", false)

  defp _update_location(
         character_id,
         location,
         old_location,
         %{map: map, map_id: map_id, rtree_name: rtree_name} = _state
       ) do
    case is_nil(old_location.solar_system_id) and
           _can_add_location(map.scope, location.solar_system_id) do
      true ->
        :ok = maybe_add_system(map_id, location, nil, rtree_name)

      _ ->
        case _is_connection_valid(
               map.scope,
               old_location.solar_system_id,
               location.solar_system_id
             ) do
          true ->
            {:ok, character} = WandererApp.Character.get_character(character_id)
            :ok = maybe_add_system(map_id, location, old_location, rtree_name)
            :ok = maybe_add_system(map_id, old_location, location, rtree_name)
            :ok = maybe_add_connection(map_id, location, old_location, character)

          _ ->
            :ok
        end
    end
  end

  defp _maybe_update_location(map_id, character_id) do
    WandererApp.Cache.lookup!(
      "character:#{character_id}:location_started",
      false
    )
    |> case do
      true ->
        {:ok, old_solar_system_id} =
          WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:solar_system_id")

        {:ok, %{solar_system_id: solar_system_id}} =
          WandererApp.Character.get_character(character_id)

        WandererApp.Cache.insert(
          "map:#{map_id}:character:#{character_id}:solar_system_id",
          solar_system_id
        )

        case solar_system_id != old_solar_system_id do
          true ->
            [
              {:character_location, %{solar_system_id: solar_system_id},
               %{solar_system_id: old_solar_system_id}}
            ]

          _ ->
            [:skip]
        end

      false ->
        {:ok, old_solar_system_id} =
          WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:solar_system_id")

        {:ok, %{solar_system_id: solar_system_id} = _character} =
          WandererApp.Character.get_character(character_id)

        WandererApp.Cache.insert(
          "map:#{map_id}:character:#{character_id}:solar_system_id",
          solar_system_id
        )

        if is_nil(old_solar_system_id) or solar_system_id != old_solar_system_id do
          [
            {:character_location, %{solar_system_id: solar_system_id}, %{solar_system_id: nil}}
          ]
        else
          [:skip]
        end
    end
  end

  defp _maybe_update_alliance(map_id, character_id) do
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
        @logger.error("Failed to update alliance: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp _maybe_update_corporation(map_id, character_id) do
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
        @logger.error("Failed to update corporation: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp _maybe_update_online(map_id, character_id) do
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
        @logger.error("Failed to update online: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp _maybe_update_ship(map_id, character_id) do
    with {:ok, old_ship_type_id} <-
           WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:ship_type_id"),
         {:ok, old_ship_name} <-
           WandererApp.Cache.lookup("map:#{map_id}:character:#{character_id}:ship_name"),
         {:ok, %{ship: ship_type_id, ship_name: ship_name}} <-
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

          [{:character_ship, %{ship: ship_type_id, ship_name: ship_name}}]

        _ ->
          [:skip]
      end
    else
      error ->
        @logger.error("Failed to update ship: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp _update_connection(
         %{map_id: map_id} = state,
         update_method,
         attributes,
         %{
           solar_system_source_id: solar_system_source_id,
           solar_system_target_id: solar_system_target_id
         } = update,
         callback_fn \\ nil
       ) do
    with {:ok, connection} <-
           WandererApp.Map.find_connection(
             map_id,
             solar_system_source_id,
             solar_system_target_id
           ),
         {:ok, update_map} <- _get_update_map(update, attributes),
         :ok <-
           WandererApp.Map.update_connection(
             map_id,
             connection |> Map.merge(update_map)
           ),
         {:ok, updated_connection} <-
           apply(WandererApp.MapConnectionRepo, update_method, [
             connection,
             update_map
           ]) do
      if not is_nil(callback_fn) do
        callback_fn.(updated_connection)
      end

      broadcast!(map_id, :update_connection, updated_connection)

      state
    else
      {:error, error} ->
        @logger.error("Failed to update connection: #{inspect(error, pretty: true)}")

        state
    end
  end

  defp _update_system(
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
         {:ok, update_map} <- _get_update_map(update, attributes),
         {:ok, updated_system} <-
           apply(WandererApp.MapSystemRepo, update_method, [
             system,
             update_map
           ]) do
      if not is_nil(callback_fn) do
        callback_fn.(updated_system)
      end

      _update_map_system_last_activity(map_id, updated_system)

      state
    else
      error ->
        @logger.error("Failed to update system: #{inspect(error, pretty: true)}")
        state
    end
  end

  defp _get_update_map(update, attributes),
    do:
      {:ok,
       Enum.reduce(attributes, Map.new(), fn attribute, map ->
         map |> Map.put_new(attribute, get_in(update, [Access.key(attribute)]))
       end)}

  defp _add_system(
         %{map_id: map_id, rtree_name: rtree_name} = state,
         %{
           solar_system_id: solar_system_id,
           coordinates: coordinates
         } = _system_info,
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
            WandererApp.Map.PositionCalculator.get_new_system_position(nil, rtree_name)

          %{"x" => x, "y" => y}
      end

    {:ok, system} =
      case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id) do
        {:ok, existing_system} when not is_nil(existing_system) ->
          @ddrt.insert(
            {solar_system_id,
             WandererApp.Map.PositionCalculator.get_system_bounding_rect(%{
               position_x: x,
               position_y: y
             })},
            rtree_name
          )

          existing_system
          |> WandererApp.MapSystemRepo.update_position(%{position_x: x, position_y: y})

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

    broadcast!(map_id, :add_system, system)

    :telemetry.execute([:wanderer_app, :map, :system, :add], %{count: 1}, %{
      character_id: character_id,
      user_id: user_id,
      map_id: map_id,
      solar_system_id: solar_system_id
    })

    state
  end

  defp _save_map_state(%{map_id: map_id} = _state) do
    systems_last_activity =
      map_id
      |> WandererApp.Map.list_systems!()
      |> Enum.reduce(%{}, fn %{id: system_id} = _system, acc ->
        case WandererApp.Cache.get("map_#{map_id}:system_#{system_id}:last_activity") do
          nil ->
            acc

          value ->
            acc |> Map.put_new(system_id, value)
        end
      end)

    connections_eol_time =
      map_id
      |> WandererApp.Map.list_connections!()
      |> Enum.reduce(%{}, fn %{id: connection_id} = _connection, acc ->
        case WandererApp.Cache.get("map_#{map_id}:conn_#{connection_id}:mark_eol_time") do
          nil ->
            acc

          value ->
            acc |> Map.put_new(connection_id, value)
        end
      end)

    WandererApp.Api.MapState.create(%{
      map_id: map_id,
      systems_last_activity: systems_last_activity,
      connections_eol_time: connections_eol_time
    })
  end

  defp _maybe_stop_rtree(%{rtree_name: rtree_name} = state) do
    case Process.whereis(rtree_name) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        GenServer.stop(pid, :normal)
    end

    state
  end

  defp _init_map_cache(%__MODULE__{map_id: map_id} = state) do
    case WandererApp.Api.MapState.by_map_id(map_id) do
      {:ok,
       %{
         systems_last_activity: systems_last_activity,
         connections_eol_time: connections_eol_time
       }} ->
        systems_last_activity
        |> Enum.each(fn {system_id, last_activity} ->
          WandererApp.Cache.put(
            "map_#{map_id}:system_#{system_id}:last_activity",
            last_activity,
            ttl: @system_inactive_timeout
          )
        end)

        connections_eol_time
        |> Enum.each(fn {connection_id, connection_eol_time} ->
          WandererApp.Cache.put(
            "map_#{map_id}:conn_#{connection_id}:mark_eol_time",
            connection_eol_time,
            ttl: @connection_eol_expire_timeout
          )
        end)

        state

      _ ->
        state
    end
  end

  defp _init_map(
         state,
         %{characters: characters} = map,
         subscription_settings,
         systems,
         connections
       ) do
    map =
      map
      |> WandererApp.Map.new()
      |> WandererApp.Map.update_subscription_settings!(subscription_settings)
      |> WandererApp.Map.add_systems!(systems)
      |> WandererApp.Map.add_connections!(connections)
      |> WandererApp.Map.add_characters!(characters)

    %{state | map: map}
  end

  defp _init_map_systems(state, [] = _systems), do: state

  defp _init_map_systems(%__MODULE__{map_id: map_id, rtree_name: rtree_name} = state, systems) do
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

  def _maybe_import_systems(state, %{"systems" => systems} = _settings, user_id, character_id) do
    state =
      systems
      |> Enum.reduce(state, fn %{
                                 "description" => description,
                                 "id" => id,
                                 "labels" => labels,
                                 "locked" => locked,
                                 "name" => name,
                                 "position" => %{"x" => x, "y" => y},
                                 "status" => status,
                                 "tag" => tag
                               } = _system,
                               acc ->
        acc
        |> add_system(
          %{
            solar_system_id: id |> String.to_integer(),
            coordinates: %{"x" => round(x), "y" => round(y)}
          },
          user_id,
          character_id
        )
        |> update_system_name(%{solar_system_id: id |> String.to_integer(), name: name})
        |> update_system_description(%{
          solar_system_id: id |> String.to_integer(),
          description: description
        })
        |> update_system_status(%{solar_system_id: id |> String.to_integer(), status: status})
        |> update_system_tag(%{solar_system_id: id |> String.to_integer(), tag: tag})
        |> update_system_locked(%{solar_system_id: id |> String.to_integer(), locked: locked})
        |> update_system_labels(%{solar_system_id: id |> String.to_integer(), labels: labels})
      end)

    removed_system_ids =
      systems
      |> Enum.filter(fn system -> not system["visible"] end)
      |> Enum.map(fn system -> system["id"] end)
      |> Enum.map(&String.to_integer/1)

    state
    |> delete_systems(removed_system_ids, user_id, character_id)
  end

  def _maybe_import_connections(state, %{"connections" => connections} = _settings, _user_id) do
    connections
    |> Enum.reduce(state, fn %{
                               "source" => source,
                               "target" => target,
                               "mass_status" => mass_status,
                               "time_status" => time_status,
                               "ship_size_type" => ship_size_type
                             } = _system,
                             acc ->
      source_id = source |> String.to_integer()
      target_id = target |> String.to_integer()

      acc
      |> add_connection(%{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id
      })
      |> update_connection_time_status(%{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id,
        time_status: time_status
      })
      |> update_connection_mass_status(%{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id,
        mass_status: mass_status
      })
      |> update_connection_ship_size_type(%{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id,
        ship_size_type: ship_size_type
      })
    end)
  end

  def _maybe_import_hubs(state, %{"hubs" => hubs} = _settings, _user_id) do
    hubs
    |> Enum.reduce(state, fn hub, acc ->
      solar_system_id = hub |> String.to_integer()

      acc
      |> add_hub(%{solar_system_id: solar_system_id})
    end)
  end

  defp _update_map_system_last_activity(
         map_id,
         updated_system
       ) do
    WandererApp.Cache.put(
      "map_#{map_id}:system_#{updated_system.id}:last_activity",
      DateTime.utc_now(),
      ttl: @system_inactive_timeout
    )

    broadcast!(map_id, :update_system, updated_system)
  end

  defp _can_add_location(_scope, nil), do: false

  defp _can_add_location(:all, _solar_system_id), do: true

  defp _can_add_location(:none, _solar_system_id), do: false

  defp _can_add_location(scope, solar_system_id) do
    system_static_info =
      case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
        {:ok, system_static_info} when not is_nil(system_static_info) ->
          system_static_info

        _ ->
          %{system_class: nil}
      end

    case scope do
      :wormholes ->
        not (@prohibited_system_classes |> Enum.member?(system_static_info.system_class)) and
          not (@prohibited_systems |> Enum.member?(solar_system_id)) and
          @wh_space |> Enum.member?(system_static_info.system_class)

      :stargates ->
        not (@prohibited_system_classes |> Enum.member?(system_static_info.system_class)) and
          @known_space |> Enum.member?(system_static_info.system_class)

      _ ->
        false
    end
  end

  defp _is_connection_exist(map_id, from_solar_system_id, to_solar_system_id),
    do:
      not is_nil(
        WandererApp.Map.find_system_by_location(
          map_id,
          %{solar_system_id: from_solar_system_id}
        )
      ) and
        not is_nil(
          WandererApp.Map.find_system_by_location(
            map_id,
            %{solar_system_id: to_solar_system_id}
          )
        )

  defp _is_connection_valid(_scope, nil, _to_solar_system_id), do: false

  defp _is_connection_valid(:all, _from_solar_system_id, _to_solar_system_id), do: true

  defp _is_connection_valid(:none, _from_solar_system_id, _to_solar_system_id), do: false

  defp _is_connection_valid(scope, from_solar_system_id, to_solar_system_id) do
    {:ok, known_jumps} =
      WandererApp.Api.MapSolarSystemJumps.find(%{
        before_system_id: from_solar_system_id,
        current_system_id: to_solar_system_id
      })

    system_static_info =
      case WandererApp.CachedInfo.get_system_static_info(to_solar_system_id) do
        {:ok, system_static_info} when not is_nil(system_static_info) ->
          system_static_info

        _ ->
          %{system_class: nil}
      end

    case scope do
      :wormholes ->
        not (@prohibited_system_classes |> Enum.member?(system_static_info.system_class)) and
          not (@prohibited_systems |> Enum.member?(to_solar_system_id)) and
          known_jumps |> Enum.empty?() and to_solar_system_id != @jita and
          from_solar_system_id != @jita

      :stargates ->
        not (@prohibited_system_classes |> Enum.member?(system_static_info.system_class)) and
          not (known_jumps |> Enum.empty?())
    end
  end

  defp _update_presence(map_id) do
    case WandererApp.Cache.lookup!("map_#{map_id}:started", false) and
           WandererApp.Cache.get_and_remove!("map_#{map_id}:presence_updated", false) do
      true ->
        {:ok, presence_character_ids} =
          WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])

        characters_ids =
          map_id
          |> WandererApp.Map.get_map!()
          |> Map.get(:characters, [])

        not_present_character_ids =
          characters_ids
          |> Enum.filter(fn character_id ->
            not Enum.member?(presence_character_ids, character_id)
          end)

        _track_characters(presence_character_ids, map_id)

        map_id
        |> _untrack_characters(not_present_character_ids)

        broadcast!(
          map_id,
          :present_characters_updated,
          presence_character_ids
          |> WandererApp.Character.get_character_eve_ids!()
        )

        :ok

      _ ->
        :ok
    end
  end

  defp _track_acls([]), do: :ok

  defp _track_acls([acl_id | rest]) do
    _track_acl(acl_id)
    _track_acls(rest)
  end

  defp _track_acl(acl_id),
    do:
      WandererApp.PubSub
      |> @pubsub_client.subscribe("acls:#{acl_id}")

  defp _track_characters([], _map_id), do: :ok

  defp _track_characters([character_id | rest], map_id) do
    _track_character(character_id, map_id)
    _track_characters(rest, map_id)
  end

  defp _track_character(character_id, map_id) do
    WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
      map_id: map_id,
      track: true,
      track_online: true,
      track_location: true,
      track_ship: true
    })
  end

  defp _update_character(map_id, character_id) do
    {:ok, character} = WandererApp.Character.get_character(character_id)
    broadcast!(map_id, :character_updated, character)
  end

  defp _untrack_characters(map_id, character_ids) do
    character_ids
    |> Enum.each(fn character_id ->
      WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
        map_id: map_id,
        track: false
      })
    end)
  end

  defp maybe_remove_connection(map_id, location, old_location)
       when not is_nil(location) and not is_nil(old_location) and
              location.solar_system_id != old_location.solar_system_id do
    case WandererApp.Map.find_connection(
           map_id,
           location.solar_system_id,
           old_location.solar_system_id
         ) do
      {:ok, connection} ->
        connection
        |> WandererApp.MapConnectionRepo.destroy!()

        broadcast!(map_id, :remove_connections, [connection])
        map_id |> WandererApp.Map.remove_connection(connection)

      {:error, _error} ->
        :ok
    end
  end

  defp maybe_remove_connection(_map_id, _location, _old_location), do: :ok

  defp maybe_add_connection(map_id, location, old_location, character)
       when not is_nil(location) and not is_nil(old_location) and
              not is_nil(old_location.solar_system_id) and
              location.solar_system_id != old_location.solar_system_id do
    case character do
      nil ->
        :ok

      _ ->
        :telemetry.execute([:wanderer_app, :map, :character, :jump], %{count: 1}, %{
          map_id: map_id,
          character: character,
          solar_system_source_id: old_location.solar_system_id,
          solar_system_target_id: location.solar_system_id
        })
    end

    case WandererApp.Map.check_connection(map_id, location, old_location) do
      :ok ->
        connection =
          WandererApp.MapConnectionRepo.create!(%{
            map_id: map_id,
            solar_system_source: old_location.solar_system_id,
            solar_system_target: location.solar_system_id
          })

        broadcast!(map_id, :add_connection, connection)
        WandererApp.Map.add_connection(map_id, connection)

      {:error, error} ->
        @logger.debug(fn -> "Failed to add connection: #{inspect(error, pretty: true)}" end)
        :ok
    end
  end

  defp maybe_add_connection(_map_id, _location, _old_location, _character), do: :ok

  defp maybe_add_system(map_id, location, old_location, rtree_name)
       when not is_nil(location) do
    case WandererApp.Map.check_location(map_id, location) do
      {:ok, location} ->
        {:ok, position} = calc_new_system_position(map_id, old_location, rtree_name)

        case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(
               map_id,
               location.solar_system_id
             ) do
          {:ok, existing_system} when not is_nil(existing_system) ->
            {:ok, updated_system} =
              existing_system
              |> WandererApp.MapSystemRepo.update_position(%{
                position_x: position.x,
                position_y: position.y
              })

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

            broadcast!(map_id, :add_system, updated_system)
            WandererApp.Map.add_system(map_id, updated_system)

          _ ->
            {:ok, solar_system_info} =
              WandererApp.Api.MapSolarSystem.by_solar_system_id(location.solar_system_id)

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

                broadcast!(map_id, :add_system, new_system)
                WandererApp.Map.add_system(map_id, new_system)

              _ ->
                :ok
            end
        end

      {:error, _} ->
        :ok
    end
  end

  defp maybe_add_system(_map_id, _location, _old_location, _rtree_name), do: :ok

  defp calc_new_system_position(map_id, old_location, rtree_name) do
    {:ok,
     map_id
     |> WandererApp.Map.find_system_by_location(old_location)
     |> WandererApp.Map.PositionCalculator.get_new_system_position(rtree_name)}
  end

  defp _broadcast_acl_updates(
         {:ok,
          %{
            eve_character_ids: eve_character_ids,
            eve_corporation_ids: eve_corporation_ids,
            eve_alliance_ids: eve_alliance_ids
          }}
       ) do
    eve_character_ids
    |> Enum.uniq()
    |> Enum.each(fn eve_character_id ->
      @pubsub_client.broadcast(
        WandererApp.PubSub,
        "character:#{eve_character_id}",
        :update_permissions
      )
    end)

    eve_corporation_ids
    |> Enum.uniq()
    |> Enum.each(fn eve_corporation_id ->
      @pubsub_client.broadcast(
        WandererApp.PubSub,
        "corporation:#{eve_corporation_id}",
        :update_permissions
      )
    end)

    eve_alliance_ids
    |> Enum.uniq()
    |> Enum.each(fn eve_alliance_id ->
      @pubsub_client.broadcast(
        WandererApp.PubSub,
        "alliance:#{eve_alliance_id}",
        :update_permissions
      )
    end)

    :ok
  end

  defp _broadcast_acl_updates(_), do: :ok

  defp _update_acl(acl_id) do
    {:ok, %{owner: owner, members: members}} =
      WandererApp.AccessListRepo.get(acl_id, [:owner, :members])

    result =
      members
      |> Enum.reduce(
        %{eve_character_ids: [owner.eve_id], eve_corporation_ids: [], eve_alliance_ids: []},
        fn member, acc ->
          case member do
            %{eve_character_id: eve_character_id} when not is_nil(eve_character_id) ->
              acc
              |> Map.put(:eve_character_ids, [eve_character_id | acc.eve_character_ids])

            %{eve_corporation_id: eve_corporation_id} when not is_nil(eve_corporation_id) ->
              acc
              |> Map.put(:eve_corporation_ids, [eve_corporation_id | acc.eve_corporation_ids])

            %{eve_alliance_id: eve_alliance_id} when not is_nil(eve_alliance_id) ->
              acc
              |> Map.put(:eve_alliance_ids, [eve_alliance_id | acc.eve_alliance_ids])

            _ ->
              acc
          end
        end
      )

    {:ok, result}
  end
end
