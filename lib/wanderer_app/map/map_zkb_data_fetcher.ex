defmodule WandererApp.Map.ZkbDataFetcher do
  @moduledoc """
  Refreshes the map zKillboard data every 15 seconds.
  """
  use GenServer

  require Logger

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
  def handle_info({ref, result}, state) do
    Process.demonitor(ref, [:flush])

    case result do
      :ok ->
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp _update_map_kills(map_id) do
    case WandererApp.Cache.lookup!("map_#{map_id}:started", false) do
      true ->
        map_id
        |> WandererApp.Map.get_map!()
        |> Map.get(:systems, Map.new())
        |> Map.keys()
        |> Enum.reduce(Map.new(), fn solar_system_id, acc ->
          kills_count = WandererApp.Cache.get("zkb_kills_#{solar_system_id}")
          acc |> Map.put_new(solar_system_id, kills_count || 0)
        end)
        |> _maybe_broadcast_map_kills(map_id)

      _ ->
        :ok
    end
  end

  defp _maybe_broadcast_map_kills(new_kills_map, map_id) do
    {:ok, old_kills_map} = WandererApp.Cache.lookup("map_#{map_id}:zkb_kills", Map.new())

    updated_kills_system_ids =
      new_kills_map
      |> Map.keys()
      |> Enum.filter(fn solar_system_id ->
        kills_count = new_kills_map |> Map.get(solar_system_id, 0)
        old_kills_count = old_kills_map |> Map.get(solar_system_id, 0)

        kills_count != old_kills_count and
          kills_count > 0
      end)

    removed_kills_system_ids =
      old_kills_map
      |> Map.keys()
      |> Enum.filter(fn solar_system_id ->
        new_kills_count = new_kills_map |> Map.get(solar_system_id, 0)
        old_kills_count = old_kills_map |> Map.get(solar_system_id, 0)

        new_kills_count != old_kills_count and
          old_kills_count > 0 and new_kills_count == 0
      end)

    [updated_kills_system_ids | removed_kills_system_ids]
    |> List.flatten()
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
