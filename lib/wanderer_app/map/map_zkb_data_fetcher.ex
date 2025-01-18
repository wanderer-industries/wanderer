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

  def start_link(_) do
    GenServer.start(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    {:ok, timer} = :timer.send_interval(@interval, :fetch_data)

    {:ok, %{timer: timer}}
  end

  @impl true
  def handle_info(:fetch_data, state) do
    WandererApp.Map.RegistryHelper.list_all_maps()
    |> Task.async_stream(
      fn %{id: map_id, pid: _server_pid} ->
        try do
          map_id
          |> WandererApp.Map.Server.map_pid()
          |> case do
            pid when is_pid(pid) ->
              _update_map_kills(map_id)
              _update_detailed_map_kills(map_id)

            nil ->
              :ok
          end
        rescue
          e ->
            @logger.error(Exception.message(e))
            :ok
        end
      end,
      max_concurrency: 10,
      on_timeout: :kill_task
    )
    |> Enum.map(fn _ -> :ok end)

    {:noreply, state}
  end

  @impl true
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])

    {:noreply, state}
  end

  defp _update_map_kills(map_id) do
    case WandererApp.Cache.lookup!("map_#{map_id}:started", false) do
      true ->
        map_id
        |> WandererApp.Map.get_map!()
        |> Map.get(:systems, Map.new())
        |> Enum.reduce(Map.new(), fn {solar_system_id, _system}, acc ->
          kills_count = WandererApp.Cache.get("zkb_kills_#{solar_system_id}")
          acc |> Map.put(solar_system_id, kills_count || 0)
        end)
        |> _maybe_broadcast_map_kills(map_id)

      _ ->
        :ok
    end
  end

  defp _update_detailed_map_kills(map_id) do
    case WandererApp.Cache.lookup!("map_#{map_id}:started", false) do
      true ->
        systems =
          map_id
          |> WandererApp.Map.get_map!()
          |> Map.get(:systems, %{})

        detailed_map =
          Enum.reduce(systems, %{}, fn {solar_system_id, _system}, acc ->
            kill_ids = KillsCache.get_system_killmail_ids(solar_system_id)

            kill_details =
              kill_ids
              |> Enum.map(&KillsCache.get_killmail/1)
              |> Enum.reject(&is_nil/1)

            Map.put(acc, solar_system_id, kill_details)
          end)

        old_detailed_map =
          WandererApp.Cache.get("map_#{map_id}:zkb_detailed_kills") || %{}

        changed_systems =
          detailed_map
          |> Enum.filter(fn {system_id, new_list} ->
            old_list = Map.get(old_detailed_map, system_id, [])
            new_list != old_list
          end)
          |> Enum.map(fn {system_id, _} -> system_id end)

        if changed_systems == [] do
          Logger.debug("[ZkbDataFetcher] No changes in detailed kills for map_id=#{map_id}")
          :ok
        else
          WandererApp.Cache.put("map_#{map_id}:zkb_detailed_kills", detailed_map,
            ttl: :timer.hours(24)
          )
          changed_data = Map.take(detailed_map, changed_systems)

          @pubsub_client.broadcast!(WandererApp.PubSub, map_id, %{
            event: :detailed_kills_updated,
            payload: changed_data
          })

          :ok
        end

      _ ->
        Logger.info("[ZkbDataFetcher] Map #{map_id} not started => skipping detailed kills update")
        :ok
    end
  end

  defp _maybe_broadcast_map_kills(new_kills_map, map_id) do
    {:ok, old_kills_map} = WandererApp.Cache.lookup("map_#{map_id}:zkb_kills", Map.new())

    updated_kills_system_ids =
      new_kills_map
      |> Map.filter(fn {solar_system_id, new_kills_count} ->
        old_kills_count = old_kills_map |> Map.get(solar_system_id, 0)

        new_kills_count != old_kills_count and
          new_kills_count > 0
      end)
      |> Map.keys()

    removed_kills_system_ids =
      old_kills_map
      |> Map.filter(fn {solar_system_id, old_kills_count} ->
        new_kills_count = new_kills_map |> Map.get(solar_system_id, 0)

        old_kills_count > 0 and new_kills_count == 0
      end)
      |> Map.keys()

    (updated_kills_system_ids ++ removed_kills_system_ids)
    |> case do
      [] ->
        :ok

      system_ids ->
        :ok =
          WandererApp.Cache.put("map_#{map_id}:zkb_kills", new_kills_map,
            ttl: @store_map_kills_timeout
          )

        @pubsub_client.broadcast!(WandererApp.PubSub, map_id, %{
          event: :kills_updated,
          payload: new_kills_map |> Map.take(system_ids)
        })

        :ok
    end
  end
end
