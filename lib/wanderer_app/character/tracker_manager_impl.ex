defmodule WandererApp.Character.TrackerManager.Impl do
  @moduledoc false
  require Logger

  defstruct [
    :characters,
    :opts
  ]

  @type t :: %__MODULE__{
          characters: [integer],
          opts: map
        }

  @garbage_collection_interval :timer.minutes(15)
  @untrack_characters_interval :timer.minutes(1)
  @inactive_character_timeout :timer.minutes(10)
  @untrack_character_timeout :timer.minutes(10)

  @logger Application.compile_env(:wanderer_app, :logger)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def init(args) do
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)
    Process.send_after(self(), :untrack_characters, @untrack_characters_interval)

    %{
      characters: [],
      opts: args
    }
    |> new()
  end

  def start(state) do
    {:ok, tracked_characters} = WandererApp.Cache.lookup("tracked_characters", [])
    WandererApp.Cache.insert("tracked_characters", [])

    tracked_characters
    |> Enum.each(fn character_id ->
      start_tracking(state, character_id, %{})
    end)

    state
  end

  def start_tracking(state, character_id, opts) do
    with {:ok, characters} <- WandererApp.Cache.lookup("tracked_characters", []),
         false <- Enum.member?(characters, character_id) do
      Logger.debug(fn -> "Start character tracker: #{inspect(character_id)}" end)

      tracked_characters = [character_id | characters] |> Enum.uniq()
      WandererApp.Cache.insert("tracked_characters", tracked_characters)

      WandererApp.Character.update_character(character_id, %{online: false})

      WandererApp.Character.update_character_state(character_id, %{
        is_online: false
      })

      WandererApp.Character.TrackerPoolDynamicSupervisor.start_tracking(character_id)

      WandererApp.TaskWrapper.start_link(WandererApp.Character, :update_character_state, [
        character_id,
        %{opts: opts}
      ])
    end

    state
  end

  def stop_tracking(state, character_id) do
    with {:ok, characters} <- WandererApp.Cache.lookup("tracked_characters", []),
         true <- Enum.member?(characters, character_id),
         {:ok, %{start_time: start_time}} <-
           WandererApp.Character.get_character_state(character_id, false) do
      Logger.debug(fn -> "Shutting down character tracker: #{inspect(character_id)}" end)

      WandererApp.Cache.delete("character:#{character_id}:last_active_time")
      WandererApp.Character.delete_character_state(character_id)

      tracked_characters =
        characters |> Enum.reject(fn c_id -> c_id == character_id end)

      WandererApp.Cache.insert("tracked_characters", tracked_characters)

      WandererApp.Character.TrackerPoolDynamicSupervisor.stop_tracking(character_id)

      duration = DateTime.diff(DateTime.utc_now(), start_time, :second)

      :telemetry.execute([:wanderer_app, :character, :tracker, :running], %{
        duration: duration
      })

      :telemetry.execute([:wanderer_app, :character, :tracker, :stopped], %{count: 1})
    end

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
      remove_from_untrack_queue(map_id, character_id)

      {:ok, character_state} =
        WandererApp.Character.Tracker.update_settings(character_id, track_settings)

      WandererApp.Character.update_character_state(character_id, character_state)
    else
      add_to_untrack_queue(map_id, character_id)
    end

    state
  end

  def add_to_untrack_queue(map_id, character_id) do
    if not WandererApp.Cache.has_key?("#{map_id}:#{character_id}:untrack_requested") do
      WandererApp.Cache.insert(
        "#{map_id}:#{character_id}:untrack_requested",
        DateTime.utc_now()
      )
    end

    WandererApp.Cache.insert_or_update(
      "character_untrack_queue",
      [{map_id, character_id}],
      fn untrack_queue ->
        [{map_id, character_id} | untrack_queue] |> Enum.uniq()
      end
    )
  end

  def remove_from_untrack_queue(map_id, character_id) do
    WandererApp.Cache.delete("#{map_id}:#{character_id}:untrack_requested")

    WandererApp.Cache.insert_or_update(
      "character_untrack_queue",
      [],
      fn untrack_queue ->
        untrack_queue
        |> Enum.reject(fn {m_id, c_id} -> m_id == map_id and c_id == character_id end)
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
        :garbage_collect,
        state
      ) do
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)

    {:ok, characters} = WandererApp.Cache.lookup("tracked_characters", [])

    characters
    |> Task.async_stream(
      fn character_id ->
        case WandererApp.Cache.lookup("character:#{character_id}:last_active_time") do
          {:ok, nil} ->
            :skip

          {:ok, last_active_time} ->
            duration = DateTime.diff(DateTime.utc_now(), last_active_time, :second)

            if duration * 1000 > @inactive_character_timeout do
              {:stop, character_id}
            else
              :skip
            end
        end
      end,
      max_concurrency: System.schedulers_online(),
      on_timeout: :kill_task,
      timeout: :timer.seconds(60)
    )
    |> Enum.map(fn result ->
      case result do
        {:ok, {:stop, character_id}} ->
          Process.send_after(self(), {:stop_track, character_id}, 100)

        _ ->
          :ok
      end
    end)

    state
  end

  def handle_info(
        :untrack_characters,
        state
      ) do
    Process.send_after(self(), :untrack_characters, @untrack_characters_interval)

    WandererApp.Cache.lookup!("character_untrack_queue", [])
    |> Task.async_stream(
      fn {map_id, character_id} ->
        untrack_timeout_reached =
          if WandererApp.Cache.has_key?("#{map_id}:#{character_id}:untrack_requested") do
            untrack_requested =
              WandererApp.Cache.lookup!(
                "#{map_id}:#{character_id}:untrack_requested",
                DateTime.utc_now()
              )

            duration = DateTime.diff(DateTime.utc_now(), untrack_requested, :millisecond)
            duration >= @untrack_character_timeout
          else
            false
          end

        Logger.debug(fn -> "Untrack timeout reached: #{inspect(untrack_timeout_reached)}" end)

        if untrack_timeout_reached do
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
        end
      end,
      max_concurrency: System.schedulers_online(),
      on_timeout: :kill_task,
      timeout: :timer.seconds(30)
    )
    |> Enum.map(fn _result -> :ok end)

    state
  end

  def handle_info({:stop_track, character_id}, state) do
    if not WandererApp.Cache.has_key?("character:#{character_id}:is_stop_tracking") do
      WandererApp.Cache.insert("character:#{character_id}:is_stop_tracking", true)
      Logger.debug(fn -> "Stopping character tracker: #{inspect(character_id)}" end)
      stop_tracking(state, character_id)
      WandererApp.Cache.delete("character:#{character_id}:is_stop_tracking")
    end

    state
  end

  def handle_info(_event, state),
    do: state

  def character_is_present(map_id, character_id) do
    {:ok, presence_character_ids} =
      WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])

    Enum.member?(presence_character_ids, character_id)
  end
end
