# Wanderer Testing Guide

This comprehensive guide covers everything you need to know about testing in the Wanderer project, from getting started in 10 minutes to advanced testing strategies.

## Table of Contents

1. [Quick Start (10 Minutes)](#quick-start-10-minutes)
2. [Test Architecture Overview](#test-architecture-overview)
3. [Writing Tests](#writing-tests)
4. [Test Types & Examples](#test-types--examples)
5. [Performance Guidelines](#performance-guidelines)
6. [Troubleshooting Reference](#troubleshooting-reference)
7. [Advanced Topics](#advanced-topics)

---

## Quick Start (10 Minutes)

### Prerequisites
- Elixir 1.14+
- Phoenix 1.7+
- PostgreSQL database running
- Project dependencies installed (`mix deps.get`)

### 1. Run Your First Test (2 minutes)

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/wanderer_app/api/map_test.exs

# Run specific test
mix test test/wanderer_app/api/map_test.exs:42
```

### 2. Understand Test Structure (3 minutes)

```
test/
├── unit/                    # Fast, isolated tests
├── integration/             # Database + external services
├── support/                 # Test helpers and utilities
├── fixtures/                # Test data and factories
└── contract/                # API contract validation
```

### 3. Write Your First Test (5 minutes)

```elixir
# test/unit/wanderer_app/api/map_test.exs
defmodule WandererApp.Api.MapTest do
  use WandererApp.DataCase
  
  alias WandererApp.Api.Map
  
  describe "create/1" do
    test "creates a map with valid attributes" do
      # Arrange
      attrs = %{
        name: "Test Map",
        slug: "test-map",
        description: "A test map"
      }
      
      # Act
      {:ok, map} = Map.create(attrs)
      
      # Assert
      assert map.name == "Test Map"
      assert map.slug == "test-map"
      assert map.description == "A test map"
    end
  end
end
```

### Common Pitfalls to Avoid

1. **Forgetting to use proper test case**: Use `WandererApp.DataCase` for database tests
2. **Not cleaning up after tests**: Use `setup` blocks for proper cleanup
3. **Testing implementation details**: Focus on behavior, not internal structure
4. **Ignoring async safety**: Use `async: true` only for tests that don't share state

### Next Steps

- Read [Writing Tests](#writing-tests) for standards and patterns
- Check [Test Types & Examples](#test-types--examples) for more complex scenarios
- Review [Troubleshooting Reference](#troubleshooting-reference) when tests fail

---

## Test Architecture Overview

### Test Pyramid Structure

```
        /\
       /  \     E2E Tests (5%)
      /____\    - Browser automation
     /      \   - Full user journeys
    /        \  
   /          \ Integration Tests (25%)
  /____________\- API endpoints
 /              \- Database operations
/                \- External services
\________________/
    Unit Tests (70%)
    - Pure functions
    - Business logic
    - Fast execution
```

### Test Categories

| Category | Purpose | Speed | Database | External Services |
|----------|---------|--------|----------|------------------|
| **Unit** | Test individual functions/modules | Fast | No | Mocked |
| **Integration** | Test component interactions | Medium | Yes | Mocked/Stubbed |
| **Contract** | Validate API contracts | Medium | Yes | Real/Stubbed |
| **E2E** | Test complete user workflows | Slow | Yes | Real |

### Test Execution Flow

1. **Pre-test Setup**: Database migrations, test data seeding
2. **Test Execution**: Run tests in parallel where possible
3. **Post-test Cleanup**: Database rollback, mock reset
4. **Reporting**: Coverage, performance, and failure reports

### Coverage Requirements

- **Unit Tests**: 90% minimum coverage
- **Integration Tests**: 80% minimum coverage
- **Overall Project**: 85% minimum coverage
- **Critical Business Logic**: 95% minimum coverage

---

## Writing Tests

### Test Standards and Patterns

#### 1. AAA Pattern (Arrange-Act-Assert)

```elixir
test "creates a map with valid attributes" do
  # Arrange - Set up test data and conditions
  user = insert(:user)
  attrs = %{name: "Test Map", owner_id: user.id}
  
  # Act - Perform the action being tested
  {:ok, map} = Map.create(attrs)
  
  # Assert - Verify the expected outcome
  assert map.name == "Test Map"
  assert map.owner_id == user.id
end
```

#### 2. Test Naming Conventions

```elixir
# Good: Descriptive test names
test "creates map with valid attributes"
test "returns error when name is too short"
test "allows admin to update any map"

# Bad: Vague test names
test "test_map_creation"
test "error_case"
test "admin_stuff"
```

#### 3. Test Organization

```elixir
defmodule WandererApp.Api.MapTest do
  use WandererApp.DataCase
  
  alias WandererApp.Api.Map
  
  describe "create/1" do
    test "success cases" do
      # ... success scenarios
    end
    
    test "validation errors" do
      # ... error scenarios
    end
  end
  
  describe "update/2" do
    # ... update tests
  end
end
```

### Factory Usage

#### Basic Factory Pattern

```elixir
# In test
user = insert(:user)
map = insert(:map, owner_id: user.id)

# With custom attributes
premium_user = insert(:user, subscription_type: :premium)
```

#### Factory Traits

```elixir
# Use traits for common variations
archived_map = insert(:map, :archived)
public_map = insert(:map, :public)
large_map = insert(:map, :with_many_systems)
```

#### Build vs Insert

```elixir
# Build - creates struct without database persistence
user = build(:user)

# Insert - creates and persists to database
user = insert(:user)

# Use build when you don't need database persistence
```

### Mock and Stub Patterns

#### Using Mox for External Services

```elixir
defmodule WandererApp.EsiApiTest do
  use WandererApp.DataCase
  
  import Mox
  
  setup :verify_on_exit!
  
  test "fetches character information" do
    # Arrange - Set up mock expectations
    WandererApp.Esi.Mock
    |> expect(:get_character, fn _id -> 
      {:ok, %{name: "Test Character"}} 
    end)
    
    # Act
    {:ok, character} = EsiApi.get_character(123)
    
    # Assert
    assert character.name == "Test Character"
  end
end
```

#### Stub Common Responses

```elixir
setup do
  # Set up common stubs for all tests
  WandererApp.Esi.Mock
  |> stub(:get_server_status, fn -> {:ok, %{players: 12345}} end)
  |> stub(:get_character_info, fn _id -> {:ok, %{name: "Test Character"}} end)
  
  :ok
end
```

### Assertion Guidelines

#### Use Specific Assertions

```elixir
# Good: Specific assertions
assert map.name == "Test Map"
assert length(map.systems) == 3
assert map.created_at != nil

# Bad: Generic assertions
assert map != nil
assert is_map(map)
```

#### Pattern Matching in Assertions

```elixir
# Good: Pattern matching for complex structures
assert {:ok, %Map{name: "Test Map", owner_id: user_id}} = Map.create(attrs)

# Good: Asserting on specific fields
assert %{name: "Test Map", systems: []} = created_map
```

### Test Setup and Teardown

#### Setup Blocks

```elixir
defmodule WandererApp.Api.MapTest do
  use WandererApp.DataCase
  
  setup do
    user = insert(:user)
    map = insert(:map, owner_id: user.id)
    
    %{user: user, map: map}
  end
  
  test "can update map name", %{map: map} do
    {:ok, updated_map} = Map.update(map, %{name: "New Name"})
    assert updated_map.name == "New Name"
  end
end
```

#### Context-Specific Setup

```elixir
describe "admin operations" do
  setup do
    admin = insert(:user, :admin)
    %{admin: admin}
  end
  
  test "admin can delete any map", %{admin: admin} do
    # Test admin-specific functionality
  end
end
```

---

## Test Types & Examples

### Unit Tests

#### Testing Pure Functions

```elixir
defmodule WandererApp.Utilities.SlugTest do
  use ExUnit.Case
  
  alias WandererApp.Utilities.Slug
  
  describe "generate/1" do
    test "creates URL-safe slug from text" do
      assert Slug.generate("Test Map Name") == "test-map-name"
      assert Slug.generate("Map with Numbers 123") == "map-with-numbers-123"
      assert Slug.generate("Special!@#$%Characters") == "special-characters"
    end
    
    test "handles empty and nil inputs" do
      assert Slug.generate("") == ""
      assert Slug.generate(nil) == ""
    end
  end
end
```

#### Testing Business Logic

```elixir
defmodule WandererApp.Map.PermissionsTest do
  use WandererApp.DataCase
  
  alias WandererApp.Map.Permissions
  
  describe "can_edit?/2" do
    test "owner can always edit their map" do
      user = insert(:user)
      map = insert(:map, owner_id: user.id)
      
      assert Permissions.can_edit?(user, map) == true
    end
    
    test "admin can edit any map" do
      admin = insert(:user, :admin)
      map = insert(:map)
      
      assert Permissions.can_edit?(admin, map) == true
    end
    
    test "regular user cannot edit others' maps" do
      user = insert(:user)
      other_map = insert(:map)
      
      assert Permissions.can_edit?(user, other_map) == false
    end
  end
end
```

### Integration Tests

#### API Controller Tests

```elixir
defmodule WandererAppWeb.MapAPIControllerTest do
  use WandererAppWeb.ConnCase
  
  setup %{conn: conn} do
    user = insert(:user)
    map = insert(:map, owner_id: user.id)
    
    conn = 
      conn
      |> put_req_header("authorization", "Bearer #{map.public_api_key}")
      |> put_req_header("content-type", "application/json")
    
    %{conn: conn, user: user, map: map}
  end
  
  describe "GET /api/maps" do
    test "returns user's maps", %{conn: conn, map: map} do
      response = 
        conn
        |> get("/api/maps")
        |> json_response(200)
      
      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == map.id
    end
  end
  
  describe "POST /api/maps" do
    test "creates new map with valid data", %{conn: conn} do
      map_params = %{
        name: "New Map",
        description: "A new test map"
      }
      
      response = 
        conn
        |> post("/api/maps", map_params)
        |> json_response(201)
      
      assert response["data"]["name"] == "New Map"
      assert response["data"]["description"] == "A new test map"
    end
    
    test "returns error with invalid data", %{conn: conn} do
      invalid_params = %{name: ""}
      
      response = 
        conn
        |> post("/api/maps", invalid_params)
        |> json_response(422)
      
      assert response["errors"]["name"] == ["can't be blank"]
    end
  end
end
```

#### Database Integration Tests

```elixir
defmodule WandererApp.Api.MapIntegrationTest do
  use WandererApp.DataCase
  
  alias WandererApp.Api.Map
  
  describe "map creation with relationships" do
    test "creates map with initial system" do
      user = insert(:user)
      character = insert(:character, user_id: user.id)
      
      {:ok, map} = Map.create(%{
        name: "Test Map",
        owner_id: user.id,
        initial_system: %{
          name: "Jita",
          solar_system_id: 30000142
        }
      })
      
      map = Map.get!(map.id, load: [:systems])
      assert length(map.systems) == 1
      assert hd(map.systems).name == "Jita"
    end
  end
end
```

### Contract Tests

#### JSON:API Contract Validation

```elixir
defmodule WandererAppWeb.JsonApiContractTest do
  use WandererAppWeb.ConnCase
  
  describe "JSON:API compliance" do
    test "returns proper content-type header" do
      user = insert(:user)
      map = insert(:map, owner_id: user.id)
      
      conn = 
        build_conn()
        |> put_req_header("authorization", "Bearer #{map.public_api_key}")
        |> put_req_header("accept", "application/vnd.api+json")
      
      response = get(conn, "/api/v1/maps")
      
      assert get_resp_header(response, "content-type") == 
        ["application/vnd.api+json; charset=utf-8"]
    end
    
    test "validates response structure" do
      # Test that response follows JSON:API spec
      response = get_json_api_response("/api/v1/maps")
      
      assert Map.has_key?(response, "data")
      assert is_list(response["data"])
      
      if length(response["data"]) > 0 do
        resource = hd(response["data"])
        assert Map.has_key?(resource, "type")
        assert Map.has_key?(resource, "id")
        assert Map.has_key?(resource, "attributes")
      end
    end
  end
end
```

#### External Service Contract Tests

```elixir
defmodule WandererApp.Esi.ContractTest do
  use WandererApp.DataCase
  
  @moduletag :external
  
  describe "ESI API contracts" do
    test "character endpoint returns expected structure" do
      # This test runs against real ESI API
      {:ok, character} = WandererApp.Esi.get_character(123456)
      
      assert Map.has_key?(character, "name")
      assert Map.has_key?(character, "corporation_id")
      assert is_binary(character["name"])
      assert is_integer(character["corporation_id"])
    end
  end
end
```

### Performance Tests

#### Load Testing

```elixir
defmodule WandererApp.Performance.MapLoadTest do
  use WandererApp.DataCase
  
  @moduletag :performance
  
  describe "map operations performance" do
    test "handles bulk system creation" do
      map = insert(:map)
      
      # Measure time for bulk operation
      {time, _result} = :timer.tc(fn ->
        1..100
        |> Enum.map(fn i ->
          insert(:map_system, map_id: map.id, name: "System #{i}")
        end)
      end)
      
      # Assert operation completes within acceptable time (5 seconds)
      assert time < 5_000_000 # microseconds
    end
  end
end
```

#### Memory Usage Tests

```elixir
defmodule WandererApp.Performance.MemoryTest do
  use WandererApp.DataCase
  
  @moduletag :performance
  
  test "memory usage stays reasonable during bulk operations" do
    initial_memory = :erlang.memory(:total)
    
    # Perform memory-intensive operation
    1..1000
    |> Enum.each(fn i ->
      insert(:map_system, name: "System #{i}")
    end)
    
    final_memory = :erlang.memory(:total)
    memory_increase = final_memory - initial_memory
    
    # Assert memory increase is reasonable (less than 100MB)
    assert memory_increase < 100_000_000
  end
end
```

### WebSocket Tests

```elixir
defmodule WandererAppWeb.MapChannelTest do
  use WandererAppWeb.ChannelCase
  
  describe "map:updates channel" do
    test "broadcasts system updates to connected clients" do
      user = insert(:user)
      map = insert(:map, owner_id: user.id)
      
      {:ok, _, socket} = 
        WandererAppWeb.MapChannel
        |> socket("user_id", %{user_id: user.id})
        |> subscribe_and_join("map:#{map.id}")
      
      # Trigger system update
      system = insert(:map_system, map_id: map.id)
      
      # Assert broadcast is received
      assert_broadcast("system_added", %{system: %{id: system.id}})
    end
  end
end
```

---

## Performance Guidelines

### Test Execution Performance

#### Parallel Test Execution

```elixir
# Enable async for unit tests
defmodule WandererApp.Utilities.SlugTest do
  use ExUnit.Case, async: true
  
  # Tests that don't use database or shared state
end

# Don't use async for integration tests
defmodule WandererAppWeb.MapAPIControllerTest do
  use WandererAppWeb.ConnCase
  # async: false (default)
  
  # Tests that use database or shared state
end
```

#### Optimize Test Data Creation

```elixir
# Good: Minimal test data
test "validates map name length" do
  # Only create what's needed
  attrs = %{name: "x"}
  
  {:error, changeset} = Map.create(attrs)
  assert "should be at least 3 character(s)" in errors_on(changeset).name
end

# Bad: Excessive test data
test "validates map name length" do
  # Creating unnecessary related data
  user = insert(:user)
  character = insert(:character, user_id: user.id)
  map = insert(:map, owner_id: user.id)
  
  attrs = %{name: "x", owner_id: user.id}
  {:error, changeset} = Map.create(attrs)
  assert "should be at least 3 character(s)" in errors_on(changeset).name
end
```

#### Database Performance

```elixir
# Use transactions for test isolation
defmodule WandererApp.DataCase do
  use ExUnit.CaseTemplate
  
  using do
    quote do
      import Ecto.Changeset
      import Ecto.Query
      import WandererApp.DataCase
      import WandererApp.Factory
      
      alias WandererApp.Repo
    end
  end
  
  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WandererApp.Repo)
    
    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, {:shared, self()})
    end
    
    :ok
  end
end
```

### Performance Monitoring

#### Track Test Execution Time

```bash
# Run tests with timing information
mix test --trace

# Run specific slow tests
mix test --only slow

# Profile test execution
mix test --profile
```

#### Memory Profiling

```elixir
# Add to test when investigating memory issues
test "memory usage for large dataset" do
  :eprof.start_profiling([self()])
  
  # Your test code here
  
  :eprof.stop_profiling()
  :eprof.analyze()
end
```

---

## Troubleshooting Reference

### Common Test Issues

#### Test Failures

```bash
# Run failed tests only
mix test --failed

# Run tests with detailed output
mix test --trace

# Run specific test with full output
mix test test/path/to/test.exs:42 --trace
```

#### Database Issues

```bash
# Reset test database
mix ecto.reset

# Create test database
MIX_ENV=test mix ecto.create

# Run migrations
MIX_ENV=test mix ecto.migrate
```

#### Factory Issues

```elixir
# Debug factory creation
factory = build(:map)
IO.inspect(factory, label: "Factory result")

# Check factory attributes
attrs = %{name: "Test", owner_id: nil}
{:error, changeset} = Map.create(attrs)
IO.inspect(changeset.errors, label: "Validation errors")
```

### Performance Issues

#### Slow Tests

```bash
# Identify slow tests
mix test --slowest 10

# Run with profiling
mix test --profile
```

#### Memory Issues

```bash
# Monitor memory usage
mix test --memory

# Check for memory leaks
:observer.start()
```

### Mock/Stub Issues

#### Mock Verification Errors

```elixir
# Debug mock calls
setup do
  WandererApp.Esi.Mock
  |> expect(:get_character, fn id -> 
    IO.puts("Mock called with: #{id}")
    {:ok, %{name: "Test"}}
  end)
  
  :ok
end
```

### CI/CD Issues

#### GitHub Actions Failures

```yaml
# Add debugging to workflow
- name: Run tests with debugging
  run: |
    mix test --trace
    mix test --cover --export-coverage default
```

### Quick Diagnostic Commands

```bash
# Check test environment
mix test --help

# Verify database connection
MIX_ENV=test mix ecto.migrate --dry-run

# Check dependencies
mix deps.get --only test

# Validate test structure
find test -name "*.exs" | wc -l

# Check coverage
mix test --cover
```

---

## Advanced Topics

### Property-Based Testing

```elixir
defmodule WandererApp.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  property "slug generation is always URL-safe" do
    check all input <- string(:printable) do
      slug = WandererApp.Utilities.Slug.generate(input)
      
      # Slug should only contain safe characters
      assert String.match?(slug, ~r/^[a-z0-9-]*$/)
      
      # Slug should not have consecutive hyphens
      refute String.contains?(slug, "--")
    end
  end
end
```

### Test Doubles and Fakes

```elixir
# Create a fake GenServer for testing
defmodule FakeMapServer do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    {:ok, %{}}
  end
  
  def handle_call({:get_map, id}, _from, state) do
    {:reply, Map.get(state, id), state}
  end
end
```

### Concurrent Testing

```elixir
defmodule WandererApp.ConcurrencyTest do
  use WandererApp.DataCase
  
  test "handles concurrent map updates" do
    map = insert(:map)
    
    # Spawn multiple processes updating the same map
    tasks = 
      1..10
      |> Enum.map(fn i ->
        Task.async(fn ->
          Map.update(map, %{description: "Update #{i}"})
        end)
      end)
    
    # Wait for all tasks and verify results
    results = Task.await_many(tasks)
    
    # At least one update should succeed
    assert Enum.any?(results, fn 
      {:ok, _} -> true
      _ -> false
    end)
  end
end
```

### Database Testing Patterns

#### Testing Migrations

```elixir
defmodule WandererApp.MigrationTest do
  use WandererApp.DataCase
  
  test "migration adds required column" do
    # Test that migration works correctly
    assert column_exists?(:maps, :public_api_key)
    assert column_type(:maps, :public_api_key) == :string
  end
end
```

#### Testing Database Constraints

```elixir
test "enforces unique constraint on map slug" do
  map1 = insert(:map, slug: "test-map")
  
  assert_raise Ecto.ConstraintError, fn ->
    insert(:map, slug: "test-map")
  end
end
```

### Advanced Mocking

#### Dynamic Mocks

```elixir
setup do
  mock_responses = %{
    123 => %{name: "Character 1"},
    456 => %{name: "Character 2"}
  }
  
  WandererApp.Esi.Mock
  |> stub(:get_character, fn id ->
    case Map.get(mock_responses, id) do
      nil -> {:error, :not_found}
      character -> {:ok, character}
    end
  end)
  
  :ok
end
```

#### Mock State Management

```elixir
defmodule MockStateServer do
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{calls: []}, name: __MODULE__)
  end
  
  def record_call(call) do
    GenServer.cast(__MODULE__, {:record, call})
  end
  
  def get_calls do
    GenServer.call(__MODULE__, :get_calls)
  end
  
  def handle_cast({:record, call}, state) do
    {:noreply, %{state | calls: [call | state.calls]}}
  end
  
  def handle_call(:get_calls, _from, state) do
    {:reply, Enum.reverse(state.calls), state}
  end
end
```

### Test Data Management

#### Seed Data for Tests

```elixir
defmodule WandererApp.TestSeeds do
  def seed_solar_systems do
    [
      %{id: 30000142, name: "Jita", security: 0.9},
      %{id: 30000144, name: "Perimeter", security: 0.9},
      %{id: 30000145, name: "Sobaseki", security: 0.8}
    ]
    |> Enum.each(&insert_solar_system/1)
  end
  
  defp insert_solar_system(attrs) do
    WandererApp.SolarSystem.create!(attrs)
  end
end
```

### Custom Test Helpers

```elixir
defmodule WandererApp.TestHelpers do
  def assert_valid_changeset(changeset) do
    assert changeset.valid?, "Expected changeset to be valid, got errors: #{inspect(changeset.errors)}"
  end
  
  def assert_invalid_changeset(changeset, field) do
    refute changeset.valid?
    assert Map.has_key?(changeset.errors, field)
  end
  
  def eventually(assertion, timeout \\ 1000) do
    eventually(assertion, timeout, 10)
  end
  
  defp eventually(assertion, timeout, interval) when timeout > 0 do
    try do
      assertion.()
    rescue
      _ ->
        :timer.sleep(interval)
        eventually(assertion, timeout - interval, interval)
    end
  end
  
  defp eventually(assertion, _timeout, _interval) do
    assertion.()
  end
end
```

---

## Additional Resources

### Related Documentation

- [WORKFLOW.md](WORKFLOW.md) - Visual testing workflows and decision trees
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - Testing architecture and metrics
- [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md) - Team onboarding guide

### External Resources

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/)
- [Mox Documentation](https://hexdocs.pm/mox/)
- [Property-Based Testing with StreamData](https://hexdocs.pm/stream_data/)
- [Phoenix Testing Guide](https://hexdocs.pm/phoenix/testing.html)

### Tools and Dependencies

- **ExUnit**: Core testing framework
- **Mox**: Mock and stub library
- **StreamData**: Property-based testing
- **Wallaby**: Browser testing
- **ExCoveralls**: Code coverage
- **Benchee**: Performance benchmarking

---

## Contributing

When adding new test patterns or examples to this guide:

1. Follow the established structure and formatting
2. Include working code examples
3. Add appropriate tags for test categories
4. Update the table of contents
5. Cross-reference with related sections
6. Validate examples work with current codebase

For questions or improvements, please refer to the [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md) guide.