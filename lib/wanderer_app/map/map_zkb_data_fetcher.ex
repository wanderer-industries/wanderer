defmodule WandererApp.Map.ZkbDataFetcher do
  @moduledoc """
  Refreshes the map zKillboard data every 15 seconds.
  """
  use GenServer

  require Logger

  alias WandererApp.Zkb.KillsProvider.KillsCache

  @interval :timer.seconds(15)
  @store_map_kills_timeout :timer.hours(1)
  @logger Application.compile_env(:wanderer_app, :logger)
  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)

  # This means 120 “ticks” of 15s each → ~30 minutes
  @preload_cycle_ticks 120

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    {:ok, _timer_ref} = :timer.send_interval(@interval, :fetch_data)
    {:ok, %{iteration: 0}}
  end

  @impl true
  def handle_info(:fetch_data, %{iteration: iteration} = state) do
    zkill_preload_disabled = WandererApp.Env.zkill_preload_disabled?()

    WandererApp.Map.RegistryHelper.list_all_maps()
    |> Task.async_stream(
      fn %{id: map_id, pid: _server_pid} ->
        try do
          if WandererApp.Map.Server.map_pid(map_id) do
            update_map_kills(map_id)

            {:ok, is_subscription_active} = map_id |> WandererApp.Map.is_subscription_active?()

            can_preload_zkill = not zkill_preload_disabled && is_subscription_active

            if can_preload_zkill do
              update_detailed_map_kills(map_id)
            end
          end
        rescue
          e ->
            @logger.error(Exception.message(e))
        end
      end,
      max_concurrency: 10,
      on_timeout: :kill_task
    )
    |> Enum.each(fn _ -> :ok end)

    new_iteration = iteration + 1

    cond do
      zkill_preload_disabled ->
        # If preload is disabled, just update iteration
        {:noreply, %{state | iteration: new_iteration}}

      new_iteration >= @preload_cycle_ticks ->
        Logger.info("[ZkbDataFetcher] Triggering a fresh kill preload pass ...")
        WandererApp.Zkb.KillsPreloader.run_preload_now()
        {:noreply, %{state | iteration: 0}}

      true ->
        {:noreply, %{state | iteration: new_iteration}}
    end
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
        kills_count = WandererApp.Cache.get("zkb_kills_#{solar_system_id}") || 0
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

      # Old cache data
      old_ids_map = WandererApp.Cache.get("map_#{map_id}:zkb_ids") || %{}
      old_details_map = WandererApp.Cache.get("map_#{map_id}:zkb_detailed_kills") || %{}

      new_ids_map =
        Enum.into(systems, %{}, fn {solar_system_id, _} ->
          ids = KillsCache.get_system_killmail_ids(solar_system_id) |> MapSet.new()
          {solar_system_id, ids}
        end)

      changed_systems =
        new_ids_map
        |> Enum.filter(fn {system_id, new_ids_set} ->
          old_set = MapSet.new(Map.get(old_ids_map, system_id, []))
          not MapSet.equal?(new_ids_set, old_set)
        end)
        |> Enum.map(&elem(&1, 0))

      if changed_systems == [] do
        Logger.debug("[ZkbDataFetcher] No changes in detailed kills for map_id=#{map_id}")
        :ok
      else
        # Build new details for each changed system
        updated_details_map =
          Enum.reduce(changed_systems, old_details_map, fn system_id, acc ->
            kill_ids =
              new_ids_map
              |> Map.fetch!(system_id)
              |> MapSet.to_list()

            kill_details =
              kill_ids
              |> Enum.map(&KillsCache.get_killmail/1)
              |> Enum.reject(&is_nil/1)

            Map.put(acc, system_id, kill_details)
          end)

        updated_ids_map =
          Enum.reduce(changed_systems, old_ids_map, fn system_id, acc ->
            new_ids_list = new_ids_map[system_id] |> MapSet.to_list()
            Map.put(acc, system_id, new_ids_list)
          end)

        WandererApp.Cache.put("map_#{map_id}:zkb_ids", updated_ids_map,
          ttl: :timer.hours(KillsCache.killmail_ttl())
        )

        WandererApp.Cache.put("map_#{map_id}:zkb_detailed_kills", updated_details_map,
          ttl: :timer.hours(KillsCache.killmail_ttl())
        )

        changed_data = Map.take(updated_details_map, changed_systems)

        @pubsub_client.broadcast!(WandererApp.PubSub, map_id, %{
          event: :detailed_kills_updated,
          payload: changed_data
        })

        :ok
      end
    end)
  end

  defp maybe_broadcast_map_kills(new_kills_map, map_id) do
    {:ok, old_kills_map} = WandererApp.Cache.lookup("map_#{map_id}:zkb_kills", %{})

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
        WandererApp.Cache.put("map_#{map_id}:zkb_kills", new_kills_map,
          ttl: @store_map_kills_timeout
        )

      payload = Map.take(new_kills_map, changed_system_ids)

      @pubsub_client.broadcast!(WandererApp.PubSub, map_id, %{
        event: :kills_updated,
        payload: payload
      })

      :ok
    end
  end

  defp with_started_map(map_id, label \\ "operation", fun) when is_function(fun, 0) do
    if WandererApp.Cache.lookup!("map_#{map_id}:started", false) do
      fun.()
    else
      Logger.debug("[ZkbDataFetcher] Map #{map_id} not started => skipping #{label}")
      :ok
    end
  end
end
