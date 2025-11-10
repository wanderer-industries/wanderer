defmodule WandererApp.Map.MapPool do
  @moduledoc false
  use GenServer, restart: :transient

  require Logger

  alias WandererApp.Map.Server

  defstruct [
    :map_ids,
    :uuid
  ]

  @name __MODULE__
  @cache :map_pool_cache
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry

  @garbage_collection_interval :timer.hours(12)
  @systems_cleanup_timeout :timer.minutes(30)
  @characters_cleanup_timeout :timer.minutes(5)
  @connections_cleanup_timeout :timer.minutes(5)
  @backup_state_timeout :timer.minutes(1)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  def start_link(map_ids) do
    uuid = UUID.uuid1()

    GenServer.start_link(
      @name,
      {uuid, map_ids},
      name: Module.concat(__MODULE__, uuid)
    )
  end

  @impl true
  def init({uuid, map_ids}) do
    {:ok, _} = Registry.register(@unique_registry, Module.concat(__MODULE__, uuid), map_ids)
    {:ok, _} = Registry.register(@registry, __MODULE__, uuid)

    map_ids
    |> Enum.each(fn id ->
      Cachex.put(@cache, id, uuid)
    end)

    state =
      %{
        uuid: uuid,
        map_ids: []
      }
      |> new()

    {:ok, state, {:continue, {:start, map_ids}}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  @impl true
  def handle_continue({:start, map_ids}, state) do
    Logger.info("#{@name} started")

    map_ids
    |> Enum.each(fn map_id ->
      GenServer.cast(self(), {:start_map, map_id})
    end)

    Process.send_after(self(), :backup_state, @backup_state_timeout)
    Process.send_after(self(), :cleanup_systems, 15_000)
    Process.send_after(self(), :cleanup_characters, @characters_cleanup_timeout)
    Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)
    # Start message queue monitoring
    Process.send_after(self(), :monitor_message_queue, :timer.seconds(30))

    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop, state), do: {:stop, :normal, state}

  @impl true
  def handle_cast({:start_map, map_id}, %{map_ids: map_ids, uuid: uuid} = state) do
    if map_id not in map_ids do
      Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
        [map_id | r_map_ids]
      end)

      Cachex.put(@cache, map_id, uuid)

      map_id
      |> WandererApp.Map.get_map_state!()
      |> Server.Impl.start_map()

      {:noreply, %{state | map_ids: [map_id | map_ids]}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(
        {:stop_map, map_id},
        %{map_ids: map_ids, uuid: uuid} = state
      ) do
    Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
      r_map_ids |> Enum.reject(fn id -> id == map_id end)
    end)

    Cachex.del(@cache, map_id)

    map_id
    |> Server.Impl.stop_map()

    {:noreply, %{state | map_ids: map_ids |> Enum.reject(fn id -> id == map_id end)}}
  end

  @impl true
  def handle_call(:error, _, state), do: {:stop, :error, :ok, state}

  @impl true
  def handle_info(:backup_state, %{map_ids: map_ids} = state) do
    Process.send_after(self(), :backup_state, @backup_state_timeout)

    try do
      map_ids
      |> Task.async_stream(
        fn map_id ->
          {:ok, _map_state} = Server.Impl.save_map_state(map_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.minutes(1)
      )
      |> Enum.each(fn _result -> :ok end)
    rescue
      e ->
        Logger.error("""
        [Map Pool] backup_state => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_systems, %{map_ids: map_ids} = state) do
    Process.send_after(self(), :cleanup_systems, @systems_cleanup_timeout)

    try do
      map_ids
      |> Task.async_stream(
        fn map_id ->
          Server.Impl.cleanup_systems(map_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.minutes(1)
      )
      |> Enum.each(fn _result -> :ok end)
    rescue
      e ->
        Logger.error("""
        [Map Pool] cleanup_systems => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_connections, %{map_ids: map_ids} = state) do
    Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)

    try do
      map_ids
      |> Task.async_stream(
        fn map_id ->
          Server.Impl.cleanup_connections(map_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.minutes(1)
      )
      |> Enum.each(fn _result -> :ok end)
    rescue
      e ->
        Logger.error("""
        [Map Pool] cleanup_connections => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_characters, %{map_ids: map_ids} = state) do
    Process.send_after(self(), :cleanup_characters, @characters_cleanup_timeout)

    try do
      map_ids
      |> Task.async_stream(
        fn map_id ->
          Server.Impl.cleanup_characters(map_id)
        end,
        max_concurrency: System.schedulers_online() * 4,
        on_timeout: :kill_task,
        timeout: :timer.minutes(1)
      )
      |> Enum.each(fn _result -> :ok end)
    rescue
      e ->
        Logger.error("""
        [Map Pool] cleanup_characters => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:garbage_collect, %{map_ids: map_ids, uuid: uuid} = state) do
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)

    try do
      map_ids
      |> Enum.each(fn map_id ->
        # presence_character_ids =
        #   WandererApp.Cache.lookup!("map_#{map_id}:presence_character_ids", [])

        # if presence_character_ids |> Enum.empty?() do
        Logger.info(
          "#{uuid}: No more characters present on: #{map_id}, shutting down map server..."
        )

        GenServer.cast(self(), {:stop_map, map_id})
        # end
      end)
    rescue
      e ->
        Logger.error(Exception.message(e))
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
        Logger.error("#{__MODULE__} failed to process: #{inspect(error)}")
        :ok

      _ ->
        :ok
    end

    {:noreply, state}
  end

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

  def handle_info(event, state) do
    Server.Impl.handle_event(event)

    {:noreply, state}
  end

  defp monitor_message_queue(state) do
    try do
      {_, message_queue_len} = Process.info(self(), :message_queue_len)
      {_, memory} = Process.info(self(), :memory)

      # Alert on high message queue
      if message_queue_len > 50 do
        Logger.warning("GENSERVER_QUEUE_HIGH: Map pool message queue buildup",
          pool_id: state.uuid,
          message_queue_length: message_queue_len,
          memory_bytes: memory,
          pool_length: length(state.map_ids)
        )

        # Emit telemetry
        :telemetry.execute(
          [:wanderer_app, :map, :map_pool, :queue_buildup],
          %{
            message_queue_length: message_queue_len,
            memory_bytes: memory
          },
          %{
            pool_id: state.uuid,
            pool_length: length(state.map_ids)
          }
        )
      end
    rescue
      error ->
        Logger.debug("Failed to monitor message queue: #{inspect(error)}")
    end
  end
end
