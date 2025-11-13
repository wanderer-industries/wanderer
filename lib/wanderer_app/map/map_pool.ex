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
  @map_pool_limit 20

  @garbage_collection_interval :timer.hours(4)
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

    # Start maps synchronously and accumulate state changes
    new_state =
      map_ids
      |> Enum.reduce(state, fn map_id, current_state ->
        case do_start_map(map_id, current_state) do
          {:ok, updated_state} ->
            updated_state

          {:error, reason} ->
            Logger.error("[Map Pool] Failed to start map #{map_id}: #{reason}")
            current_state
        end
      end)

    # Schedule periodic tasks
    Process.send_after(self(), :backup_state, @backup_state_timeout)
    Process.send_after(self(), :cleanup_systems, 15_000)
    Process.send_after(self(), :cleanup_characters, @characters_cleanup_timeout)
    Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)
    # Start message queue monitoring
    Process.send_after(self(), :monitor_message_queue, :timer.seconds(30))

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:stop, state), do: {:stop, :normal, state}

  @impl true
  def handle_call({:start_map, map_id}, _from, %{map_ids: map_ids, uuid: uuid} = state) do
    # Enforce capacity limit to prevent pool overload due to race conditions
    if length(map_ids) >= @map_pool_limit do
      Logger.warning(
        "[Map Pool #{uuid}] Pool at capacity (#{length(map_ids)}/#{@map_pool_limit}), " <>
          "rejecting map #{map_id} and triggering new pool creation"
      )

      # Trigger a new pool creation attempt asynchronously
      # This allows the system to create a new pool for this map
      spawn(fn ->
        WandererApp.Map.MapPoolDynamicSupervisor.start_map(map_id)
      end)

      {:reply, :ok, state}
    else
      case do_start_map(map_id, state) do
        {:ok, new_state} ->
          {:reply, :ok, new_state}

        {:error, _reason} ->
          # Error already logged in do_start_map
          {:reply, :ok, state}
      end
    end
  end

  @impl true
  def handle_call(
        {:stop_map, map_id},
        _from,
        state
      ) do
    case do_stop_map(map_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp do_start_map(map_id, %{map_ids: map_ids, uuid: uuid} = state) do
    if map_id in map_ids do
      # Map already started
      {:ok, state}
    else
      # Track what operations succeeded for potential rollback
      completed_operations = []

      try do
        # Step 1: Update Registry (most critical, do first)
        registry_result =
          Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
            [map_id | r_map_ids]
          end)

        completed_operations = [:registry | completed_operations]

        case registry_result do
          {new_value, _old_value} when is_list(new_value) ->
            :ok

          :error ->
            raise "Failed to update registry for pool #{uuid}"
        end

        # Step 2: Add to cache
        case Cachex.put(@cache, map_id, uuid) do
          {:ok, _} ->
            completed_operations = [:cache | completed_operations]

          {:error, reason} ->
            raise "Failed to add to cache: #{inspect(reason)}"
        end

        # Step 3: Start the map server
        map_id
        |> WandererApp.Map.get_map_state!()
        |> Server.Impl.start_map()

        completed_operations = [:map_server | completed_operations]

        # Step 4: Update GenServer state (last, as this is in-memory and fast)
        new_state = %{state | map_ids: [map_id | map_ids]}

        Logger.debug("[Map Pool] Successfully started map #{map_id} in pool #{uuid}")
        {:ok, new_state}
      rescue
        e ->
          Logger.error("""
          [Map Pool] Failed to start map #{map_id} (completed: #{inspect(completed_operations)}): #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

          # Attempt rollback of completed operations
          rollback_start_map_operations(map_id, uuid, completed_operations)

          {:error, Exception.message(e)}
      end
    end
  end

  defp rollback_start_map_operations(map_id, uuid, completed_operations) do
    Logger.warning("[Map Pool] Attempting to rollback start_map operations for #{map_id}")

    # Rollback in reverse order
    if :map_server in completed_operations do
      Logger.debug("[Map Pool] Rollback: Stopping map server for #{map_id}")

      try do
        Server.Impl.stop_map(map_id)
      rescue
        e ->
          Logger.error("[Map Pool] Rollback failed to stop map server: #{Exception.message(e)}")
      end
    end

    if :cache in completed_operations do
      Logger.debug("[Map Pool] Rollback: Removing #{map_id} from cache")

      case Cachex.del(@cache, map_id) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.error("[Map Pool] Rollback failed for cache: #{inspect(reason)}")
      end
    end

    if :registry in completed_operations do
      Logger.debug("[Map Pool] Rollback: Removing #{map_id} from registry")

      try do
        Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
          r_map_ids |> Enum.reject(fn id -> id == map_id end)
        end)
      rescue
        e ->
          Logger.error("[Map Pool] Rollback failed for registry: #{Exception.message(e)}")
      end
    end
  end

  defp do_stop_map(map_id, %{map_ids: map_ids, uuid: uuid} = state) do
    # Track what operations succeeded for potential rollback
    completed_operations = []

    try do
      # Step 1: Update Registry (most critical, do first)
      registry_result =
        Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
          r_map_ids |> Enum.reject(fn id -> id == map_id end)
        end)

      completed_operations = [:registry | completed_operations]

      case registry_result do
        {new_value, _old_value} when is_list(new_value) ->
          :ok

        :error ->
          raise "Failed to update registry for pool #{uuid}"
      end

      # Step 2: Delete from cache
      case Cachex.del(@cache, map_id) do
        {:ok, _} ->
          completed_operations = [:cache | completed_operations]

        {:error, reason} ->
          raise "Failed to delete from cache: #{inspect(reason)}"
      end

      # Step 3: Stop the map server (clean up all map resources)
      map_id
      |> Server.Impl.stop_map()

      completed_operations = [:map_server | completed_operations]

      # Step 4: Update GenServer state (last, as this is in-memory and fast)
      new_state = %{state | map_ids: map_ids |> Enum.reject(fn id -> id == map_id end)}

      Logger.debug("[Map Pool] Successfully stopped map #{map_id} from pool #{uuid}")
      {:ok, new_state}
    rescue
      e ->
        Logger.error("""
        [Map Pool] Failed to stop map #{map_id} (completed: #{inspect(completed_operations)}): #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)

        # Attempt rollback of completed operations
        rollback_stop_map_operations(map_id, uuid, completed_operations)

        {:error, Exception.message(e)}
    end
  end

  defp rollback_stop_map_operations(map_id, uuid, completed_operations) do
    Logger.warning("[Map Pool] Attempting to rollback stop_map operations for #{map_id}")

    # Rollback in reverse order
    if :cache in completed_operations do
      Logger.debug("[Map Pool] Rollback: Re-adding #{map_id} to cache")

      case Cachex.put(@cache, map_id, uuid) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.error("[Map Pool] Rollback failed for cache: #{inspect(reason)}")
      end
    end

    if :registry in completed_operations do
      Logger.debug("[Map Pool] Rollback: Re-adding #{map_id} to registry")

      try do
        Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
          if map_id in r_map_ids do
            r_map_ids
          else
            [map_id | r_map_ids]
          end
        end)
      rescue
        e ->
          Logger.error("[Map Pool] Rollback failed for registry: #{Exception.message(e)}")
      end
    end

    # Note: We don't rollback map_server stop as Server.Impl.stop_map() is idempotent
    # and the cleanup operations are safe to leave in a "stopped" state
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
      # Process each map and accumulate state changes
      new_state =
        map_ids
        |> Enum.reduce(state, fn map_id, current_state ->
          presence_character_ids =
            WandererApp.Cache.lookup!("map_#{map_id}:presence_character_ids", [])

          if presence_character_ids |> Enum.empty?() do
            Logger.info(
              "#{uuid}: No more characters present on: #{map_id}, shutting down map server..."
            )

            case do_stop_map(map_id, current_state) do
              {:ok, updated_state} ->
                Logger.debug("#{uuid}: Successfully stopped map #{map_id}")
                updated_state

              {:error, reason} ->
                Logger.error("#{uuid}: Failed to stop map #{map_id}: #{reason}")
                current_state
            end
          else
            current_state
          end
        end)

      {:noreply, new_state}
    rescue
      e ->
        Logger.error("#{uuid}: Garbage collection error: #{Exception.message(e)}")
        {:noreply, state}
    end
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
    try do
      Server.Impl.handle_event(event)
    rescue
      e ->
        Logger.error("""
        [Map Pool] handle_info => exception: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)

        ErrorTracker.report(e, __STACKTRACE__)
    end

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
