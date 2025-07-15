# 🚀 Testing Quickstart Guide

Welcome to the WandererApp testing ecosystem! This guide will get you up and running with testing in **under 10 minutes**.

## 📋 Prerequisites

- Elixir 1.14+ installed
- Phoenix framework knowledge
- Basic understanding of ExUnit
- Database setup completed (`mix setup`)

## 🏃‍♂️ Quick Setup (2 minutes)

### 1. Install Dependencies
```bash
mix deps.get
```

### 2. Setup Test Database
```bash
mix setup
```

### 3. Run Your First Tests
```bash
# Run all tests
mix test

# Run with performance monitoring
PERFORMANCE_MONITORING=true mix test

# Run with real-time dashboard
mix test.performance --dashboard
```

🎉 **Success!** If tests pass, you're ready to start testing.

## 🧪 Test Types Overview

WandererApp uses **4 main test types**:

| Type | Purpose | Example | Run Command |
|------|---------|---------|-------------|
| **Unit** | Test individual functions | `test/unit/map/operations/systems_test.exs` | `mix test test/unit/` |
| **Integration** | Test API endpoints | `test/integration/api/map_api_controller_test.exs` | `mix test test/integration/` |
| **Contract** | Validate OpenAPI schemas | `test/contract/error_response_contract_test.exs` | `mix test test/contract/` |
| **Performance** | Monitor performance | `test/performance/api_performance_test.exs` | `mix test.performance` |

## 📂 Test Directory Structure

```
test/
├── unit/                    # 🔬 Pure unit tests
│   ├── map/                 # Map-related functionality
│   ├── character/           # Character management
│   └── user/                # User operations
├── integration/             # 🔗 API integration tests
│   ├── api/                 # API endpoint tests
│   └── web/                 # Web interface tests
├── contract/                # 📋 OpenAPI contract tests
├── performance/             # ⚡ Performance tests
├── manual/                  # 🛠️ Manual testing scripts
└── support/                 # 🎯 Test helpers & utilities
    ├── factories/           # Test data factories
    ├── helpers/             # Test helper functions
    └── mocks/               # Mock implementations
```

## ✍️ Writing Your First Test

### Unit Test Example
```elixir
defmodule WandererApp.Map.Operations.MyFeatureTest do
  use WandererApp.DataCase, async: true
  
  alias WandererApp.Map.Operations.MyFeature
  
  describe "my_function/2" do
    test "returns success for valid input" do
      # Arrange
      input = %{name: "test", value: 42}
      
      # Act
      result = MyFeature.my_function(input)
      
      # Assert
      assert {:ok, processed} = result
      assert processed.name == "test"
      assert processed.value == 42
    end
    
    test "returns error for invalid input" do
      # Arrange
      invalid_input = %{name: nil}
      
      # Act & Assert
      assert {:error, :invalid_name} = MyFeature.my_function(invalid_input)
    end
  end
end
```

### Integration Test Example
```elixir
defmodule WandererAppWeb.MyAPIControllerTest do
  use WandererAppWeb.ApiCase, async: true
  
  describe "GET /api/my-endpoint" do
    setup :setup_map_authentication
    
    test "returns success with valid data", %{conn: conn} do
      # Act
      conn = get(conn, "/api/my-endpoint")
      
      # Assert
      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
    end
    
    test "returns 401 without authentication" do
      # Act
      conn = build_conn() |> get("/api/my-endpoint")
      
      # Assert
      assert json_response(conn, 401)
    end
  end
end
```

### Performance Test Example
```elixir
defmodule WandererApp.MyPerformanceTest do
  use WandererApp.PerformanceTestFramework, test_type: :api_test
  
  performance_test "API should respond quickly", budget: 500 do
    # Test code that must complete within 500ms
    conn = get(build_conn(), "/api/fast-endpoint")
    assert json_response(conn, 200)
  end
end
```

## 🎯 Common Testing Patterns

### 1. **Using Factories**
```elixir
# Create test data
user = insert(:user)
character = insert(:character, %{user_id: user.id})
map = insert(:map, %{owner_id: character.id})

# Build without persisting
user_attrs = build(:user) |> Map.from_struct()
```

### 2. **Authentication Setup**
```elixir
setup :setup_map_authentication

# Or manually:
conn = build_conn()
  |> put_req_header("authorization", "Bearer #{api_key}")
  |> put_req_header("content-type", "application/json")
```

### 3. **Testing Async Operations**
```elixir
test "async operation completes" do
  # Start async operation
  task = Task.async(fn -> long_running_operation() end)
  
  # Wait for completion
  result = Task.await(task, :timer.seconds(30))
  
  assert {:ok, _} = result
end
```

### 4. **Database Transactions**
```elixir
test "database operation" do
  # Test runs in transaction, automatically rolled back
  user = insert(:user)
  
  assert user.id
  # No cleanup needed - automatic rollback
end
```

## 🔧 Development Workflow

### Running Tests During Development
```bash
# Run tests continuously (file watcher)
mix test.watch

# Run specific test file
mix test test/unit/my_test.exs

# Run specific test
mix test test/unit/my_test.exs:42

# Run with debugging
iex -S mix test test/unit/my_test.exs
```

### Performance Monitoring
```bash
# Enable performance monitoring
export PERFORMANCE_MONITORING=true
mix test

# Start performance dashboard
mix test.performance --dashboard
# Visit: http://localhost:4001
```

### Debugging Failed Tests
```bash
# Run only failed tests
mix test --failed

# Run with detailed output
mix test --trace

# Run with coverage
mix test --cover
```

## 📊 Performance Testing

### Basic Performance Test
```elixir
performance_test "should be fast", budget: 200 do
  # Test code here
end
```

### Load Testing
```elixir
test "load test endpoint" do
  endpoint_config = %{
    method: :get,
    path: "/api/endpoint",
    headers: [],
    body: nil
  }
  
  load_config = %{
    concurrent_users: 10,
    duration_seconds: 30
  }
  
  results = load_test_endpoint(endpoint_config, load_config)
  assert results.success_rate >= 0.95
end
```

## 🚨 Common Pitfalls & Solutions

### ❌ **Problem**: Tests fail randomly
```elixir
# Bad: Shared state between tests
setup do
  @shared_data = create_data()
end

# Good: Isolated test data
setup do
  %{data: create_data()}
end
```

### ❌ **Problem**: Slow tests
```elixir
# Bad: Synchronous operations
test "slow test" do
  Enum.each(1..100, fn _ -> 
    create_user() |> process_user()
  end)
end

# Good: Batch operations or async
test "fast test" do
  users = insert_list(100, :user)
  process_users_batch(users)
end
```

### ❌ **Problem**: Flaky tests
```elixir
# Bad: Time-dependent tests
test "time sensitive" do
  start_time = DateTime.utc_now()
  result = async_operation()
  end_time = DateTime.utc_now()
  
  assert DateTime.diff(end_time, start_time) < 1000
end

# Good: Mock time or use proper waiting
test "with proper waiting" do
  task = async_operation()
  assert_receive {:completed, _result}, 5000
end
```

## 🔍 Test Quality Checklist

Before submitting your tests, ensure:

- [ ] **Tests are isolated** - No shared state between tests
- [ ] **Tests are deterministic** - Same result every time
- [ ] **Tests are fast** - Unit tests < 100ms, Integration < 2s
- [ ] **Tests have clear names** - Describe what they test
- [ ] **Tests follow AAA pattern** - Arrange, Act, Assert
- [ ] **Edge cases are covered** - Error conditions and boundaries
- [ ] **Performance budgets met** - Tests complete within expected time
- [ ] **Documentation updated** - Complex tests are documented

## 🎓 Next Steps

### For Unit Testing
1. Read: [`test/STANDARDS.md`](STANDARDS.md) - Testing standards and best practices
2. Study: [`test/EXAMPLES.md`](EXAMPLES.md) - Comprehensive testing examples
3. Practice: [`test/unit/`](unit/) - Existing unit test examples

### For Integration Testing
1. Study: [`test/integration/`](integration/) - API testing patterns
2. Learn: [`test/support/api_case.ex`](support/api_case.ex) - API test utilities
3. Practice: Write API tests for new endpoints

### For Performance Testing
1. Read: [`test/performance/README.md`](performance/README.md) - Performance testing guide
2. Try: `mix test.performance --dashboard` - Real-time monitoring
3. Create: Performance tests for critical paths

### For Advanced Topics
1. **OpenAPI Contract Testing**: [`test/contract/`](contract/)
2. **Mock Systems**: [`test/support/mocks/`](support/mocks/)
3. **Factory Patterns**: [`test/support/factories/`](support/factories/)
4. **Performance Optimization**: [`test/support/test_optimizer.ex`](support/test_optimizer.ex)

## 🆘 Getting Help

### Quick References
- **Test Commands**: `mix help test`
- **Performance Tools**: `mix test.performance --help`
- **Factory Usage**: Check `test/support/factory.ex`

### Documentation
- **Detailed Standards**: [`test/STANDARDS.md`](STANDARDS.md)
- **Comprehensive Examples**: [`test/EXAMPLES.md`](EXAMPLES.md)
- **Performance Guide**: [`test/performance/README.md`](performance/README.md)

### Troubleshooting
- **Database Issues**: `mix ecto.reset`
- **Dependency Issues**: `mix deps.clean --all && mix deps.get`
- **Test Environment**: `mix test --trace` for detailed output

---

🎉 **You're ready to test!** Start with simple unit tests and gradually work your way up to integration and performance testing.

For questions or issues, check the detailed documentation in the `test/` directory or reach out to the development team.