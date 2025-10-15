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
    map_opts: []
  ]

  @systems_cleanup_timeout :timer.minutes(30)
  @characters_cleanup_timeout :timer.minutes(5)
  @connections_cleanup_timeout :timer.minutes(1)

  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)
  @backup_state_timeout :timer.minutes(1)
  @update_presence_timeout :timer.seconds(5)
  @update_characters_timeout :timer.seconds(1)
  @update_tracked_characters_timeout :timer.minutes(1)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def init(args) do
    map_id = args[:map_id]
    Logger.info("Starting map server for #{map_id}")

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
      |> SystemsImpl.init_map_systems(systems)
      |> init_map_cache()
    else
      error ->
        Logger.error("Failed to load map state: #{inspect(error, pretty: true)}")
        state
    end
  end

  def start_map(%__MODULE__{map: map, map_id: map_id} = state) do
    # Check if map was loaded successfully
    case map do
      nil ->
        Logger.error("Cannot start map #{map_id}: map not loaded")
        {:error, :map_not_loaded}

      map ->
        with :ok <- AclsImpl.track_acls(map.acls |> Enum.map(& &1.id)) do
          @pubsub_client.subscribe(
            WandererApp.PubSub,
            "maps:#{map_id}"
          )

          Process.send_after(self(), :update_characters, @update_characters_timeout)

          Process.send_after(
            self(),
            :update_tracked_characters,
            @update_tracked_characters_timeout
          )

          Process.send_after(self(), :update_presence, @update_presence_timeout)
          Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)
          Process.send_after(self(), :cleanup_systems, 10_000)
          Process.send_after(self(), :cleanup_characters, @characters_cleanup_timeout)
          Process.send_after(self(), :backup_state, @backup_state_timeout)

          WandererApp.Cache.insert("map_#{map_id}:started", true)

          # Initialize zkb cache structure to prevent timing issues
          cache_key = "map:#{map_id}:zkb:detailed_kills"
          WandererApp.Cache.insert(cache_key, %{}, ttl: :timer.hours(24))

          broadcast!(map_id, :map_server_started)
          @pubsub_client.broadcast!(WandererApp.PubSub, "maps", :map_server_started)

          :telemetry.execute([:wanderer_app, :map, :started], %{count: 1})

          state
        else
          error ->
            Logger.error("Failed to start map: #{inspect(error, pretty: true)}")
            state
        end
    end
  end

  def stop_map(%{map_id: map_id} = state) do
    Logger.debug(fn -> "Stopping map server for #{map_id}" end)

    WandererApp.Cache.delete("map_#{map_id}:started")
    WandererApp.Cache.delete("map_characters-#{map_id}")

    :telemetry.execute([:wanderer_app, :map, :stopped], %{count: 1})

    state
    |> maybe_stop_rtree()
  end

  def get_map(%{map: map} = _state), do: {:ok, map}

  defdelegate add_character(state, character, track_character), to: CharactersImpl

  def remove_character(%{map_id: map_id} = state, character_id) do
    CharactersImpl.remove_character(map_id, character_id)

    state
  end

  def untrack_characters(%{map_id: map_id} = state, characters_ids) do
    CharactersImpl.untrack_characters(map_id, characters_ids)

    state
  end

  defdelegate add_system(state, system_info, user_id, character_id), to: SystemsImpl

  defdelegate paste_systems(state, systems, user_id, character_id), to: SystemsImpl

  defdelegate add_system_comment(state, comment_info, user_id, character_id), to: SystemsImpl

  defdelegate remove_system_comment(state, comment_id, user_id, character_id), to: SystemsImpl

  defdelegate delete_systems(
                state,
                removed_ids,
                user_id,
                character_id
              ),
              to: SystemsImpl

  defdelegate update_system_name(state, update), to: SystemsImpl

  defdelegate update_system_description(state, update), to: SystemsImpl

  defdelegate update_system_status(state, update), to: SystemsImpl

  defdelegate update_system_tag(state, update), to: SystemsImpl

  defdelegate update_system_temporary_name(state, update), to: SystemsImpl

  defdelegate update_system_locked(state, update), to: SystemsImpl

  defdelegate update_system_labels(state, update), to: SystemsImpl

  defdelegate update_system_linked_sig_eve_id(state, update), to: SystemsImpl

  defdelegate update_system_position(state, update), to: SystemsImpl

  defdelegate add_hub(state, hub_info), to: SystemsImpl

  defdelegate remove_hub(state, hub_info), to: SystemsImpl

  defdelegate add_ping(state, ping_info), to: PingsImpl

  defdelegate cancel_ping(state, ping_info), to: PingsImpl

  defdelegate add_connection(state, connection_info), to: ConnectionsImpl

  defdelegate delete_connection(state, connection_info), to: ConnectionsImpl

  defdelegate get_connection_info(state, connection_info), to: ConnectionsImpl

  defdelegate paste_connections(state, connections, user_id, character_id), to: ConnectionsImpl

  defdelegate update_connection_time_status(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_type(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_mass_status(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_ship_size_type(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_locked(state, connection_update), to: ConnectionsImpl

  defdelegate update_connection_custom_info(state, signatures_update), to: ConnectionsImpl

  defdelegate update_signatures(state, signatures_update), to: SignaturesImpl

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

  def handle_event(:update_characters, state) do
    Process.send_after(self(), :update_characters, @update_characters_timeout)

    CharactersImpl.update_characters(state)

    state
  end

  def handle_event(:update_tracked_characters, %{map_id: map_id} = state) do
    Process.send_after(self(), :update_tracked_characters, @update_tracked_characters_timeout)

    CharactersImpl.update_tracked_characters(map_id)

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
        state
      ) do
    state |> AclsImpl.handle_map_acl_updated(added_acls, removed_acls)
  end

  def handle_event({:acl_updated, %{acl_id: acl_id}}, %{map_id: map_id} = state) do
    AclsImpl.handle_acl_updated(map_id, acl_id)

    state
  end

  def handle_event({:acl_deleted, %{acl_id: acl_id}}, %{map_id: map_id} = state) do
    AclsImpl.handle_acl_deleted(map_id, acl_id)

    state
  end

  def handle_event(:cleanup_connections, state) do
    Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)

    state |> ConnectionsImpl.cleanup_connections()
  end

  def handle_event(:cleanup_characters, %{map_id: map_id, map: %{owner_id: owner_id}} = state) do
    Process.send_after(self(), :cleanup_characters, @characters_cleanup_timeout)

    CharactersImpl.cleanup_characters(map_id, owner_id)

    state
  end

  def handle_event(:cleanup_systems, state) do
    Process.send_after(self(), :cleanup_systems, @systems_cleanup_timeout)

    state |> SystemsImpl.cleanup_systems()
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

  def handle_event({:options_updated, options}, %{map: map} = state) do
    map |> WandererApp.Map.update_options!(options)

    %{state | map_opts: map_options(options)}
  end

  def handle_event({ref, _result}, %{map_id: _map_id} = state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    state
  end

  def handle_event(msg, state) do
    Logger.warning("Unhandled event: #{inspect(msg)}")

    state
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
        options |> Map.get("restrict_offline_showing", "false") |> String.to_existing_atom()
    ]
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

    WandererApp.Api.MapState.create(%{
      map_id: map_id,
      systems_last_activity: systems_last_activity,
      connections_eol_time: connections_eol_time,
      connections_start_time: connections_start_time
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
         connections_eol_time: connections_eol_time,
         connections_start_time: connections_start_time
       }} ->
        SystemsImpl.init_last_activity_cache(map_id, systems_last_activity)
        ConnectionsImpl.init_eol_cache(map_id, connections_eol_time)
        ConnectionsImpl.init_start_cache(map_id, connections_start_time)

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
    {:ok, options} = WandererApp.MapRepo.options_to_form_data(initial_map)

    map =
      initial_map
      |> WandererApp.Map.new()
      |> WandererApp.Map.update_options!(options)
      |> WandererApp.Map.update_subscription_settings!(subscription_settings)
      |> WandererApp.Map.add_systems!(systems)
      |> WandererApp.Map.add_connections!(connections)
      |> WandererApp.Map.add_characters!(characters)

    character_ids =
      map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:characters, [])

    WandererApp.Cache.insert("map_#{map_id}:invalidate_character_ids", character_ids)

    %{state | map: map, map_opts: map_options(options)}
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
                                 "tag" => tag,
                                 "temporary_name" => temporary_name
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
        |> update_system_temporary_name(%{
          solar_system_id: id |> String.to_integer(),
          temporary_name: temporary_name
        })
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

        WandererApp.Cache.insert(
          "map_#{map_id}:old_presence_character_ids",
          presence_character_ids
        )

        CharactersImpl.track_characters(map_id, new_present_character_ids)
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
