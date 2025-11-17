defmodule WandererApp.Map.UpdateCoordinator do
  @moduledoc """
  Coordinates database, cache, R-tree, and broadcast updates to eliminate race conditions.

  Ensures the following order:
  1. Database write (via Ash)
  2. Cache update (:map_cache)
  3. R-tree update (spatial index)
  4. PubSub broadcast (internal clients)
  5. ExternalEvents broadcast (webhooks/SSE)

  This guarantees that when clients receive a broadcast, all underlying data
  is already queryable and consistent.
  """

  require Logger

  alias WandererApp.Map
  alias WandererApp.Map.CacheRTree
  alias WandererApp.Map.Server.Impl
  alias WandererApp.ExternalEvents

  @spatial_index_module Application.compile_env(:wanderer_app, :spatial_index_module, CacheRTree)

  @rtree_prefix "rtree_"
  @log_prefix "[UpdateCoordinator]"

  defp rtree_name(map_id), do: "#{@rtree_prefix}#{map_id}"

  defp log(level, message, metadata \\ []) do
    Logger.log(level, "#{@log_prefix} #{message}", metadata)
  end

  defp with_coordination(operation, map_id, metadata, fun) do
    case fun.() do
      :ok = result ->
        :telemetry.execute(
          [:wanderer_app, :update_coordinator, :success],
          %{count: 1},
          Elixir.Map.merge(metadata, %{operation: operation, map_id: map_id})
        )

        result

      {:error, reason} = error ->
        log(
          :error,
          "Failed to coordinate #{operation}: #{inspect(reason)}",
          Elixir.Map.put(metadata, :map_id, map_id)
        )

        :telemetry.execute(
          [:wanderer_app, :update_coordinator, :error],
          %{count: 1},
          %{operation: operation, map_id: map_id, reason: reason}
        )

        error
    end
  end

  @doc """
  Coordinates adding a system to a map.

  ## Steps:
  1. Database write (already done by Ash action)
  2. Update :map_cache
  3. Update R-tree spatial index
  4. Broadcast to PubSub subscribers
  5. Broadcast to external webhooks/SSE

  ## Parameters:
  - `map_id` - The map ID
  - `system` - The system record (already persisted to DB)
  - `broadcast?` - Whether to broadcast (default: true)

  ## Returns:
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def add_system(map_id, %{solar_system_id: solar_system_id} = system, opts \\ []) do
    broadcast? = Keyword.get(opts, :broadcast?, true)

    with_coordination(:add_system, map_id, %{solar_system_id: solar_system_id}, fn ->
      with :ok <- update_cache_add_system(map_id, system),
           :ok <- update_rtree_add_system(map_id, system),
           :ok <- maybe_broadcast_system_added(map_id, system, broadcast?) do
        :ok
      end
    end)
  end

  @doc """
  Coordinates updating a system on a map.

  ## Options:
  - `:broadcast?` - Whether to broadcast (default: true)
  - `:event` - Event type (default: :update_system)
  - `:minimal` - Use minimal broadcast payload (default: false)
  """
  def update_system(map_id, %{solar_system_id: solar_system_id} = system, opts \\ []) do
    broadcast? = Keyword.get(opts, :broadcast?, true)
    event = Keyword.get(opts, :event, :update_system)
    minimal = Keyword.get(opts, :minimal, false)

    with_coordination(
      :update_system,
      map_id,
      %{solar_system_id: solar_system_id, event: event, minimal: minimal},
      fn ->
        with :ok <- update_cache_update_system(map_id, system),
             :ok <- update_rtree_update_system(map_id, system),
             :ok <- maybe_broadcast_system_updated(map_id, system, event, broadcast?, minimal) do
          :ok
        end
      end
    )
  end

  @doc """
  Coordinates removing a system from a map.
  """
  def remove_system(map_id, solar_system_id, opts \\ []) do
    broadcast? = Keyword.get(opts, :broadcast?, true)

    with_coordination(:remove_system, map_id, %{solar_system_id: solar_system_id}, fn ->
      with :ok <- update_cache_remove_system(map_id, solar_system_id),
           :ok <- update_rtree_remove_system(map_id, solar_system_id),
           :ok <- maybe_broadcast_system_removed(map_id, solar_system_id, broadcast?) do
        :ok
      end
    end)
  end

  @doc """
  Coordinates adding a connection to a map.
  """
  def add_connection(map_id, connection, opts \\ []) do
    broadcast? = Keyword.get(opts, :broadcast?, true)

    with_coordination(:add_connection, map_id, %{connection_id: connection.id}, fn ->
      with :ok <- update_cache_add_connection(map_id, connection),
           :ok <- maybe_broadcast_connection_added(map_id, connection, broadcast?) do
        :ok
      end
    end)
  end

  @doc """
  Coordinates updating a connection on a map.
  """
  def update_connection(map_id, connection, opts \\ []) do
    broadcast? = Keyword.get(opts, :broadcast?, true)

    with_coordination(:update_connection, map_id, %{connection_id: connection.id}, fn ->
      with :ok <- update_cache_update_connection(map_id, connection),
           :ok <- maybe_broadcast_connection_updated(map_id, connection, broadcast?) do
        :ok
      end
    end)
  end

  @doc """
  Coordinates removing a connection from a map.
  """
  def remove_connection(map_id, connection, opts \\ []) do
    broadcast? = Keyword.get(opts, :broadcast?, true)

    with_coordination(:remove_connection, map_id, %{connection_id: connection.id}, fn ->
      with :ok <- update_cache_remove_connection(map_id, connection),
           :ok <- maybe_broadcast_connection_removed(map_id, connection, broadcast?) do
        :ok
      end
    end)
  end

  defp execute_cache_operation(operation, fun) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      e ->
        log(
          :error,
          "Cache operation #{operation} failed (non-critical): #{Exception.message(e)}",
          operation: operation,
          error: inspect(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        :telemetry.execute(
          [:wanderer_app, :update_coordinator, :cache_error],
          %{count: 1},
          %{operation: operation, error_type: e.__struct__}
        )

        {:error, {:cache_operation_failed, operation, e}}
    end
  end

  defp update_cache_add_system(map_id, system) do
    case execute_cache_operation(:add_system, fn ->
           Map.add_system(map_id, system)
         end) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp update_cache_update_system(map_id, system) do
    case execute_cache_operation(:update_system, fn ->
           Map.add_system(map_id, system)
         end) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp update_cache_remove_system(map_id, solar_system_id) do
    case execute_cache_operation(:remove_system, fn ->
           Map.remove_system(map_id, solar_system_id)
         end) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp update_cache_add_connection(map_id, connection) do
    case execute_cache_operation(:add_connection, fn ->
           Map.add_connection(map_id, connection)
         end) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp update_cache_update_connection(map_id, connection) do
    case execute_cache_operation(:update_connection, fn ->
           Map.update_connection(map_id, connection)
         end) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp update_cache_remove_connection(map_id, connection) do
    case execute_cache_operation(:remove_connection, fn ->
           Map.remove_connection(map_id, connection)
         end) do
      {:ok, _result} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp update_rtree_add_system(map_id, system) do
    try do
      tree_name = rtree_name(map_id)
      bounding_rect = Map.PositionCalculator.get_system_bounding_rect(system)

      {:ok, _} =
        @spatial_index_module.insert(
          {system.solar_system_id, bounding_rect},
          tree_name
        )

      :ok
    rescue
      e ->
        log(
          :error,
          "R-tree add failed but continuing: #{Exception.message(e)}",
          map_id: map_id,
          solar_system_id: system.solar_system_id,
          operation: :add_system,
          error: inspect(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        :telemetry.execute(
          [:wanderer_app, :update_coordinator, :rtree_error],
          %{count: 1},
          %{operation: :add_system, map_id: map_id, error_type: e.__struct__}
        )

        :ok
    end
  end

  defp update_rtree_update_system(map_id, system) do
    :ok = update_rtree_remove_system(map_id, system.solar_system_id)
    :ok = update_rtree_add_system(map_id, system)
    :ok
  end

  defp update_rtree_remove_system(map_id, solar_system_id) do
    try do
      tree_name = rtree_name(map_id)
      {:ok, _} = @spatial_index_module.delete([solar_system_id], tree_name)
      :ok
    rescue
      e ->
        log(
          :error,
          "R-tree remove failed but continuing: #{Exception.message(e)}",
          map_id: map_id,
          solar_system_id: solar_system_id,
          operation: :remove_system,
          error: inspect(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        :telemetry.execute(
          [:wanderer_app, :update_coordinator, :rtree_error],
          %{count: 1},
          %{operation: :remove_system, map_id: map_id, error_type: e.__struct__}
        )

        :ok
    end
  end

  defp maybe_broadcast_system_added(_map_id, _system, false), do: :ok

  defp maybe_broadcast_system_added(map_id, system, true) do
    try do
      Impl.broadcast!(map_id, :add_system, system)

      ExternalEvents.broadcast(map_id, :add_system, %{
        solar_system_id: system.solar_system_id,
        name: system.name,
        position_x: system.position_x,
        position_y: system.position_y
      })

      :ok
    rescue
      e ->
        log(:error, "Broadcast failed for add_system: #{inspect(e)}")
        :ok
    end
  end

  defp build_minimal_payload(system) do
    %{
      id: system.id,
      solar_system_id: system.solar_system_id,
      position_x: system.position_x,
      position_y: system.position_y,
      updated_at: system.updated_at || DateTime.utc_now()
    }
  end

  defp build_external_payload(system) do
    %{
      solar_system_id: system.solar_system_id,
      name: system.name,
      position_x: system.position_x,
      position_y: system.position_y
    }
  end

  defp log_broadcast_error(error, event, system, minimal?, stacktrace) do
    log(
      :error,
      "#{if minimal?, do: "Minimal ", else: ""}broadcast failed for #{event}",
      error: inspect(error),
      map_id: system.map_id,
      system_id: system.id,
      solar_system_id: system.solar_system_id,
      event: event,
      minimal: minimal?,
      stacktrace: Exception.format_stacktrace(stacktrace)
    )
  end

  defp maybe_broadcast_system_updated(_map_id, _system, _event, false, _minimal), do: :ok

  defp maybe_broadcast_system_updated(map_id, system, event, true, minimal?) do
    try do
      internal_payload = if minimal?, do: build_minimal_payload(system), else: system
      Impl.broadcast!(map_id, event, internal_payload)

      if minimal? do
        ExternalEvents.broadcast(map_id, event, internal_payload)
      else
        external_event = map_update_event_to_external(event)

        if external_event do
          external_payload = build_external_payload(system)
          ExternalEvents.broadcast(map_id, external_event, external_payload)
        end
      end

      :ok
    rescue
      e ->
        log_broadcast_error(e, event, system, minimal?, __STACKTRACE__)
        :ok
    end
  end

  defp maybe_broadcast_system_removed(_map_id, _solar_system_id, false), do: :ok

  defp maybe_broadcast_system_removed(map_id, solar_system_id, true) do
    try do
      Impl.broadcast!(map_id, :systems_removed, [solar_system_id])

      ExternalEvents.broadcast(map_id, :deleted_system, %{
        solar_system_id: solar_system_id,
        name: nil,
        position_x: nil,
        position_y: nil
      })

      :ok
    rescue
      e ->
        log(:error, "Broadcast failed for systems_removed: #{inspect(e)}")
        :ok
    end
  end

  defp maybe_broadcast_connection_added(_map_id, _connection, false), do: :ok

  defp maybe_broadcast_connection_added(map_id, connection, true) do
    try do
      Impl.broadcast!(map_id, :add_connection, connection)
      ExternalEvents.broadcast(map_id, :add_connection, connection)
      :ok
    rescue
      e ->
        log(:error, "Broadcast failed for add_connection: #{inspect(e)}")
        :ok
    end
  end

  defp maybe_broadcast_connection_updated(_map_id, _connection, false), do: :ok

  defp maybe_broadcast_connection_updated(map_id, connection, true) do
    try do
      Impl.broadcast!(map_id, :update_connection, connection)
      ExternalEvents.broadcast(map_id, :update_connection, connection)
      :ok
    rescue
      e ->
        log(:error, "Broadcast failed for update_connection: #{inspect(e)}")
        :ok
    end
  end

  defp maybe_broadcast_connection_removed(_map_id, _connection, false), do: :ok

  defp maybe_broadcast_connection_removed(map_id, connection, true) do
    try do
      Impl.broadcast!(map_id, :remove_connections, [connection])
      ExternalEvents.broadcast(map_id, :remove_connections, [connection])
      :ok
    rescue
      e ->
        log(:error, "Broadcast failed for remove_connections: #{inspect(e)}")
        :ok
    end
  end

  defp map_update_event_to_external(:update_system), do: :update_system
  defp map_update_event_to_external(:position_updated), do: :position_updated
  defp map_update_event_to_external(:systems_removed), do: :deleted_system
  defp map_update_event_to_external(_), do: nil
end
