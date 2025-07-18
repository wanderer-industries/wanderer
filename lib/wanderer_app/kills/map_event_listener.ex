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

  @pubsub_client Application.compile_env(:wanderer_app, :pubsub_client)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to map lifecycle events
    @pubsub_client.subscribe(WandererApp.PubSub, "maps")

    # Defer subscription update to avoid blocking init
    Process.send_after(self(), :initial_subscription_update, 30_000)

    # Also schedule a re-subscription after a delay in case maps start after us
    Process.send_after(self(), :resubscribe_to_maps, 60_000)

    {:ok,
     %{
       last_update: nil,
       pending_update: nil,
       pending_removals: MapSet.new(),
       subscribed_maps: MapSet.new(),
       retry_count: 0,
       retry_timer: nil
     }}
  end

  @impl true
  def handle_info(:initial_subscription_update, state) do
    {:noreply, do_update_subscriptions(state)}
  end

  @impl true
  def handle_info(%{event: :map_server_started, payload: map_info}, state) do
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(:map_server_started, state) do
    Process.send_after(self(), :resubscribe_to_maps, 1000)
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(%{event: :add_system, payload: system}, state) do
    Logger.debug(fn -> "[MapEventListener] System added: #{inspect(system)}" end)
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info({:add_system, system}, state) do
    Logger.debug(fn -> "[MapEventListener] System added (alt format): #{inspect(system)}" end)
    {:noreply, schedule_subscription_update(state)}
  end

  def handle_info(%{event: :systems_removed, payload: system_ids}, state) do
    Logger.debug(fn -> "[MapEventListener] Systems removed: #{length(system_ids)} systems" end)
    # Track pending removals so we can handle them immediately
    new_pending_removals = MapSet.union(state.pending_removals, MapSet.new(system_ids))
    {:noreply, schedule_subscription_update(%{state | pending_removals: new_pending_removals})}
  end

  def handle_info({:systems_removed, system_ids}, state) do
    Logger.debug(fn ->
      "[MapEventListener] Systems removed (alt format): #{length(system_ids)} systems"
    end)

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
    Logger.debug(fn -> "[MapEventListener] Performing scheduled subscription update" end)
    # Clear pending removals after processing
    new_state = do_update_subscriptions(%{state | pending_update: nil})
    {:noreply, new_state}
  end

  # Handle re-subscription attempt
  def handle_info(:resubscribe_to_maps, state) do
    running_maps = WandererApp.Map.RegistryHelper.list_all_maps()
    current_running_map_ids = MapSet.new(Enum.map(running_maps, & &1.id))

    Logger.debug(fn ->
      "[MapEventListener] Resubscribing to maps. Running maps: #{MapSet.size(current_running_map_ids)}"
    end)

    # Unsubscribe from maps no longer running
    maps_to_unsubscribe = MapSet.difference(state.subscribed_maps, current_running_map_ids)

    Enum.each(maps_to_unsubscribe, fn map_id ->
      @pubsub_client.unsubscribe(WandererApp.PubSub, map_id)
    end)

    # Subscribe to new running maps
    maps_to_subscribe = MapSet.difference(current_running_map_ids, state.subscribed_maps)

    Enum.each(maps_to_subscribe, fn map_id ->
      @pubsub_client.subscribe(WandererApp.PubSub, map_id)
    end)

    {:noreply, %{state | subscribed_maps: current_running_map_ids}}
  end

  # Handle map creation - subscribe to new map
  def handle_info({:map_created, map_id}, state) do
    Logger.debug(fn -> "[MapEventListener] Map created: #{map_id}" end)
    @pubsub_client.subscribe(WandererApp.PubSub, map_id)
    updated_subscribed_maps = MapSet.put(state.subscribed_maps, map_id)
    {:noreply, schedule_subscription_update(%{state | subscribed_maps: updated_subscribed_maps})}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Unsubscribe from all maps
    Enum.each(state.subscribed_maps, fn map_id ->
      @pubsub_client.unsubscribe(WandererApp.PubSub, map_id)
    end)

    # Unsubscribe from general maps channel
    @pubsub_client.unsubscribe(WandererApp.PubSub, "maps")

    :ok
  end

  # Debounce delay in milliseconds
  @debounce_delay 1000
  # Backoff delays for retries when client is not connected
  @retry_delays [5_000, 10_000, 30_000, 60_000]

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
    state =
      try do
        case perform_subscription_update(state.pending_removals) do
          :ok ->
            # Also refresh the system->map index
            WandererApp.Kills.Subscription.SystemMapIndex.refresh()
            %{state | pending_removals: MapSet.new(), retry_count: 0}

          {:error, :connecting} ->
            # Client is connecting, retry with backoff
            schedule_retry_update(state)

          {:error, :not_connected} ->
            # Client is not connected, retry with backoff
            schedule_retry_update(state)

          error ->
            schedule_retry_update(state)
        end
      rescue
        e ->
          Logger.error("[MapEventListener] Error updating subscriptions: #{inspect(e)}")
          schedule_retry_update(state)
      end

    %{state | last_update: System.monotonic_time(:millisecond)}
  end

  defp schedule_retry_update(state) do
    # Cancel any existing retry timer
    if state.retry_timer do
      Process.cancel_timer(state.retry_timer)
    end

    retry_count = state.retry_count
    delay = Enum.at(@retry_delays, min(retry_count, length(@retry_delays) - 1))

    timer_ref = Process.send_after(self(), :perform_subscription_update, delay)

    %{state | retry_timer: timer_ref, retry_count: retry_count + 1}
  end

  defp perform_subscription_update(pending_removals) do
    case Client.get_status() do
      {:ok, %{connected: true, subscriptions: %{subscribed_systems: current_systems}}} ->
        apply_subscription_changes(current_systems, pending_removals)
        :ok

      {:ok, %{connecting: true}} ->
        {:error, :connecting}

      {:error, :not_running} ->
        {:error, :not_running}

      {:ok, status} ->
        {:error, :not_connected}

      error ->
        Logger.error("[MapEventListener] Failed to get client status: #{inspect(error)}")
        {:error, :client_error}
    end
  end

  defp apply_subscription_changes(current_systems, pending_removals) do
    current_set = MapSet.new(current_systems)

    Logger.debug(fn ->
      "[MapEventListener] Current subscriptions: #{MapSet.size(current_set)} systems, " <>
        "Pending removals: #{MapSet.size(pending_removals)} systems"
    end)

    # Use get_tracked_system_ids to get only systems from running maps
    case MapIntegration.get_tracked_system_ids() do
      {:ok, tracked_systems} ->
        handle_tracked_systems(tracked_systems, current_set, pending_removals)

      {:error, reason} ->
        Logger.error("[MapEventListener] Failed to get tracked system IDs: #{inspect(reason)}")
    end
  end

  defp handle_tracked_systems(tracked_systems, current_set, pending_removals) do
    tracked_systems_set = MapSet.new(tracked_systems)

    # Remove pending removals from tracked_systems since DB might not be updated yet
    tracked_systems_adjusted = MapSet.difference(tracked_systems_set, pending_removals)

    Logger.debug(fn ->
      "[MapEventListener] Tracked systems from maps: #{MapSet.size(tracked_systems_set)}, " <>
        "After removing pending: #{MapSet.size(tracked_systems_adjusted)}"
    end)

    # Use the existing MapIntegration logic to determine changes
    {:ok, to_subscribe, to_unsubscribe} =
      MapIntegration.handle_map_systems_updated(
        MapSet.to_list(tracked_systems_adjusted),
        current_set
      )

    # Apply the changes
    if to_subscribe != [] do
      Logger.debug(fn ->
        "[MapEventListener] Triggering subscription for #{length(to_subscribe)} systems"
      end)

      Client.subscribe_to_systems(to_subscribe)
    end

    if to_unsubscribe != [] do
      Logger.debug(fn ->
        "[MapEventListener] Triggering unsubscription for #{length(to_unsubscribe)} systems"
      end)

      Client.unsubscribe_from_systems(to_unsubscribe)
    end
  end
end
