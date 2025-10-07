defmodule WandererApp.Map.ZkbDataFetcher do
  @moduledoc """
  Refreshes and broadcasts map kill data every 15 seconds.
  Works with cache data populated by the WandererKills WebSocket service.
  """
  use GenServer

  require Logger

  alias WandererApp.Map.Server.Impl, as: MapServerImpl

  @interval :timer.seconds(15)
  @store_map_kills_timeout :timer.hours(1)
  @killmail_ttl_hours 24
  @logger Application.compile_env(:wanderer_app, :logger)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    {:ok, _timer_ref} = :timer.send_interval(@interval, :fetch_data)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:fetch_data, state) do
    kills_enabled = Application.get_env(:wanderer_app, :wanderer_kills_service_enabled, true)

    if kills_enabled do
      WandererApp.Map.RegistryHelper.list_all_maps()
      |> Task.async_stream(
        fn %{id: map_id, pid: _server_pid} ->
          try do
            if WandererApp.Map.Server.map_pid(map_id) do
              # Always update kill counts
              update_map_kills(map_id)

              # Update detailed kills for maps with active subscriptions
              {:ok, is_subscription_active} = map_id |> WandererApp.Map.is_subscription_active?()

              if is_subscription_active do
                update_detailed_map_kills(map_id)
              end
            end
          rescue
            e ->
              @logger.error(Exception.message(e))
          end
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn _ -> :ok end)
    end

    {:noreply, state}
  end

  # Catch any async task results we aren't explicitly pattern-matching
  @impl true
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp update_map_kills(map_id) do
    with_started_map(map_id, "basic kills update", fn ->
      map_id
      |> WandererApp.Map.get_map!()
      |> Map.get(:systems, %{})
      |> Enum.into(%{}, fn {solar_system_id, _system} ->
        # Read kill counts from cache (populated by WebSocket)
        kills_count = WandererApp.Cache.get("zkb:kills:#{solar_system_id}") || 0
        {solar_system_id, kills_count}
      end)
      |> maybe_broadcast_map_kills(map_id)
    end)
  end

  defp update_detailed_map_kills(map_id) do
    with_started_map(map_id, "detailed kills update", fn ->
      systems =
        map_id
        |> WandererApp.Map.get_map!()
        |> Map.get(:systems, %{})

      # Get existing cached data - ensure it's a map
      cache_key_ids = "map:#{map_id}:zkb:ids"
      cache_key_details = "map:#{map_id}:zkb:detailed_kills"

      old_ids_map =
        case WandererApp.Cache.get(cache_key_ids) do
          map when is_map(map) -> map
          _ -> %{}
        end

      old_details_map =
        case WandererApp.Cache.get(cache_key_details) do
          map when is_map(map) ->
            map

          _ ->
            # Initialize with empty map and store it
            WandererApp.Cache.insert(cache_key_details, %{},
              ttl: :timer.hours(@killmail_ttl_hours)
            )

            %{}
        end

      # Build current killmail ID map from cache
      new_ids_map =
        Enum.into(systems, %{}, fn {solar_system_id, _} ->
          # Get killmail IDs from cache (populated by WebSocket)
          ids = WandererApp.Cache.get("zkb:kills:list:#{solar_system_id}") || []
          {solar_system_id, MapSet.new(ids)}
        end)

      # Find systems with changed killmail lists or empty detailed kills
      changed_systems =
        new_ids_map
        |> Enum.filter(fn {system_id, new_ids_set} ->
          old_set = MapSet.new(Map.get(old_ids_map, system_id, []))
          old_details = Map.get(old_details_map, system_id, [])
          # Update if IDs changed OR if we have IDs but no detailed kills
          not MapSet.equal?(new_ids_set, old_set) or
            (MapSet.size(new_ids_set) > 0 and old_details == [])
        end)
        |> Enum.map(&elem(&1, 0))

      if changed_systems == [] do
        log_no_changes(map_id)

        # Don't overwrite existing cache data when there are no changes
        # Only initialize if cache doesn't exist
        maybe_initialize_empty_details_map(old_details_map, systems, cache_key_details)

        :ok
      else
        # Build new details for each changed system
        updated_details_map =
          build_updated_details_map(changed_systems, old_details_map, new_ids_map)

        # Update the ID map cache
        updated_ids_map = build_updated_ids_map(changed_systems, old_ids_map, new_ids_map)

        # Store updated caches
        WandererApp.Cache.insert(cache_key_ids, updated_ids_map,
          ttl: :timer.hours(@killmail_ttl_hours)
        )

        WandererApp.Cache.insert(cache_key_details, updated_details_map,
          ttl: :timer.hours(@killmail_ttl_hours)
        )

        # Broadcast changes
        changed_data = Map.take(updated_details_map, changed_systems)
        MapServerImpl.broadcast!(map_id, :detailed_kills_updated, changed_data)

        :ok
      end
    end)
  end

  defp maybe_broadcast_map_kills(new_kills_map, map_id) do
    {:ok, old_kills_map} = WandererApp.Cache.lookup("map:#{map_id}:zkb:kills", %{})

    # Use the union of keys from both the new and old maps
    all_system_ids = Map.keys(Map.merge(new_kills_map, old_kills_map))

    changed_system_ids =
      Enum.filter(all_system_ids, fn system_id ->
        new_kills_count = Map.get(new_kills_map, system_id, 0)
        old_kills_count = Map.get(old_kills_map, system_id, 0)

        new_kills_count != old_kills_count and
          (new_kills_count > 0 or (old_kills_count > 0 and new_kills_count == 0))
      end)

    if changed_system_ids == [] do
      :ok
    else
      :ok =
        WandererApp.Cache.insert("map:#{map_id}:zkb:kills", new_kills_map,
          ttl: @store_map_kills_timeout
        )

      payload = Map.take(new_kills_map, changed_system_ids)

      MapServerImpl.broadcast!(map_id, :kills_updated, payload)

      :ok
    end
  end

  defp with_started_map(map_id, label, fun) when is_function(fun, 0) do
    if WandererApp.Cache.lookup!("map_#{map_id}:started", false) do
      fun.()
    else
      Logger.debug(fn -> "[ZkbDataFetcher] Map #{map_id} not started => skipping #{label}" end)
      :ok
    end
  end

  defp maybe_initialize_empty_details_map(%{}, systems, cache_key_details) do
    # First time initialization - create empty structure
    initial_map = Enum.into(systems, %{}, fn {system_id, _} -> {system_id, []} end)

    WandererApp.Cache.insert(cache_key_details, initial_map,
      ttl: :timer.hours(@killmail_ttl_hours)
    )
  end

  defp maybe_initialize_empty_details_map(_old_details_map, _systems, _cache_key_details), do: :ok

  defp build_updated_details_map(changed_systems, old_details_map, new_ids_map) do
    Enum.reduce(changed_systems, old_details_map, fn system_id, acc ->
      kill_details = get_kill_details_for_system(system_id, new_ids_map)
      Map.put(acc, system_id, kill_details)
    end)
  end

  defp get_kill_details_for_system(system_id, new_ids_map) do
    new_ids_map
    |> Map.fetch!(system_id)
    |> MapSet.to_list()
    |> Enum.map(&WandererApp.Cache.get("zkb:killmail:#{&1}"))
    |> Enum.reject(&is_nil/1)
  end

  defp build_updated_ids_map(changed_systems, old_ids_map, new_ids_map) do
    Enum.reduce(changed_systems, old_ids_map, fn system_id, acc ->
      new_ids_list = new_ids_map[system_id] |> MapSet.to_list()
      Map.put(acc, system_id, new_ids_list)
    end)
  end

  defp log_no_changes(map_id) do
    Logger.debug(fn ->
      "[ZkbDataFetcher] No changes in detailed kills for map_id=#{map_id}"
    end)
  end
end
