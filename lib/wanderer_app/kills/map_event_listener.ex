defmodule WandererApp.Kills.MapEventListener do
  @moduledoc """
  Listens for map events and updates kill subscriptions accordingly.

  This module bridges the gap between map system changes and the kills
  WebSocket subscription system.
  """

  use GenServer
  require Logger

  alias WandererApp.Kills.Client
  alias WandererApp.Kills.Subscription.MapIntegration

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to map lifecycle events
    Phoenix.PubSub.subscribe(WandererApp.PubSub, "maps")

    # Subscribe to existing running maps
    running_maps = WandererApp.Map.RegistryHelper.list_all_maps()

    running_maps
    |> Enum.each(fn %{id: map_id} ->
      try do
        Phoenix.PubSub.subscribe(WandererApp.PubSub, map_id)
      rescue
        e ->
          Logger.error("[MapEventListener] Failed to subscribe to map #{map_id}: #{inspect(e)}")
      end
    end)

    # Defer subscription update to avoid blocking init
    send(self(), :initial_subscription_update)

    # Also schedule a re-subscription after a delay in case maps start after us
    Process.send_after(self(), :resubscribe_to_maps, 5000)

    {:ok, %{last_update: nil, pending_update: nil, pending_removals: MapSet.new()}}
  end

  @impl true
  def handle_info(:initial_subscription_update, state) do
    {:noreply, do_update_subscriptions(state)}
  end

  @impl true
  def handle_info(%{event: :map_server_started}, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(:map_server_started, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(%{event: :add_system, payload: _system}, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info({:add_system, _system}, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(%{event: :systems_removed, payload: system_ids}, state) do
    # Track pending removals so we can handle them immediately
    new_pending_removals = MapSet.union(state.pending_removals, MapSet.new(system_ids))
    {:noreply, schedule_subscription_update(%{state | pending_removals: new_pending_removals})}
  end

  def handle_info({:systems_removed, system_ids}, state) do
    # Track pending removals so we can handle them immediately
    new_pending_removals = MapSet.union(state.pending_removals, MapSet.new(system_ids))
    {:noreply, schedule_subscription_update(%{state | pending_removals: new_pending_removals})}
  end

  def handle_info(%{event: :update_system, payload: _system}, state) do
    # System updates might change visibility or other properties
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info({:update_system, _system}, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(%{event: :map_server_stopped}, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(:map_server_stopped, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  # Handle scheduled update
  def handle_info(:perform_subscription_update, state) do
    # Clear pending removals after processing
    new_state = do_update_subscriptions(%{state | pending_update: nil})
    {:noreply, %{new_state | pending_removals: MapSet.new()}}
  end

  # Handle re-subscription attempt
  def handle_info(:resubscribe_to_maps, state) do
    running_maps = WandererApp.Map.RegistryHelper.list_all_maps()

    running_maps
    |> Enum.each(fn %{id: map_id} ->
      Phoenix.PubSub.subscribe(WandererApp.PubSub, map_id)
    end)

    {:noreply, state}
  end

  # Handle map creation - subscribe to new map
  def handle_info({:map_created, map_id}, state) do
    Phoenix.PubSub.subscribe(WandererApp.PubSub, map_id)
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Debounce delay in milliseconds
  @debounce_delay 500

  defp schedule_subscription_update(state) do
    # Cancel pending update if exists
    if state.pending_update do
      Process.cancel_timer(state.pending_update)
    end

    # Schedule new update
    timer_ref = Process.send_after(self(), :perform_subscription_update, @debounce_delay)
    %{state | pending_update: timer_ref}
  end

  defp do_update_subscriptions(state) do
    Task.start(fn ->
      try do
        perform_subscription_update(state.pending_removals)
        # Also refresh the system->map index
        WandererApp.Kills.Subscription.SystemMapIndex.refresh()
      rescue
        e ->
          Logger.error("[MapEventListener] Error updating subscriptions: #{inspect(e)}")
      end
    end)

    %{state | last_update: System.monotonic_time(:millisecond)}
  end

  defp perform_subscription_update(pending_removals) do
    case Client.get_status() do
      {:ok, %{subscriptions: %{subscribed_systems: current_systems}}} ->
        apply_subscription_changes(current_systems, pending_removals)

      {:error, :not_running} ->
        Logger.debug("[MapEventListener] Kills client not running yet")

      error ->
        Logger.error("[MapEventListener] Failed to get client status: #{inspect(error)}")
    end
  end

  defp apply_subscription_changes(current_systems, pending_removals) do
    current_set = MapSet.new(current_systems)
    all_systems = MapIntegration.get_all_map_systems()

    # Remove pending removals from all_systems since DB might not be updated yet
    all_systems_adjusted = MapSet.difference(all_systems, pending_removals)

    # Use the existing MapIntegration logic to determine changes
    {:ok, to_subscribe, to_unsubscribe} =
      MapIntegration.handle_map_systems_updated(
        MapSet.to_list(all_systems_adjusted),
        current_set
      )

    # Apply the changes
    if to_subscribe != [] do
      Client.subscribe_to_systems(to_subscribe)
    end

    if to_unsubscribe != [] do
      Client.unsubscribe_from_systems(to_unsubscribe)
    end
  end
end
