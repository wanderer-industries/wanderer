defmodule WandererApp.Map.Server.Impl do
  @moduledoc """
  Holds state for a map and exposes an interface to managing the map instance
  """
  require Logger

  alias WandererApp.Map.Server.{
    AclsImpl,
    CharactersImpl,
    ConnectionsImpl,
    SystemsImpl,
    SignaturesImpl,
    PingsImpl
  }

  @enforce_keys [
    :map_id
  ]

  defstruct [
    :map_id,
    :rtree_name,
    map: nil,
    acls: [],
    map_opts: []
  ]

  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)
  @ddrt Application.compile_env(:wanderer_app, :ddrt)

  @update_presence_timeout :timer.seconds(5)
  @update_characters_timeout :timer.seconds(1)
  @invalidate_characters_timeout :timer.hours(1)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def do_init_state(opts) do
    map_id = opts[:map_id]

    initial_state =
      %{
        map_id: map_id,
        rtree_name: "rtree_#{map_id}"
      }
      |> new()

    # Parallelize database queries for faster initialization
    start_time = System.monotonic_time(:millisecond)

    tasks = [
      Task.async(fn ->
        {:map,
         WandererApp.MapRepo.get(map_id, [
           :owner
         ])}
      end),
      Task.async(fn ->
        {:acls, WandererApp.Api.MapAccessList.read_by_map(%{map_id: map_id})}
      end),
      Task.async(fn ->
        {:characters, WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id)}
      end),
      Task.async(fn ->
        {:systems, WandererApp.MapSystemRepo.get_visible_by_map(map_id)}
      end),
      Task.async(fn ->
        {:connections, WandererApp.MapConnectionRepo.get_by_map(map_id)}
      end),
      Task.async(fn ->
        {:subscription, WandererApp.Map.SubscriptionManager.get_active_map_subscription(map_id)}
      end)
    ]

    results = Task.await_many(tasks, :timer.seconds(15))

    duration = System.monotonic_time(:millisecond) - start_time

    # Emit telemetry for slow initializations
    if duration > 5_000 do
      Logger.warning("[Map Server] Slow map state initialization: #{map_id} took #{duration}ms")

      :telemetry.execute(
        [:wanderer_app, :map, :slow_init],
        %{duration_ms: duration},
        %{map_id: map_id}
      )
    end

    # Extract results
    map_result =
      Enum.find_value(results, fn
        {:map, result} -> result
        _ -> nil
      end)

    acls_result =
      Enum.find_value(results, fn
        {:acls, result} -> result
        _ -> nil
      end)

    characters_result =
      Enum.find_value(results, fn
        {:characters, result} -> result
        _ -> nil
      end)

    systems_result =
      Enum.find_value(results, fn
        {:systems, result} -> result
        _ -> nil
      end)

    connections_result =
      Enum.find_value(results, fn
        {:connections, result} -> result
        _ -> nil
      end)

    subscription_result =
      Enum.find_value(results, fn
        {:subscription, result} -> result
        _ -> nil
      end)

    # Process results
    with {:ok, map} <- map_result,
         {:ok, acls} <- acls_result,
         {:ok, characters} <- characters_result,
         {:ok, systems} <- systems_result,
         {:ok, connections} <- connections_result,
         {:ok, subscription_settings} <- subscription_result do
      initial_state
      |> init_map(
        map,
        acls,
        characters,
        subscription_settings,
        systems,
        connections
      )
    else
      error ->
        Logger.error("Failed to load map state: #{inspect(error, pretty: true)}")
        initial_state
    end
  end

  def start_map(%__MODULE__{map: map, acls: acls, map_id: map_id} = _state) do
    WandererApp.Cache.insert("map_#{map_id}:started", false)

    # Check if map was loaded successfully
    case map do
      nil ->
        Logger.error("Cannot start map #{map_id}: map not loaded")
        {:error, :map_not_loaded}

      _map ->
        with :ok <- AclsImpl.track_acls(acls |> Enum.map(& &1.access_list_id)) do
          @pubsub_client.subscribe(
            WandererApp.PubSub,
            "maps:#{map_id}"
          )

          Process.send_after(self(), {:update_characters, map_id}, @update_characters_timeout)

          Process.send_after(
            self(),
            {:invalidate_characters, map_id},
            @invalidate_characters_timeout
          )

          Process.send_after(self(), {:update_presence, map_id}, @update_presence_timeout)

          WandererApp.Cache.insert("map_#{map_id}:started", true)

          # Initialize zkb cache structure to prevent timing issues
          WandererApp.Cache.insert("map:#{map_id}:zkb:detailed_kills", %{}, ttl: :timer.hours(24))

          broadcast!(map_id, :map_server_started)
          @pubsub_client.broadcast!(WandererApp.PubSub, "maps", :map_server_started)

          :telemetry.execute([:wanderer_app, :map, :started], %{count: 1})
        else
          error ->
            Logger.error("Failed to start map: #{inspect(error, pretty: true)}")
        end
    end
  end

  def stop_map(map_id) do
    Logger.debug(fn -> "Stopping map server for #{map_id}" end)

    @pubsub_client.unsubscribe(
      WandererApp.PubSub,
      "maps:#{map_id}"
    )

    WandererApp.Cache.delete("map_#{map_id}:started")
    WandererApp.Cache.delete("map_characters-#{map_id}")
    WandererApp.Map.CacheRTree.clear_tree("rtree_#{map_id}")
    WandererApp.Map.delete_map_state(map_id)

    WandererApp.Cache.insert_or_update(
      "started_maps",
      [],
      fn started_maps ->
        started_maps
        |> Enum.reject(fn started_map_id -> started_map_id == map_id end)
      end
    )

    :telemetry.execute([:wanderer_app, :map, :stopped], %{count: 1})
  end

  defdelegate cleanup_systems(map_id), to: SystemsImpl
  defdelegate cleanup_connections(map_id), to: ConnectionsImpl
  defdelegate cleanup_characters(map_id), to: CharactersImpl
  defdelegate untrack_characters(map_id, characters_ids), to: CharactersImpl
  defdelegate add_system(map_id, system_info, user_id, character_id, opts \\ []), to: SystemsImpl
  defdelegate paste_connections(map_id, connections, user_id, character_id), to: ConnectionsImpl
  defdelegate paste_systems(map_id, systems, user_id, character_id, opts), to: SystemsImpl
  defdelegate add_system_comment(map_id, comment_info, user_id, character_id), to: SystemsImpl
  defdelegate remove_system_comment(map_id, comment_id, user_id, character_id), to: SystemsImpl

  defdelegate delete_systems(
                map_id,
                removed_ids,
                user_id,
                character_id
              ),
              to: SystemsImpl

  defdelegate update_system_name(map_id, update), to: SystemsImpl
  defdelegate update_system_description(map_id, update), to: SystemsImpl
  defdelegate update_system_status(map_id, update), to: SystemsImpl
  defdelegate update_system_tag(map_id, update), to: SystemsImpl
  defdelegate update_system_temporary_name(map_id, update), to: SystemsImpl
  defdelegate update_system_custom_name(map_id, update), to: SystemsImpl
  defdelegate update_system_locked(map_id, update), to: SystemsImpl
  defdelegate update_system_labels(map_id, update), to: SystemsImpl
  defdelegate update_system_linked_sig_eve_id(map_id, update), to: SystemsImpl
  defdelegate update_system_position(map_id, update), to: SystemsImpl
  defdelegate add_hub(map_id, hub_info), to: SystemsImpl
  defdelegate remove_hub(map_id, hub_info), to: SystemsImpl
  defdelegate add_ping(map_id, ping_info), to: PingsImpl
  defdelegate cancel_ping(map_id, ping_info), to: PingsImpl
  defdelegate add_connection(map_id, connection_info), to: ConnectionsImpl
  defdelegate delete_connection(map_id, connection_info), to: ConnectionsImpl
  defdelegate get_connection_info(map_id, connection_info), to: ConnectionsImpl
  defdelegate update_connection_time_status(map_id, connection_update), to: ConnectionsImpl
  defdelegate update_connection_type(map_id, connection_update), to: ConnectionsImpl
  defdelegate update_connection_mass_status(map_id, connection_update), to: ConnectionsImpl
  defdelegate update_connection_ship_size_type(map_id, connection_update), to: ConnectionsImpl
  defdelegate update_connection_locked(map_id, connection_update), to: ConnectionsImpl
  defdelegate update_connection_custom_info(map_id, connection_update), to: ConnectionsImpl
  defdelegate update_signatures(map_id, signatures_update), to: SignaturesImpl

  def import_settings(map_id, settings, user_id) do
    WandererApp.Cache.put(
      "map_#{map_id}:importing",
      true
    )

    maybe_import_systems(map_id, settings, user_id, nil)
    maybe_import_connections(map_id, settings, user_id)
    maybe_import_hubs(map_id, settings, user_id)

    WandererApp.Cache.take("map_#{map_id}:importing")
  end

  def save_map_state(map_id) do
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

    connections =
      map_id
      |> WandererApp.Map.list_connections!()

    connections_eol_time =
      connections
      |> Enum.reduce(%{}, fn %{id: connection_id} = _connection, acc ->
        case WandererApp.Cache.get("map_#{map_id}:conn_#{connection_id}:mark_eol_time") do
          nil ->
            acc

          value ->
            acc |> Map.put_new(connection_id, value)
        end
      end)

    connections_start_time =
      connections
      |> Enum.reduce(%{}, fn %{id: connection_id} = _connection, acc ->
        connection_start_time = ConnectionsImpl.get_start_time(map_id, connection_id)
        acc |> Map.put_new(connection_id, connection_start_time)
      end)

    # Create map state with retry logic for test scenarios
    WandererApp.Api.MapState.create(%{
      map_id: map_id,
      systems_last_activity: systems_last_activity,
      connections_eol_time: connections_eol_time,
      connections_start_time: connections_start_time
    })
  end

  def handle_event({:update_characters, map_id} = event) do
    Process.send_after(self(), event, @update_characters_timeout)

    CharactersImpl.update_characters(map_id)
  end

  def handle_event({:invalidate_characters, map_id} = event) do
    Process.send_after(
      self(),
      event,
      @invalidate_characters_timeout
    )

    CharactersImpl.invalidate_characters(map_id)
  end

  def handle_event({:update_presence, map_id} = event) do
    Process.send_after(self(), event, @update_presence_timeout)

    update_presence(map_id)
  end

  def handle_event({:map_acl_updated, map_id, added_acls, removed_acls}) do
    AclsImpl.handle_map_acl_updated(map_id, added_acls, removed_acls)
  end

  def handle_event({:acl_updated, %{acl_id: acl_id}}) do
    # Find all maps that use this ACL
    case Ash.read(
           WandererApp.Api.MapAccessList
           |> Ash.Query.for_read(:read_by_acl, %{acl_id: acl_id})
         ) do
      {:ok, map_acls} ->
        Logger.debug(fn ->
          "Found #{length(map_acls)} maps using ACL #{acl_id}: #{inspect(Enum.map(map_acls, & &1.map_id))}"
        end)

        # Broadcast to each map
        Enum.each(map_acls, fn %{map_id: map_id} ->
          Logger.debug(fn -> "Broadcasting acl_updated to map #{map_id}" end)
          AclsImpl.handle_acl_updated(map_id, acl_id)
        end)

        Logger.debug(fn ->
          "Successfully broadcast acl_updated event to #{length(map_acls)} maps"
        end)

      {:error, error} ->
        Logger.error("Failed to find maps for ACL #{acl_id}: #{inspect(error)}")
        :ok
    end
  end

  def handle_event({:acl_deleted, %{acl_id: acl_id}}) do
    case Ash.read(
           WandererApp.Api.MapAccessList
           |> Ash.Query.for_read(:read_by_acl, %{acl_id: acl_id})
         ) do
      {:ok, map_acls} ->
        Logger.debug(fn ->
          "Found #{length(map_acls)} maps using ACL #{acl_id}: #{inspect(Enum.map(map_acls, & &1.map_id))}"
        end)

        # Broadcast to each map
        Enum.each(map_acls, fn %{map_id: map_id} ->
          Logger.debug(fn -> "Broadcasting acl_deleted to map #{map_id}" end)
          AclsImpl.handle_acl_deleted(map_id, acl_id)
        end)

        Logger.debug(fn ->
          "Successfully broadcast acl_deleted event to #{length(map_acls)} maps"
        end)

      {:error, error} ->
        Logger.error("Failed to find maps for ACL #{acl_id}: #{inspect(error)}")
        :ok
    end
  end

  def handle_event({:subscription_settings_updated, map_id}) do
    {:ok, subscription_settings} =
      WandererApp.Map.SubscriptionManager.get_active_map_subscription(map_id)

    update_subscription_settings(map_id, subscription_settings)
  end

  def handle_event({:options_updated, map_id, options}) do
    update_options(map_id, options)
  end

  def handle_event(:map_deleted) do
    # Map has been deleted - this event is handled by MapPool to stop the server
    # and by MapLive to redirect users. Nothing to do here.
    Logger.debug("Map deletion event received, will be handled by MapPool")
    :ok
  end

  def handle_event({ref, _result}) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
  end

  def handle_event(msg) do
    Logger.warning("Unhandled event: #{inspect(msg)}")
  end

  def update_subscription_settings(map_id, subscription_settings) do
    {:ok, %{map: map}} = WandererApp.Map.get_map_state(map_id)

    WandererApp.Map.update_map_state(map_id, %{
      map: map |> WandererApp.Map.update_subscription_settings!(subscription_settings)
    })
  end

  def update_options(map_id, options) do
    {:ok, %{map: map}} = WandererApp.Map.get_map_state(map_id)

    WandererApp.Map.update_map_state(map_id, %{
      map: map |> WandererApp.Map.update_options!(options),
      map_opts: map_options(options)
    })
  end

  def broadcast!(map_id, event, payload \\ nil) do
    if can_broadcast?(map_id) do
      @pubsub_client.broadcast!(WandererApp.PubSub, map_id, %{
        event: event,
        payload: payload
      })
    end

    :ok
  end

  defp can_broadcast?(map_id),
    do:
      not WandererApp.Cache.lookup!("map_#{map_id}:importing", false) and
        WandererApp.Cache.lookup!("map_#{map_id}:started", false)

  def get_update_map(update, attributes),
    do:
      {:ok,
       Enum.reduce(attributes, Map.new(), fn attribute, map ->
         map |> Map.put_new(attribute, get_in(update, [Access.key(attribute)]))
       end)}

  defp map_options(options) do
    [
      layout: options |> Map.get("layout", "left_to_right"),
      store_custom_labels:
        options |> Map.get("store_custom_labels", "false") |> String.to_existing_atom(),
      show_linked_signature_id:
        options |> Map.get("show_linked_signature_id", "false") |> String.to_existing_atom(),
      show_linked_signature_id_temp_name:
        options
        |> Map.get("show_linked_signature_id_temp_name", "false")
        |> String.to_existing_atom(),
      show_temp_system_name:
        options |> Map.get("show_temp_system_name", "false") |> String.to_existing_atom(),
      restrict_offline_showing:
        options |> Map.get("restrict_offline_showing", "false") |> String.to_existing_atom(),
      allowed_copy_for: options |> Map.get("allowed_copy_for", "admin"),
      allowed_paste_for: options |> Map.get("allowed_paste_for", "member")
    ]
  end

  defp init_map_cache(map_id) do
    case WandererApp.Api.MapState.by_map_id(map_id) do
      {:ok,
       %{
         systems_last_activity: systems_last_activity,
         connections_eol_time: connections_eol_time,
         connections_start_time: connections_start_time
       }} ->
        SystemsImpl.init_last_activity_cache(map_id, systems_last_activity)
        ConnectionsImpl.init_eol_cache(map_id, connections_eol_time)
        ConnectionsImpl.init_start_cache(map_id, connections_start_time)

      _ ->
        :ok
    end
  end

  defp init_map(
         state,
         %{id: map_id} = initial_map,
         acls,
         characters,
         subscription_settings,
         systems,
         connections
       ) do
    {:ok, options} = WandererApp.MapRepo.options_to_form_data(initial_map)

    @ddrt.init_tree("rtree_#{map_id}", %{width: 150, verbose: false})

    map =
      initial_map
      |> WandererApp.Map.new()
      |> WandererApp.Map.update_options!(options)
      |> WandererApp.Map.update_subscription_settings!(subscription_settings)
      |> WandererApp.Map.add_systems!(systems)
      |> WandererApp.Map.add_connections!(connections)
      |> WandererApp.Map.add_characters!(characters)

    SystemsImpl.init_map_systems(map_id, systems)

    character_ids =
      map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:characters, [])

    init_map_cache(map_id)

    WandererApp.Cache.insert("map_#{map_id}:invalidate_character_ids", character_ids)

    %{state | map: map, acls: acls, map_opts: map_options(options)}
  end

  def maybe_import_systems(
        map_id,
        %{"systems" => systems} = _settings,
        user_id,
        character_id
      ) do
    systems
    |> Enum.each(fn %{
                      "description" => description,
                      "id" => id,
                      "labels" => labels,
                      "locked" => locked,
                      "name" => name,
                      "position" => %{"x" => x, "y" => y},
                      "status" => status,
                      "tag" => tag,
                      "temporary_name" => temporary_name
                    } ->
      solar_system_id = id |> String.to_integer()

      add_system(
        map_id,
        %{
          solar_system_id: solar_system_id,
          coordinates: %{"x" => round(x), "y" => round(y)}
        },
        user_id,
        character_id
      )

      update_system_name(map_id, %{solar_system_id: solar_system_id, name: name})

      update_system_description(map_id, %{
        solar_system_id: solar_system_id,
        description: description
      })

      update_system_status(map_id, %{solar_system_id: solar_system_id, status: status})

      update_system_tag(map_id, %{solar_system_id: solar_system_id, tag: tag})

      update_system_temporary_name(map_id, %{
        solar_system_id: solar_system_id,
        temporary_name: temporary_name
      })

      update_system_locked(map_id, %{solar_system_id: solar_system_id, locked: locked})

      update_system_labels(map_id, %{solar_system_id: solar_system_id, labels: labels})
    end)

    removed_system_ids =
      systems
      |> Enum.filter(fn system -> not system["visible"] end)
      |> Enum.map(fn system -> system["id"] end)
      |> Enum.map(&String.to_integer/1)

    delete_systems(map_id, removed_system_ids, user_id, character_id)
  end

  def maybe_import_connections(map_id, %{"connections" => connections} = _settings, _user_id) do
    connections
    |> Enum.each(fn %{
                      "source" => source,
                      "target" => target,
                      "mass_status" => mass_status,
                      "time_status" => time_status,
                      "ship_size_type" => ship_size_type
                    } ->
      source_id = source |> String.to_integer()
      target_id = target |> String.to_integer()

      add_connection(map_id, %{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id
      })

      update_connection_time_status(map_id, %{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id,
        time_status: time_status
      })

      update_connection_mass_status(map_id, %{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id,
        mass_status: mass_status
      })

      update_connection_ship_size_type(map_id, %{
        solar_system_source_id: source_id,
        solar_system_target_id: target_id,
        ship_size_type: ship_size_type
      })
    end)
  end

  def maybe_import_hubs(map_id, %{"hubs" => hubs} = _settings, _user_id) do
    hubs
    |> Enum.each(fn hub ->
      solar_system_id = hub |> String.to_integer()

      add_hub(map_id, %{solar_system_id: solar_system_id})
    end)
  end

  defp update_presence(map_id) do
    case WandererApp.Cache.lookup!("map_#{map_id}:started", false) and
           WandererApp.Cache.get_and_remove!("map_#{map_id}:presence_updated", false) do
      true ->
        {:ok, presence_character_ids} =
          WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])

        {:ok, old_presence_character_ids} =
          WandererApp.Cache.lookup("map_#{map_id}:old_presence_character_ids", [])

        new_present_character_ids =
          presence_character_ids
          |> Enum.filter(fn character_id ->
            not Enum.member?(old_presence_character_ids, character_id)
          end)

        not_present_character_ids =
          old_presence_character_ids
          |> Enum.filter(fn character_id ->
            not Enum.member?(presence_character_ids, character_id)
          end)

        # Log presence changes for debugging
        if length(new_present_character_ids) > 0 or length(not_present_character_ids) > 0 do
          Logger.debug(fn ->
            "[MapServer] Map #{map_id} presence update - " <>
              "newly_present: #{inspect(new_present_character_ids)}, " <>
              "no_longer_present: #{inspect(not_present_character_ids)}, " <>
              "total_present: #{length(presence_character_ids)}"
          end)
        end

        WandererApp.Cache.insert(
          "map_#{map_id}:old_presence_character_ids",
          presence_character_ids
        )

        # Track new characters
        if length(new_present_character_ids) > 0 do
          Logger.debug(fn ->
            "[MapServer] Map #{map_id} - starting tracking for #{length(new_present_character_ids)} newly present characters"
          end)
        end

        CharactersImpl.track_characters(map_id, new_present_character_ids)

        # Untrack characters no longer present (grace period has expired)
        if length(not_present_character_ids) > 0 do
          Logger.debug(fn ->
            "[MapServer] Map #{map_id} - #{length(not_present_character_ids)} characters no longer in presence " <>
              "(grace period expired or never had one) - will be untracked"
          end)

          # Emit telemetry for presence-based untracking
          :telemetry.execute(
            [:wanderer_app, :map, :presence, :characters_left],
            %{count: length(not_present_character_ids), system_time: System.system_time()},
            %{map_id: map_id, character_ids: not_present_character_ids}
          )
        end

        CharactersImpl.untrack_characters(map_id, not_present_character_ids)

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
end
