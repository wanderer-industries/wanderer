defmodule WandererAppWeb.PresenceGracePeriodManager do
  @moduledoc """
  Manages grace period for character presence tracking.

  This module prevents rapid start/stop cycles of character tracking
  by introducing a 5-minute grace period before stopping tracking
  for characters that leave presence.
  """
  use GenServer

  require Logger

  # 30 minutes
  @grace_period_ms :timer.minutes(10)
  @check_remove_queue_interval :timer.seconds(30)

  defstruct pending_removals: %{}, timers: %{}, to_remove: []

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process presence changes with grace period logic.

  Updates the cache with the final list of character IDs that should be tracked,
  accounting for the grace period.
  """
  def process_presence_change(map_id, presence_data) do
    GenServer.cast(__MODULE__, {:process_presence_change, map_id, presence_data})
  end

  @impl true
  def init(_opts) do
    Logger.info("#{__MODULE__} started")
    Process.send_after(self(), :check_remove_queue, @check_remove_queue_interval)

    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:process_presence_change, map_id, presence_data}, state) do
    # Extract currently tracked character IDs from presence data
    current_tracked_character_ids =
      presence_data
      |> Enum.filter(fn %{tracked: tracked} -> tracked end)
      |> Enum.map(fn %{character_id: character_id} -> character_id end)

    # Get previous tracked character IDs from cache
    previous_tracked_character_ids = get_previous_character_ids(map_id)

    current_set = MapSet.new(current_tracked_character_ids)
    previous_set = MapSet.new(previous_tracked_character_ids)

    # Characters that just joined (not in previous, but in current)
    newly_joined = MapSet.difference(current_set, previous_set)

    # Characters that just left (in previous, but not in current)
    newly_left = MapSet.difference(previous_set, current_set)

    # Process newly joined characters - cancel any pending removals
    state =
      state
      |> cancel_pending_removals(map_id, current_set)
      |> schedule_removals(map_id, newly_left)

    # Process newly left characters - schedule them for removal after grace period
    # Calculate the final character IDs (current + still pending removal)
    pending_for_map = get_pending_removals_for_map(state, map_id)

    final_character_ids = MapSet.union(current_set, pending_for_map) |> MapSet.to_list()

    # Update cache with final character IDs (includes grace period logic)
    WandererApp.Cache.insert("map_#{map_id}:presence_character_ids", final_character_ids)

    # Only update presence_data if the character IDs actually changed
    if final_character_ids != previous_tracked_character_ids do
      WandererApp.Cache.insert("map_#{map_id}:presence_data", presence_data)
    end

    WandererApp.Cache.insert("map_#{map_id}:presence_updated", true)

    {:noreply, state}
  end

  @impl true
  def handle_info({:grace_period_expired, map_id, character_id}, state) do
    Logger.debug(fn -> "Grace period expired for character #{character_id} on map #{map_id}" end)

    # Remove from pending removals and timers
    state =
      state
      |> remove_pending_removal(map_id, character_id)
      |> remove_after_grace_period(map_id, character_id)

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_remove_queue, state) do
    Process.send_after(self(), :check_remove_queue, @check_remove_queue_interval)

    remove_from_cache_after_grace_period(state)
    {:noreply, %{state | to_remove: []}}
  end

  defp cancel_pending_removals(state, map_id, character_ids) do
    Enum.reduce(character_ids, state, fn character_id, acc_state ->
      case get_timer_ref(acc_state, map_id, character_id) do
        nil ->
          acc_state

        timer_ref ->
          Logger.debug(fn ->
            "Cancelling grace period for character #{character_id} on map #{map_id} (rejoined)"
          end)

          Process.cancel_timer(timer_ref)
          remove_pending_removal(acc_state, map_id, character_id)
      end
    end)
  end

  defp schedule_removals(state, map_id, character_ids) do
    Enum.reduce(character_ids, state, fn character_id, acc_state ->
      # Only schedule if not already pending
      case get_timer_ref(acc_state, map_id, character_id) do
        nil ->
          Logger.debug(fn ->
            "Scheduling grace period for character #{character_id} on map #{map_id}"
          end)

          timer_ref =
            Process.send_after(
              self(),
              {:grace_period_expired, map_id, character_id},
              @grace_period_ms
            )

          add_pending_removal(acc_state, map_id, character_id, timer_ref)

        _ ->
          acc_state
      end
    end)
  end

  defp add_pending_removal(state, map_id, character_id, timer_ref) do
    pending_key = {map_id, character_id}

    %{
      state
      | pending_removals: Map.put(state.pending_removals, pending_key, true),
        timers: Map.put(state.timers, pending_key, timer_ref)
    }
  end

  defp remove_pending_removal(state, map_id, character_id) do
    pending_key = {map_id, character_id}

    %{
      state
      | pending_removals: Map.delete(state.pending_removals, pending_key),
        timers: Map.delete(state.timers, pending_key)
    }
  end

  defp get_timer_ref(state, map_id, character_id) do
    Map.get(state.timers, {map_id, character_id})
  end

  defp get_previous_character_ids(map_id) do
    case WandererApp.Cache.get("map_#{map_id}:presence_character_ids") do
      nil -> []
      character_ids -> character_ids
    end
  end

  defp get_pending_removals_for_map(state, map_id) do
    state.pending_removals
    |> Enum.filter(fn {{pending_map_id, _character_id}, _} -> pending_map_id == map_id end)
    |> Enum.map(fn {{_map_id, character_id}, _} -> character_id end)
    |> MapSet.new()
  end

  defp remove_after_grace_period(%{to_remove: to_remove} = state, map_id, character_id_to_remove) do
    %{
      state
      | to_remove:
          (to_remove ++ [{map_id, character_id_to_remove}])
          |> Enum.uniq_by(fn {map_id, character_id} -> map_id <> character_id end)
    }
  end

  defp remove_from_cache_after_grace_period(%{to_remove: to_remove} = state) do
    # Get current presence data to recalculate without the expired character
    to_remove
    |> Enum.each(fn {map_id, character_id_to_remove} ->
      case WandererApp.Cache.get("map_#{map_id}:presence_data") do
        nil ->
          :ok

        presence_data ->
          # Recalculate tracked character IDs from current presence data
          updated_presence_data =
            presence_data
            |> Enum.filter(fn %{character_id: character_id} ->
              character_id != character_id_to_remove
            end)

          presence_tracked_character_ids =
            updated_presence_data
            |> Enum.filter(fn %{tracked: tracked} ->
              tracked
            end)
            |> Enum.map(fn %{character_id: character_id} -> character_id end)

          WandererApp.Cache.insert("map_#{map_id}:presence_data", updated_presence_data)
          # Update both caches
          WandererApp.Cache.insert(
            "map_#{map_id}:presence_character_ids",
            presence_tracked_character_ids
          )

          WandererApp.Cache.insert("map_#{map_id}:presence_updated", true)

          Logger.debug(fn ->
            "Updated cache after grace period for map #{map_id}, tracked characters: #{inspect(presence_tracked_character_ids)}"
          end)
      end
    end)
  end
end
