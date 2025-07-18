# WandererApp Test Suite Documentation

## 🚀 Quick Start

**New to testing here?** Start with our [QUICKSTART.md](QUICKSTART.md) - get up and running in 10 minutes!

**Looking for specific guidance?** Check our [INDEX.md](INDEX.md) for quick navigation to the right documentation.

## 📚 Documentation Structure

We have comprehensive testing documentation organized for different needs:

| Document | Purpose | Time | Audience |
|----------|---------|------|----------|
| **[INDEX.md](INDEX.md)** | 📚 Navigation hub | 2 min | Everyone |
| **[QUICKSTART.md](QUICKSTART.md)** | 🚀 Fast setup guide | 10 min | New developers |
| **[WORKFLOW.md](WORKFLOW.md)** | 🔄 Visual workflows | 15 min | All developers |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | 🔧 Problem solving | As needed | When stuck |
| **[STANDARDS_CONSOLIDATED.md](STANDARDS_CONSOLIDATED.md)** | 📏 Unified standards | 30 min | All developers |
| **[DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)** | 👥 Team integration | 1-2 weeks | New team members |
| **[EXAMPLES.md](EXAMPLES.md)** | 📋 Practical examples | 30 min | Code writers |
| **[performance/README.md](performance/README.md)** | ⚡ Performance testing | 20 min | Performance focus |

## Overview

This document provides comprehensive guidance for writing, running, and maintaining tests in the WandererApp project. Our test suite follows Elixir best practices and is designed to ensure API reliability, performance, and maintainability.

> **💡 Pro Tip**: This README contains detailed reference material. For quick getting started, use [QUICKSTART.md](QUICKSTART.md) instead!

## Table of Contents

1. [Test Structure](#test-structure)
2. [Running Tests](#running-tests)
3. [Writing Tests](#writing-tests)
4. [Test Patterns](#test-patterns)
5. [Mocking & Stubs](#mocking--stubs)
6. [Test Data & Factories](#test-data--factories)
7. [Coverage Requirements](#coverage-requirements)
8. [CI/CD Integration](#cicd-integration)
9. [Troubleshooting](#troubleshooting)

## Test Structure

```
test/
├── support/                      # Test helpers and utilities
│   ├── channel_case.ex          # WebSocket channel test helpers
│   ├── conn_case.ex             # HTTP connection test helpers
│   ├── data_case.ex             # Database test helpers
│   ├── factory.ex               # Test data factories
│   ├── mocks.ex                 # Mock definitions
│   ├── openapi_contract_helpers.ex  # OpenAPI validation helpers
│   ├── openapi_spec_analyzer.ex     # OpenAPI analysis tools
│   ├── openapi_schema_evolution.ex  # Schema change detection
│   └── openapi_test_generator.ex    # Auto-generate contract tests
├── unit/                        # Unit tests
│   ├── api/                     # Ash resource tests
│   ├── utils/                   # Utility function tests
│   └── business_logic/          # Domain logic tests
├── integration/                 # Integration tests
│   ├── api/                     # API controller tests
│   │   ├── auth_integration_test.exs
│   │   └── edge_cases/          # Edge case scenarios
│   │       ├── rate_limiting_test.exs
│   │       ├── database_constraints_test.exs
│   │       ├── external_service_failures_test.exs
│   │       └── malformed_requests_test.exs
│   ├── auth/                    # Authentication flow tests
│   └── workflows/               # Multi-step process tests
├── contract/                    # Contract tests
│   ├── map_api_contract_test.exs
│   ├── error_response_contract_test.exs
│   └── parameter_validation_contract_test.exs
└── performance/                 # Performance tests (future)
```

## Running Tests

### Basic Commands

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover
mix coveralls

# Run specific test file
mix test test/integration/api/auth_integration_test.exs

# Run specific test
mix test test/integration/api/auth_integration_test.exs:45

# Run tests matching description
mix test --only describe:"API key validation"

# Run tests with specific tags
mix test --only integration
mix test --exclude slow
```

### Coverage Reports

```bash
# Generate HTML coverage report
mix coveralls.html

# Generate JSON coverage report
mix coveralls.json

# Check coverage meets minimum threshold
mix coveralls --minimum-coverage 70

# Send coverage to CI service
mix coveralls.github
```

### Quality Checks

```bash
# Run full quality check suite
mix check

# Generate quality report
mix quality.report

# Run specific checks
mix credo --strict
mix dialyzer
mix format --check-formatted
```

## Writing Tests

### Basic Test Structure

```elixir
defmodule WandererAppWeb.MapAPIControllerTest do
  use WandererAppWeb.ConnCase, async: true
  
  alias WandererApp.Test.Factory
  
  describe "GET /api/maps/:slug" do
    setup do
      # Setup test data
      user = Factory.create_user()
      map = Factory.create_map(%{user_id: user.id})
      api_key = Factory.create_map_api_key(%{map_id: map.id})
      
      %{
        user: user,
        map: map,
        api_key: api_key,
        conn: put_req_header(conn, "x-api-key", api_key.key)
      }
    end
    
    test "returns map data with valid API key", %{conn: conn, map: map} do
      conn = get(conn, "/api/maps/#{map.slug}")
      
      assert response = json_response(conn, 200)
      assert response["data"]["id"] == map.slug
      assert response["data"]["type"] == "map"
      
      # Validate against OpenAPI schema
      assert_schema(response, "MapResponse", api_spec())
    end
    
    test "returns 401 with invalid API key", %{conn: _conn} do
      conn = 
        build_conn()
        |> put_req_header("x-api-key", "invalid-key")
        |> get("/api/maps/some-map")
      
      assert json_response(conn, 401)
    end
  end
end
```

### Test Naming Conventions

- Use descriptive test names that explain what is being tested
- Start with the action: "returns", "creates", "updates", "deletes", "handles"
- Include the condition: "with valid data", "when unauthorized", "if not found"
- Include the expected outcome: "successfully", "returns error", "raises exception"

Examples:
- `test "creates system with valid data"`
- `test "returns 404 when map not found"`
- `test "handles database timeout gracefully"`

### Assertion Best Practices

```elixir
# Good - specific assertions
assert %{"data" => %{"id" => ^expected_id}} = json_response(conn, 200)
assert map.name == "Test Map"
assert length(systems) == 3

# Avoid - vague assertions
assert json_response(conn, 200) != nil
assert map
assert systems
```

## Test Patterns

### Integration Test Pattern

```elixir
defmodule WandererAppWeb.SystemIntegrationTest do
  use WandererAppWeb.ConnCase, async: false
  
  describe "system lifecycle" do
    setup [:create_map_with_api_key]
    
    test "complete CRUD operations", %{conn: conn, map: map} do
      # Create
      system_params = %{
        "solar_system_id" => 30000142,
        "position_x" => 100,
        "position_y" => 200
      }
      
      conn = post(conn, "/api/maps/#{map.slug}/systems", system_params)
      assert %{"data" => created} = json_response(conn, 201)
      
      # Read
      conn = get(conn, "/api/maps/#{map.slug}/systems/#{created["solar_system_id"]}")
      assert %{"data" => read} = json_response(conn, 200)
      assert read["solar_system_id"] == created["solar_system_id"]
      
      # Update
      update_params = %{"position_x" => 150}
      conn = put(conn, "/api/maps/#{map.slug}/systems/#{created["solar_system_id"]}", update_params)
      assert %{"data" => updated} = json_response(conn, 200)
      assert updated["position_x"] == 150
      
      # Delete
      conn = delete(conn, "/api/maps/#{map.slug}/systems/#{created["solar_system_id"]}")
      assert conn.status == 204
      
      # Verify deletion
      conn = get(conn, "/api/maps/#{map.slug}/systems/#{created["solar_system_id"]}")
      assert json_response(conn, 404)
    end
  end
  
  defp create_map_with_api_key(_) do
    user = Factory.create_user()
    map = Factory.create_map(%{user_id: user.id})
    api_key = Factory.create_map_api_key(%{map_id: map.id})
    
    %{
      user: user,
      map: map,
      api_key: api_key,
      conn: build_conn() |> put_req_header("x-api-key", api_key.key)
    }
  end
end
```

### Contract Test Pattern

```elixir
defmodule WandererAppWeb.MapAPIContractTest do
  use WandererAppWeb.ConnCase
  use WandererAppWeb.OpenAPICase
  
  describe "POST /api/maps/:slug/systems" do
    setup [:create_test_map]
    
    test "request and response match OpenAPI schema", %{conn: conn, map: map} do
      request_body = %{
        "solar_system_id" => 30000142,
        "position_x" => 100,
        "position_y" => 200,
        "name" => "Jita"
      }
      
      # Validate request against schema
      assert_request_schema(request_body, "CreateSystemRequest", api_spec())
      
      # Make request
      conn = post(conn, "/api/maps/#{map.slug}/systems", request_body)
      
      # Validate response against schema
      response = json_response(conn, 201)
      assert_response_schema(response, 201, "CreateSystemResponse", api_spec())
      
      # Validate headers
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      assert get_resp_header(conn, "location")
    end
  end
end
```

### Edge Case Test Pattern

```elixir
defmodule WandererAppWeb.EdgeCaseTest do
  use WandererAppWeb.ConnCase
  
  describe "handles extreme inputs" do
    setup [:create_test_map]
    
    test "rejects extremely long strings", %{conn: conn, map: map} do
      long_name = String.duplicate("a", 10_000)
      
      params = %{
        "name" => long_name,
        "description" => "Test"
      }
      
      conn = post(conn, "/api/maps/#{map.slug}/acl", params)
      
      assert %{"errors" => error} = json_response(conn, 422)
      assert error["detail"] =~ "too long" or error["detail"] =~ "length"
    end
    
    @tag :slow
    test "handles concurrent requests", %{conn: conn, map: map} do
      # Create multiple concurrent requests
      tasks = for i <- 1..100 do
        Task.async(fn ->
          conn
          |> put_req_header("x-api-key", api_key.key)
          |> get("/api/maps/#{map.slug}")
        end)
      end
      
      results = Task.await_many(tasks, 10_000)
      
      # All should succeed
      assert Enum.all?(results, &(&1.status == 200))
    end
  end
end
```

## Mocking & Stubs

### Mock Setup

```elixir
# test/support/mocks.ex
Mox.defmock(Test.EVEAPIClientMock, for: WandererApp.EVEAPIClient.Behaviour)
Mox.defmock(Test.CacheMock, for: WandererApp.Cache.Behaviour)
Mox.defmock(Test.PubSubMock, for: WandererApp.PubSub.Behaviour)

# Configure default stubs
Test.LoggerMock
|> stub(:info, fn _msg -> :ok end)
|> stub(:error, fn _msg -> :ok end)
```

### Using Mocks in Tests

```elixir
defmodule WandererApp.EVEAPITest do
  use WandererApp.DataCase
  import Mox
  
  setup :verify_on_exit!
  
  test "handles EVE API errors gracefully" do
    # Set expectation
    Test.EVEAPIClientMock
    |> expect(:get_character_info, fn character_id ->
      assert character_id == 123456
      {:error, :timeout}
    end)
    
    # Test the code that uses the mock
    result = WandererApp.Characters.fetch_character_info(123456)
    
    assert {:error, :external_service_error} = result
  end
  
  test "caches successful responses" do
    # Multiple expectations
    Test.EVEAPIClientMock
    |> expect(:get_system_info, fn _system_id ->
      {:ok, %{"name" => "Jita", "security" => 0.9}}
    end)
    
    Test.CacheMock
    |> expect(:get, fn key ->
      assert key == "system:30000142"
      {:error, :not_found}
    end)
    |> expect(:put, fn key, value, opts ->
      assert key == "system:30000142"
      assert value.name == "Jita"
      assert opts[:ttl] == 3600
      :ok
    end)
    
    # Run the test
    {:ok, system} = WandererApp.Systems.get_system_info(30000142)
    assert system.name == "Jita"
  end
end
```

## Test Data & Factories

### Factory Examples

```elixir
# test/support/factory.ex
defmodule WandererApp.Test.Factory do
  alias WandererApp.Api
  
  def build_user(attrs \\ %{}) do
    %{
      character_id: sequence(:character_id, &(&1 + 1000000)),
      character_name: sequence(:character_name, &"Test Character #{&1}"),
      character_owner_hash: Ecto.UUID.generate(),
      admin: false
    }
    |> Map.merge(attrs)
  end
  
  def create_user(attrs \\ %{}) do
    attrs = build_user(attrs)
    {:ok, user} = Ash.create(Api.User, attrs)
    user
  end
  
  def create_map_with_systems(attrs \\ %{}) do
    map = create_map(attrs)
    
    # Create interconnected systems
    system1 = create_map_system(%{map_id: map.id, solar_system_id: 30000142})
    system2 = create_map_system(%{map_id: map.id, solar_system_id: 30000143})
    system3 = create_map_system(%{map_id: map.id, solar_system_id: 30000144})
    
    # Create connections
    create_map_connection(%{
      map_id: map.id,
      from_solar_system_id: system1.solar_system_id,
      to_solar_system_id: system2.solar_system_id
    })
    
    %{map | systems: [system1, system2, system3]}
  end
  
  # Sequence helper
  defp sequence(name, formatter) do
    Agent.get_and_update(__MODULE__, fn sequences ->
      current = Map.get(sequences, name, 0) + 1
      {formatter.(current), Map.put(sequences, name, current)}
    end)
  end
end
```

### Using Factories in Tests

```elixir
test "lists user's maps" do
  user = Factory.create_user()
  maps = for _ <- 1..3, do: Factory.create_map(%{user_id: user.id})
  other_map = Factory.create_map() # Different user
  
  conn = 
    build_conn()
    |> authenticate_as(user)
    |> get("/api/user/maps")
  
  response = json_response(conn, 200)
  returned_ids = Enum.map(response["data"], & &1["id"])
  
  assert length(returned_ids) == 3
  assert Enum.all?(maps, &(&1.slug in returned_ids))
  refute other_map.slug in returned_ids
end
```

## Coverage Requirements

### Current Thresholds

- **Minimum Coverage**: 70% (current), 90% (target by Q2 2025)
- **Critical Paths**: 95%+ coverage required
- **New Code**: 90%+ coverage required

### Coverage by Component

| Component | Current Target | Future Target |
|-----------|---------------|---------------|
| Controllers | 85% | 95% |
| Ash Resources | 80% | 90% |
| Business Logic | 90% | 95% |
| Utilities | 85% | 90% |
| Error Handlers | 75% | 85% |

### Measuring Coverage

```bash
# Generate detailed coverage report
mix coveralls.detail

# Check coverage for specific modules
mix coveralls.html
# Open cover/excoveralls.html in browser

# Focus on uncovered lines
mix coveralls.json
cat cover/excoveralls.json | jq '.source_files[] | select(.coverage < 80)'
```

## CI/CD Integration

### GitHub Actions Workflow

Our CI pipeline runs on every push and pull request:

1. **Compilation Check**: Ensures code compiles without warnings
2. **Formatting Check**: Verifies code follows standard formatting
3. **Credo Analysis**: Checks code quality and style
4. **Dialyzer**: Performs static analysis
5. **Tests**: Runs full test suite with coverage
6. **OpenAPI Validation**: Checks for breaking changes

### Quality Gates

Current error budgets (defined in `config/quality_gates.exs`):

- Compilation warnings: ≤ 100
- Credo issues: ≤ 50
- Dialyzer errors: 0
- Test coverage: ≥ 70%
- Test failures: ≤ 10
- Test duration: ≤ 5 minutes

### Running CI Checks Locally

```bash
# Run all CI checks
mix check

# Run specific CI steps
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test --cover
mix quality.report
```

## Troubleshooting

### Common Issues

#### Tests Failing with Database Errors

```bash
# Reset test database
MIX_ENV=test mix ecto.drop
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
```

#### Mock Expectations Not Met

```elixir
# Ensure setup includes
setup :verify_on_exit!

# Use stub for optional calls
stub(MockModule, :function, fn _ -> :ok end)

# Use expect for required calls
expect(MockModule, :function, 1, fn _ -> :ok end)
```

#### Flaky Tests

1. Check for race conditions
2. Ensure proper test isolation
3. Use `async: false` for tests that can't run in parallel
4. Add explicit waits for async operations

```elixir
# Wait for async operation
assert_eventually fn ->
  conn = get(conn, "/api/status")
  json_response(conn, 200)["status"] == "ready"
end
```

#### Coverage Not Updating

```bash
# Clear coverage data
rm -rf cover/
mix test --cover

# Force recompilation
mix clean
mix compile
mix test --cover
```

### Performance Optimization

#### Parallel Test Execution

```elixir
# Enable for isolated tests
use WandererAppWeb.ConnCase, async: true

# Disable for tests using shared resources
use WandererAppWeb.ConnCase, async: false
```

#### Database Optimization

```elixir
# Use sandbox for test isolation
setup tags do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(WandererApp.Repo)
  
  unless tags[:async] do
    Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, {:shared, self()})
  end
  
  :ok
end
```

#### Test Data Optimization

```elixir
# Reuse expensive setup
setup_all do
  # Create once for all tests in module
  expensive_data = create_complex_test_data()
  %{shared_data: expensive_data}
end

# Use fixtures for static data
@fixture_file "test/fixtures/eve_systems.json"
def load_eve_systems do
  @fixture_file
  |> File.read!()
  |> Jason.decode!()
end
```

## Best Practices Summary

1. **Write tests first** when fixing bugs or adding features
2. **Keep tests focused** - one assertion per test when possible
3. **Use descriptive names** that explain what and why
4. **Avoid sleep/timeouts** - use polling or mocks instead
5. **Clean up after tests** - use on_exit callbacks
6. **Tag slow tests** appropriately
7. **Document complex setups** with comments
8. **Maintain test data** - keep factories up to date
9. **Review test failures** - don't ignore intermittent failures
10. **Monitor test performance** - keep suite under 5 minutes

---

For more information, see:
- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)
- [Phoenix Testing Guide](https://hexdocs.pm/phoenix/testing.html)
- [Mox Documentation](https://hexdocs.pm/mox/Mox.html)
- [Test Coverage Best Practices](https://hexdocs.pm/excoveralls/readme.html)