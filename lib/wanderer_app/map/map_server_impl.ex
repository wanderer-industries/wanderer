defmodule WandererApp.Map.Server.Impl do
  @moduledoc """
  Holds state for a map and exposes an interface to managing the map instance
  """
  require Logger

  alias WandererApp.Map.Server.ConnectionsImpl

  @enforce_keys [
    :map_id
  ]

  defstruct [
    :map_id,
    :rtree_name,
    map: nil,
    map_opts: []
  ]

  @systems_cleanup_timeout :timer.minutes(30)
  @characters_cleanup_timeout :timer.minutes(1)
  @connections_cleanup_timeout :timer.minutes(2)

  @system_auto_expire_minutes 15

  @ddrt Application.compile_env(:wanderer_app, :ddrt)
  @logger Application.compile_env(:wanderer_app, :logger)
  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)
  @backup_state_timeout :timer.minutes(1)
  @system_inactive_timeout :timer.minutes(15)
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
    with {:ok, map} <-
           WandererApp.MapRepo.get(map_id, [
             :owner,
             :characters,
             acls: [
               :owner_id,
               members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
             ]
           ]),
         {:ok, systems} <- WandererApp.MapSystemRepo.get_visible_by_map(map_id),
         {:ok, connections} <- WandererApp.MapConnectionRepo.get_by_map(map_id),
         {:ok, subscription_settings} <-
           WandererApp.Map.SubscriptionManager.get_active_map_subscription(map_id) do
      state
      |> init_map(
        map,
        subscription_settings,
        systems,
        connections
      )
      |> init_map_systems(systems)
      |> init_map_cache()
    else
      error ->
        @logger.error("Failed to load map state: #{inspect(error, pretty: true)}")
        state
    end
  end

  def start_map(%__MODULE__{map: map, map_id: map_id} = state) do
    with :ok <- track_acls(map.acls |> Enum.map(& &1.id)) do
      @pubsub_client.subscribe(
        WandererApp.PubSub,
        "maps:#{map_id}"
      )

      Process.send_after(self(), :update_characters, @update_characters_timeout)
      Process.send_after(self(), :update_tracked_characters, 100)
      Process.send_after(self(), :update_presence, @update_presence_timeout)
      Process.send_after(self(), :cleanup_connections, 5000)
      Process.send_after(self(), :cleanup_systems, 10_000)
      Process.send_after(self(), :cleanup_characters, :timer.minutes(5))
      Process.send_after(self(), :backup_state, @backup_state_timeout)

      WandererApp.Cache.insert("map_#{map_id}:started", true)

      broadcast!(map_id, :map_server_started)

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
    |> maybe_stop_rtree()
  end

  def get_map(%{map: map} = _state), do: {:ok, map}

  def get_characters(%{map_id: map_id} = _state),
    do: {:ok, map_id |> WandererApp.Map.list_characters()}

  def add_character(%{map_id: map_id} = state, %{id: character_id} = character, track_character) do
    Task.start_link(fn ->
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

        :ok
      else
        _error ->
          {:ok, character} = WandererApp.Character.get_character(character_id)
          broadcast!(map_id, :character_added, character)
          :ok
      end
    end)

    state
  end

  def remove_character(%{map_id: map_id} = state, character_id) do
    Task.start_link(fn ->
      with :ok <- WandererApp.Map.remove_character(map_id, character_id),
           {:ok, character} <- WandererApp.Character.get_character(character_id) do
        broadcast!(map_id, :character_removed, character)

        :telemetry.execute([:wanderer_app, :map, :character, :removed], %{count: 1})

        :ok
      else
        {:error, _error} ->
          :ok
      end
    end)

    state
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
      WandererApp.MapConnectionRepo.destroy(map_id, connection)
    end)

    @ddrt.delete(removed_ids, rtree_name)

    broadcast!(map_id, :remove_connections, connections_to_remove)
    broadcast!(map_id, :systems_removed, removed_ids)

    case not is_nil(user_id) do
      true ->
        {:ok, _} =
          WandererApp.User.ActivityTracker.track_map_event(:systems_removed, %{
            character_id: character_id,
            user_id: user_id,
            map_id: map_id,
            solar_system_ids: removed_ids
          })

        :telemetry.execute(
          [:wanderer_app, :map, :systems, :remove],
          %{count: removed_ids |> Enum.count()}
        )

        :ok

      _ ->
        :ok
    end

    state
  end

  defdelegate add_connection(state, connection_info), to: ConnectionsImpl

  defdelegate delete_connection(state, connection_info), to: ConnectionsImpl

  defdelegate get_connection_info(state, connection_info), to: ConnectionsImpl

  defdelegate update_connection_time_status(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_type(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_mass_status(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_ship_size_type(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_locked(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_custom_info(state, connection_update), to: ConnectionsImpl

  def import_settings(%{map_id: map_id} = state, settings, user_id) do
    WandererApp.Cache.put(
      "map_#{map_id}:importing",
      true
    )

    state =
      state
      |> maybe_import_systems(settings, user_id, nil)
      |> maybe_import_connections(settings, user_id)
      |> maybe_import_hubs(settings, user_id)

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
          maybe_update_online(map_id, character_id) ++
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

            {:character_alliance, _info} ->
              WandererApp.Cache.insert_or_update(
                "map_#{map_id}:invalidate_character_ids",
                [character_id],
                fn ids ->
                  [character_id | ids]
                end
              )

              :broadcast

            {:character_corporation, _info} ->
              WandererApp.Cache.insert_or_update(
                "map_#{map_id}:invalidate_character_ids",
                [character_id],
                fn ids ->
                  [character_id | ids]
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
      {:ok, map_tracked_character_ids} =
        map_id
        |> WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_all()
        |> case do
          {:ok, settings} -> {:ok, settings |> Enum.map(&Map.get(&1, :character_id))}
          _ -> {:ok, []}
        end

      {:ok, tracked_characters} = WandererApp.Cache.lookup("tracked_characters", [])

      map_active_tracked_characters =
        map_tracked_character_ids
        |> Enum.filter(fn character -> character in tracked_characters end)

      WandererApp.Cache.insert("maps:#{map_id}:tracked_characters", map_active_tracked_characters)

      :ok
    end)

    state
  end

  def handle_event(:update_presence, %{map_id: map_id} = state) do
    Process.send_after(self(), :update_presence, @update_presence_timeout)

    update_presence(map_id)

    state
  end

  def handle_event(:backup_state, state) do
    Process.send_after(self(), :backup_state, @backup_state_timeout)
    {:ok, _map_state} = state |> save_map_state()

    state
  end

  def handle_event(
        {:map_acl_updated, added_acls, removed_acls},
        %{map_id: map_id, map: old_map} = state
      ) do
    {:ok, map} =
      WandererApp.MapRepo.get(map_id,
        acls: [
          :owner_id,
          members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
        ]
      )

    track_acls(added_acls)

    result =
      (added_acls ++ removed_acls)
      |> Task.async_stream(
        fn acl_id ->
          update_acl(acl_id)
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
              @logger.error("Failed to update map #{map_id} acl: #{inspect(error, pretty: true)}")

              acc
          end
        end
      )

    map_update = %{acls: map.acls, scope: map.scope}

    WandererApp.Map.update_map(map_id, map_update)

    broadcast_acl_updates({:ok, result}, map_id)

    %{state | map: Map.merge(old_map, map_update)}
  end

  def handle_event({:acl_updated, %{acl_id: acl_id}}, %{map_id: map_id, map: old_map} = state) do
    {:ok, map} =
      WandererApp.MapRepo.get(map_id,
        acls: [
          :owner_id,
          members: [:role, :eve_character_id, :eve_corporation_id, :eve_alliance_id]
        ]
      )

    if map.acls |> Enum.map(& &1.id) |> Enum.member?(acl_id) do
      map_update = %{acls: map.acls}

      WandererApp.Map.update_map(map_id, map_update)

      :ok =
        acl_id
        |> update_acl()
        |> broadcast_acl_updates(map_id)

      state
    else
      state
    end
  end

  def handle_event(:cleanup_connections, state) do
    Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)

    state |> ConnectionsImpl.cleanup_connections()
  end

  def handle_event(:cleanup_characters, %{map_id: map_id, map: %{owner_id: owner_id}} = state) do
    Process.send_after(self(), :cleanup_characters, @characters_cleanup_timeout)

    {:ok, invalidate_character_ids} =
      WandererApp.Cache.lookup(
        "map_#{map_id}:invalidate_character_ids",
        []
      )

    invalidate_character_ids
    |> Task.async_stream(
      fn character_id ->
        character_id
        |> WandererApp.Character.get_character()
        |> case do
          {:ok, character} ->
            acls =
              map_id
              |> WandererApp.Map.get_map!()
              |> Map.get(:acls, [])

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
      max_concurrency: System.schedulers_online(),
      on_timeout: :kill_task
    )
    |> Enum.each(fn
      {:ok, {:remove_character, character_id}} ->
        state |> remove_and_untrack_characters([character_id])
        :ok

      {:ok, _result} ->
        :ok

      {:error, reason} ->
        @logger.error("Error in cleanup_characters: #{inspect(reason)}")
    end)

    WandererApp.Cache.insert(
      "map_#{map_id}:invalidate_character_ids",
      []
    )

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

  def handle_event({:options_updated, options}, state),
    do: %{
      state
      | map_opts: [
          layout: options |> Map.get("layout", "left_to_right"),
          store_custom_labels:
            options |> Map.get("store_custom_labels", "false") |> String.to_existing_atom()
        ]
    }

  def handle_event({ref, _result}, %{map_id: _map_id} = state) do
    Process.demonitor(ref, [:flush])

    state
  end

  def handle_event(msg, state) do
    Logger.warning("Unhandled event: #{inspect(msg)}")

    state
  end

  def broadcast!(map_id, event, payload \\ nil) do
    if can_broadcast?(map_id) do
      @pubsub_client.broadcast!(WandererApp.PubSub, map_id, %{event: event, payload: payload})
    end

    :ok
  end

  defp remove_and_untrack_characters(%{map_id: map_id} = state, character_ids) do
    Logger.warning(fn ->
      "Map #{map_id} - remove and untrack characters #{inspect(character_ids)}"
    end)

    map_id
    |> _untrack_characters(character_ids)

    map_id
    |> WandererApp.MapCharacterSettingsRepo.get_tracked_by_map_filtered(character_ids)
    |> case do
      {:ok, settings} ->
        settings
        |> Enum.each(fn s ->
          s |> WandererApp.MapCharacterSettingsRepo.untrack()
          state |> remove_character(s.character_id)
        end)

      _ ->
        :ok
    end
  end

  defp can_broadcast?(map_id),
    do:
      not WandererApp.Cache.lookup!("map_#{map_id}:importing", false) and
        WandererApp.Cache.lookup!("map_#{map_id}:started", false)

  defp update_location(
         character_id,
         location,
         old_location,
         %{map: map, map_id: map_id, rtree_name: rtree_name, map_opts: map_opts} = _state
       ) do
    case is_nil(old_location.solar_system_id) and
           ConnectionsImpl.can_add_location(map.scope, location.solar_system_id) do
      true ->
        :ok = maybe_add_system(map_id, location, nil, rtree_name, map_opts)

      _ ->
        ConnectionsImpl.is_connection_valid(
          map.scope,
          old_location.solar_system_id,
          location.solar_system_id
        )
        |> case do
          true ->
            :ok = maybe_add_system(map_id, location, old_location, rtree_name, map_opts)
            :ok = maybe_add_system(map_id, old_location, location, rtree_name, map_opts)

            :ok =
              ConnectionsImpl.maybe_add_connection(map_id, location, old_location, character_id)

          _ ->
            :ok
        end
    end
  end

  defp maybe_update_location(map_id, character_id) do
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
        @logger.error("Failed to update alliance: #{inspect(error, pretty: true)}")
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
        @logger.error("Failed to update corporation: #{inspect(error, pretty: true)}")
        [:skip]
    end
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
        @logger.error("Failed to update online: #{inspect(error, pretty: true)}")
        [:skip]
    end
  end

  defp maybe_update_ship(map_id, character_id) do
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
         {:ok, update_map} <- get_update_map(update, attributes) do
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
        @logger.error("Fail ed to update system: #{inspect(error, pretty: true)}")
        state
    end
  end

  def get_update_map(update, attributes),
    do:
      {:ok,
       Enum.reduce(attributes, Map.new(), fn attribute, map ->
         map |> Map.put_new(attribute, get_in(update, [Access.key(attribute)]))
       end)}

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

    broadcast!(map_id, :add_system, system)

    {:ok, _} =
      WandererApp.User.ActivityTracker.track_map_event(:system_added, %{
        character_id: character_id,
        user_id: user_id,
        map_id: map_id,
        solar_system_id: solar_system_id
      })

    state
  end

  defp save_map_state(%{map_id: map_id} = _state) do
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

  defp maybe_stop_rtree(%{rtree_name: rtree_name} = state) do
    case Process.whereis(rtree_name) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        GenServer.stop(pid, :normal)
    end

    state
  end

  defp init_map_cache(%__MODULE__{map_id: map_id} = state) do
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

        ConnectionsImpl.init_eol_cache(map_id, connections_eol_time)

        state

      _ ->
        state
    end
  end

  defp init_map(
         state,
         %{id: map_id, characters: characters} = initial_map,
         subscription_settings,
         systems,
         connections
       ) do
    map =
      initial_map
      |> WandererApp.Map.new()
      |> WandererApp.Map.update_subscription_settings!(subscription_settings)
      |> WandererApp.Map.add_systems!(systems)
      |> WandererApp.Map.add_connections!(connections)
      |> WandererApp.Map.add_characters!(characters)

    {:ok, map_options} = WandererApp.MapRepo.options_to_form_data(initial_map)

    map_opts = [
      layout: map_options |> Map.get("layout", "left_to_right"),
      store_custom_labels:
        map_options |> Map.get("store_custom_labels", "false") |> String.to_existing_atom()
    ]

    character_ids =
      map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:characters, [])

    WandererApp.Cache.insert("map_#{map_id}:invalidate_character_ids", character_ids)

    %{state | map: map, map_opts: map_opts}
  end

  defp init_map_systems(state, [] = _systems), do: state

  defp init_map_systems(%__MODULE__{map_id: map_id, rtree_name: rtree_name} = state, systems) do
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

  def maybe_import_systems(state, %{"systems" => systems} = _settings, user_id, character_id) do
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

  def maybe_import_connections(state, %{"connections" => connections} = _settings, _user_id) do
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

  def maybe_import_hubs(state, %{"hubs" => hubs} = _settings, _user_id) do
    hubs
    |> Enum.reduce(state, fn hub, acc ->
      solar_system_id = hub |> String.to_integer()

      acc
      |> add_hub(%{solar_system_id: solar_system_id})
    end)
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

    broadcast!(map_id, :update_system, updated_system)
  end

  defp update_presence(map_id) do
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

        track_characters(presence_character_ids, map_id)

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

  defp track_acls([]), do: :ok

  defp track_acls([acl_id | rest]) do
    track_acl(acl_id)
    track_acls(rest)
  end

  defp track_acl(acl_id),
    do: @pubsub_client.subscribe(WandererApp.PubSub, "acls:#{acl_id}")

  defp track_characters([], _map_id), do: :ok

  defp track_characters([character_id | rest], map_id) do
    track_character(character_id, map_id)
    track_characters(rest, map_id)
  end

  defp track_character(character_id, map_id),
    do:
      WandererApp.Character.TrackerManager.update_track_settings(character_id, %{
        map_id: map_id,
        track: true,
        track_online: true,
        track_location: true,
        track_ship: true
      })

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

  defp maybe_add_system(map_id, location, old_location, rtree_name, map_opts)
       when not is_nil(location) do
    case WandererApp.Map.check_location(map_id, location) do
      {:ok, location} ->
        {:ok, position} = calc_new_system_position(map_id, old_location, rtree_name, map_opts)

        case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(
               map_id,
               location.solar_system_id
             ) do
          {:ok, existing_system} when not is_nil(existing_system) ->
            {:ok, updated_system} =
              existing_system
              |> WandererApp.MapSystemRepo.update_position!(%{
                position_x: position.x,
                position_y: position.y
              })
              |> WandererApp.MapSystemRepo.cleanup_labels!(map_opts)
              |> WandererApp.MapSystemRepo.update_visible!(%{visible: true})
              |> WandererApp.MapSystemRepo.cleanup_tags()

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

            broadcast!(map_id, :add_system, updated_system)
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
                broadcast!(map_id, :add_system, new_system)

                :ok

              error ->
                @logger.warning("Failed to create system: #{inspect(error, pretty: true)}")
                :ok
            end
        end

      error ->
        @logger.debug("Skip adding system: #{inspect(error, pretty: true)}")
        :ok
    end
  end

  defp maybe_add_system(_map_id, _location, _old_location, _rtree_name, _map_opts), do: :ok

  defp calc_new_system_position(map_id, old_location, rtree_name, opts),
    do:
      {:ok,
       map_id
       |> WandererApp.Map.find_system_by_location(old_location)
       |> WandererApp.Map.PositionCalculator.get_new_system_position(rtree_name, opts)}

  defp broadcast_acl_updates(
         {:ok,
          %{
            eve_character_ids: eve_character_ids,
            eve_corporation_ids: eve_corporation_ids,
            eve_alliance_ids: eve_alliance_ids
          }},
         map_id
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

    character_ids =
      map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:characters, [])

    WandererApp.Cache.insert("map_#{map_id}:invalidate_character_ids", character_ids)

    :ok
  end

  defp broadcast_acl_updates(_, _map_id), do: :ok

  defp update_acl(acl_id) do
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
