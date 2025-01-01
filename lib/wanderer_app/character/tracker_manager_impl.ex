defmodule WandererApp.Character.TrackerManager.Impl do
  @moduledoc false
  require Logger

  defstruct [
    :characters,
    :opts,
    server_online: true
  ]

  @type t :: %__MODULE__{
          characters: [integer],
          opts: map,
          server_online: boolean
        }

  @update_location_interval :timer.seconds(2)
  @update_online_interval :timer.seconds(5)
  @check_online_errors_interval :timer.seconds(30)
  @update_ship_interval :timer.seconds(5)
  @update_info_interval :timer.minutes(1)
  @update_wallet_interval :timer.minutes(5)
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
    Phoenix.PubSub.subscribe(
      WandererApp.PubSub,
      "server_status"
    )

    Process.send_after(self(), :update_online, 100)
    Process.send_after(self(), :check_online_errors, @check_online_errors_interval)
    Process.send_after(self(), :update_location, 300)
    Process.send_after(self(), :update_ship, 500)
    Process.send_after(self(), :update_info, 1500)

    if WandererApp.Env.wallet_tracking_enabled?() do
      Process.send_after(self(), :update_wallet, 1000)
    end

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

        %{state | characters: tracked_characters}
    end
  end

  def stop_tracking(%__MODULE__{} = state, character_id) do
    {:ok, character_state} = WandererApp.Character.get_character_state(character_id, false)

    case character_state do
      nil ->
        state

      %{start_time: start_time} ->
        duration = DateTime.diff(DateTime.utc_now(), start_time, :second)
        :telemetry.execute([:wanderer_app, :character, :tracker, :running], %{duration: duration})
        :telemetry.execute([:wanderer_app, :character, :tracker, :stopped], %{count: 1})
        Logger.debug(fn -> "Shutting down character tracker: #{inspect(character_id)}" end)

        WandererApp.Cache.delete("character:#{character_id}:location_started")
        WandererApp.Cache.delete("character:#{character_id}:start_solar_system_id")
        WandererApp.Character.delete_character_state(character_id)

        tracked_characters = state.characters |> Enum.reject(fn c_id -> c_id == character_id end)

        WandererApp.Cache.insert("tracked_characters", tracked_characters)

        %{state | characters: tracked_characters}
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
        WandererApp.Character.Tracker.update_track_settings(character_id, track_settings)

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

  def handle_info({:server_status, status}, state),
    do: %{state | server_online: not status.vip}

  def handle_info(
        :update_online,
        %{
          characters: characters,
          server_online: true
        } =
          state
      ) do
    Process.send_after(self(), :update_online, @update_online_interval)

    characters
    |> Enum.map(fn character_id ->
      WandererApp.TaskWrapper.start_link(WandererApp.Character.Tracker, :update_online, [
        character_id
      ])
    end)

    state
  end

  def handle_info(
        :update_online,
        state
      ) do
    Process.send_after(self(), :update_online, @update_online_interval)

    state
  end

  def handle_info(
        :check_online_errors,
        %{
          characters: characters
        } =
          state
      ) do
    Process.send_after(self(), :check_online_errors, @check_online_errors_interval)

    characters
    |> Task.async_stream(
      fn character_id ->
        WandererApp.TaskWrapper.start_link(WandererApp.Character.Tracker, :check_online_errors, [
          character_id
        ])
      end,
      timeout: :timer.seconds(15),
      max_concurrency: System.schedulers_online(),
      on_timeout: :kill_task
    )
    |> Enum.each(fn
      {:ok, _result} -> :ok
      {:error, reason} -> @logger.error("Error in check_online_errors: #{inspect(reason)}")
    end)

    state
  end

  def handle_info(
        :update_location,
        %{
          characters: characters,
          server_online: true
        } =
          state
      ) do
    Process.send_after(self(), :update_location, @update_location_interval)

    characters
    |> Enum.map(fn character_id ->
      WandererApp.TaskWrapper.start_link(WandererApp.Character.Tracker, :update_location, [
        character_id
      ])
    end)

    state
  end

  def handle_info(
        :update_location,
        state
      ) do
    Process.send_after(self(), :update_location, @update_location_interval)

    state
  end

  def handle_info(
        :update_ship,
        %{
          characters: characters,
          server_online: true
        } =
          state
      ) do
    Process.send_after(self(), :update_ship, @update_ship_interval)

    characters
    |> Enum.map(fn character_id ->
      WandererApp.TaskWrapper.start_link(WandererApp.Character.Tracker, :update_ship, [
        character_id
      ])
    end)

    state
  end

  def handle_info(
        :update_ship,
        state
      ) do
    Process.send_after(self(), :update_ship, @update_ship_interval)

    state
  end

  def handle_info(
        :update_info,
        %{
          characters: characters,
          server_online: true
        } =
          state
      ) do
    Process.send_after(self(), :update_info, @update_info_interval)

    characters
    |> Task.async_stream(
      fn character_id ->
        WandererApp.TaskWrapper.start_link(WandererApp.Character.Tracker, :update_info, [
          character_id
        ])
      end,
      timeout: :timer.seconds(15),
      max_concurrency: System.schedulers_online(),
      on_timeout: :kill_task
    )
    |> Enum.each(fn
      {:ok, _result} -> :ok
      {:error, reason} -> @logger.error("Error in update_info: #{inspect(reason)}")
    end)

    state
  end

  def handle_info(
        :update_info,
        state
      ) do
    Process.send_after(self(), :update_info, @update_info_interval)

    state
  end

  def handle_info(
        :update_wallet,
        %{
          characters: characters,
          server_online: true
        } =
          state
      ) do
    Process.send_after(self(), :update_wallet, @update_wallet_interval)

    characters
    |> Task.async_stream(
      fn character_id ->
        WandererApp.TaskWrapper.start_link(WandererApp.Character.Tracker, :update_wallet, [
          character_id
        ])
      end,
      timeout: :timer.seconds(15),
      max_concurrency: System.schedulers_online(),
      on_timeout: :kill_task
    )
    |> Enum.each(fn
      {:ok, _result} -> :ok
      {:error, reason} -> @logger.error("Error in update_wallet: #{inspect(reason)}")
    end)

    state
  end

  def handle_info(
        :update_wallet,
        state
      ) do
    Process.send_after(self(), :update_wallet, @update_wallet_interval)

    state
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
        WandererApp.Cache.delete("map_#{map_id}:character_#{character_id}:tracked")

        {:ok, character_state} =
          WandererApp.Character.Tracker.update_track_settings(character_id, %{
            map_id: map_id,
            track: false,
            followed: false
          })

        WandererApp.Character.update_character_state(character_id, character_state)
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
end
