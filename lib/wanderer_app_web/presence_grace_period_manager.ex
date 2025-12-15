defmodule WandererAppWeb.PresenceGracePeriodManager do
  @moduledoc """
  Manages grace period for character presence tracking.

  This module prevents rapid start/stop cycles of character tracking
  by introducing a 30-minute grace period before stopping tracking
  for characters that leave presence.

  ## Architecture

  When a character's presence leaves (e.g., browser close, network disconnect):
  1. Character is scheduled for removal after grace period (30 min)
  2. Character remains in `presence_character_ids` during grace period
  3. If character rejoins during grace period, removal is cancelled
  4. After grace period expires, character is atomically removed from cache

  ## Logging

  This module emits detailed logs for debugging character tracking issues:
  - INFO: Grace period expire events (actual character removal)
  - WARNING: Unexpected states or potential issues
  - DEBUG: Grace period start/cancel, presence changes, state changes
  """
  use GenServer

  require Logger

  # 15 minutes grace period before removing disconnected characters
  @grace_period_ms :timer.minutes(15)

  defstruct pending_removals: %{}, timers: %{}

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

  @doc """
  Get current grace period state for debugging purposes.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Reset state for testing purposes.
  Cancels all pending timers and clears all state.
  """
  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end

  @doc """
  Clear state for a specific map. Used for cleanup.
  Cancels any pending timers for characters on this map.
  """
  def clear_map_state(map_id) do
    GenServer.call(__MODULE__, {:clear_map_state, map_id})
  end

  @doc """
  Synchronous version of process_presence_change for testing.
  Returns :ok when processing is complete.
  """
  def process_presence_change_sync(map_id, presence_data) do
    GenServer.call(__MODULE__, {:process_presence_change_sync, map_id, presence_data})
  end

  @impl true
  def init(_opts) do
    Logger.debug("[PresenceGracePeriod] Manager started")

    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:reset_state, _from, state) do
    # Cancel all pending timers
    Enum.each(state.timers, fn {_key, timer_ref} ->
      Process.cancel_timer(timer_ref)
    end)

    Logger.debug("[PresenceGracePeriod] State reset - cancelled #{map_size(state.timers)} timers")

    {:reply, :ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:clear_map_state, map_id}, _from, state) do
    # Find and cancel all timers for this map
    {timers_to_cancel, remaining_timers} =
      Enum.split_with(state.timers, fn {{m_id, _char_id}, _ref} -> m_id == map_id end)

    # Cancel the timers
    Enum.each(timers_to_cancel, fn {_key, timer_ref} ->
      Process.cancel_timer(timer_ref)
    end)

    # Filter pending_removals for this map
    remaining_pending =
      Enum.reject(state.pending_removals, fn {{m_id, _char_id}, _} -> m_id == map_id end)
      |> Map.new()

    if length(timers_to_cancel) > 0 do
      Logger.debug(
        "[PresenceGracePeriod] Cleared state for map #{map_id} - cancelled #{length(timers_to_cancel)} timers"
      )
    end

    new_state = %{
      state
      | timers: Map.new(remaining_timers),
        pending_removals: remaining_pending
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:process_presence_change_sync, map_id, presence_data}, _from, state) do
    # Same logic as the cast version, but synchronous
    new_state = do_process_presence_change(state, map_id, presence_data)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:process_presence_change, map_id, presence_data}, state) do
    new_state = do_process_presence_change(state, map_id, presence_data)
    {:noreply, new_state}
  end

  # Shared logic for presence change processing
  defp do_process_presence_change(state, map_id, presence_data) do
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

    # Log presence changes for debugging
    if MapSet.size(newly_joined) > 0 or MapSet.size(newly_left) > 0 do
      Logger.debug(fn ->
        "[PresenceGracePeriod] Map #{map_id} presence change - " <>
          "joined: #{inspect(MapSet.to_list(newly_joined))}, " <>
          "left: #{inspect(MapSet.to_list(newly_left))}"
      end)
    end

    # Cancel any pending removals for ALL currently present tracked characters
    # This handles the case where a character rejoins during grace period
    # (they're still in cache, so they won't be in "newly_joined")
    state =
      state
      |> cancel_pending_removals(map_id, current_set)
      |> schedule_removals(map_id, newly_left)

    # Calculate the final character IDs (current + characters in grace period)
    # This includes both pending_removals (timer not yet fired)
    characters_in_grace_period = get_characters_in_grace_period(state, map_id)

    final_character_ids =
      MapSet.union(current_set, characters_in_grace_period) |> MapSet.to_list()

    # Update cache with final character IDs (includes grace period logic)
    WandererApp.Cache.insert("map_#{map_id}:presence_character_ids", final_character_ids)
    WandererApp.Cache.insert("map_#{map_id}:presence_data", presence_data)
    WandererApp.Cache.insert("map_#{map_id}:presence_updated", true)

    Logger.debug(fn ->
      "[PresenceGracePeriod] Map #{map_id} cache updated - " <>
        "current: #{length(current_tracked_character_ids)}, " <>
        "in_grace_period: #{MapSet.size(characters_in_grace_period)}, " <>
        "final: #{length(final_character_ids)}"
    end)

    state
  end

  @impl true
  def handle_info({:grace_period_expired, map_id, character_id}, state) do
    # Check if this removal is still valid (wasn't cancelled)
    case get_timer_ref(state, map_id, character_id) do
      nil ->
        # Timer was cancelled (character rejoined), ignore
        Logger.debug(fn ->
          "[PresenceGracePeriod] Grace period expired for character #{character_id} on map #{map_id} " <>
            "but timer was already cancelled (character likely rejoined)"
        end)

        {:noreply, state}

      _timer_ref ->
        # Grace period expired and is still valid - perform atomic removal
        Logger.info(fn ->
          "[PresenceGracePeriod] Grace period expired for character #{character_id} on map #{map_id} - " <>
            "removing from tracking after #{div(@grace_period_ms, 60_000)} minutes of inactivity"
        end)

        # Remove from pending removals state
        state = remove_pending_removal(state, map_id, character_id)

        # Atomically remove from cache (Fix #2 - no batching)
        remove_character_from_cache(map_id, character_id)

        # Emit telemetry for monitoring
        :telemetry.execute(
          [:wanderer_app, :presence, :grace_period_expired],
          %{duration_ms: @grace_period_ms, system_time: System.system_time()},
          %{map_id: map_id, character_id: character_id, reason: :grace_period_timeout}
        )

        {:noreply, state}
    end
  end

  # Cancel pending removals for characters that have rejoined
  defp cancel_pending_removals(state, map_id, character_ids) do
    Enum.reduce(character_ids, state, fn character_id, acc_state ->
      case get_timer_ref(acc_state, map_id, character_id) do
        nil ->
          acc_state

        timer_ref ->
          # Character rejoined during grace period - cancel removal
          time_remaining = Process.cancel_timer(timer_ref)

          Logger.debug(fn ->
            time_remaining_str =
              if is_integer(time_remaining) do
                "#{div(time_remaining, 60_000)} minutes remaining"
              else
                "timer already fired"
              end

            "[PresenceGracePeriod] Cancelled grace period for character #{character_id} on map #{map_id} - " <>
              "character rejoined (#{time_remaining_str})"
          end)

          # Emit telemetry for cancelled grace period
          :telemetry.execute(
            [:wanderer_app, :presence, :grace_period_cancelled],
            %{system_time: System.system_time()},
            %{map_id: map_id, character_id: character_id, reason: :character_rejoined}
          )

          remove_pending_removal(acc_state, map_id, character_id)
      end
    end)
  end

  # Schedule removals for characters that have left presence
  defp schedule_removals(state, map_id, character_ids) do
    Enum.reduce(character_ids, state, fn character_id, acc_state ->
      # Only schedule if not already pending
      case get_timer_ref(acc_state, map_id, character_id) do
        nil ->
          Logger.debug(fn ->
            "[PresenceGracePeriod] Starting #{div(@grace_period_ms, 60_000)}-minute grace period " <>
              "for character #{character_id} on map #{map_id} - character left presence"
          end)

          timer_ref =
            Process.send_after(
              self(),
              {:grace_period_expired, map_id, character_id},
              @grace_period_ms
            )

          # Emit telemetry for grace period start
          :telemetry.execute(
            [:wanderer_app, :presence, :grace_period_started],
            %{grace_period_ms: @grace_period_ms, system_time: System.system_time()},
            %{map_id: map_id, character_id: character_id, reason: :presence_left}
          )

          add_pending_removal(acc_state, map_id, character_id, timer_ref)

        _existing_timer ->
          # Already has a pending removal scheduled
          Logger.debug(fn ->
            "[PresenceGracePeriod] Character #{character_id} on map #{map_id} already has pending removal"
          end)

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

  # Fix #1: Include all characters in grace period (both pending and awaiting removal)
  # This prevents race conditions where a character could be removed early
  defp get_characters_in_grace_period(state, map_id) do
    state.pending_removals
    |> Enum.filter(fn {{pending_map_id, _character_id}, _} -> pending_map_id == map_id end)
    |> Enum.map(fn {{_map_id, character_id}, _} -> character_id end)
    |> MapSet.new()
  end

  # Fix #2: Atomic removal from cache when grace period expires
  # This removes the character immediately instead of batching
  defp remove_character_from_cache(map_id, character_id_to_remove) do
    # Get current presence_character_ids and remove the character
    current_character_ids =
      case WandererApp.Cache.get("map_#{map_id}:presence_character_ids") do
        nil -> []
        ids -> ids
      end

    updated_character_ids =
      Enum.reject(current_character_ids, fn id -> id == character_id_to_remove end)

    # Also update presence_data if it exists
    case WandererApp.Cache.get("map_#{map_id}:presence_data") do
      nil ->
        # No presence data, just update character IDs
        :ok

      presence_data ->
        updated_presence_data =
          presence_data
          |> Enum.filter(fn %{character_id: character_id} ->
            character_id != character_id_to_remove
          end)

        WandererApp.Cache.insert("map_#{map_id}:presence_data", updated_presence_data)
    end

    WandererApp.Cache.insert("map_#{map_id}:presence_character_ids", updated_character_ids)
    WandererApp.Cache.insert("map_#{map_id}:presence_updated", true)

    Logger.debug(fn ->
      "[PresenceGracePeriod] Removed character #{character_id_to_remove} from map #{map_id} cache - " <>
        "remaining tracked characters: #{length(updated_character_ids)}"
    end)

    :ok
  end
end
