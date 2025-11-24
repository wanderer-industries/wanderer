defmodule WandererApp.Character.TrackerPool do
  @moduledoc false
  use GenServer, restart: :transient

  require Logger

  defstruct [
    :tracked_ids,
    :uuid,
    :characters,
    server_online: false,
    last_location_duration: 0
  ]

  @name __MODULE__
  @cache :tracked_characters
  @registry :tracker_pool_registry
  @unique_registry :unique_tracker_pool_registry

  @update_location_interval :timer.seconds(1)
  @update_online_interval :timer.seconds(30)
  @check_offline_characters_interval :timer.minutes(5)
  @update_ship_interval :timer.seconds(2)
  @update_info_interval :timer.minutes(2)
  @update_wallet_interval :timer.minutes(10)

  # Per-operation concurrency limits
  # Location updates are critical and need high concurrency (100 chars in ~200ms)
  # Note: This is fetched at runtime since it's configured via runtime.exs
  defp location_concurrency do
    Application.get_env(:wanderer_app, :location_concurrency, System.schedulers_online() * 12)
  end

  # Other operations can use lower concurrency
  @standard_concurrency System.schedulers_online() * 2

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

    # Stagger pool startups to distribute load across multiple pools
    # Critical location updates get minimal stagger (0-500ms)
    # Other operations get wider stagger (0-10s) to reduce thundering herd
    location_stagger = :rand.uniform(500)
    online_stagger = :rand.uniform(10_000)
    ship_stagger = :rand.uniform(10_000)
    info_stagger = :rand.uniform(60_000)

    Process.send_after(self(), :update_online, 100 + online_stagger)
    Process.send_after(self(), :update_location, 300 + location_stagger)
    Process.send_after(self(), :update_ship, 500 + ship_stagger)
    Process.send_after(self(), :update_info, 1500 + info_stagger)
    Process.send_after(self(), :check_offline_characters, @check_offline_characters_interval)

    if WandererApp.Env.wallet_tracking_enabled?() do
      wallet_stagger = :rand.uniform(120_000)
      Process.send_after(self(), :update_wallet, 1000 + wallet_stagger)
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
        max_concurrency: @standard_concurrency,
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

        ErrorTracker.report(e, __STACKTRACE__)
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
        max_concurrency: @standard_concurrency,
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
        :update_location,
        %{
          characters: characters,
          server_online: true
        } =
          state
      ) do
    Process.send_after(self(), :update_location, @update_location_interval)

    start_time = System.monotonic_time(:millisecond)

    try do
      characters
      |> Task.async_stream(
        fn character_id ->
          WandererApp.Character.Tracker.update_location(character_id)
        end,
        max_concurrency: location_concurrency(),
        on_timeout: :kill_task,
        timeout: :timer.seconds(5)
      )
      |> Enum.each(fn _result -> :ok end)

      # Emit telemetry for location update performance
      duration = System.monotonic_time(:millisecond) - start_time

      :telemetry.execute(
        [:wanderer_app, :tracker_pool, :location_update],
        %{duration: duration, character_count: length(characters)},
        %{pool_uuid: state.uuid}
      )

      # Warn if location updates are falling behind (taking > 800ms for 100 chars)
      if duration > 2000 do
        Logger.warning(
          "[Tracker Pool] Location updates falling behind: #{duration}ms for #{length(characters)} chars (pool: #{state.uuid})"
        )

        :telemetry.execute(
          [:wanderer_app, :tracker_pool, :location_lag],
          %{duration: duration, character_count: length(characters)},
          %{pool_uuid: state.uuid}
        )
      end

      {:noreply, %{state | last_location_duration: duration}}
    rescue
      e ->
        Logger.error("""
        [Tracker Pool] update_location => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)

        {:noreply, state}
    end
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
          server_online: true,
          last_location_duration: location_duration
        } =
          state
      ) do
    Process.send_after(self(), :update_ship, @update_ship_interval)

    # Backpressure: Skip ship updates if location updates are falling behind
    if location_duration > 1000 do
      Logger.debug(
        "[Tracker Pool] Skipping ship update due to location lag (#{location_duration}ms)"
      )

      :telemetry.execute(
        [:wanderer_app, :tracker_pool, :ship_skipped],
        %{count: 1},
        %{pool_uuid: state.uuid, reason: :location_lag}
      )

      {:noreply, state}
    else
      try do
        characters
        |> Task.async_stream(
          fn character_id ->
            WandererApp.Character.Tracker.update_ship(character_id)
          end,
          max_concurrency: @standard_concurrency,
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
          server_online: true,
          last_location_duration: location_duration
        } =
          state
      ) do
    Process.send_after(self(), :update_info, @update_info_interval)

    # Backpressure: Skip info updates if location updates are severely falling behind
    if location_duration > 1500 do
      Logger.debug(
        "[Tracker Pool] Skipping info update due to location lag (#{location_duration}ms)"
      )

      :telemetry.execute(
        [:wanderer_app, :tracker_pool, :info_skipped],
        %{count: 1},
        %{pool_uuid: state.uuid, reason: :location_lag}
      )

      {:noreply, state}
    else
      try do
        characters
        |> Task.async_stream(
          fn character_id ->
            WandererApp.Character.Tracker.update_info(character_id)
          end,
          timeout: :timer.seconds(15),
          max_concurrency: @standard_concurrency,
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
        max_concurrency: @standard_concurrency,
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
end
