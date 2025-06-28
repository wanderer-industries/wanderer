defmodule WandererApp.Kills.Subscription.MapIntegration do
  @moduledoc """
  Handles integration between the kills WebSocket service and the map system.

  Manages automatic subscription updates when maps change and provides
  utilities for syncing kill data with map systems.
  """

  require Logger

  @doc """
  Handles updates when map systems change.

  Determines which systems to subscribe/unsubscribe based on the update.
  """
  @spec handle_map_systems_updated([integer()], MapSet.t(integer())) ::
          {:ok, [integer()], [integer()]}
  def handle_map_systems_updated(system_ids, current_subscriptions) when is_list(system_ids) do
    # Systems to subscribe: in the update and in active maps but not currently subscribed
    new_systems =
      system_ids
      |> Enum.reject(&MapSet.member?(current_subscriptions, &1))

    # Systems to unsubscribe: currently subscribed but no longer in any active map
    obsolete_systems =
      current_subscriptions
      |> MapSet.to_list()
      |> Enum.reject(&(&1 in system_ids))

    if new_systems != [] or obsolete_systems != [] do
      Logger.debug(fn ->
        "[MapIntegration] Map systems updated - " <>
          "New: #{length(new_systems)}, Obsolete: #{length(obsolete_systems)}, " <>
          "Total active: #{length(system_ids)}"
      end)
    end

    {:ok, new_systems, obsolete_systems}
  end

  @doc """
  Gets all unique system IDs across all active maps.

  This function queries the DATABASE for all persisted maps and their systems,
  regardless of whether those maps have active GenServer processes running.

  This is different from `get_tracked_system_ids/0` which only returns systems
  from maps with live processes in the Registry.

  Use this function when you need a complete view of all systems across all
  stored maps (e.g., for bulk operations or reporting).

  This replaces the duplicate functionality from SystemTracker.
  """
  @spec get_all_map_systems() :: MapSet.t(integer())
  def get_all_map_systems do
    {:ok, maps} = WandererApp.Maps.get_available_maps()

    # Get all map IDs
    map_ids = Enum.map(maps, & &1.id)

    # Batch query all systems for all maps at once
    all_systems = WandererApp.MapSystemRepo.get_all_by_maps(map_ids)

    # Handle direct list return from repo
    all_systems
    |> Enum.map(& &1.solar_system_id)
    |> MapSet.new()
  end

  @doc """
  Gets all system IDs that should be tracked for kills.

  Returns a list of unique system IDs from all active maps.

  This function returns systems from LIVE MAP PROCESSES only - maps that are currently
  running in the system. It uses the Registry to find active map GenServers.

  This is different from `get_all_map_systems/0` which queries the database for ALL
  persisted maps regardless of whether they have an active process.

  Use this function when you need to know which systems are actively being tracked
  by running map processes (e.g., for real-time updates).

  This consolidates functionality from SystemTracker.
  """
  @spec get_tracked_system_ids() :: {:ok, list(integer())} | {:error, term()}
  def get_tracked_system_ids do
    try do
      # Get systems from currently running maps
      active_maps = WandererApp.Map.RegistryHelper.list_all_maps()

      Logger.debug("[MapIntegration] Found #{length(active_maps)} active maps")

      map_systems =
        active_maps
        |> Enum.map(fn %{id: map_id} ->
          case WandererApp.MapSystemRepo.get_visible_by_map(map_id) do
            {:ok, systems} ->
              system_ids = Enum.map(systems, & &1.solar_system_id)
              Logger.debug("[MapIntegration] Map #{map_id} has #{length(system_ids)} systems")
              {map_id, system_ids}

            _ ->
              Logger.warning("[MapIntegration] Failed to get systems for map #{map_id}")
              {map_id, []}
          end
        end)

      system_ids =
        map_systems
        |> Enum.flat_map(fn {_map_id, systems} -> systems end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      Logger.debug(fn ->
        "[MapIntegration] Total tracked systems: #{length(system_ids)} across #{length(active_maps)} maps"
      end)

      {:ok, system_ids}
    rescue
      error ->
        Logger.error("[MapIntegration] Failed to get tracked systems: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Gets all system IDs for a specific map.
  """
  @spec get_map_system_ids(String.t()) :: {:ok, [integer()]} | {:error, term()}
  def get_map_system_ids(map_id) do
    case WandererApp.MapSystemRepo.get_all_by_map(map_id) do
      {:ok, systems} ->
        system_ids = Enum.map(systems, & &1.solar_system_id)
        {:ok, system_ids}

      error ->
        Logger.error(
          "[MapIntegration] Failed to get systems for map #{map_id}: #{inspect(error)}"
        )

        error
    end
  end

  @doc """
  Checks if a system is in any active map.
  """
  @spec system_in_active_map?(integer()) :: boolean()
  def system_in_active_map?(system_id) do
    {:ok, maps} = WandererApp.Maps.get_available_maps()
    Enum.any?(maps, &system_in_map?(&1, system_id))
  end

  @doc """
  Broadcasts kill data to relevant map servers.
  """
  @spec broadcast_kill_to_maps(map()) :: :ok | {:error, term()}
  def broadcast_kill_to_maps(kill_data) when is_map(kill_data) do
    case Map.get(kill_data, "solar_system_id") do
      system_id when is_integer(system_id) ->
        # Use the index to find maps containing this system
        map_ids = WandererApp.Kills.Subscription.SystemMapIndex.get_maps_for_system(system_id)

        # Broadcast to each relevant map
        Enum.each(map_ids, fn map_id ->
          Phoenix.PubSub.broadcast(
            WandererApp.PubSub,
            "map:#{map_id}",
            {:map_kill, kill_data}
          )
        end)

        # ADDITIVE: Also broadcast to external event system (webhooks/WebSocket)
        # This does NOT modify existing behavior, it's purely additive
        Enum.each(map_ids, fn map_id ->
          try do
            WandererApp.ExternalEvents.broadcast(map_id, :map_kill, kill_data)
          rescue
            error ->
              Logger.error(
                "Failed to broadcast external event for map #{map_id}: #{inspect(error)}"
              )

              # Continue processing other maps even if one fails
          end
        end)

        :ok

      system_id when is_binary(system_id) ->
        Logger.warning(
          "[MapIntegration] Invalid solar_system_id format (string): #{inspect(system_id)}"
        )

        {:error, {:invalid_system_id_format, system_id}}

      nil ->
        Logger.warning(
          "[MapIntegration] Missing solar_system_id in kill data: #{inspect(Map.keys(kill_data))}"
        )

        {:error, {:missing_solar_system_id, kill_data}}

      invalid_id ->
        Logger.warning("[MapIntegration] Invalid solar_system_id type: #{inspect(invalid_id)}")
        {:error, {:invalid_system_id_type, invalid_id}}
    end
  end

  def broadcast_kill_to_maps(invalid_data) do
    Logger.warning(
      "[MapIntegration] Invalid kill_data type (expected map): #{inspect(invalid_data)}"
    )

    {:error, {:invalid_kill_data_type, invalid_data}}
  end

  @doc """
  Gets subscription statistics grouped by map.
  """
  @spec get_map_subscription_stats(MapSet.t(integer())) :: map()
  def get_map_subscription_stats(subscribed_systems) do
    {:ok, maps} = WandererApp.Maps.get_available_maps()
    stats = Enum.map(maps, &get_map_stats(&1, subscribed_systems))

    %{
      maps: stats,
      total_subscribed: MapSet.size(subscribed_systems),
      total_maps: length(maps)
    }
  end

  @doc """
  Handles map deletion by returning systems to unsubscribe.
  """
  @spec handle_map_deleted(String.t(), MapSet.t(integer())) :: [integer()]
  def handle_map_deleted(map_id, current_subscriptions) do
    # Get systems from the deleted map
    case get_map_system_ids(map_id) do
      {:ok, deleted_systems} ->
        # Precompute all active systems to avoid O(N×M) queries
        active_systems = get_all_active_systems_set()

        # Only unsubscribe systems that aren't in other maps
        deleted_systems
        |> Enum.filter(&MapSet.member?(current_subscriptions, &1))
        |> Enum.reject(&MapSet.member?(active_systems, &1))

      _ ->
        []
    end
  end

  # Helper functions to reduce nesting

  defp get_all_active_systems_set do
    {:ok, maps} = WandererApp.Maps.get_available_maps()

    maps
    |> Enum.flat_map(&get_map_systems_or_empty/1)
    |> MapSet.new()
  end

  defp get_map_systems_or_empty(map) do
    case get_map_system_ids(map.id) do
      {:ok, system_ids} -> system_ids
      _ -> []
    end
  end

  defp system_in_map?(map, system_id) do
    case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map.id, system_id) do
      {:ok, _system} -> true
      _ -> false
    end
  end

  defp get_map_stats(map, subscribed_systems) do
    case get_map_system_ids(map.id) do
      {:ok, system_ids} ->
        subscribed_count =
          system_ids
          |> Enum.filter(&MapSet.member?(subscribed_systems, &1))
          |> length()

        %{
          map_id: map.id,
          map_name: map.name,
          total_systems: length(system_ids),
          subscribed_systems: subscribed_count,
          subscription_rate:
            if(length(system_ids) > 0,
              do: subscribed_count / length(system_ids) * 100,
              else: 0
            )
        }

      _ ->
        %{
          map_id: map.id,
          map_name: map.name,
          error: "Failed to load systems"
        }
    end
  end
end
