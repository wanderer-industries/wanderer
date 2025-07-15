# 📏 Consolidated Testing Standards

This document consolidates and standardizes testing patterns across WandererApp to ensure consistency, maintainability, and quality.

## 🎯 Testing Philosophy

### Core Principles
1. **Tests as Documentation** - Tests should clearly explain what the code does
2. **Fast Feedback** - Tests should run quickly and provide immediate feedback
3. **Deterministic** - Tests should produce the same result every time
4. **Isolated** - Tests should not depend on or affect other tests
5. **Maintainable** - Tests should be easy to understand and modify

### Testing Pyramid
```
    🔺 E2E Tests (Few)
      🔺 Integration Tests (Some)
        🔺 Unit Tests (Many)
```

## 📋 Standardized Test Patterns

### 1. **Test Structure Standard (AAA Pattern)**

**✅ Required Structure:**
```elixir
test "descriptive test name explaining what it tests" do
  # 🅰️ ARRANGE - Set up test data and conditions
  user = insert(:user, %{name: "Test User"})
  params = %{email: "new@example.com"}
  
  # 🅰️ ACT - Execute the function being tested
  result = UserService.update_email(user, params)
  
  # 🅰️ ASSERT - Verify the expected outcome
  assert {:ok, updated_user} = result
  assert updated_user.email == "new@example.com"
end
```

**❌ Avoid:**
```elixir
# Bad: Unclear test name
test "user test" do
  # Bad: Mixed arrange/act/assert without clear separation
  user = insert(:user)
  result = UserService.update_email(user, %{email: "new@example.com"})
  assert {:ok, _} = result
  user2 = insert(:user)  # Bad: More arrangement after action
end
```

### 2. **Test Naming Standards**

**✅ Required Format:**
```elixir
describe "function_name/arity" do
  test "returns success when given valid input" do
  test "returns error when input is invalid" do
  test "raises exception when input is nil" do
  test "handles edge case with empty list" do
end

describe "API endpoint behavior" do
  test "GET /api/resource returns 200 with valid data" do
  test "GET /api/resource returns 401 without authentication" do
  test "POST /api/resource creates new resource successfully" do
end
```

**❌ Avoid:**
```elixir
# Bad: Vague or non-descriptive names
test "it works" do
test "user stuff" do
test "test 1" do
test "basic test" do
```

### 3. **Setup and Teardown Standards**

#### Standard Setup Pattern:
```elixir
defmodule MyModuleTest do
  use WandererApp.DataCase, async: true
  
  # ✅ Use setup for common test data
  setup do
    user = insert(:user)
    %{user: user}
  end
  
  # ✅ Use setup with context for conditional setup
  setup %{requires_admin: true} do
    admin = insert(:user, %{role: :admin})
    %{admin: admin}
  end
  
  # ✅ Use setup callbacks for specific needs
  setup :create_test_map
  
  defp create_test_map(_context) do
    map = insert(:map)
    %{map: map}
  end
end
```

#### Standard Teardown Pattern:
```elixir
test "with cleanup required" do
  # Setup
  {:ok, pid} = GenServer.start_link(MyServer, [])
  
  # Register cleanup
  on_exit(fn ->
    if Process.alive?(pid) do
      GenServer.stop(pid)
    end
  end)
  
  # Test logic
end
```

### 4. **Assertion Standards**

#### Standard Assertion Patterns:
```elixir
# ✅ Pattern matching for complex returns
assert {:ok, %{id: id, name: name}} = UserService.create(params)
assert is_binary(id)
assert name == "Expected Name"

# ✅ Multiple specific assertions rather than one complex
assert result.status == :ok
assert result.data.count == 5
assert length(result.data.items) == 5

# ✅ Use appropriate assertion functions
assert_in_delta 3.14, result.pi, 0.01  # For floating point
assert_receive {:message, _data}, 5000   # For async operations
assert_raise ArgumentError, fn -> invalid_function() end
```

#### Error Handling Assertions:
```elixir
# ✅ Standard error assertion pattern
assert {:error, reason} = MyModule.risky_function(invalid_params)
assert reason in [:invalid_input, :not_found, :timeout]

# ✅ Exception assertion with message validation
assert_raise ArgumentError, ~r/cannot be nil/, fn ->
  MyModule.function_with_validation(nil)
end
```

### 5. **Factory Usage Standards**

#### Standard Factory Patterns:
```elixir
# ✅ Basic factory usage
user = insert(:user)
character = insert(:character, %{user_id: user.id})

# ✅ Factory with overrides
premium_user = insert(:user, %{subscription: :premium})

# ✅ Factory lists for bulk data
users = insert_list(5, :user)

# ✅ Build without persisting
user_attrs = build(:user) |> Map.from_struct()

# ✅ Factory with associations
map_with_systems = insert(:map_with_systems, systems_count: 10)
```

#### Factory Definition Standards:
```elixir
# ✅ Standard factory definition
def user_factory do
  %WandererApp.Api.User{
    eve_id: sequence(:eve_id, &"eve_#{&1}"),
    name: sequence(:name, &"User #{&1}"),
    email: sequence(:email, &"user#{&1}@example.com"),
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  }
end

# ✅ Factory with traits
def user_factory(attrs) do
  user = %WandererApp.Api.User{
    # ... base attributes
  }
  
  # Apply traits
  case attrs[:trait] do
    :admin -> %{user | role: :admin}
    :premium -> %{user | subscription: :premium}
    _ -> user
  end
end
```

## 🔗 API Testing Standards

### 1. **Integration Test Structure**

```elixir
defmodule WandererAppWeb.MyAPIControllerTest do
  use WandererAppWeb.ApiCase, async: true
  
  describe "GET /api/resource" do
    setup :setup_map_authentication
    
    test "returns 200 with valid data", %{conn: conn, map: map} do
      # Arrange
      resource = insert(:resource, %{map_id: map.id})
      
      # Act
      conn = get(conn, ~p"/api/maps/#{map.slug}/resources")
      
      # Assert
      assert %{"data" => [returned_resource]} = json_response(conn, 200)
      assert returned_resource["id"] == resource.id
    end
    
    test "returns 404 for non-existent map", %{conn: conn} do
      # Act
      conn = get(conn, ~p"/api/maps/nonexistent/resources")
      
      # Assert
      assert %{"error" => "Map not found"} = json_response(conn, 404)
    end
    
    test "returns 401 without authentication" do
      # Act
      conn = build_conn() |> get(~p"/api/maps/test/resources")
      
      # Assert
      assert json_response(conn, 401)
    end
  end
end
```

### 2. **Authentication Test Standards**

```elixir
# ✅ Standard authentication setup
setup :setup_map_authentication

# ✅ Custom authentication when needed
setup do
  user = insert(:user)
  character = insert(:character, %{user_id: user.id})
  map = insert(:map, %{owner_id: character.id})
  
  conn = build_conn()
    |> put_req_header("authorization", "Bearer #{map.public_api_key}")
    |> put_req_header("content-type", "application/json")
  
  %{conn: conn, map: map, user: user, character: character}
end
```

### 3. **Response Validation Standards**

```elixir
# ✅ Standard response validation
test "returns properly formatted response", %{conn: conn} do
  conn = get(conn, "/api/endpoint")
  
  response = json_response(conn, 200)
  
  # Validate response structure
  assert %{"data" => data, "meta" => meta} = response
  assert is_list(data)
  assert %{"total" => total, "page" => page} = meta
  assert is_integer(total)
  assert is_integer(page)
  
  # Validate data content
  if length(data) > 0 do
    first_item = hd(data)
    assert %{"id" => _, "name" => _, "created_at" => _} = first_item
  end
end
```

## 🔬 Unit Testing Standards

### 1. **Pure Function Testing**

```elixir
describe "pure_function/2" do
  test "returns expected result for valid input" do
    # Arrange
    input_a = "valid_string"
    input_b = 42
    
    # Act
    result = MyModule.pure_function(input_a, input_b)
    
    # Assert
    assert result == "expected_output"
  end
  
  test "handles edge cases" do
    # Test boundary conditions
    assert MyModule.pure_function("", 0) == ""
    assert MyModule.pure_function("x", 1) == "x"
    
    # Test error conditions
    assert_raise ArgumentError, fn ->
      MyModule.pure_function(nil, 42)
    end
  end
end
```

### 2. **Stateful Module Testing**

```elixir
describe "GenServer behavior" do
  setup do
    {:ok, pid} = MyGenServer.start_link([])
    %{server: pid}
  end
  
  test "maintains state correctly", %{server: server} do
    # Initial state
    assert MyGenServer.get_state(server) == %{}
    
    # State modification
    :ok = MyGenServer.update_state(server, %{key: "value"})
    assert MyGenServer.get_state(server) == %{key: "value"}
  end
end
```

### 3. **Database Operation Testing**

```elixir
describe "database operations" do
  test "creates record successfully" do
    # Arrange
    attrs = %{name: "Test", email: "test@example.com"}
    
    # Act
    assert {:ok, record} = MyRepo.create_record(attrs)
    
    # Assert
    assert record.id
    assert record.name == "Test"
    assert record.email == "test@example.com"
    
    # Verify persistence
    persisted = MyRepo.get_record(record.id)
    assert persisted.name == "Test"
  end
  
  test "validates required fields" do
    # Test validation failures
    assert {:error, changeset} = MyRepo.create_record(%{})
    assert %{name: ["can't be blank"]} = errors_on(changeset)
  end
end
```

## ⚡ Performance Testing Standards

### 1. **Performance Test Structure**

```elixir
defmodule MyPerformanceTest do
  use WandererApp.PerformanceTestFramework, test_type: :api_test
  
  performance_test "critical operation should be fast", budget: 500 do
    # Arrange
    data = create_test_data()
    
    # Act & Assert (within performance budget)
    result = CriticalOperation.perform(data)
    assert result.status == :ok
  end
  
  benchmark_test "database query performance", max_avg_time: 100 do
    # This will be benchmarked multiple times
    query_result = Repo.all(User)
    assert length(query_result) >= 0
  end
end
```

### 2. **Load Testing Standards**

```elixir
test "API handles concurrent load" do
  endpoint_config = %{
    method: :get,
    path: "/api/high-traffic-endpoint",
    headers: [{"authorization", "Bearer #{api_key}"}],
    body: nil
  }
  
  load_config = %{
    concurrent_users: 20,
    duration_seconds: 30,
    ramp_up_seconds: 5
  }
  
  results = load_test_endpoint(endpoint_config, load_config)
  
  # Standard load test assertions
  assert results.success_rate >= 0.95
  assert results.avg_response_time_ms <= 1000
  assert results.throughput_rps >= 10
end
```

## 🎭 Mock and Stub Standards

### 1. **Mock Definition Standards**

```elixir
# ✅ In test file
import Mox

setup :verify_on_exit!

test "calls external service correctly" do
  # Arrange
  expected_response = {:ok, %{data: "test"}}
  
  expect(ExternalService.Mock, :call_api, fn params ->
    assert params.endpoint == "/test"
    expected_response
  end)
  
  # Act
  result = MyModule.call_external_service(%{endpoint: "/test"})
  
  # Assert
  assert result == expected_response
end
```

### 2. **Stub Usage Standards**

```elixir
# ✅ For consistent behavior across tests
describe "with external service stubbed" do
  setup do
    stub(ExternalService.Mock, :call_api, fn _ -> {:ok, %{default: "response"}} end)
    :ok
  end
  
  test "handles successful response" do
    # Service will return stubbed response
    result = MyModule.process_with_external_service()
    assert result.status == :success
  end
end
```

## 📋 Contract Testing Standards

### 1. **OpenAPI Contract Tests**

```elixir
defmodule MyAPIContractTest do
  use WandererApp.ContractCase, async: true
  
  test "GET /api/endpoint matches OpenAPI schema" do
    # Setup
    setup_test_data()
    
    # Make request
    conn = get(build_authenticated_conn(), "/api/endpoint")
    
    # Validate against OpenAPI schema
    assert_response_matches_schema(conn, 200, "EndpointResponse")
  end
  
  test "error responses match schema" do
    conn = get(build_conn(), "/api/protected-endpoint")  # No auth
    
    # Validate error response format
    assert_response_matches_schema(conn, 401, "ErrorResponse")
  end
end
```

### 2. **Schema Validation Standards**

```elixir
# ✅ Custom schema validation
test "response matches expected structure" do
  conn = get(build_authenticated_conn(), "/api/complex-endpoint")
  response = json_response(conn, 200)
  
  # Validate top-level structure
  assert %{"data" => data, "meta" => meta, "links" => links} = response
  
  # Validate data structure
  assert is_list(data)
  if length(data) > 0 do
    first_item = hd(data)
    assert %{
      "id" => id,
      "type" => type,
      "attributes" => attributes,
      "relationships" => relationships
    } = first_item
    
    assert is_binary(id)
    assert type in ["user", "admin", "guest"]
    assert is_map(attributes)
    assert is_map(relationships)
  end
  
  # Validate meta structure
  assert %{"total" => total, "page" => page, "per_page" => per_page} = meta
  assert is_integer(total) and total >= 0
  assert is_integer(page) and page >= 1
  assert is_integer(per_page) and per_page > 0
end
```

## 🚨 Error Handling Standards

### 1. **Error Testing Patterns**

```elixir
describe "error handling" do
  test "handles invalid input gracefully" do
    # Test various invalid inputs
    invalid_inputs = [nil, "", %{}, [], -1, "invalid"]
    
    for input <- invalid_inputs do
      assert {:error, reason} = MyModule.process(input)
      assert reason in [:invalid_input, :bad_format, :out_of_range]
    end
  end
  
  test "propagates errors from dependencies" do
    # Mock dependency to return error
    expect(Dependency.Mock, :call, fn _ -> {:error, :service_unavailable} end)
    
    # Test error propagation
    assert {:error, :service_unavailable} = MyModule.operation_with_dependency()
  end
end
```

### 2. **Exception Testing Standards**

```elixir
test "raises appropriate exceptions" do
  # Test specific exception types
  assert_raise ArgumentError, ~r/invalid argument/, fn ->
    MyModule.strict_function(invalid_arg)
  end
  
  # Test exception with custom message
  assert_raise MyCustomError, "Specific error message", fn ->
    MyModule.function_that_raises()
  end
end
```

## 📊 Code Quality Standards

### 1. **Test Coverage Requirements**

- **Minimum Overall Coverage**: 80%
- **Critical Path Coverage**: 95%
- **New Code Coverage**: 90%

### 2. **Test Quality Metrics**

- **Maximum Test Duration**: 
  - Unit tests: 100ms
  - Integration tests: 2 seconds
  - Performance tests: 30 seconds
- **Maximum Setup Time**: 50ms per test
- **Flaky Test Rate**: < 5%

### 3. **Documentation Standards**

```elixir
defmodule ComplexModuleTest do
  @moduledoc """
  Tests for ComplexModule functionality.
  
  This module tests the core business logic for complex operations
  including edge cases, error conditions, and performance requirements.
  """
  
  use WandererApp.DataCase, async: true
  
  describe "complex_operation/3" do
    @describedoc """
    Tests for the main complex operation that handles multiple
    input types and returns various result formats.
    """
    
    test "processes valid input correctly" do
      # Clear test description and logic
    end
  end
end
```

## 🔄 Continuous Improvement

### 1. **Test Review Checklist**

Before merging, ensure:
- [ ] All tests follow naming conventions
- [ ] AAA pattern is used consistently
- [ ] Proper setup/teardown
- [ ] Appropriate assertions
- [ ] Error cases covered
- [ ] Performance budgets met
- [ ] No flaky behavior
- [ ] Documentation updated

### 2. **Regular Maintenance**

- **Weekly**: Review flaky test reports
- **Monthly**: Analyze test performance trends
- **Quarterly**: Update testing standards
- **Annually**: Comprehensive test suite review

## 📚 Quick Reference

### Test File Templates

#### Unit Test Template:
```elixir
defmodule WandererApp.MyModuleTest do
  use WandererApp.DataCase, async: true
  
  alias WandererApp.MyModule
  
  describe "function_name/arity" do
    test "returns success for valid input" do
      # Arrange
      
      # Act
      
      # Assert
    end
    
    test "returns error for invalid input" do
      # Test error cases
    end
  end
end
```

#### Integration Test Template:
```elixir
defmodule WandererAppWeb.MyAPIControllerTest do
  use WandererAppWeb.ApiCase, async: true
  
  describe "GET /api/endpoint" do
    setup :setup_map_authentication
    
    test "returns 200 with valid data", %{conn: conn} do
      # Arrange
      
      # Act
      
      # Assert
    end
  end
end
```

#### Performance Test Template:
```elixir
defmodule WandererApp.MyPerformanceTest do
  use WandererApp.PerformanceTestFramework, test_type: :unit_test
  
  performance_test "operation should be fast", budget: 100 do
    # Test within performance budget
  end
end
```

---

These consolidated standards ensure consistency, quality, and maintainability across all tests in WandererApp. Follow these patterns for all new tests and gradually update existing tests to match these standards.