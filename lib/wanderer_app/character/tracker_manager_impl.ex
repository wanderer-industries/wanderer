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
  @untrack_characters_interval :timer.minutes(5)
  @inactive_character_timeout :timer.minutes(5)

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

  def start(%{opts: opts} = state) do
    opts[:characters]
    |> Enum.reduce(state, fn character_id, acc ->
      start_tracking(acc, character_id, %{})
    end)
  end

  def start_tracking(%__MODULE__{characters: characters} = state, character_id, opts) do
    case Enum.member?(characters, character_id) do
      true ->
        state

      false ->
        Logger.debug(fn -> "Start character tracker: #{inspect(character_id)}" end)

        WandererApp.TaskWrapper.start_link(WandererApp.Character, :update_character_state, [
          character_id,
          %{opts: opts}
        ])

        tracked_characters = [character_id | state.characters] |> Enum.uniq()
        WandererApp.Cache.insert("tracked_characters", tracked_characters)

        WandererApp.Character.TrackerPoolDynamicSupervisor.start_tracking(character_id)

        %{state | characters: tracked_characters}
    end
  end

  def stop_tracking(%__MODULE__{characters: characters} = state, character_id) do
    case Enum.member?(characters, character_id) do
      true ->
        {:ok, character_state} = WandererApp.Character.get_character_state(character_id, false)

        case character_state do
          nil ->
            state

          %{start_time: start_time} ->
            duration = DateTime.diff(DateTime.utc_now(), start_time, :second)

            :telemetry.execute([:wanderer_app, :character, :tracker, :running], %{
              duration: duration
            })

            :telemetry.execute([:wanderer_app, :character, :tracker, :stopped], %{count: 1})
            Logger.debug(fn -> "Shutting down character tracker: #{inspect(character_id)}" end)

            WandererApp.Cache.delete("character:#{character_id}:location_started")
            WandererApp.Cache.delete("character:#{character_id}:start_solar_system_id")
            WandererApp.Character.delete_character_state(character_id)

            tracked_characters =
              state.characters |> Enum.reject(fn c_id -> c_id == character_id end)

            WandererApp.Cache.insert("tracked_characters", tracked_characters)

            WandererApp.Character.TrackerPoolDynamicSupervisor.stop_tracking(character_id)

            %{state | characters: tracked_characters}
        end

      false ->
        state
    end
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
      WandererApp.Cache.insert_or_update(
        "character_untrack_queue",
        [],
        fn untrack_queue ->
          untrack_queue
          |> Enum.reject(fn {m_id, c_id} -> m_id == map_id and c_id == character_id end)
        end
      )

      {:ok, character_state} =
        WandererApp.Character.Tracker.update_settings(character_id, track_settings)

      WandererApp.Character.update_character_state(character_id, character_state)
    else
      WandererApp.Cache.insert_or_update(
        "character_untrack_queue",
        [{map_id, character_id}],
        fn untrack_queue ->
          [{map_id, character_id} | untrack_queue] |> Enum.uniq()
        end
      )
    end

    state
  end

  def get_characters(
        %{
          characters: characters
        } = state,
        _opts \\ []
      ),
      do: {characters, state}

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
        %{
          characters: characters
        } =
          state
      ) do
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)

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
      timeout: :timer.seconds(15)
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

    WandererApp.Cache.get_and_remove!("character_untrack_queue", [])
    |> Task.async_stream(
      fn {map_id, character_id} ->
        if not character_is_present(map_id, character_id) do
          WandererApp.Cache.delete("map_#{map_id}:character_#{character_id}:tracked")

          {:ok, character_state} =
            WandererApp.Character.Tracker.update_settings(character_id, %{
              map_id: map_id,
              track: false
            })

          WandererApp.Character.update_character_state(character_id, character_state)
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
    WandererApp.Cache.has_key?("character:#{character_id}:is_stop_tracking")
    |> case do
      false ->
        WandererApp.Cache.insert("character:#{character_id}:is_stop_tracking", true)
        Logger.debug(fn -> "Stopping character tracker: #{inspect(character_id)}" end)
        state = state |> stop_tracking(character_id)
        WandererApp.Cache.delete("character:#{character_id}:is_stop_tracking")

        state

      _ ->
        state
    end
  end

  def handle_info(_event, state),
    do: state

  defp character_is_present(map_id, character_id) do
    {:ok, presence_character_ids} =
      WandererApp.Cache.lookup("map_#{map_id}:presence_character_ids", [])

    Enum.member?(presence_character_ids, character_id)
  end
end
