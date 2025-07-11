# WandererApp Test Code Quality Standards

This document defines the quality standards and best practices for test code in the WandererApp project. All contributors should follow these standards to maintain a high-quality, maintainable test suite.

## Table of Contents

1. [Test Organization](#test-organization)
2. [Naming Conventions](#naming-conventions)
3. [Test Structure](#test-structure)
4. [Assertions & Expectations](#assertions--expectations)
5. [Test Data Management](#test-data-management)
6. [Mocking & Stubbing](#mocking--stubbing)
7. [Performance Standards](#performance-standards)
8. [Documentation Requirements](#documentation-requirements)
9. [Code Review Checklist](#code-review-checklist)

## Test Organization

### File Structure

```
test/
├── unit/           # Pure unit tests (no external dependencies)
├── integration/    # Integration tests (may use database, etc.)
├── contract/       # API contract validation tests
├── e2e/           # End-to-end tests (future)
└── support/       # Test helpers and utilities
```

### Module Organization

```elixir
defmodule WandererAppWeb.MapAPIControllerTest do
  # 1. Use statements
  use WandererAppWeb.ConnCase, async: true
  
  # 2. Aliases (alphabetically sorted)
  alias WandererApp.Api
  alias WandererApp.Test.Factory
  
  # 3. Module attributes
  @valid_attrs %{name: "Test Map", description: "Test"}
  @invalid_attrs %{name: nil}
  
  # 4. Setup callbacks
  setup :create_user
  setup :create_map
  
  # 5. Test cases grouped by describe blocks
  describe "index/2" do
    # Tests for index action
  end
  
  describe "create/2" do
    # Tests for create action
  end
  
  # 6. Private helper functions at the bottom
  defp create_user(_), do: # ...
  defp create_map(_), do: # ...
end
```

## Naming Conventions

### Test Files

- **Pattern**: `{module_name}_test.exs`
- **Examples**:
  - `map_controller_test.exs`
  - `user_auth_test.exs`
  - `system_factory_test.exs`

### Test Names

- Start with an action verb
- Be descriptive but concise
- Include the condition and expected outcome
- Use consistent terminology

```elixir
# ✅ Good test names
test "returns user's maps when authenticated"
test "creates system with valid attributes"
test "returns 404 when map not found"
test "broadcasts update to all connected clients"
test "rate limits requests after threshold exceeded"

# ❌ Bad test names
test "test maps"
test "it works"
test "map creation"
test "error"
```

### Describe Blocks

- Use function names for unit tests: `describe "calculate_distance/2"`
- Use endpoint paths for API tests: `describe "POST /api/maps/:id/systems"`
- Use feature names for integration tests: `describe "user authentication flow"`

## Test Structure

### Standard Test Template

```elixir
test "descriptive test name", %{conn: conn, user: user} do
  # Arrange - Set up test data
  map = Factory.create_map(%{user_id: user.id})
  system_params = build_system_params()
  
  # Act - Perform the action
  conn = post(conn, "/api/maps/#{map.id}/systems", system_params)
  
  # Assert - Verify the outcome
  assert response = json_response(conn, 201)
  assert response["data"]["id"]
  assert response["data"]["attributes"]["name"] == system_params["name"]
  
  # Additional assertions for side effects
  assert_broadcast "system:created", %{system: _}
  assert Repo.get_by(System, name: system_params["name"])
end
```

### Setup Callbacks

```elixir
# Use named setup functions for clarity
setup :create_test_user
setup :authenticate_connection

# Prefer named functions over anonymous functions
setup do
  user = Factory.create_user()
  {:ok, user: user}
end

# Better:
setup :create_user

defp create_user(_) do
  user = Factory.create_user()
  {:ok, user: user}
end
```

### Test Isolation

- Each test must be independent
- Use `async: true` when possible
- Clean up after tests using `on_exit` callbacks
- Don't rely on test execution order

```elixir
setup do
  # Set up test data
  file_path = "/tmp/test_#{System.unique_integer()}.txt"
  File.write!(file_path, "test content")
  
  # Ensure cleanup
  on_exit(fn ->
    File.rm(file_path)
  end)
  
  {:ok, file_path: file_path}
end
```

## Assertions & Expectations

### Assertion Guidelines

```elixir
# ✅ Specific assertions
assert user.name == "John Doe"
assert length(items) == 3
assert {:ok, %User{} = user} = Api.create_user(attrs)
assert %{"data" => %{"id" => ^expected_id}} = json_response(conn, 200)

# ❌ Vague assertions
assert user
assert items != []
assert response
```

### Pattern Matching in Assertions

```elixir
# Use pattern matching for precise assertions
assert {:ok, %System{} = system} = Api.create_system(attrs)
assert %{
  "data" => %{
    "type" => "system",
    "id" => system_id,
    "attributes" => %{
      "name" => "Jita",
      "security" => security
    }
  }
} = json_response(conn, 200)

# Verify specific fields
assert system_id == system.id
assert security > 0.5
```

### Error Assertions

```elixir
# Assert specific errors
assert {:error, changeset} = Api.create_user(%{})
assert "can't be blank" in errors_on(changeset).name

# For API responses
assert %{"errors" => errors} = json_response(conn, 422)
assert %{
  "status" => "422",
  "detail" => detail,
  "source" => %{"pointer" => "/data/attributes/name"}
} = hd(errors)
```

### Async Assertions

```elixir
# Use assert_receive for async operations
Phoenix.PubSub.subscribe(pubsub, "updates")
trigger_async_operation()

assert_receive {:update, %{id: ^expected_id}}, 1000

# Use refute_receive to ensure no message
refute_receive {:update, _}, 100
```

## Test Data Management

### Factory Usage

```elixir
# ✅ Good factory usage
user = Factory.create_user(%{name: "Test User"})
map = Factory.create_map(%{user_id: user.id})
systems = Factory.create_list(3, :system, map_id: map.id)

# Build without persisting
attrs = Factory.build(:user)
params = Factory.params_for(:system)

# Create related data
map = Factory.create_map_with_systems(system_count: 5)

# ❌ Bad factory usage
user = Factory.create_user(%{
  id: 123,  # Don't set IDs manually
  inserted_at: yesterday  # Let the database handle timestamps
})
```

### Test Data Principles

1. **Minimal Data**: Create only what's needed for the test
2. **Explicit Relations**: Make relationships clear in test setup
3. **Realistic Data**: Use realistic values, not "test" or "foo"
4. **Unique Data**: Generate unique values to avoid conflicts

```elixir
# Generate unique data
defp unique_email, do: "user#{System.unique_integer()}@example.com"
defp unique_map_name, do: "Map #{System.unique_integer()}"

# Use realistic data
system_params = %{
  "solar_system_id" => 30000142,  # Real EVE system ID
  "name" => "Jita",
  "security_status" => 0.9,
  "constellation_id" => 20000020
}
```

## Mocking & Stubbing

### Mock Guidelines

```elixir
# Define mocks in test/support/mocks.ex
Mox.defmock(Test.EVEAPIClientMock, for: WandererApp.EVEAPIClient.Behaviour)

# In tests, set up expectations
setup :verify_on_exit!

test "handles EVE API errors gracefully" do
  # Use expect for required calls
  Test.EVEAPIClientMock
  |> expect(:get_character_info, 1, fn character_id ->
    assert character_id == 123456
    {:error, :timeout}
  end)
  
  # Use stub for optional calls
  Test.LoggerMock
  |> stub(:error, fn _msg -> :ok end)
  
  # Test the behavior
  assert {:error, :external_service} = Characters.fetch_info(123456)
end
```

### Mocking Best Practices

1. **Mock at boundaries**: Only mock external services, not internal modules
2. **Verify expectations**: Use `verify_on_exit!` to ensure mocks are called
3. **Be specific**: Set specific expectations rather than permissive stubs
4. **Document mocks**: Explain why mocking is necessary

```elixir
describe "with external service failures" do
  setup :verify_on_exit!
  
  test "retries failed requests up to 3 times" do
    # Document the mock scenario
    # Simulating intermittent network failures
    Test.HTTPClientMock
    |> expect(:get, 3, fn _url ->
      {:error, :timeout}
    end)
    
    assert {:error, :all_retries_failed} = Service.fetch_with_retry(url)
  end
end
```

## Performance Standards

### Test Execution Time

- **Unit tests**: < 10ms per test
- **Integration tests**: < 100ms per test
- **Contract tests**: < 50ms per test
- **Full suite**: < 5 minutes

### Performance Guidelines

```elixir
# Tag slow tests
@tag :slow
test "processes large dataset" do
  # Test implementation
end

# Use async when possible
use WandererAppWeb.ConnCase, async: true

# Optimize database operations
setup do
  # Use database transactions for isolation
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  
  # Batch create test data
  users = Factory.insert_list(10, :user)
  
  {:ok, users: users}
end

# Avoid N+1 queries in tests
test "loads associations efficiently" do
  maps = Map
  |> preload([:systems, :connections])
  |> Repo.all()
  
  # Assertions...
end
```

### Resource Usage

```elixir
# Clean up resources
test "processes file uploads" do
  path = "/tmp/test_upload_#{System.unique_integer()}.txt"
  
  on_exit(fn ->
    File.rm(path)
  end)
  
  # Test implementation
end

# Limit concurrent resources
@tag max_concurrency: 5
test "handles concurrent requests" do
  # Test implementation
end
```

## Documentation Requirements

### Test Documentation

```elixir
defmodule WandererAppWeb.AuthenticationTest do
  @moduledoc """
  Tests for authentication and authorization flows.
  
  These tests cover:
  - User login/logout
  - API key authentication
  - Permission checking
  - Session management
  """
  
  describe "POST /api/login" do
    @tag :auth
    test "returns JWT token with valid credentials" do
      # When testing authentication endpoints, we need to ensure
      # the token contains proper claims and expiration
      
      user = Factory.create_user()
      
      conn = post(conn, "/api/login", %{
        "username" => user.username,
        "password" => "valid_password"
      })
      
      assert %{"token" => token} = json_response(conn, 200)
      assert {:ok, claims} = verify_token(token)
      assert claims["sub"] == user.id
    end
  end
end
```

### Complex Test Documentation

```elixir
test "handles race condition in concurrent map updates" do
  # This test verifies that our optimistic locking prevents
  # lost updates when multiple clients update the same map
  # simultaneously. We simulate this by:
  # 1. Loading the same map in two connections
  # 2. Making different updates
  # 3. Verifying that the second update fails with 409
  
  map = Factory.create_map()
  
  # Client 1 loads the map
  conn1 = get(conn, "/api/maps/#{map.id}")
  version1 = json_response(conn1, 200)["data"]["version"]
  
  # Client 2 loads the map
  conn2 = get(conn, "/api/maps/#{map.id}")
  version2 = json_response(conn2, 200)["data"]["version"]
  
  # Client 1 updates successfully
  conn1 = put(conn1, "/api/maps/#{map.id}", %{
    "version" => version1,
    "name" => "Updated by Client 1"
  })
  assert json_response(conn1, 200)
  
  # Client 2's update should fail
  conn2 = put(conn2, "/api/maps/#{map.id}", %{
    "version" => version2,
    "name" => "Updated by Client 2"
  })
  assert json_response(conn2, 409)["errors"]["detail"] =~ "conflict"
end
```

## Code Review Checklist

### Before Submitting Tests

- [ ] All tests pass locally
- [ ] Tests are properly isolated (can run individually)
- [ ] No hardcoded values or magic numbers
- [ ] Descriptive test names following conventions
- [ ] Appropriate use of `async: true`
- [ ] Factory usage follows guidelines
- [ ] Mocks are properly verified
- [ ] No flaky tests (run multiple times to verify)
- [ ] Performance is acceptable (< 100ms for most tests)
- [ ] Complex tests have documentation
- [ ] Setup/teardown is clean and complete
- [ ] Assertions are specific and meaningful
- [ ] Error cases are tested
- [ ] Edge cases are covered

### Review Points

1. **Test Coverage**
   - Are all code paths tested?
   - Are error conditions handled?
   - Are edge cases covered?

2. **Test Quality**
   - Are tests readable and understandable?
   - Do test names clearly describe what's tested?
   - Are assertions specific enough?

3. **Test Maintainability**
   - Will these tests be stable over time?
   - Are they resilient to small implementation changes?
   - Do they use appropriate abstractions?

4. **Performance Impact**
   - Do tests run quickly?
   - Is database usage optimized?
   - Are external calls properly mocked?

### Common Issues to Avoid

```elixir
# ❌ Brittle tests that break with small changes
test "returns exact JSON structure" do
  assert json_response(conn, 200) == %{
    "data" => %{
      "id" => "123",
      "type" => "user",
      "attributes" => %{
        "name" => "John",
        "email" => "john@example.com",
        "created_at" => "2023-01-01T00:00:00Z",
        "updated_at" => "2023-01-01T00:00:00Z"
      }
    }
  }
end

# ✅ Flexible tests that check important properties
test "returns user data" do
  response = json_response(conn, 200)
  assert response["data"]["type"] == "user"
  assert response["data"]["attributes"]["name"] == "John"
  assert response["data"]["attributes"]["email"] == "john@example.com"
  assert response["data"]["attributes"]["created_at"]
end

# ❌ Tests with race conditions
test "updates are processed in order" do
  spawn(fn -> update_map(map, %{name: "First"}) end)
  spawn(fn -> update_map(map, %{name: "Second"}) end)
  
  Process.sleep(100)
  assert Repo.get!(Map, map.id).name == "Second"
end

# ✅ Deterministic tests
test "last update wins" do
  {:ok, _} = update_map(map, %{name: "First"})
  {:ok, updated} = update_map(map, %{name: "Second"})
  
  assert updated.name == "Second"
  assert Repo.get!(Map, map.id).name == "Second"
end
```

## Continuous Improvement

### Metrics to Track

1. **Test Execution Time**: Monitor and optimize slow tests
2. **Flaky Test Rate**: Identify and fix unstable tests
3. **Coverage Percentage**: Maintain and improve coverage
4. **Test Maintenance Time**: Reduce time spent fixing tests

### Regular Reviews

- Weekly: Review test failures and flaky tests
- Monthly: Analyze test performance metrics
- Quarterly: Update standards based on lessons learned

### Contributing to Standards

These standards are living documentation. To propose changes:

1. Discuss in team meetings or Slack
2. Create a PR with proposed changes
3. Get consensus from team members
4. Update standards and communicate changes

---

Remember: Good tests are an investment in code quality and developer productivity. Take the time to write them well.