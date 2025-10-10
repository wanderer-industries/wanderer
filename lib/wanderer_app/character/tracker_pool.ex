defmodule WandererApp.Character.TrackerPool do
  @moduledoc false
  use GenServer, restart: :transient

  require Logger

  defstruct [
    :tracked_ids,
    :uuid,
    :characters,
    server_online: true
  ]

  @name __MODULE__
  @cache :tracked_characters
  @registry :tracker_pool_registry
  @unique_registry :unique_tracker_pool_registry

  @update_location_interval :timer.seconds(1)
  @update_online_interval :timer.seconds(5)
  @check_offline_characters_interval :timer.minutes(5)
  @check_online_errors_interval :timer.minutes(1)
  @check_ship_errors_interval :timer.minutes(1)
  @check_location_errors_interval :timer.minutes(1)
  @update_ship_interval :timer.seconds(2)
  @update_info_interval :timer.minutes(2)
  @update_wallet_interval :timer.minutes(10)

  @logger Application.compile_env(:wanderer_app, :logger)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def start_link(tracked_ids) do
    uuid = UUID.uuid1()

    GenServer.start_link(
      @name,
      {uuid, tracked_ids},
      name: Module.concat(__MODULE__, uuid)
    )
  end

  @impl true
  def init({uuid, tracked_ids}) do
    {:ok, _} = Registry.register(@unique_registry, Module.concat(__MODULE__, uuid), tracked_ids)
    {:ok, _} = Registry.register(@registry, __MODULE__, uuid)

    # Cachex.get_and_update(@cache, :tracked_characters, fn ids ->
    #   {:commit, ids ++ tracked_ids}
    # end)

    tracked_ids
    |> Enum.each(fn id ->
      Cachex.put(@cache, id, uuid)
    end)

    state =
      %{
        uuid: uuid,
        characters: tracked_ids
      }
      |> new()

    {:ok, state, {:continue, :start}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  @impl true
  def handle_cast(:stop, state), do: {:stop, :normal, state}

  @impl true
  def handle_cast({:add_tracked_id, tracked_id}, %{characters: characters, uuid: uuid} = state) do
    Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_tracked_ids ->
      [tracked_id | r_tracked_ids]
    end)

    # Cachex.get_and_update(@cache, :tracked_characters, fn ids ->
    #   {:commit, ids ++ [tracked_id]}
    # end)
    Cachex.put(@cache, tracked_id, uuid)

    {:noreply, %{state | characters: [tracked_id | characters]}}
  end

  @impl true
  def handle_cast(
        {:remove_tracked_id, tracked_id},
        %{characters: characters, uuid: uuid} = state
      ) do
    Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_tracked_ids ->
      r_tracked_ids |> Enum.reject(fn id -> id == tracked_id end)
    end)

    # Cachex.get_and_update(@cache, :tracked_characters, fn ids ->
    #   {:commit, ids |> Enum.reject(fn id -> id == tracked_id end)}
    # end)
    #
    Cachex.del(@cache, tracked_id)

    {:noreply, %{state | characters: characters |> Enum.reject(fn id -> id == tracked_id end)}}
  end

  @impl true
  def handle_call(:error, _, state), do: {:stop, :error, :ok, state}

  @impl true
  def handle_continue(:start, state) do
    Logger.info("#{@name} started")

    # Start message queue monitoring
    Process.send_after(self(), :monitor_message_queue, :timer.seconds(30))

    Phoenix.PubSub.subscribe(
      WandererApp.PubSub,
      "server_status"
    )

    Process.send_after(self(), :update_online, 100)
    Process.send_after(self(), :check_online_errors, :timer.seconds(60))
    Process.send_after(self(), :check_ship_errors, :timer.seconds(90))
    Process.send_after(self(), :check_location_errors, :timer.seconds(120))
    Process.send_after(self(), :check_offline_characters, @check_offline_characters_interval)
    Process.send_after(self(), :update_location, 300)
    Process.send_after(self(), :update_ship, 500)
    Process.send_after(self(), :update_info, 1500)

    if WandererApp.Env.wallet_tracking_enabled?() do
      Process.send_after(self(), :update_wallet, 1000)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:monitor_message_queue, state) do
    monitor_message_queue(state)

    # Schedule next monitoring check
    Process.send_after(self(), :monitor_message_queue, :timer.seconds(30))

    {:noreply, state}
  end

  def handle_info({ref, result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case result do
      {:error, error} ->
        @logger.error("#{__MODULE__} failed to process: #{inspect(error)}")
        :ok

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:server_status, status}, state),
    do: {:noreply, %{state | server_online: not status.vip}}

  def handle_info(
        :update_online,
        %{
          characters: characters,
          server_online: true
        } =
          state
      ) do
    Process.send_after(self(), :update_online, @update_online_interval)

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.Character.Tracker.update_online(character_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.seconds(5)
      )
      |> Enum.each(fn _result -> :ok end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] update_online => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :update_online,
        %{
          characters: characters
        } =
          state
      ) do
    Process.send_after(self(), :update_online, @update_online_interval)

    try do
      characters
      |> Enum.each(fn character_id ->
        WandererApp.Character.update_character(character_id, %{online: false})

        WandererApp.Character.update_character_state(character_id, %{
          is_online: false
        })
      end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] update_online => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :check_offline_characters,
        %{
          characters: characters
        } =
          state
      ) do
    Process.send_after(self(), :check_offline_characters, @check_offline_characters_interval)

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.Character.Tracker.check_offline(character_id)
        end,
        timeout: :timer.seconds(15),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn
        {:ok, _result} -> :ok
        error -> @logger.error("Error in check_offline: #{inspect(error)}")
      end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] check_offline => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :check_online_errors,
        %{
          characters: characters
        } =
          state
      ) do
    Process.send_after(self(), :check_online_errors, @check_online_errors_interval)

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.TaskWrapper.start_link(
            WandererApp.Character.Tracker,
            :check_online_errors,
            [
              character_id
            ]
          )
        end,
        timeout: :timer.seconds(15),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn
        {:ok, _result} -> :ok
        error -> @logger.error("Error in check_online_errors: #{inspect(error)}")
      end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] check_online_errors => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :check_ship_errors,
        %{
          characters: characters
        } =
          state
      ) do
    Process.send_after(self(), :check_ship_errors, @check_ship_errors_interval)

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.TaskWrapper.start_link(
            WandererApp.Character.Tracker,
            :check_ship_errors,
            [
              character_id
            ]
          )
        end,
        timeout: :timer.seconds(15),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn
        {:ok, _result} -> :ok
        error -> @logger.error("Error in check_ship_errors: #{inspect(error)}")
      end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] check_ship_errors => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :check_location_errors,
        %{
          characters: characters
        } =
          state
      ) do
    Process.send_after(self(), :check_location_errors, @check_location_errors_interval)

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.TaskWrapper.start_link(
            WandererApp.Character.Tracker,
            :check_location_errors,
            [
              character_id
            ]
          )
        end,
        timeout: :timer.seconds(15),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn
        {:ok, _result} -> :ok
        error -> @logger.error("Error in check_location_errors: #{inspect(error)}")
      end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] check_location_errors => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
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

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.Character.Tracker.update_location(character_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.seconds(5)
      )
      |> Enum.each(fn _result -> :ok end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] update_location => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :update_location,
        state
      ) do
    Process.send_after(self(), :update_location, @update_location_interval)

    {:noreply, state}
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

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.Character.Tracker.update_ship(character_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.seconds(5)
      )
      |> Enum.each(fn _result -> :ok end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] update_ship => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :update_ship,
        state
      ) do
    Process.send_after(self(), :update_ship, @update_ship_interval)

    {:noreply, state}
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

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.Character.Tracker.update_info(character_id)
        end,
        timeout: :timer.seconds(15),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn
        {:ok, _result} -> :ok
        error -> Logger.error("Error in update_info: #{inspect(error)}")
      end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] update_info => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :update_info,
        state
      ) do
    Process.send_after(self(), :update_info, @update_info_interval)

    {:noreply, state}
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

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.Character.Tracker.update_wallet(character_id)
        end,
        timeout: :timer.minutes(5),
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task
      )
      |> Enum.each(fn
        {:ok, _result} -> :ok
        error -> Logger.error("Error in update_wallet: #{inspect(error)}")
      end)
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] update_wallet => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  def handle_info(
        :update_wallet,
        state
      ) do
    Process.send_after(self(), :update_wallet, @update_wallet_interval)

    {:noreply, state}
  end

  defp monitor_message_queue(state) do
    try do
      {_, message_queue_len} = Process.info(self(), :message_queue_len)
      {_, memory} = Process.info(self(), :memory)

      # Alert on high message queue
      if message_queue_len > 50 do
        Logger.warning("GENSERVER_QUEUE_HIGH: Character tracker pool message queue buildup",
          pool_id: state.uuid,
          message_queue_length: message_queue_len,
          memory_bytes: memory,
          tracked_characters: length(state.characters)
        )

        # Emit telemetry
        :telemetry.execute(
          [:wanderer_app, :character, :tracker_pool, :queue_buildup],
          %{
            message_queue_length: message_queue_len,
            memory_bytes: memory
          },
          %{
            pool_id: state.uuid,
            tracked_characters: length(state.characters)
          }
        )
      end
    rescue
      error ->
        Logger.debug("Failed to monitor message queue: #{inspect(error)}")
    end
  end

  defp via_tuple(uuid) do
    {:via, Registry, {@unique_registry, Module.concat(__MODULE__, uuid)}}
  end
end
