defmodule WandererApp.Map.MapPool do
  @moduledoc false
  use GenServer, restart: :transient

  require Logger

  alias WandererApp.Map.{MapPoolState, Server}

  defstruct [
    :map_ids,
    :uuid
  ]

  @name __MODULE__
  @cache :map_pool_cache
  @registry :map_pool_registry
  @unique_registry :unique_map_pool_registry
  @map_pool_limit 10

  @garbage_collection_interval :timer.hours(4)
  # Use very long timeouts in test environment to prevent background tasks from running during tests
  # This avoids database connection ownership errors when tests finish before async tasks complete
  @environment Application.compile_env(:wanderer_app, :environment)

  @systems_cleanup_timeout if @environment == :test,
                             do: :timer.hours(24),
                             else: :timer.minutes(30)
  @characters_cleanup_timeout if @environment == :test,
                                do: :timer.hours(24),
                                else: :timer.minutes(5)
  @connections_cleanup_timeout if @environment == :test,
                                 do: :timer.hours(24),
                                 else: :timer.minutes(5)
  @backup_state_timeout if @environment == :test,
                          do: :timer.hours(24),
                          else: :timer.minutes(1)

  def new(), do: __struct__()
  def new(args), do: __struct__(args)

  # Accept both {uuid, map_ids} tuple (from supervisor restart) and just map_ids (legacy)
  def start_link({uuid, map_ids}) when is_binary(uuid) and is_list(map_ids) do
    GenServer.start_link(
      @name,
      {uuid, map_ids},
      name: Module.concat(__MODULE__, uuid)
    )
  end

  # For backward compatibility - generate UUID if only map_ids provided
  def start_link(map_ids) when is_list(map_ids) do
    uuid = UUID.uuid1()

    GenServer.start_link(
      @name,
      {uuid, map_ids},
      name: Module.concat(__MODULE__, uuid)
    )
  end

  @impl true
  def init({uuid, map_ids}) do
    # Check for crash recovery - if we have previous state in ETS, merge it with new map_ids
    {final_map_ids, recovery_info} =
      case MapPoolState.get_pool_state(uuid) do
        {:ok, recovered_map_ids} ->
          # Merge and deduplicate map IDs
          merged = Enum.uniq(recovered_map_ids ++ map_ids)
          recovery_count = length(recovered_map_ids)

          Logger.info(
            "[Map Pool #{uuid}] Crash recovery detected: recovering #{recovery_count} maps",
            pool_uuid: uuid,
            recovered_maps: recovered_map_ids,
            new_maps: map_ids,
            total_maps: length(merged)
          )

          # Emit telemetry for crash recovery
          :telemetry.execute(
            [:wanderer_app, :map_pool, :recovery, :start],
            %{recovered_map_count: recovery_count, total_map_count: length(merged)},
            %{pool_uuid: uuid}
          )

          {merged, %{recovered: true, count: recovery_count}}

        {:error, :not_found} ->
          # Normal startup, no previous state to recover
          {map_ids, %{recovered: false}}
      end

    # Register with empty list - maps will be added as they're started in handle_continue
    {:ok, _} = Registry.register(@unique_registry, Module.concat(__MODULE__, uuid), [])
    {:ok, _} = Registry.register(@registry, __MODULE__, uuid)

    # Don't pre-populate cache - will be populated as maps start in handle_continue
    # This prevents duplicates when recovering

    state =
      %{
        uuid: uuid,
        map_ids: []
      }
      |> new()

    {:ok, state, {:continue, {:start, {final_map_ids, recovery_info}}}}
  end

  @impl true
  def terminate(reason, %{uuid: uuid} = _state) do
    # On graceful shutdown, clean up ETS state
    # On crash, keep ETS state for recovery
    case reason do
      :normal ->
        Logger.debug("[Map Pool #{uuid}] Graceful shutdown, cleaning up ETS state")
        MapPoolState.delete_pool_state(uuid)

      :shutdown ->
        Logger.debug("[Map Pool #{uuid}] Graceful shutdown, cleaning up ETS state")
        MapPoolState.delete_pool_state(uuid)

      {:shutdown, _} ->
        Logger.debug("[Map Pool #{uuid}] Graceful shutdown, cleaning up ETS state")
        MapPoolState.delete_pool_state(uuid)

      _ ->
        Logger.warning(
          "[Map Pool #{uuid}] Abnormal termination (#{inspect(reason)}), keeping ETS state for recovery"
        )

        # Keep ETS state for crash recovery
        :ok
    end

    :ok
  end

  @impl true
  def handle_continue({:start, {map_ids, recovery_info}}, state) do
    Logger.info("#{@name} started")

    # Track recovery statistics
    start_time = System.monotonic_time(:millisecond)
    initial_count = length(map_ids)

    # Start maps synchronously and accumulate state changes
    {new_state, failed_maps} =
      map_ids
      |> Enum.reduce({state, []}, fn map_id, {current_state, failed} ->
        case do_start_map(map_id, current_state) do
          {:ok, updated_state} ->
            {updated_state, failed}

          {:error, reason} ->
            Logger.error("[Map Pool] Failed to start map #{map_id}: #{reason}")

            # Emit telemetry for individual map recovery failure
            if recovery_info.recovered do
              :telemetry.execute(
                [:wanderer_app, :map_pool, :recovery, :map_failed],
                %{map_id: map_id},
                %{pool_uuid: state.uuid, reason: reason}
              )
            end

            {current_state, [map_id | failed]}
        end
      end)

    # Calculate final statistics
    end_time = System.monotonic_time(:millisecond)
    duration_ms = end_time - start_time
    successful_count = length(new_state.map_ids)
    failed_count = length(failed_maps)

    # Log and emit telemetry for recovery completion
    if recovery_info.recovered do
      Logger.info(
        "[Map Pool #{state.uuid}] Crash recovery completed: #{successful_count}/#{initial_count} maps recovered in #{duration_ms}ms",
        pool_uuid: state.uuid,
        recovered_count: successful_count,
        failed_count: failed_count,
        total_count: initial_count,
        duration_ms: duration_ms,
        failed_maps: failed_maps
      )

      :telemetry.execute(
        [:wanderer_app, :map_pool, :recovery, :complete],
        %{
          recovered_count: successful_count,
          failed_count: failed_count,
          duration_ms: duration_ms
        },
        %{pool_uuid: state.uuid}
      )
    end

    # Schedule periodic tasks
    Process.send_after(self(), :backup_state, @backup_state_timeout)
    Process.send_after(self(), :cleanup_systems, @systems_cleanup_timeout)
    Process.send_after(self(), :cleanup_characters, @characters_cleanup_timeout)
    Process.send_after(self(), :cleanup_connections, @connections_cleanup_timeout)
    Process.send_after(self(), :garbage_collect, @garbage_collection_interval)
    # Start message queue monitoring
    Process.send_after(self(), :monitor_message_queue, :timer.seconds(30))

    {:noreply, new_state}
  end

  @impl true
  def handle_continue({:init_map, map_id}, %{uuid: uuid} = state) do
    # Perform the actual map initialization asynchronously
    # This runs after the GenServer.call has already returned
    start_time = System.monotonic_time(:millisecond)

    try do
      # Initialize the map state and start the map server using extracted helper
      do_initialize_map_server(map_id)

      duration = System.monotonic_time(:millisecond) - start_time

      Logger.info("[Map Pool #{uuid}] Map #{map_id} initialized successfully in #{duration}ms")

      # Emit telemetry for slow initializations
      if duration > 5_000 do
        Logger.warning("[Map Pool #{uuid}] Slow map initialization: #{map_id} took #{duration}ms")

        :telemetry.execute(
          [:wanderer_app, :map_pool, :slow_init],
          %{duration_ms: duration},
          %{map_id: map_id, pool_uuid: uuid}
        )
      end

      {:noreply, state}
    rescue
      e ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.error("""
        [Map Pool #{uuid}] Failed to initialize map #{map_id} after #{duration}ms: #{Exception.message(e)}
        #{Exception.format_stacktrace(__STACKTRACE__)}
        """)

        # Rollback: Remove from state, registry, cache, and ETS using extracted helper
        new_state = do_unregister_map(map_id, uuid, state)

        # Emit telemetry for failed initialization
        :telemetry.execute(
          [:wanderer_app, :map_pool, :init_failed],
          %{duration_ms: duration},
          %{map_id: map_id, pool_uuid: uuid, reason: Exception.message(e)}
        )

        {:noreply, new_state}
    end
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
      # Check if map is already started or being initialized
      if map_id in map_ids do
        Logger.debug("[Map Pool #{uuid}] Map #{map_id} already in pool")
        {:reply, {:ok, :already_started}, state}
      else
        # Pre-register the map in registry and cache to claim ownership
        # This prevents race conditions where multiple pools try to start the same map
        registry_result =
          Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
            [map_id | r_map_ids]
          end)

        case registry_result do
          {_new_value, _old_value} ->
            # Add to cache
            Cachex.put(@cache, map_id, uuid)

            # Add to state
            new_state = %{state | map_ids: [map_id | map_ids]}

            # Persist state to ETS
            MapPoolState.save_pool_state(uuid, new_state.map_ids)

            Logger.debug("[Map Pool #{uuid}] Map #{map_id} queued for async initialization")

            # Return immediately and initialize asynchronously
            {:reply, {:ok, :initializing}, new_state, {:continue, {:init_map, map_id}}}

          :error ->
            Logger.error("[Map Pool #{uuid}] Failed to register map #{map_id} in registry")
            {:reply, {:error, :registration_failed}, state}
        end
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

  @impl true
  def handle_call(:error, _, state), do: {:stop, :error, :ok, state}

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

        case registry_result do
          {new_value, _old_value} when is_list(new_value) ->
            :ok

          :error ->
            raise "Failed to update registry for pool #{uuid}"
        end

        # Step 2: Add to cache
        case Cachex.put(@cache, map_id, uuid) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            raise "Failed to add to cache: #{inspect(reason)}"
        end

        # Step 3: Start the map server using extracted helper
        do_initialize_map_server(map_id)

        # Step 4: Update GenServer state (last, as this is in-memory and fast)
        new_state = %{state | map_ids: [map_id | map_ids]}

        # Step 5: Persist state to ETS for crash recovery
        MapPoolState.save_pool_state(uuid, new_state.map_ids)

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

      case registry_result do
        {new_value, _old_value} when is_list(new_value) ->
          :ok

        :error ->
          raise "Failed to update registry for pool #{uuid}"
      end

      # Step 2: Delete from cache
      case Cachex.del(@cache, map_id) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          raise "Failed to delete from cache: #{inspect(reason)}"
      end

      # Step 3: Stop the map server (clean up all map resources)
      map_id
      |> Server.Impl.stop_map()

      # Step 4: Update GenServer state (last, as this is in-memory and fast)
      new_state = %{state | map_ids: map_ids |> Enum.reject(fn id -> id == map_id end)}

      # Step 5: Persist state to ETS for crash recovery
      MapPoolState.save_pool_state(uuid, new_state.map_ids)

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

  # Helper function to initialize the map server (no state management)
  # This extracts the common map initialization logic used in both
  # synchronous (do_start_map) and asynchronous ({:init_map, map_id}) paths
  defp do_initialize_map_server(map_id) do
    map_id
    |> WandererApp.Map.get_map_state!()
    |> Server.Impl.start_map()
  end

  # Helper function to unregister a map from all tracking
  # Used for rollback when map initialization fails in the async path
  defp do_unregister_map(map_id, uuid, state) do
    # Remove from registry
    Registry.update_value(@unique_registry, Module.concat(__MODULE__, uuid), fn r_map_ids ->
      Enum.reject(r_map_ids, &(&1 == map_id))
    end)

    # Remove from cache
    Cachex.del(@cache, map_id)

    # Update state
    new_state = %{state | map_ids: Enum.reject(state.map_ids, &(&1 == map_id))}

    # Update ETS
    MapPoolState.save_pool_state(uuid, new_state.map_ids)

    new_state
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
  def handle_info(:backup_state, %{map_ids: map_ids, uuid: uuid} = state) do
    Process.send_after(self(), :backup_state, @backup_state_timeout)

    try do
      # Persist pool state to ETS
      MapPoolState.save_pool_state(uuid, map_ids)

      # Backup individual map states to database
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

  def handle_info(:map_deleted, %{map_ids: map_ids} = state) do
    # When a map is deleted, stop all maps in this pool that are deleted
    # This is a graceful shutdown triggered by user action
    Logger.info("[Map Pool #{state.uuid}] Received map_deleted event, stopping affected maps")

    # Check which of our maps were deleted and stop them
    new_state =
      map_ids
      |> Enum.reduce(state, fn map_id, current_state ->
        # Check if the map still exists in the database
        case WandererApp.MapRepo.get(map_id) do
          {:ok, %{deleted: true}} ->
            Logger.info("[Map Pool #{state.uuid}] Map #{map_id} was deleted, stopping it")

            case do_stop_map(map_id, current_state) do
              {:ok, updated_state} ->
                updated_state

              {:error, reason} ->
                Logger.error(
                  "[Map Pool #{state.uuid}] Failed to stop deleted map #{map_id}: #{reason}"
                )

                current_state
            end

          {:ok, _map} ->
            # Map still exists and is not deleted
            current_state

          {:error, _} ->
            # Map doesn't exist, should stop it
            Logger.info("[Map Pool #{state.uuid}] Map #{map_id} not found, stopping it")

            case do_stop_map(map_id, current_state) do
              {:ok, updated_state} ->
                updated_state

              {:error, reason} ->
                Logger.error(
                  "[Map Pool #{state.uuid}] Failed to stop missing map #{map_id}: #{reason}"
                )

                current_state
            end
        end
      end)

    {:noreply, new_state}
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
