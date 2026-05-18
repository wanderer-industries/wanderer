defmodule WandererApp.Character.TrackerManager.Impl do
  @moduledoc """
  Implementation of the character tracker manager.

  This module manages the lifecycle of character trackers and handles:
  - Starting/stopping character tracking
  - Garbage collection of inactive trackers (5-minute timeout)
  - Processing the untrack queue (5-minute interval)

  ## Logging

  This module emits detailed logs for debugging character tracking issues:
  - WARNING: Unexpected states or potential issues
  - DEBUG: Start/stop tracking events, garbage collection, queue processing
  """
  require Logger

  defstruct [
    :characters,
    :opts
  ]

  @type t :: %__MODULE__{
          characters: [integer],
          opts: map
        }

  @check_start_queue_interval :timer.seconds(1)
  @garbage_collection_interval :timer.minutes(5)
  @untrack_characters_interval :timer.minutes(5)
  @inactive_character_timeout :timer.minutes(5)

  @logger Application.compile_env(:wanderer_app, :logger)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def init(args) do
    Process.send_after(self(), :check_start_queue, @check_start_queue_interval)
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)
    Process.send_after(self(), :untrack_characters, @untrack_characters_interval)

    Logger.debug(
      "[TrackerManager] Initialized with intervals: " <>
        "garbage_collection=#{div(@garbage_collection_interval, 60_000)}min, " <>
        "untrack=#{div(@untrack_characters_interval, 60_000)}min, " <>
        "inactive_timeout=#{div(@inactive_character_timeout, 60_000)}min"
    )

    %{
      characters: [],
      opts: args
    }
    |> new()
  end

  def start(state) do
    {:ok, tracked_characters} = WandererApp.Cache.lookup("tracked_characters", [])
    WandererApp.Cache.insert("tracked_characters", [])

    if length(tracked_characters) > 0 do
      Logger.debug(
        "[TrackerManager] Restoring #{length(tracked_characters)} tracked characters from cache"
      )
    end

    tracked_characters
    |> Enum.each(fn character_id ->
      start_tracking(state, character_id)
    end)

    state
  end

  def start_tracking(state, character_id) do
    if not WandererApp.Cache.has_key?("#{character_id}:track_requested") do
      WandererApp.Cache.insert(
        "#{character_id}:track_requested",
        true
      )

      Logger.debug(fn ->
        "[TrackerManager] Queuing character #{character_id} for tracking start"
      end)

      WandererApp.Cache.insert_or_update(
        "track_characters_queue",
        [character_id],
        fn existing ->
          [character_id | existing] |> Enum.uniq()
        end
      )
    end

    state
  end

  def stop_tracking(state, character_id) do
    with {:ok, characters} <- WandererApp.Cache.lookup("tracked_characters", []),
         true <- Enum.member?(characters, character_id),
         false <- WandererApp.Cache.has_key?("#{character_id}:track_requested") do
      Logger.debug(fn ->
        "[TrackerManager] Stopping tracker for character #{character_id} - " <>
          "reason: no active maps (garbage collected after #{div(@inactive_character_timeout, 60_000)} minutes)"
      end)

      WandererApp.Cache.delete("character:#{character_id}:last_active_time")
      WandererApp.Character.delete_character_state(character_id)
      WandererApp.Character.TrackerPoolDynamicSupervisor.stop_tracking(character_id)

      :telemetry.execute(
        [:wanderer_app, :character, :tracker, :stopped],
        %{count: 1, system_time: System.system_time()},
        %{character_id: character_id, reason: :garbage_collection}
      )
    else
      {:ok, characters} when is_list(characters) ->
        Logger.debug(fn ->
          "[TrackerManager] Character #{character_id} not in tracked list, skipping stop"
        end)

      false ->
        Logger.debug(fn ->
          "[TrackerManager] Character #{character_id} has pending track request, skipping stop"
        end)

      _ ->
        :ok
    end

    WandererApp.Cache.insert_or_update(
      "tracked_characters",
      [],
      fn tracked_characters ->
        tracked_characters
        |> Enum.reject(fn c_id -> c_id == character_id end)
      end
    )

    state
  end

  def update_track_settings(
        %__MODULE__{} = state,
        character_id,
        %{
          map_id: map_id,
          track: track
        } = track_settings
      ) do
    if track do
      Logger.debug(fn ->
        "[TrackerManager] Enabling tracking for character #{character_id} on map #{map_id}"
      end)

      remove_from_untrack_queue(map_id, character_id)

      case WandererApp.Character.Tracker.update_settings(character_id, track_settings) do
        {:ok, character_state} ->
          WandererApp.Character.update_character_state(character_id, character_state)

        {:error, :not_found} ->
          # Tracker process not running yet - this is expected during initial tracking setup
          # The tracking_start_time cache key was already set by TrackingUtils.track_character
          Logger.debug(fn ->
            "[TrackerManager] Tracker not yet running for character #{character_id} - " <>
              "tracking will be active via cache key"
          end)

        {:error, reason} ->
          Logger.warning(fn ->
            "[TrackerManager] Failed to update settings for character #{character_id}: #{inspect(reason)}"
          end)
      end
    else
      Logger.debug(fn ->
        "[TrackerManager] Queuing character #{character_id} for untracking from map #{map_id} - " <>
          "will be processed within #{div(@untrack_characters_interval, 60_000)} minutes"
      end)

      add_to_untrack_queue(map_id, character_id)
    end

    state
  end

  def add_to_untrack_queue(map_id, character_id) do
    WandererApp.Cache.insert_or_update(
      "character_untrack_queue",
      [{map_id, character_id}],
      fn untrack_queue ->
        [{map_id, character_id} | untrack_queue]
        |> Enum.uniq_by(fn {map_id, character_id} -> map_id <> character_id end)
      end
    )
  end

  def remove_from_untrack_queue(map_id, character_id) do
    WandererApp.Cache.insert_or_update(
      "character_untrack_queue",
      [],
      fn untrack_queue ->
        original_length = length(untrack_queue)

        filtered =
          untrack_queue
          |> Enum.reject(fn {m_id, c_id} -> m_id == map_id and c_id == character_id end)

        if length(filtered) < original_length do
          Logger.debug(fn ->
            "[TrackerManager] Removed character #{character_id} from untrack queue for map #{map_id} - " <>
              "character re-enabled tracking"
          end)
        end

        filtered
      end
    )
  end

  def get_characters(
        state,
        _opts \\ []
      ) do
    {:ok, characters} = WandererApp.Cache.lookup("tracked_characters", [])
    {characters, state}
  end

  def handle_event({ref, result}, state) do
    Process.demonitor(ref, [:flush])

    case result do
      :ok ->
        state

      {:error, :skipped} ->
        state

      {:error, error} ->
        @logger.error("#{__MODULE__} failed to process: #{inspect(error)}")
        state

      _ ->
        state
    end
  end

  def handle_info(
        :check_start_queue,
        state
      ) do
    Process.send_after(self(), :check_start_queue, @check_start_queue_interval)
    {:ok, track_characters_queue} = WandererApp.Cache.lookup("track_characters_queue", [])

    if length(track_characters_queue) > 0 do
      Logger.debug(fn ->
        "[TrackerManager] Processing start queue: #{length(track_characters_queue)} characters"
      end)
    end

    track_characters_queue
    |> Enum.each(fn character_id ->
      track_character(character_id, %{})
    end)

    state
  end

  def handle_info(
        :garbage_collect,
        state
      ) do
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)

    {:ok, characters} = WandererApp.Cache.lookup("tracked_characters", [])

    Logger.debug(fn ->
      "[TrackerManager] Running garbage collection on #{length(characters)} tracked characters"
    end)

    inactive_characters =
      characters
      |> Task.async_stream(
        fn character_id ->
          case WandererApp.Cache.lookup("character:#{character_id}:last_active_time") do
            {:ok, nil} ->
              # Character is still active (no last_active_time set)
              :skip

            {:ok, last_active_time} ->
              duration_seconds = DateTime.diff(DateTime.utc_now(), last_active_time, :second)
              duration_ms = duration_seconds * 1000

              if duration_ms > @inactive_character_timeout do
                Logger.debug(fn ->
                  "[TrackerManager] Character #{character_id} marked for garbage collection - " <>
                    "inactive for #{div(duration_seconds, 60)} minutes " <>
                    "(threshold: #{div(@inactive_character_timeout, 60_000)} minutes)"
                end)

                {:stop, character_id, duration_seconds}
              else
                :skip
              end
          end
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.seconds(60)
      )
      |> Enum.reduce([], fn result, acc ->
        case result do
          {:ok, {:stop, character_id, duration}} ->
            [{character_id, duration} | acc]

          _ ->
            acc
        end
      end)

    if length(inactive_characters) > 0 do
      Logger.debug(fn ->
        "[TrackerManager] Garbage collection found #{length(inactive_characters)} inactive characters to stop"
      end)

      # Emit telemetry for garbage collection
      :telemetry.execute(
        [:wanderer_app, :character, :tracker, :garbage_collection],
        %{inactive_count: length(inactive_characters), total_tracked: length(characters)},
        %{character_ids: Enum.map(inactive_characters, fn {id, _} -> id end)}
      )
    end

    inactive_characters
    |> Enum.each(fn {character_id, _duration} ->
      Process.send_after(self(), {:stop_track, character_id}, 100)
    end)

    state
  end

  def handle_info(
        :untrack_characters,
        state
      ) do
    Process.send_after(self(), :untrack_characters, @untrack_characters_interval)

    untrack_queue = WandererApp.Cache.lookup!("character_untrack_queue", [])

    if length(untrack_queue) > 0 do
      Logger.debug(fn ->
        "[TrackerManager] Processing untrack queue: #{length(untrack_queue)} character-map pairs"
      end)
    end

    untrack_queue
    |> Task.async_stream(
      fn {map_id, character_id} ->
        Logger.debug(fn ->
          "[TrackerManager] Untracking character #{character_id} from map #{map_id} - " <>
            "reason: character no longer present on map"
        end)

        remove_from_untrack_queue(map_id, character_id)

        WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:solar_system_id")
        WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:station_id")
        WandererApp.Cache.delete("map:#{map_id}:character:#{character_id}:structure_id")

        {:ok, character_state} =
          WandererApp.Character.Tracker.update_settings(character_id, %{
            map_id: map_id,
            track: false
          })

        {:ok, character} = WandererApp.Character.get_character(character_id)

        {:ok, _updated} =
          WandererApp.MapCharacterSettingsRepo.update(map_id, character_id, %{
            ship: character.ship,
            ship_name: character.ship_name,
            ship_item_id: character.ship_item_id,
            solar_system_id: character.solar_system_id,
            structure_id: character.structure_id,
            station_id: character.station_id
          })

        WandererApp.Character.update_character_state(character_id, character_state)
        WandererApp.Map.Server.Impl.broadcast!(map_id, :untrack_character, character_id)

        # Emit telemetry for untrack event
        :telemetry.execute(
          [:wanderer_app, :character, :tracker, :untracked_from_map],
          %{system_time: System.system_time()},
          %{character_id: character_id, map_id: map_id, reason: :presence_left}
        )

        {:ok, character_id, map_id}
      end,
      max_concurrency: System.schedulers_online() * 4,
      on_timeout: :kill_task,
      timeout: :timer.seconds(30)
    )
    |> Enum.each(fn result ->
      case result do
        {:ok, {:ok, character_id, map_id}} ->
          Logger.debug(fn ->
            "[TrackerManager] Successfully untracked character #{character_id} from map #{map_id}"
          end)

        {:exit, reason} ->
          Logger.warning(fn ->
            "[TrackerManager] Untrack task exited with reason: #{inspect(reason)}"
          end)

        _ ->
          :ok
      end
    end)

    state
  end

  def handle_info({:stop_track, character_id}, state) do
    if not WandererApp.Cache.has_key?("character:#{character_id}:is_stop_tracking") do
      WandererApp.Cache.insert("character:#{character_id}:is_stop_tracking", true)

      Logger.debug(fn ->
        "[TrackerManager] Executing stop_track for character #{character_id}"
      end)

      stop_tracking(state, character_id)
      WandererApp.Cache.delete("character:#{character_id}:is_stop_tracking")
    else
      Logger.debug(fn ->
        "[TrackerManager] Character #{character_id} already being stopped, skipping duplicate request"
      end)
    end

    state
  end

  def track_character(character_id, opts) do
    with {:ok, characters} <- WandererApp.Cache.lookup("tracked_characters", []),
         false <- Enum.member?(characters, character_id) do
      Logger.debug(fn ->
        "[TrackerManager] Starting tracker for character #{character_id}"
      end)

      WandererApp.Cache.insert_or_update(
        "tracked_characters",
        [character_id],
        fn existing ->
          [character_id | existing] |> Enum.uniq()
        end
      )

      WandererApp.Cache.insert_or_update(
        "track_characters_queue",
        [],
        fn existing ->
          existing
          |> Enum.reject(fn c_id -> c_id == character_id end)
        end
      )

      WandererApp.Cache.delete("#{character_id}:track_requested")

      WandererApp.Character.update_character(character_id, %{online: false})

      WandererApp.Character.update_character_state(character_id, %{
        is_online: false
      })

      WandererApp.Character.TrackerPoolDynamicSupervisor.start_tracking(character_id)

      WandererApp.TaskWrapper.start_link(WandererApp.Character, :update_character_state, [
        character_id,
        %{opts: opts}
      ])

      # Emit telemetry for tracker start
      :telemetry.execute(
        [:wanderer_app, :character, :tracker, :started],
        %{count: 1, system_time: System.system_time()},
        %{character_id: character_id}
      )
    else
      true ->
        Logger.debug(fn ->
          "[TrackerManager] Character #{character_id} already being tracked"
        end)

        WandererApp.Cache.insert_or_update(
          "track_characters_queue",
          [],
          fn existing ->
            existing
            |> Enum.reject(fn c_id -> c_id == character_id end)
          end
        )

        WandererApp.Cache.delete("#{character_id}:track_requested")

      _ ->
        WandererApp.Cache.insert_or_update(
          "track_characters_queue",
          [],
          fn existing ->
            existing
            |> Enum.reject(fn c_id -> c_id == character_id end)
          end
        )

        WandererApp.Cache.delete("#{character_id}:track_requested")
    end
  end

  def character_is_present(map_id, character_id) do
    {:ok, presence_character_ids} =
      WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])

    Enum.member?(presence_character_ids, character_id)
  end
end
