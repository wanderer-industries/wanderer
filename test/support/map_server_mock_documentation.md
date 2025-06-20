# Map Server Mock Infrastructure Documentation

## Overview

The Map Server Mock Infrastructure enables integration tests that require map server state without running actual GenServer processes. This solves the problem of ~30 skipped tests that require map server GenServer to be running.

## Components

### 1. MapServerMock (`test/support/map_server_mock.ex`)

Core mock implementation that simulates map server behavior:

- **`setup_map_mock/1`** - Initializes mock map cache and marks map as started
- **`cleanup_map_mock/1`** - Cleans up mock data after tests
- **`add_system_to_map/2`** - Adds a system to the mocked map cache
- **`add_connection_to_map/2`** - Adds a connection to the mocked map cache
- **`remove_system_from_map/2`** - Removes a system from the map
- **`remove_connection_from_map/3`** - Removes a connection from the map
- **`get_map_state/1`** - Returns the current mocked state
- **`track_character_location/3`** - Mocks character tracking
- **`is_map_started?/1`** - Checks if map server is mocked as started

### 2. MapTestHelpers (`test/support/map_test_helpers.ex`)

High-level test helpers that combine factory data creation with map server mocking:

- **`setup_map_with_mock/1`** - Creates a map with optional systems and connections
- **`setup_mock_for_existing_map/1`** - Sets up mock for an already created map
- **`add_system_to_mock/2`** - Convenient wrapper for adding systems
- **`add_connection_to_mock/4`** - Convenient wrapper for adding connections
- **`track_character_in_map/3`** - Simulates character tracking
- **`assert_map_has_systems/2`** - Assertion helper for system count
- **`assert_map_has_connections/2`** - Assertion helper for connection count

### 3. ApiCase Integration (`test/api/support/api_case.ex`)

The ApiCase has been enhanced to:

- Import `MapTestHelpers` for all API tests
- Alias `MapServerMock` for direct access
- Automatically setup map server mock when using `create_test_map_with_auth/1`
- Register cleanup callbacks to prevent state leakage
- Support `@tag with_map_mock: true` for automatic setup

### 4. Factory Integration (`test/support/factory.ex`)

The factory has been updated to:

- Check if map server is mocked before updating cache
- Automatically add systems/connections to mock when created
- Remove the problematic `ensure_map_server_started/1` function

## Usage Examples

### Basic Map Operations

```elixir
test "creating a map with mock", %{conn: conn} do
  # Automatically sets up mock
  map_data = create_test_map_with_auth()
  
  # Mock is ready to use
  assert MapServerMock.is_map_started?(map_data.map.id)
end
```

### Adding Systems and Connections

```elixir
test "map with systems", %{conn: conn} do
  map_data = create_test_map_with_auth()
  
  # Add systems
  system1 = add_system_to_mock(map_data, %{
    name: "System A",
    solar_system_id: 30000001
  })
  
  system2 = add_system_to_mock(map_data, %{
    name: "System B",
    solar_system_id: 30000002
  })
  
  # Add connection
  connection = add_connection_to_mock(map_data, system1, system2)
  
  # Verify
  assert_map_has_systems(map_data.map.id, 2)
  assert_map_has_connections(map_data.map.id, 1)
end
```

### Using the Helper

```elixir
test "quick setup", %{conn: conn} do
  # Create map with 3 systems connected in a chain
  map_data = setup_map_with_mock(
    with_systems: 3,
    with_connections: true
  )
  
  assert length(map_data.systems) == 3
  assert length(map_data.connections) == 2
end
```

### Character Tracking

```elixir
test "track character", %{conn: conn} do
  map_data = create_test_map_with_auth()
  system = add_system_to_mock(map_data)
  
  # Track character location
  track_character_in_map(map_data.map.id, map_data.owner, system.solar_system_id)
end
```

## Migration Guide

To enable existing skipped tests:

1. Remove `@tag :skip` or `@moduletag :skip`
2. Use `create_test_map_with_auth()` instead of manual map creation
3. Replace direct GenServer calls with mock helpers
4. Add systems/connections using the helper functions
5. Use assertion helpers to verify state

## Benefits

- Enables ~30 previously skipped integration tests
- No need for actual GenServer processes
- Faster test execution
- Isolated test state
- Automatic cleanup prevents state leakage
- Consistent test data setup

## Notes

- The mock uses Cachex for state storage, matching production behavior
- Mock state is automatically cleaned up after each test
- The infrastructure is backward compatible with existing tests
- Tests can gradually migrate to use the mock infrastructure