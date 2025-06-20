defmodule WandererApp.Test.MapServerMock do
  @moduledoc """
  Mock implementation for map server state management in tests.

  This module provides a lightweight replacement for the GenServer-based map server
  that allows tests to run without starting actual map processes.
  """

  @doc """
  Initializes mock map cache for testing.
  This ensures that map-related operations have the expected cache structure.
  """
  def init_map_cache(map_id) do
    map_struct = %{
      map_id: map_id,
      connections: %{},
      systems: %{}
    }

    Cachex.put(:map_cache, map_id, map_struct)
    :ok
  end

  @doc """
  Mocks map server "started" state for testing.
  This prevents tests from trying to start actual GenServer processes.
  """
  def mark_map_started(map_id) do
    WandererApp.Cache.insert("map_#{map_id}:started", true)
    :ok
  end

  @doc """
  Complete mock setup for a map including cache and server state.
  """
  def setup_map_mock(map_id) do
    with :ok <- init_map_cache(map_id),
         :ok <- mark_map_started(map_id) do
      :ok
    end
  end

  @doc """
  Cleanup mock data for a map.
  """
  def cleanup_map_mock(map_id) do
    Cachex.del(:map_cache, map_id)
    WandererApp.Cache.take("map_#{map_id}:started")
    :ok
  end

  @doc """
  Mock adding a system to a map.
  Updates the map cache with system data without requiring GenServer.
  """
  def add_system_to_map(map_id, system) do
    case Cachex.get(:map_cache, map_id) do
      {:ok, map} when is_map(map) ->
        system_data = %{
          id: system.id,
          map_id: system.map_id,
          solar_system_id: system.solar_system_id,
          name: system.name,
          position_x: system.position_x,
          position_y: system.position_y,
          tag: system.tag,
          description: system.description,
          locked: system.locked || false,
          labels: system.labels || [],
          visible: system.visible
        }

        updated_systems = Map.put(map.systems || %{}, system.solar_system_id, system_data)
        updated_map = Map.put(map, :systems, updated_systems)
        Cachex.put(:map_cache, map_id, updated_map)
        :ok

      _ ->
        # If map not in cache, initialize it with the system
        setup_map_mock(map_id)
        add_system_to_map(map_id, system)
    end
  end

  @doc """
  Mock adding a connection to a map.
  Updates the map cache with connection data without requiring GenServer.
  """
  def add_connection_to_map(map_id, connection) do
    case Cachex.get(:map_cache, map_id) do
      {:ok, map} when is_map(map) ->
        connection_key = "#{connection.solar_system_source}_#{connection.solar_system_target}"

        connection_data = %{
          id: connection.id,
          map_id: connection.map_id,
          solar_system_source: connection.solar_system_source,
          solar_system_target: connection.solar_system_target,
          type: connection.type,
          ship_size_type: connection.ship_size_type,
          mass_status: connection.mass_status || 0,
          time_status: connection.time_status || 0,
          locked: connection.locked || false,
          custom_info: connection.custom_info
        }

        updated_connections = Map.put(map.connections || %{}, connection_key, connection_data)
        updated_map = Map.put(map, :connections, updated_connections)
        Cachex.put(:map_cache, map_id, updated_map)
        :ok

      _ ->
        # If map not in cache, initialize it with the connection
        setup_map_mock(map_id)
        add_connection_to_map(map_id, connection)
    end
  end

  @doc """
  Mock removing a system from a map.
  """
  def remove_system_from_map(map_id, solar_system_id) do
    case Cachex.get(:map_cache, map_id) do
      {:ok, map} when is_map(map) ->
        updated_systems = Map.delete(map.systems || %{}, solar_system_id)
        updated_map = Map.put(map, :systems, updated_systems)
        Cachex.put(:map_cache, map_id, updated_map)
        :ok

      _ ->
        {:error, :map_not_found}
    end
  end

  @doc """
  Mock removing a connection from a map.
  """
  def remove_connection_from_map(map_id, source_id, target_id) do
    case Cachex.get(:map_cache, map_id) do
      {:ok, map} when is_map(map) ->
        connection_key = "#{source_id}_#{target_id}"
        updated_connections = Map.delete(map.connections || %{}, connection_key)
        updated_map = Map.put(map, :connections, updated_connections)
        Cachex.put(:map_cache, map_id, updated_map)
        :ok

      _ ->
        {:error, :map_not_found}
    end
  end

  @doc """
  Get the current mocked state of a map.
  """
  def get_map_state(map_id) do
    case Cachex.get(:map_cache, map_id) do
      {:ok, map} -> {:ok, map}
      _ -> {:error, :map_not_found}
    end
  end

  @doc """
  Mock character tracking for a map.
  """
  def track_character_location(map_id, character_id, solar_system_id) do
    key = "map_#{map_id}:character_#{character_id}:location"
    WandererApp.Cache.insert(key, solar_system_id)
    :ok
  end

  @doc """
  Mock getting tracked characters for a system.
  """
  def get_system_characters(_map_id, _solar_system_id) do
    # In a real implementation, this would query all tracked characters
    # For testing, we'll return an empty list or mock data as needed
    []
  end

  @doc """
  Check if map server is mocked as started.
  """
  def is_map_started?(map_id) do
    case WandererApp.Cache.lookup("map_#{map_id}:started") do
      {:ok, true} -> true
      _ -> false
    end
  end
end
