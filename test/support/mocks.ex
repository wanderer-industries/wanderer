defmodule Test.LoggerMock do
  # @behaviour WandererApp.Test.Logger

  def info(_message), do: :ok
  def debug(_message), do: :ok
  def error(_message), do: :ok
end

defmodule Test.PubSubMock do
  # @behaviour WandererApp.Test.PubSub

  def subscribe(_pubsub, _topic), do: :ok
  def broadcast(_pubsub, _topic, _message), do: :ok
  def broadcast!(_pubsub, _topic, _message), do: :ok
end

defmodule Test.DDRTMock do
  # @behaviour WandererApp.Test.DDRT

  def delete(_ids, _name), do: {:ok, %{}}
  def insert(_leaves, _name), do: {:ok, %{}}
  def update(_ids, _box, _name), do: {:ok, %{}}
end

defmodule Test.MapServerMock do
  @moduledoc """
  Mock implementation of WandererApp.Map.Server for testing.

  This mock bypasses the GenServer process requirements and actually creates
  database records to match the expected behavior.
  """

  # Initialize a map in the cache when systems are added
  defp ensure_map_in_cache(map_id) do
    case Cachex.get(:map_cache, map_id) do
      {:ok, nil} ->
        # Create a minimal map structure in cache
        map_struct = %{
          map_id: map_id,
          connections: %{},
          systems: %{}
        }

        Cachex.put(:map_cache, map_id, map_struct)

      _ ->
        :ok
    end
  end

  def add_system(map_id, system_info, _user_id, _character_id) do
    ensure_map_in_cache(map_id)

    # Create the system record in the database since operations expect it to exist after calling this
    system_id = system_info[:solar_system_id] || system_info["solar_system_id"]
    coords = system_info[:coordinates] || system_info["coordinates"] || %{}
    params = system_info[:params] || system_info["params"] || %{}

    # Check if system already exists
    case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
      {:ok, _existing_system} ->
        # System already exists, this should be counted as an update/skip
        {:error, "System already exists"}

      {:error, :not_found} ->
        # System doesn't exist, create it
        attrs = %{
          map_id: map_id,
          solar_system_id: system_id,
          position_x: coords[:x] || coords["x"] || params["x"] || params[:x] || 0,
          position_y: coords[:y] || coords["y"] || params["y"] || params[:y] || 0,
          name: "Test System #{system_id}",
          temporary_name: params["temporary_name"] || params[:temporary_name],
          status: 0
        }

        # Also add system to cache to support connection creation
        system_static_info = %{
          solar_system_id: system_id,
          solar_system_name: "Test System #{system_id}",
          system_class: 0,
          security: 0.5,
          region_id: 10_000_001,
          constellation_id: 20_000_001
        }

        Cachex.put(:system_static_info_cache, system_id, system_static_info)

        case Ash.create(WandererApp.Api.MapSystem, attrs) do
          {:ok, _system} -> :ok
          {:error, error} -> {:error, error}
        end
    end
  end

  def delete_system(map_id, %{solar_system_id: solar_system_id}, _user_id, _character_id) do
    # Delete a single system record from the database
    case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, solar_system_id) do
      {:ok, system} ->
        case Ash.destroy(system) do
          :ok -> :ok
          {:ok, _} -> :ok
          error -> error
        end

      _ ->
        {:error, :not_found}
    end
  end

  def delete_systems(map_id, solar_system_ids, _user_id, _character_id) do
    # Delete the system records from the database
    Enum.each(solar_system_ids, fn system_id ->
      case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
        {:ok, system} ->
          Ash.destroy(system)

        _ ->
          :ok
      end
    end)

    :ok
  end

  def add_connection(map_id, connection_info) do
    ensure_map_in_cache(map_id)

    # Create the connection record in the database
    attrs = %{
      map_id: map_id,
      solar_system_source: connection_info[:solar_system_source_id],
      solar_system_target: connection_info[:solar_system_target_id],
      type: connection_info[:type] || 0,
      ship_size_type: connection_info[:ship_size_type] || 1
    }

    case Ash.create(WandererApp.Api.MapConnection, attrs) do
      {:ok, connection} ->
        # Update the cache with the connection
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
              mass_status: connection.mass_status,
              time_status: connection.time_status
            }

            updated_connections = Map.put(map.connections || %{}, connection_key, connection_data)
            updated_map = Map.put(map, :connections, updated_connections)
            Cachex.put(:map_cache, map_id, updated_map)

          _ ->
            :ok
        end

        :ok

      {:error, _error} ->
        # Continue even if connection already exists
        :ok
    end
  end

  def delete_connection(map_id, connection_info) do
    # Delete the connection record from the database
    source_id = connection_info.solar_system_source_id
    target_id = connection_info.solar_system_target_id

    # Find and delete the connection
    case WandererApp.MapConnectionRepo.get_by_locations(map_id, source_id, target_id) do
      {:ok, connections} when is_list(connections) ->
        Enum.each(connections, fn conn ->
          Ash.destroy!(conn)
        end)

        # Also update the cache to remove the connection
        case Cachex.get(:map_cache, map_id) do
          {:ok, map} when is_map(map) ->
            connection_key = "#{source_id}_#{target_id}"
            updated_connections = Map.delete(map.connections || %{}, connection_key)
            updated_map = Map.put(map, :connections, updated_connections)
            Cachex.put(:map_cache, map_id, updated_map)

          _ ->
            :ok
        end

        :ok

      _ ->
        :ok
    end
  end

  def update_system(map_id, update_info, _user_id, _character_id) do
    # Generic update system method that handles all types of updates
    system_id = update_info[:solar_system_id] || update_info["solar_system_id"]
    update_attrs = update_info[:update_attrs] || update_info["update_attrs"] || %{}
    
    case WandererApp.MapSystemRepo.get_by_map_and_solar_system_id(map_id, system_id) do
      {:ok, system} ->
        case Ash.update(system, update_attrs) do
          {:ok, _updated} -> :ok
          error -> error
        end
        
      _ ->
        {:error, :not_found}
    end
  end

  def update_system_position(_map_id, _update) do
    :ok
  end

  def update_system_name(_map_id, _update) do
    :ok
  end

  def update_system_description(_map_id, _update) do
    :ok
  end

  def update_system_status(_map_id, _update) do
    :ok
  end

  def update_system_tag(_map_id, _update) do
    :ok
  end

  def update_system_locked(_map_id, _update) do
    :ok
  end

  def update_system_labels(_map_id, _update) do
    :ok
  end

  def map_pid(_map_id) do
    # Return a fake PID to satisfy is_pid checks
    self()
  end

  def map_pid!(_map_id) do
    # Return a fake PID instead of throwing
    self()
  end

  # Connection operations
  def update_connection_mass_status(map_id, update) do
    with {:ok, connections} <-
           WandererApp.MapConnectionRepo.get_by_locations(
             map_id,
             update.solar_system_source_id,
             update.solar_system_target_id
           ),
         [connection | _] <- connections do
      WandererApp.MapConnectionRepo.update_mass_status(connection, %{
        mass_status: update.mass_status
      })

      :ok
    else
      _ -> :ok
    end
  end

  def update_connection_ship_size_type(map_id, update) do
    with {:ok, connections} <-
           WandererApp.MapConnectionRepo.get_by_locations(
             map_id,
             update.solar_system_source_id,
             update.solar_system_target_id
           ),
         [connection | _] <- connections do
      WandererApp.MapConnectionRepo.update_ship_size_type(connection, %{
        ship_size_type: update.ship_size_type
      })

      :ok
    else
      _ -> :ok
    end
  end

  def update_connection_type(map_id, update) do
    with {:ok, connections} <-
           WandererApp.MapConnectionRepo.get_by_locations(
             map_id,
             update.solar_system_source_id,
             update.solar_system_target_id
           ),
         [connection | _] <- connections do
      WandererApp.MapConnectionRepo.update_type(connection, %{type: update.type})
      :ok
    else
      _ -> :ok
    end
  end

  def update_connection_time_status(map_id, update) do
    with {:ok, connections} <-
           WandererApp.MapConnectionRepo.get_by_locations(
             map_id,
             update.solar_system_source_id,
             update.solar_system_target_id
           ),
         [connection | _] <- connections do
      WandererApp.MapConnectionRepo.update_time_status(connection, %{
        time_status: update.time_status
      })

      :ok
    else
      _ -> :ok
    end
  end

  def update_system_temporary_name(_map_id, _update) do
    :ok
  end
end
