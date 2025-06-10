defmodule WandererApp.Kills.Subscription.MapIntegration do
  @moduledoc """
  Handles integration between the kills WebSocket service and the map system.

  Manages automatic subscription updates when maps change and provides
  utilities for syncing kill data with map systems.
  """

  require Logger

  @logger Application.compile_env(:wanderer_app, :logger)

  @doc """
  Handles updates when map systems change.

  Determines which systems to subscribe/unsubscribe based on the update.
  """
  @spec handle_map_systems_updated([integer()], MapSet.t(integer())) ::
          {:ok, [integer()], [integer()]}
  def handle_map_systems_updated(system_ids, current_subscriptions) when is_list(system_ids) do
    # Find all unique systems across all maps
    all_map_systems = get_all_map_systems()

    # Systems to subscribe: in the update and in active maps but not currently subscribed
    new_systems =
      system_ids
      |> Enum.filter(&(&1 in all_map_systems))
      |> Enum.reject(&MapSet.member?(current_subscriptions, &1))

    # Systems to unsubscribe: currently subscribed but no longer in any active map
    obsolete_systems =
      current_subscriptions
      |> MapSet.to_list()
      |> Enum.reject(&(&1 in all_map_systems))

    {:ok, new_systems, obsolete_systems}
  end

  @doc """
  Gets all unique system IDs across all active maps.

  This replaces the duplicate functionality from SystemTracker.
  """
  @spec get_all_map_systems() :: MapSet.t(integer())
  def get_all_map_systems do
    case WandererApp.Maps.get_available_maps() do
      {:ok, maps} ->
        all_systems =
          Enum.reduce(maps, MapSet.new(), fn map, acc ->
            case get_map_system_ids(map.id) do
              {:ok, system_ids} ->
                MapSet.union(acc, MapSet.new(system_ids))

              _ ->
                acc
            end
          end)

        all_systems

      {:error, reason} ->
        @logger.error("[MapIntegration] Failed to get available maps: #{inspect(reason)}")
        MapSet.new()
    end
  end

  @doc """
  Gets all system IDs that should be tracked for kills.

  Returns a list of unique system IDs from all active maps.
  This consolidates functionality from SystemTracker.
  """
  @spec get_tracked_system_ids() :: {:ok, list(integer())} | {:error, term()}
  def get_tracked_system_ids do
    try do
      # Get systems from currently running maps
      system_ids =
        WandererApp.Map.RegistryHelper.list_all_maps()
        |> Enum.flat_map(fn %{id: map_id} ->
          case WandererApp.MapSystemRepo.get_all_by_map(map_id) do
            {:ok, systems} -> Enum.map(systems, & &1.solar_system_id)
            _ -> []
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      {:ok, system_ids}
    rescue
      error ->
        @logger.error("[MapIntegration] Failed to get tracked systems: #{inspect(error)}")
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
        @logger.error(
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
    case WandererApp.Maps.get_available_maps() do
      {:ok, maps} ->
        Enum.any?(maps, fn map ->
          case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map.id, system_id) do
            {:ok, _system} -> true
            _ -> false
          end
        end)

      {:error, reason} ->
        @logger.error(
          "[MapIntegration] Failed to get available maps for system check: #{inspect(reason)}"
        )

        false
    end
  end

  @doc """
  Broadcasts kill data to relevant map servers.
  """
  @spec broadcast_kill_to_maps(map()) :: :ok | {:error, term()}
  def broadcast_kill_to_maps(kill_data) when is_map(kill_data) do
    case Map.get(kill_data, "solar_system_id") do
      system_id when is_integer(system_id) ->
        # Find all maps containing this system
        case WandererApp.Maps.get_available_maps() do
          {:ok, maps} ->
            Enum.each(maps, fn map ->
              case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map.id, system_id) do
                {:ok, _system} ->
                  # Broadcast to this map's topic
                  Phoenix.PubSub.broadcast(
                    WandererApp.PubSub,
                    "map:#{map.id}",
                    {:map_kill, kill_data}
                  )

                _ ->
                  # System not in this map
                  :ok
              end
            end)

            :ok

          {:error, reason} ->
            @logger.warning(
              "[MapIntegration] Failed to get available maps for kill broadcast: #{inspect(reason)}"
            )

            {:error, {:maps_unavailable, reason}}
        end

      system_id when is_binary(system_id) ->
        @logger.warning(
          "[MapIntegration] Invalid solar_system_id format (string): #{inspect(system_id)}"
        )

        {:error, {:invalid_system_id_format, system_id}}

      nil ->
        @logger.warning(
          "[MapIntegration] Missing solar_system_id in kill data: #{inspect(Map.keys(kill_data))}"
        )

        {:error, {:missing_solar_system_id, kill_data}}

      invalid_id ->
        @logger.warning("[MapIntegration] Invalid solar_system_id type: #{inspect(invalid_id)}")
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
    case WandererApp.Maps.get_available_maps() do
      {:ok, maps} ->
        stats =
          Enum.map(maps, fn map ->
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
          end)

        %{
          maps: stats,
          total_subscribed: MapSet.size(subscribed_systems),
          total_maps: length(maps)
        }

      {:error, reason} ->
        @logger.error(
          "[MapIntegration] Failed to get available maps for subscription stats: #{inspect(reason)}"
        )

        %{
          maps: [],
          total_subscribed: MapSet.size(subscribed_systems),
          total_maps: 0,
          error: "Failed to load maps: #{inspect(reason)}"
        }
    end
  end

  @doc """
  Handles map deletion by returning systems to unsubscribe.
  """
  @spec handle_map_deleted(String.t(), MapSet.t(integer())) :: [integer()]
  def handle_map_deleted(map_id, current_subscriptions) do
    # Get systems from the deleted map
    case get_map_system_ids(map_id) do
      {:ok, deleted_systems} ->
        # Only unsubscribe systems that aren't in other maps
        deleted_systems
        |> Enum.filter(&MapSet.member?(current_subscriptions, &1))
        |> Enum.reject(&system_in_active_map?/1)

      _ ->
        []
    end
  end
end
