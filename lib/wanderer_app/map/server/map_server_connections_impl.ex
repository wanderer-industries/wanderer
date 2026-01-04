defmodule WandererApp.Map.Server.ConnectionsImpl do
  @moduledoc false

  require Logger

  alias WandererApp.Map.Server.Impl
  alias WandererApp.Map.Server.SignaturesImpl
  alias WandererApp.Map.Server.SystemsImpl

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
  @barbican 15
  @vidette 16
  @conflux 17
  @redoubt 18
  @a1 19
  @a2 20
  @a3 21
  @a4 22
  @a5 23
  @ccp4 24
  @pochven 25
  # @zarzakh 10100

  @frigate_ship_size 0
  @large_ship_size 2

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
    @barbican,
    @vidette,
    @conflux,
    @redoubt
  ]

  @known_space [@hs, @ls, @ns, @pochven]

  # Individual space type lists for granular scope matching
  @hi_space [@hs]
  @low_space [@ls]
  @null_space [@ns]
  @pochven_space [@pochven]

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

  # default (env) setting, not EOL
  @connection_time_status_default 0
  # EOL 1h
  @connection_time_status_eol 1
  # EOL 4h
  @connection_time_status_eol_4 2
  # EOL 4.5h
  @connection_time_status_eol_4_5 3
  # EOL 16h
  @connection_time_status_eol_16 4
  # EOL 24h
  @connection_time_status_eol_24 5
  # EOL 48h
  @connection_time_status_eol_48 6

  # EOL 1h
  @connection_eol_minutes 60
  # EOL 4h
  @connection_eol_4_minutes 4 * 60
  # EOL 4.5h
  @connection_eol_4_5_minutes 4.5 * 60
  # EOL 16h
  @connection_eol_16_minutes 16 * 60
  # EOL 24h
  @connection_eol_24_minutes 24 * 60
  # EOL 48h
  @connection_eol_48_minutes 48 * 60

  @connection_type_wormhole 0
  @connection_type_stargate 1
  # @connection_type_bridge 2 # reserved for future use
  @medium_ship_size 1

  def get_connection_auto_expire_hours(), do: WandererApp.Env.map_connection_auto_expire_hours()

  def get_connection_auto_eol_hours(), do: WandererApp.Env.map_connection_auto_eol_hours()

  def get_eol_expire_timeout_mins(), do: WandererApp.Env.map_connection_eol_expire_timeout_mins()

  def get_eol_expire_timeout(),
    do:
      :timer.hours(get_connection_auto_expire_hours() - get_connection_auto_eol_hours()) +
        :timer.minutes(get_eol_expire_timeout_mins())

  def get_connection_expire_timeout(),
    do:
      :timer.hours(get_connection_auto_expire_hours()) +
        :timer.minutes(get_eol_expire_timeout_mins())

  def init_eol_cache(map_id, connections_eol_time) do
    connections_eol_time
    |> Enum.each(fn {connection_id, connection_eol_time} ->
      WandererApp.Cache.put(
        "map_#{map_id}:conn_#{connection_id}:mark_eol_time",
        connection_eol_time
      )
    end)
  end

  def init_start_cache(map_id, connections_start_time) when not is_nil(connections_start_time) do
    connections_start_time
    |> Enum.each(fn {connection_id, start_time} ->
      set_start_time(map_id, connection_id, start_time)
    end)
  end

  def init_start_cache(_map_id, _connections_start_time), do: :ok

  def add_connection(
        map_id,
        %{
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id,
          character_id: character_id
        } = connection_info
      ),
      do:
        maybe_add_connection(
          map_id,
          %{solar_system_id: solar_system_target_id},
          %{
            solar_system_id: solar_system_source_id
          },
          character_id,
          true,
          connection_info |> Map.get(:extra_info)
        )

  def paste_connections(
        map_id,
        connections,
        _user_id,
        character_id
      ) do
    connections
    |> Enum.each(fn %{
                      "source" => source,
                      "target" => target
                    } = connection ->
      solar_system_source_id = source |> String.to_integer()
      solar_system_target_id = target |> String.to_integer()

      add_connection(map_id, %{
        solar_system_source_id: solar_system_source_id,
        solar_system_target_id: solar_system_target_id,
        character_id: character_id,
        extra_info: connection
      })
    end)
  end

  def delete_connection(
        map_id,
        %{
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id
        } = _connection_info
      ),
      do:
        maybe_remove_connection(map_id, %{solar_system_id: solar_system_target_id}, %{
          solar_system_id: solar_system_source_id
        })

  def get_connection_info(
        map_id,
        %{
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id
        } = _connection_info
      ) do
    WandererApp.Map.find_connection(
      map_id,
      solar_system_source_id,
      solar_system_target_id
    )
    |> case do
      {:ok, %{id: connection_id}} ->
        connection_mark_eol_time = get_connection_mark_eol_time(map_id, connection_id, nil)
        {:ok, %{marl_eol_time: connection_mark_eol_time}}

      _ ->
        {:error, :not_found}
    end
  end

  def update_connection_time_status(
        map_id,
        connection_update
      ),
      do:
        update_connection(map_id, :update_time_status, [:time_status], connection_update, fn
          %{time_status: old_time_status},
          %{id: connection_id, time_status: time_status} = updated_connection ->
            # Handle EOL marking cache separately
            case time_status == @connection_time_status_eol do
              true ->
                if old_time_status != @connection_time_status_eol do
                  WandererApp.Cache.put(
                    "map_#{map_id}:conn_#{connection_id}:mark_eol_time",
                    DateTime.utc_now()
                  )
                end

              _ ->
                if old_time_status == @connection_time_status_eol do
                  WandererApp.Cache.delete("map_#{map_id}:conn_#{connection_id}:mark_eol_time")
                end
            end

            # Always reset start_time when status changes (manual override)
            # This ensures user manual changes aren't immediately overridden by cleanup
            if time_status != old_time_status do
              # Emit telemetry for manual time status change
              :telemetry.execute(
                [:wanderer_app, :connection, :manual_status_change],
                %{system_time: System.system_time()},
                %{
                  map_id: map_id,
                  connection_id: connection_id,
                  old_time_status: old_time_status,
                  new_time_status: time_status
                }
              )

              set_start_time(map_id, connection_id, DateTime.utc_now())
              maybe_update_linked_signature_time_status(map_id, updated_connection)
            end
        end)

  def update_connection_type(
        map_id,
        connection_update
      ),
      do: update_connection(map_id, :update_type, [:type], connection_update)

  def update_connection_mass_status(
        map_id,
        connection_update
      ),
      do: update_connection(map_id, :update_mass_status, [:mass_status], connection_update)

  def update_connection_ship_size_type(
        map_id,
        connection_update
      ),
      do: update_connection(map_id, :update_ship_size_type, [:ship_size_type], connection_update)

  def update_connection_locked(
        map_id,
        connection_update
      ),
      do: update_connection(map_id, :update_locked, [:locked], connection_update)

  def update_connection_custom_info(
        map_id,
        connection_update
      ),
      do: update_connection(map_id, :update_custom_info, [:custom_info], connection_update)

  def cleanup_connections(map_id) do
    # Defensive check: Skip cleanup if cache appears invalid
    # This prevents incorrectly deleting connections when cache is empty due to
    # race conditions during map restart or cache corruption
    case WandererApp.Map.get_map(map_id) do
      {:error, :not_found} ->
        Logger.warning(
          "[cleanup_connections] Skipping map #{map_id} - cache miss detected, " <>
            "map data not found in cache"
        )

        :telemetry.execute(
          [:wanderer_app, :map, :cleanup_connections, :cache_miss],
          %{system_time: System.system_time()},
          %{map_id: map_id}
        )

        :ok

      {:ok, _map} ->
        do_cleanup_connections(map_id)
    end
  end

  defp do_cleanup_connections(map_id) do
    connection_auto_expire_hours = get_connection_auto_expire_hours()
    connection_auto_eol_hours = get_connection_auto_eol_hours()
    connection_eol_expire_timeout_hours = get_eol_expire_timeout_mins() / 60

    map_id
    |> WandererApp.Map.list_connections!()
    |> Enum.each(fn connection ->
      maybe_update_connection_time_status(map_id, connection)
    end)

    map_id
    |> WandererApp.Map.list_connections!()
    |> Enum.filter(fn %{
                        id: connection_id,
                        solar_system_source: solar_system_source_id,
                        solar_system_target: solar_system_target_id,
                        time_status: time_status,
                        type: type
                      } ->
      is_connection_exist =
        is_connection_exist(
          map_id,
          solar_system_source_id,
          solar_system_target_id
        ) ||
          not is_nil(
            WandererApp.Map.get_connection(
              map_id,
              solar_system_target_id,
              solar_system_source_id
            )
          )

      not is_connection_exist ||
        (type == @connection_type_wormhole &&
           time_status == @connection_time_status_eol &&
           is_connection_valid(
             :wormholes,
             solar_system_source_id,
             solar_system_target_id
           ) &&
           DateTime.diff(
             DateTime.utc_now(),
             get_connection_mark_eol_time(map_id, connection_id),
             :hour
           ) >=
             connection_auto_expire_hours - connection_auto_eol_hours +
               connection_eol_expire_timeout_hours)
    end)
    |> Enum.each(fn %{
                      solar_system_source: solar_system_source_id,
                      solar_system_target: solar_system_target_id
                    } ->
      # Emit telemetry for connection auto-deletion
      :telemetry.execute(
        [:wanderer_app, :map, :connection_cleanup, :delete],
        %{system_time: System.system_time()},
        %{
          map_id: map_id,
          solar_system_source_id: solar_system_source_id,
          solar_system_target_id: solar_system_target_id,
          reason: :auto_cleanup
        }
      )

      # Log auto-deletion for audit trail (no user/character context for auto-cleanup)
      WandererApp.User.ActivityTracker.track_map_event(:map_connection_removed, %{
        character_id: nil,
        user_id: nil,
        map_id: map_id,
        solar_system_source_id: solar_system_source_id,
        solar_system_target_id: solar_system_target_id
      })

      delete_connection(map_id, %{
        solar_system_source_id: solar_system_source_id,
        solar_system_target_id: solar_system_target_id
      })
    end)
  end

  defp maybe_update_connection_time_status(map_id, %{
         id: connection_id,
         solar_system_source: solar_system_source_id,
         solar_system_target: solar_system_target_id,
         time_status: time_status,
         type: @connection_type_wormhole
       }) do
    connection_start_time = get_start_time(map_id, connection_id)
    new_time_status = get_new_time_status(connection_start_time, time_status)

    if new_time_status != time_status &&
         is_connection_valid(
           :wormholes,
           solar_system_source_id,
           solar_system_target_id
         ) do
      # Emit telemetry for automatic time status downgrade
      elapsed_minutes = DateTime.diff(DateTime.utc_now(), connection_start_time, :minute)

      :telemetry.execute(
        [:wanderer_app, :connection, :auto_downgrade],
        %{
          elapsed_minutes: elapsed_minutes,
          system_time: System.system_time()
        },
        %{
          map_id: map_id,
          connection_id: connection_id,
          old_time_status: time_status,
          new_time_status: new_time_status,
          solar_system_source: solar_system_source_id,
          solar_system_target: solar_system_target_id
        }
      )

      set_start_time(map_id, connection_id, DateTime.utc_now())

      update_connection_time_status(map_id, %{
        solar_system_source_id: solar_system_source_id,
        solar_system_target_id: solar_system_target_id,
        time_status: new_time_status
      })
    end
  end

  defp maybe_update_connection_time_status(_map_id, _connection), do: :ok

  defp maybe_update_linked_signature_time_status(
         map_id,
         %{
           time_status: time_status,
           solar_system_source: solar_system_source,
           solar_system_target: solar_system_target
         } = _updated_connection
       ) do
    with source_system when not is_nil(source_system) <-
           WandererApp.Map.find_system_by_location(
             map_id,
             %{solar_system_id: solar_system_source}
           ),
         target_system when not is_nil(target_system) <-
           WandererApp.Map.find_system_by_location(
             map_id,
             %{solar_system_id: solar_system_target}
           ),
         source_linked_signatures <-
           find_linked_signatures(source_system, target_system),
         target_linked_signatures <- find_linked_signatures(target_system, source_system) do
      update_signatures_time_status(
        map_id,
        source_system.solar_system_id,
        source_linked_signatures,
        time_status
      )

      update_signatures_time_status(
        map_id,
        target_system.solar_system_id,
        target_linked_signatures,
        time_status
      )
    else
      error ->
        Logger.warning("Failed to update_linked_signature_time_status: #{inspect(error)}")
    end
  end

  defp find_linked_signatures(
         %{id: source_system_id} = _source_system,
         %{solar_system_id: solar_system_id, linked_sig_eve_id: linked_sig_eve_id} =
           _target_system
       )
       when not is_nil(linked_sig_eve_id) do
    {:ok, signatures} =
      WandererApp.Api.MapSystemSignature.by_linked_system_id(solar_system_id)

    signatures |> Enum.filter(fn sig -> sig.system_id == source_system_id end)
  end

  defp find_linked_signatures(_source_system, _target_system), do: []

  defp update_signatures_time_status(_map_id, _solar_system_id, [], _time_status), do: :ok

  defp update_signatures_time_status(map_id, solar_system_id, signatures, time_status) do
    signatures
    |> Enum.each(fn %{custom_info: custom_info_json} = sig ->
      update_params =
        if not is_nil(custom_info_json) do
          updated_custom_info =
            custom_info_json
            |> Jason.decode!()
            |> Map.merge(%{"time_status" => time_status})
            |> Jason.encode!()

          %{custom_info: updated_custom_info}
        else
          updated_custom_info = Jason.encode!(%{"time_status" => time_status})
          %{custom_info: updated_custom_info}
        end

      SignaturesImpl.apply_update_signature(map_id, sig, update_params)
    end)

    Impl.broadcast!(map_id, :signatures_updated, solar_system_id)
  end

  def maybe_add_connection(
        map_id,
        location,
        old_location,
        character_id,
        is_manual,
        extra_info
      )
      when not is_nil(location) and not is_nil(old_location) and
             not is_nil(old_location.solar_system_id) and
             location.solar_system_id != old_location.solar_system_id do
    {:ok, character} = WandererApp.Character.get_character(character_id)

    if not is_manual do
      :telemetry.execute([:wanderer_app, :map, :character, :jump], %{count: 1}, %{})

      {:ok, _} =
        WandererApp.Api.MapChainPassages.new(%{
          map_id: map_id,
          character_id: character_id,
          ship_type_id: character.ship,
          ship_name: character.ship_name,
          solar_system_source_id: old_location.solar_system_id,
          solar_system_target_id: location.solar_system_id
        })
    end

    case WandererApp.Map.check_connection(map_id, location, old_location) do
      :ok ->
        connection_type =
          is_connection_valid(
            :stargates,
            old_location.solar_system_id,
            location.solar_system_id
          )
          |> case do
            true ->
              @connection_type_stargate

            _ ->
              @connection_type_wormhole
          end

        # Set ship size type based on system classes and special rules
        ship_size_type =
          get_ship_size_type(
            old_location.solar_system_id,
            location.solar_system_id,
            connection_type
          )

        time_status =
          if connection_type == @connection_type_wormhole do
            get_time_status(
              old_location.solar_system_id,
              location.solar_system_id,
              ship_size_type
            )
          else
            @connection_time_status_default
          end

        connection_type = get_extra_info(extra_info, "type", connection_type)
        ship_size_type = get_extra_info(extra_info, "ship_size_type", ship_size_type)
        time_status = get_extra_info(extra_info, "time_status", time_status)
        mass_status = get_extra_info(extra_info, "mass_status", 0)
        locked = get_extra_info(extra_info, "locked", false)

        {:ok, connection} =
          WandererApp.MapConnectionRepo.create(%{
            map_id: map_id,
            solar_system_source: old_location.solar_system_id,
            solar_system_target: location.solar_system_id,
            type: connection_type,
            ship_size_type: ship_size_type,
            time_status: time_status,
            mass_status: mass_status,
            locked: locked
          })

        if connection_type == @connection_type_wormhole do
          set_start_time(map_id, connection.id, DateTime.utc_now())
        end

        WandererApp.Map.add_connection(map_id, connection)

        Impl.broadcast!(map_id, :maybe_select_system, %{
          character_id: character_id,
          solar_system_id: location.solar_system_id
        })

        Impl.broadcast!(map_id, :add_connection, connection)

        Impl.broadcast!(map_id, :maybe_link_signature, %{
          character_id: character_id,
          solar_system_source: old_location.solar_system_id,
          solar_system_target: location.solar_system_id
        })

        # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
        WandererApp.ExternalEvents.broadcast(map_id, :connection_added, %{
          connection_id: connection.id,
          solar_system_source_id: old_location.solar_system_id,
          solar_system_target_id: location.solar_system_id,
          type: connection_type,
          ship_size_type: ship_size_type,
          mass_status: connection.mass_status,
          time_status: connection.time_status
        })

        WandererApp.User.ActivityTracker.track_map_event(:map_connection_added, %{
          character_id: character_id,
          user_id: character.user_id,
          map_id: map_id,
          solar_system_source_id: old_location.solar_system_id,
          solar_system_target_id: location.solar_system_id
        })

        :ok

      {:error, :already_exists} ->
        # Still broadcast location change in case of followed character
        Impl.broadcast!(map_id, :maybe_select_system, %{
          character_id: character_id,
          solar_system_id: location.solar_system_id
        })

        :ok

      {:error, error} ->
        Logger.debug(fn -> "Failed to add connection: #{inspect(error, pretty: true)}" end)

        :ok
    end
  end

  def maybe_add_connection(
        _map_id,
        _location,
        _old_location,
        _character_id,
        _is_manual,
        _connection_extra_info
      ),
      do: :ok

  defp get_extra_info(nil, _key, default_value), do: default_value

  defp get_extra_info(extra_info, key, default_value), do: Map.get(extra_info, key, default_value)

  def get_start_time(map_id, connection_id) do
    case WandererApp.Cache.get("map_#{map_id}:conn_#{connection_id}:start_time") do
      nil ->
        set_start_time(map_id, connection_id, DateTime.utc_now())
        DateTime.utc_now()

      value ->
        value
    end
  end

  def set_start_time(map_id, connection_id, start_time),
    do:
      WandererApp.Cache.put(
        "map_#{map_id}:conn_#{connection_id}:start_time",
        start_time
      )

  def can_add_location(_scopes, nil), do: false

  def can_add_location([], _solar_system_id), do: false

  def can_add_location(scopes, solar_system_id) when is_list(scopes) do
    {:ok, system_static_info} = get_system_static_info(solar_system_id)

    not is_prohibited_system_class?(system_static_info.system_class) and
      not (@prohibited_systems |> Enum.member?(solar_system_id)) and
      system_matches_any_scope?(system_static_info.system_class, scopes)
  end

  # Legacy support for single scope atom
  def can_add_location(:none, _solar_system_id), do: false

  def can_add_location(scope, solar_system_id) when is_atom(scope) do
    can_add_location(legacy_scope_to_scopes(scope), solar_system_id)
  end

  # Helper function to check if a system class matches any of the selected scopes
  defp system_matches_any_scope?(_system_class, []), do: false

  defp system_matches_any_scope?(system_class, scopes) do
    Enum.any?(scopes, fn scope ->
      system_matches_scope?(system_class, scope)
    end)
  end

  # Individual scope matching functions
  defp system_matches_scope?(system_class, :wormholes), do: system_class in @wh_space
  defp system_matches_scope?(system_class, :hi), do: system_class in @hi_space
  defp system_matches_scope?(system_class, :low), do: system_class in @low_space
  defp system_matches_scope?(system_class, :null), do: system_class in @null_space
  defp system_matches_scope?(system_class, :pochven), do: system_class in @pochven_space
  defp system_matches_scope?(_system_class, _), do: false

  # Legacy scope to new scopes array conversion
  defp legacy_scope_to_scopes(:wormholes), do: [:wormholes]
  defp legacy_scope_to_scopes(:stargates), do: [:hi, :low, :null, :pochven]
  defp legacy_scope_to_scopes(:all), do: [:wormholes, :hi, :low, :null, :pochven]
  defp legacy_scope_to_scopes(:none), do: []
  defp legacy_scope_to_scopes(_), do: [:wormholes]

  def is_prohibited_system_class?(system_class) do
    @prohibited_system_classes |> Enum.member?(system_class)
  end

  def is_connection_exist(map_id, from_solar_system_id, to_solar_system_id),
    do:
      not is_nil(
        WandererApp.Map.find_system_by_location(
          map_id,
          %{solar_system_id: from_solar_system_id}
        )
      ) &&
        not is_nil(
          WandererApp.Map.find_system_by_location(
            map_id,
            %{solar_system_id: to_solar_system_id}
          )
        )

  def is_connection_valid(_scopes, from_solar_system_id, to_solar_system_id)
      when is_nil(from_solar_system_id) or is_nil(to_solar_system_id),
      do: false

  def is_connection_valid([], _from_solar_system_id, _to_solar_system_id), do: false

  # New array-based scopes support
  def is_connection_valid(scopes, from_solar_system_id, to_solar_system_id)
      when is_list(scopes) and from_solar_system_id != to_solar_system_id do
    with {:ok, from_system_static_info} <- get_system_static_info(from_solar_system_id),
         {:ok, to_system_static_info} <- get_system_static_info(to_solar_system_id) do
      # First check: neither system is prohibited
      not_prohibited =
        not is_prohibited_system_class?(from_system_static_info.system_class) and
          not is_prohibited_system_class?(to_system_static_info.system_class) and
          not (@prohibited_systems |> Enum.member?(from_solar_system_id)) and
          not (@prohibited_systems |> Enum.member?(to_solar_system_id))

      if not_prohibited do
        from_is_wormhole = from_system_static_info.system_class in @wh_space
        to_is_wormhole = to_system_static_info.system_class in @wh_space
        wormholes_enabled = :wormholes in scopes

        cond do
          # Case 1: Wormhole border behavior - at least one system is a wormhole
          # and :wormholes is enabled, allow the connection (adds border k-space systems)
          wormholes_enabled and (from_is_wormhole or to_is_wormhole) ->
            # At least one system matches (wormhole matches :wormholes, or other matches its scope)
            system_matches_any_scope?(from_system_static_info.system_class, scopes) or
              system_matches_any_scope?(to_system_static_info.system_class, scopes)

          # Case 2: K-space to K-space with :wormholes enabled - check if it's a wormhole connection
          # If neither system is a wormhole AND there's no stargate between them, it's a wormhole connection
          wormholes_enabled and not from_is_wormhole and not to_is_wormhole ->
            # Check if there's a known stargate connection
            case find_solar_system_jump(from_solar_system_id, to_solar_system_id) do
              {:ok, known_jumps} when known_jumps == [] ->
                # No stargate exists - this is a wormhole connection through k-space
                true

              {:ok, _known_jumps} ->
                # Stargate exists - this is NOT a wormhole, check normal scope matching
                system_matches_any_scope?(from_system_static_info.system_class, scopes) and
                  system_matches_any_scope?(to_system_static_info.system_class, scopes)

              _ ->
                # Error fetching jumps - fall back to scope matching
                system_matches_any_scope?(from_system_static_info.system_class, scopes) and
                  system_matches_any_scope?(to_system_static_info.system_class, scopes)
            end

          # Case 3: Non-wormhole movement without :wormholes scope
          # Both systems must match the configured scopes
          true ->
            system_matches_any_scope?(from_system_static_info.system_class, scopes) and
              system_matches_any_scope?(to_system_static_info.system_class, scopes)
        end
      else
        false
      end
    else
      _ -> false
    end
  end

  # Legacy support: :all scope
  def is_connection_valid(:all, from_solar_system_id, to_solar_system_id),
    do: from_solar_system_id != to_solar_system_id

  # Legacy support: :none scope
  def is_connection_valid(:none, _from_solar_system_id, _to_solar_system_id), do: false

  # Legacy support: single atom scope (including :stargates which is used for connection type detection)
  def is_connection_valid(scope, from_solar_system_id, to_solar_system_id)
      when is_atom(scope) and from_solar_system_id != to_solar_system_id do
    with {:ok, known_jumps} <- find_solar_system_jump(from_solar_system_id, to_solar_system_id),
         {:ok, from_system_static_info} <- get_system_static_info(from_solar_system_id),
         {:ok, to_system_static_info} <- get_system_static_info(to_solar_system_id) do
      case scope do
        :wormholes ->
          not is_prohibited_system_class?(from_system_static_info.system_class) and
            not is_prohibited_system_class?(to_system_static_info.system_class) and
            not (@prohibited_systems |> Enum.member?(from_solar_system_id)) and
            not (@prohibited_systems |> Enum.member?(to_solar_system_id)) and
            known_jumps |> Enum.empty?()

        :stargates ->
          # For stargates, we need to check:
          # 1. Both systems are in known space (HS, LS, NS, Pochven)
          # 2. There is a known jump between them
          # 3. Neither system is prohibited
          from_system_static_info.system_class in @known_space and
            to_system_static_info.system_class in @known_space and
            not is_prohibited_system_class?(from_system_static_info.system_class) and
            not is_prohibited_system_class?(to_system_static_info.system_class) and
            not (known_jumps |> Enum.empty?())

        _ ->
          # For other legacy scopes, convert to array and use new logic
          is_connection_valid(
            legacy_scope_to_scopes(scope),
            from_solar_system_id,
            to_solar_system_id
          )
      end
    else
      _ -> false
    end
  end

  def is_connection_valid(_scopes, _from_solar_system_id, _to_solar_system_id), do: false

  def get_connection_mark_eol_time(map_id, connection_id, default \\ DateTime.utc_now()) do
    WandererApp.Cache.get("map_#{map_id}:conn_#{connection_id}:mark_eol_time")
    |> case do
      nil ->
        default

      value ->
        value
    end
  end

  defp find_solar_system_jump(from_solar_system_id, to_solar_system_id) do
    case WandererApp.CachedInfo.get_solar_system_jump(from_solar_system_id, to_solar_system_id) do
      {:ok, jump} when not is_nil(jump) -> {:ok, [jump]}
      _ -> {:ok, []}
    end
  end

  @doc """
  Check if a connection between two k-space systems is a wormhole connection.
  Returns true if:
  1. Both systems are k-space (not wormhole space)
  2. There is no known stargate between them

  This is used to detect wormhole connections through k-space, like when
  a player jumps from low-sec to low-sec through a wormhole.
  """
  def is_kspace_wormhole_connection?(from_solar_system_id, to_solar_system_id)
      when is_nil(from_solar_system_id) or is_nil(to_solar_system_id),
      do: false

  def is_kspace_wormhole_connection?(from_solar_system_id, to_solar_system_id)
      when from_solar_system_id == to_solar_system_id,
      do: false

  def is_kspace_wormhole_connection?(from_solar_system_id, to_solar_system_id) do
    with {:ok, from_info} <- get_system_static_info(from_solar_system_id),
         {:ok, to_info} <- get_system_static_info(to_solar_system_id) do
      from_is_wormhole = from_info.system_class in @wh_space
      to_is_wormhole = to_info.system_class in @wh_space

      # Both must be k-space (not wormhole space)
      if not from_is_wormhole and not to_is_wormhole do
        # Check if there's a known stargate
        case find_solar_system_jump(from_solar_system_id, to_solar_system_id) do
          {:ok, []} -> true  # No stargate = wormhole connection
          _ -> false  # Stargate exists or error
        end
      else
        false
      end
    else
      _ -> false
    end
  end

  defp get_system_static_info(solar_system_id) do
    case WandererApp.CachedInfo.get_system_static_info(solar_system_id) do
      {:ok, system_static_info} when not is_nil(system_static_info) ->
        {:ok, system_static_info}

      _ ->
        {:ok, %{system_class: nil}}
    end
  end

  defp maybe_remove_connection(map_id, location, old_location)
       when not is_nil(location) and not is_nil(old_location) and
              location.solar_system_id != old_location.solar_system_id do
    case WandererApp.Map.find_connection(
           map_id,
           location.solar_system_id,
           old_location.solar_system_id
         ) do
      {:ok, connection} when not is_nil(connection) ->
        :ok = WandererApp.MapConnectionRepo.destroy(map_id, connection)

        Impl.broadcast!(map_id, :remove_connections, [connection])
        map_id |> WandererApp.Map.remove_connection(connection)

        # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
        WandererApp.ExternalEvents.broadcast(map_id, :connection_removed, %{
          connection_id: connection.id,
          solar_system_source_id: location.solar_system_id,
          solar_system_target_id: old_location.solar_system_id
        })

        WandererApp.Cache.delete("map_#{map_id}:conn_#{connection.id}:start_time")

        # Clear linked_sig_eve_id on target system when connection is deleted
        # This ensures old signatures become orphaned and won't affect future connections
        SystemsImpl.update_system_linked_sig_eve_id(map_id, %{
          solar_system_id: location.solar_system_id,
          linked_sig_eve_id: nil
        })

      _error ->
        :ok
    end
  end

  defp maybe_remove_connection(_map_id, _location, _old_location), do: :ok

  defp update_connection(
         map_id,
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
         {:ok, update_map} <- Impl.get_update_map(update, attributes),
         {:ok, updated_connection} <-
           apply(WandererApp.MapConnectionRepo, update_method, [
             connection,
             update_map
           ]),
         :ok <-
           WandererApp.Map.update_connection(
             map_id,
             connection |> Map.merge(update_map)
           ) do
      if not is_nil(callback_fn) do
        callback_fn.(connection, updated_connection)
      end

      Impl.broadcast!(map_id, :update_connection, updated_connection)

      # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
      WandererApp.ExternalEvents.broadcast(map_id, :connection_updated, %{
        connection_id: updated_connection.id,
        solar_system_source_id: solar_system_source_id,
        solar_system_target_id: solar_system_target_id,
        type: updated_connection.type,
        ship_size_type: updated_connection.ship_size_type,
        mass_status: updated_connection.mass_status,
        time_status: updated_connection.time_status,
        locked: updated_connection.locked,
        custom_info: updated_connection.custom_info
      })

      :ok
    else
      {:error, error} ->
        Logger.error("Failed to update connection: #{inspect(error, pretty: true)}")

        :ok
    end
  end

  defp get_ship_size_type(
         source_solar_system_id,
         target_solar_system_id,
         @connection_type_wormhole
       ) do
    # Check if either system is C1 before creating the connection
    {:ok, source_system_info} = get_system_static_info(source_solar_system_id)
    {:ok, target_system_info} = get_system_static_info(target_solar_system_id)

    cond do
      # C1 systems always get medium
      source_system_info.system_class == @c1 or target_system_info.system_class == @c1 ->
        @medium_ship_size

      # C13 systems always get frigate
      source_system_info.system_class == @c13 or target_system_info.system_class == @c13 ->
        @frigate_ship_size

      true ->
        # Default to large for other wormhole connections
        @large_ship_size
    end
  end

  # Default to large for non-wormhole connections
  defp get_ship_size_type(_source_solar_system_id, _target_solar_system_id, _connection_type),
    do: @large_ship_size

  defp get_time_status(
         _source_solar_system_id,
         _target_solar_system_id,
         @frigate_ship_size
       ),
       do: @connection_time_status_eol_4_5

  defp get_time_status(
         source_solar_system_id,
         target_solar_system_id,
         _ship_size_type
       ) do
    # Check if either system is C1 before creating the connection
    {:ok, source_system_info} = get_system_static_info(source_solar_system_id)
    {:ok, target_system_info} = get_system_static_info(target_solar_system_id)

    cond do
      # C1/2/3/4 systems always get eol_16
      source_system_info.system_class in [@c1, @c2, @c3, @c4] or
          target_system_info.system_class in [@c1, @c2, @c3, @c4] ->
        @connection_time_status_eol_16

      # C5/6 systems always get eol_24
      source_system_info.system_class in [@c5, @c6] or
          target_system_info.system_class in [@c5, @c6] ->
        @connection_time_status_eol_24

      true ->
        @connection_time_status_default
    end
  end

  defp get_new_time_status(_start_time, @connection_time_status_default),
    do: @connection_time_status_eol_24

  defp get_new_time_status(start_time, old_time_status) do
    left_minutes =
      get_time_status_minutes(old_time_status) -
        DateTime.diff(DateTime.utc_now(), start_time, :minute)

    cond do
      left_minutes <= @connection_eol_minutes ->
        @connection_time_status_eol

      left_minutes <= @connection_eol_4_minutes ->
        @connection_time_status_eol_4

      left_minutes <= @connection_eol_4_5_minutes ->
        @connection_time_status_eol_4_5

      left_minutes <= @connection_eol_16_minutes ->
        @connection_time_status_eol_16

      left_minutes <= @connection_eol_24_minutes ->
        @connection_time_status_eol_24

      left_minutes <= @connection_eol_48_minutes ->
        @connection_time_status_eol_48

      true ->
        @connection_time_status_default
    end
  end

  defp get_time_status_minutes(@connection_time_status_eol), do: @connection_eol_minutes
  defp get_time_status_minutes(@connection_time_status_eol_4), do: @connection_eol_4_minutes
  defp get_time_status_minutes(@connection_time_status_eol_4_5), do: @connection_eol_4_5_minutes
  defp get_time_status_minutes(@connection_time_status_eol_16), do: @connection_eol_16_minutes
  defp get_time_status_minutes(@connection_time_status_eol_24), do: @connection_eol_24_minutes
  defp get_time_status_minutes(@connection_time_status_eol_48), do: @connection_eol_48_minutes
  defp get_time_status_minutes(_), do: @connection_eol_24_minutes
end
