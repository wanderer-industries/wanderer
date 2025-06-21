defmodule WandererApp.Test.MapTestHelpers do
  @moduledoc """
  Test helpers for setting up map server state in tests.

  This module provides high-level helpers that combine factory data creation
  with map server mocking to enable comprehensive integration testing without
  requiring actual GenServer processes.
  """

  alias WandererApp.Factory
  alias WandererApp.Test.MapServerMock

  @doc """
  Sets up a map with mocked server state.

  This helper:
  1. Creates a map using the factory
  2. Sets up the map server mock
  3. Returns the created map data

  Options:
  - `:with_systems` - number of systems to add (default: 0)
  - `:with_connections` - create connections between systems (default: false)
  - Other options are passed to the factory
  """
  def setup_map_with_mock(opts \\ []) do
    {with_systems, opts} = Keyword.pop(opts, :with_systems, 0)
    {with_connections, opts} = Keyword.pop(opts, :with_connections, false)

    # Create the map with authentication
    map_data = Factory.setup_test_map_with_auth(opts)

    # Add systems if requested
    systems =
      if with_systems > 0 do
        create_systems_for_map(map_data, with_systems)
      else
        []
      end

    # Add connections if requested
    connections =
      if with_connections && length(systems) > 1 do
        create_connections_for_map(map_data, systems)
      else
        []
      end

    Map.merge(map_data, %{
      systems: systems,
      connections: connections
    })
  end

  @doc """
  Sets up a map server mock for an existing map.

  This is useful when you have already created a map through other means
  and just need to set up the mock server state.
  """
  def setup_mock_for_existing_map(map) do
    MapServerMock.setup_map_mock(map.id)

    # Load any existing systems and connections into the mock
    load_existing_data_into_mock(map)

    :ok
  end

  @doc """
  Adds a system to a mocked map and updates the cache.
  """
  def add_system_to_mock(map_data, system_attrs \\ %{}) do
    system =
      Factory.create_map_system(
        Map.merge(%{map: map_data.map}, system_attrs),
        map_data.owner
      )

    MapServerMock.add_system_to_map(map_data.map.id, system)
    system
  end

  @doc """
  Adds a connection to a mocked map and updates the cache.
  """
  def add_connection_to_mock(map_data, source_system, target_system, attrs \\ %{}) do
    connection_attrs =
      Map.merge(
        %{
          map: map_data.map,
          source_system: source_system,
          target_system: target_system
        },
        attrs
      )

    connection = Factory.create_map_connection(connection_attrs, map_data.owner)
    MapServerMock.add_connection_to_map(map_data.map.id, connection)
    connection
  end

  @doc """
  Simulates character tracking in a map.
  """
  def track_character_in_map(map_id, character, solar_system_id) do
    MapServerMock.track_character_location(map_id, character.id, solar_system_id)
  end

  @doc """
  Gets the current state of a mocked map.
  """
  def get_mock_map_state(map_id) do
    MapServerMock.get_map_state(map_id)
  end

  @doc """
  Asserts that a map has the expected number of systems in the mock.
  """
  def assert_map_has_systems(map_id, expected_count) do
    {:ok, state} = MapServerMock.get_map_state(map_id)
    actual_count = state.systems |> Kernel.map_size()

    unless actual_count == expected_count do
      raise ExUnit.AssertionError,
        message: "Expected map to have #{expected_count} systems, but has #{actual_count}"
    end

    :ok
  end

  @doc """
  Asserts that a map has the expected number of connections in the mock.
  """
  def assert_map_has_connections(map_id, expected_count) do
    {:ok, state} = MapServerMock.get_map_state(map_id)
    actual_count = state.connections |> Kernel.map_size()

    unless actual_count == expected_count do
      raise ExUnit.AssertionError,
        message: "Expected map to have #{expected_count} connections, but has #{actual_count}"
    end

    :ok
  end

  @doc """
  Cleanup helper that removes all mock data for a map.

  This should be called in test cleanup to prevent state leakage.
  """
  def cleanup_map_mock(map_id) do
    MapServerMock.cleanup_map_mock(map_id)
  end

  # Private helpers

  defp create_systems_for_map(map_data, count) do
    Enum.map(1..count, fn i ->
      system_attrs = %{
        map: map_data.map,
        name: "System #{i}",
        solar_system_id: 30_000_000 + i,
        position_x: i * 100,
        position_y: i * 100
      }

      system = Factory.create_map_system(system_attrs, map_data.owner)
      MapServerMock.add_system_to_map(map_data.map.id, system)
      system
    end)
  end

  defp create_connections_for_map(map_data, systems) do
    # Create a chain of connections between consecutive systems
    systems
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [source, target] ->
      connection_attrs = %{
        map: map_data.map,
        source_system: source,
        target_system: target,
        # wormhole
        type: 0
      }

      connection = Factory.create_map_connection(connection_attrs, map_data.owner)
      MapServerMock.add_connection_to_map(map_data.map.id, connection)
      connection
    end)
  end

  defp load_existing_data_into_mock(map) do
    # Load existing systems
    map_systems =
      WandererApp.Api.MapSystem
      |> Ash.read!()
      |> Enum.filter(fn system -> system.map_id == map.id end)

    Enum.each(map_systems, fn system ->
      MapServerMock.add_system_to_map(map.id, system)
    end)

    # Load existing connections
    map_connections =
      WandererApp.Api.MapConnection
      |> Ash.read!()
      |> Enum.filter(fn connection -> connection.map_id == map.id end)

    Enum.each(map_connections, fn connection ->
      MapServerMock.add_connection_to_map(map.id, connection)
    end)
  end
end
