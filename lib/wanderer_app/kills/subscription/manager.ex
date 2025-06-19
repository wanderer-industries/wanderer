defmodule WandererApp.Kills.Subscription.Manager do
  @moduledoc """
  Manages system subscriptions for kills WebSocket service.
  """
  require Logger

  @type subscriptions :: MapSet.t(integer())

  @spec subscribe_systems(subscriptions(), [integer()]) :: {subscriptions(), [integer()]}
  def subscribe_systems(current_systems, system_ids) when is_list(system_ids) do
    system_set = MapSet.new(system_ids)
    new_systems = MapSet.difference(system_set, current_systems)
    new_list = MapSet.to_list(new_systems)
    {MapSet.union(current_systems, new_systems), new_list}
  end

  @spec unsubscribe_systems(subscriptions(), [integer()]) :: {subscriptions(), [integer()]}
  def unsubscribe_systems(current_systems, system_ids) when is_list(system_ids) do
    system_set = MapSet.new(system_ids)
    systems_to_remove = MapSet.intersection(current_systems, system_set)
    removed_list = MapSet.to_list(systems_to_remove)

    {MapSet.difference(current_systems, systems_to_remove), removed_list}
  end

  @spec sync_with_server(pid() | nil, [integer()], [integer()]) :: :ok
  def sync_with_server(nil, _to_subscribe, _to_unsubscribe) do
    Logger.warning("[Manager] Attempted to sync with server but socket_pid is nil")
    :ok
  end

  def sync_with_server(socket_pid, to_subscribe, to_unsubscribe) do
    if to_unsubscribe != [] do
      send(socket_pid, {:unsubscribe_systems, to_unsubscribe})
    end

    if to_subscribe != [] do
      send(socket_pid, {:subscribe_systems, to_subscribe})
    end

    :ok
  end

  @spec resubscribe_all(pid(), subscriptions()) :: :ok
  def resubscribe_all(socket_pid, subscribed_systems) do
    system_list = MapSet.to_list(subscribed_systems)

    if system_list != [] do
      Logger.info(
        "[Manager] Resubscribing to all #{length(system_list)} systems after reconnection"
      )

      send(socket_pid, {:subscribe_systems, system_list})
    else
      Logger.debug(fn -> "[Manager] No systems to resubscribe after reconnection" end)
    end

    :ok
  end

  @spec get_stats(subscriptions()) :: map()
  def get_stats(subscribed_systems) do
    %{
      total_subscribed: MapSet.size(subscribed_systems),
      subscribed_systems: MapSet.to_list(subscribed_systems) |> Enum.sort()
    }
  end

  @spec cleanup_subscriptions(subscriptions()) :: {subscriptions(), [integer()]}
  def cleanup_subscriptions(subscribed_systems) do
    systems_to_check = MapSet.to_list(subscribed_systems)
    # Use MapIntegration's system_in_active_map? to avoid duplication
    valid_systems =
      Enum.filter(
        systems_to_check,
        &WandererApp.Kills.Subscription.MapIntegration.system_in_active_map?/1
      )

    invalid_systems = systems_to_check -- valid_systems

    if invalid_systems != [] do
      {MapSet.new(valid_systems), invalid_systems}
    else
      {subscribed_systems, []}
    end
  end
end
