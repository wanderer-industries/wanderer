# 🔧 Testing Troubleshooting Guide

This guide helps you diagnose and resolve common testing issues in WandererApp.

## 🚨 Common Issues Quick Reference

| Issue | Quick Fix | Detailed Section |
|-------|-----------|------------------|
| Tests won't run | `mix deps.get && mix ecto.reset` | [Environment Issues](#environment-issues) |
| Flaky tests | Check for race conditions | [Flaky Tests](#flaky-tests) |
| Slow tests | Enable performance monitoring | [Performance Issues](#performance-issues) |
| Database errors | Reset test database | [Database Issues](#database-issues) |
| Authentication failures | Check test setup | [Authentication Issues](#authentication-issues) |
| Memory errors | Check for leaks | [Memory Issues](#memory-issues) |

## 🔍 Diagnostic Commands

### Quick Health Check
```bash
# Check test environment health
mix test.health_check

# Verify dependencies
mix deps.get
mix deps.compile

# Reset everything
mix ecto.reset
mix clean
mix compile
```

### Detailed Diagnostics
```bash
# Run tests with detailed output
mix test --trace --verbose

# Check test coverage
mix test --cover

# Profile memory usage
mix test --profile memory

# Check for compilation issues
mix compile --warnings-as-errors
```

## 🐛 Environment Issues

### Problem: Tests Won't Start

**Symptoms:**
- `mix test` fails to start
- Database connection errors
- Module loading errors

**Quick Fixes:**
```bash
# Reset dependencies
mix deps.clean --all
mix deps.get
mix deps.compile

# Reset database
mix ecto.drop
mix ecto.create
mix ecto.migrate

# Clear build artifacts
mix clean
mix compile
```

**Detailed Diagnosis:**
```bash
# Check Elixir/OTP versions
elixir --version
mix --version

# Verify database connection
mix ecto.ping

# Check environment variables
env | grep MIX
env | grep DATABASE

# Verify test configuration
mix run -e "IO.inspect(Application.get_env(:wanderer_app, WandererApp.Repo))"
```

### Problem: Module Not Found Errors

**Symptoms:**
```
** (UndefinedFunctionError) function MyModule.my_function/1 is undefined or private
```

**Solutions:**
```bash
# Recompile everything
mix clean && mix compile

# Check module exists
find . -name "*.ex" -exec grep -l "defmodule MyModule" {} \;

# Verify module is loaded
mix run -e "Code.ensure_loaded(MyModule)"
```

## 🎲 Flaky Tests

### Identifying Flaky Tests

**Run tests multiple times:**
```bash
# Run same test multiple times
for i in {1..10}; do mix test test/path/to/test.exs:42; done

# Use flaky test detection
mix test.stability test/path/to/test.exs --runs 20

# Check test monitor data
mix run -e "WandererApp.TestMonitor.get_flaky_tests() |> IO.inspect()"
```

### Common Flaky Test Patterns

#### 1. **Race Conditions**

**Problem:**
```elixir
test "async operation completes" do
  start_async_operation()
  Process.sleep(100)  # ❌ Unreliable timing
  assert operation_completed?()
end
```

**Solution:**
```elixir
test "async operation completes" do
  start_async_operation()
  
  # ✅ Use proper synchronization
  assert_receive {:operation_completed, _result}, 5000
  # or
  eventually(fn -> operation_completed?() end, timeout: 5000)
end
```

#### 2. **Shared State**

**Problem:**
```elixir
# ❌ Global state shared between tests
@shared_data %{counter: 0}

test "increment counter" do
  @shared_data = %{@shared_data | counter: @shared_data.counter + 1}
  assert @shared_data.counter == 1  # Fails if run after other tests
end
```

**Solution:**
```elixir
# ✅ Isolated test state
test "increment counter" do
  initial_data = %{counter: 0}
  updated_data = %{initial_data | counter: initial_data.counter + 1}
  assert updated_data.counter == 1
end
```

#### 3. **Time-Dependent Tests**

**Problem:**
```elixir
test "timestamp is recent" do
  timestamp = DateTime.utc_now()
  result = create_record()
  
  # ❌ Flaky due to timing
  assert DateTime.diff(result.inserted_at, timestamp) < 1000
end
```

**Solution:**
```elixir
test "timestamp is recent" do
  before_time = DateTime.utc_now()
  result = create_record()
  after_time = DateTime.utc_now()
  
  # ✅ Use time ranges
  assert DateTime.compare(result.inserted_at, before_time) != :lt
  assert DateTime.compare(result.inserted_at, after_time) != :gt
end
```

### Flaky Test Debugging Tools

```elixir
# Add to test helper
defmodule TestHelpers do
  def eventually(assertion_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 100)
    
    eventually_loop(assertion_fn, timeout, interval)
  end
  
  defp eventually_loop(assertion_fn, timeout, interval) when timeout > 0 do
    try do
      assertion_fn.()
    rescue
      _ ->
        Process.sleep(interval)
        eventually_loop(assertion_fn, timeout - interval, interval)
    end
  end
  
  defp eventually_loop(_assertion_fn, _timeout, _interval) do
    raise "Assertion never succeeded within timeout"
  end
end
```

## 🚀 Performance Issues

### Slow Test Suite

**Identify slow tests:**
```bash
# Enable performance monitoring
export PERFORMANCE_MONITORING=true
mix test

# Run performance analysis
mix test.performance --report-only

# Check individual test times
mix test --trace | grep -E "\d+\.\d+ms"
```

**Common performance issues:**

#### 1. **Database Operations**

**Problem:**
```elixir
test "creates many records" do
  # ❌ N+1 database operations
  for i <- 1..100 do
    insert(:user, %{name: "User #{i}"})
  end
end
```

**Solution:**
```elixir
test "creates many records" do
  # ✅ Batch operations
  users = for i <- 1..100, do: %{name: "User #{i}"}
  Repo.insert_all(User, users)
  
  # or use factory batch
  insert_list(100, :user)
end
```

#### 2. **Unnecessary Setup**

**Problem:**
```elixir
setup do
  # ❌ Expensive setup for every test
  user = insert(:user)
  map = insert(:map, %{owner_id: user.id})
  insert_list(100, :system, %{map_id: map.id})
  
  %{user: user, map: map}
end
```

**Solution:**
```elixir
# ✅ Only create what you need
setup :create_minimal_data

defp create_minimal_data(_context) do
  user = insert(:user)
  %{user: user}
end

# Create additional data only in tests that need it
test "with many systems", %{user: user} do
  map = insert(:map, %{owner_id: user.id})
  systems = insert_list(10, :system, %{map_id: map.id})  # Only what's needed
  
  # test logic
end
```

### Memory Issues

**Detect memory leaks:**
```bash
# Monitor memory usage
mix test --profile memory

# Run memory leak detection
mix run -e "
  test_fn = fn -> 
    # Your test code here
  end
  
  WandererApp.PerformanceTestFramework.memory_leak_test(test_fn, 100)
  |> IO.inspect()
"
```

**Common memory issues:**

#### 1. **Large Data Structures**

**Problem:**
```elixir
test "processes large dataset" do
  # ❌ Creates large objects that aren't cleaned up
  large_data = for i <- 1..100_000, do: %{id: i, data: String.duplicate("x", 1000)}
  
  result = process_data(large_data)
  assert length(result) == 100_000
end
```

**Solution:**
```elixir
test "processes large dataset" do
  # ✅ Stream processing or smaller batches
  result = 
    1..100_000
    |> Stream.map(&%{id: &1, data: "x"})
    |> Stream.chunk_every(1000)
    |> Enum.reduce([], fn batch, acc ->
      processed = process_batch(batch)
      acc ++ processed
    end)
  
  assert length(result) == 100_000
end
```

#### 2. **Process Leaks**

**Problem:**
```elixir
test "spawns background processes" do
  # ❌ Processes not cleaned up
  pid = spawn(fn -> background_work() end)
  
  # test logic
  # Process is never cleaned up
end
```

**Solution:**
```elixir
test "spawns background processes" do
  # ✅ Proper cleanup
  {:ok, pid} = GenServer.start_link(MyWorker, [])
  
  # test logic
  
  # Cleanup
  on_exit(fn ->
    if Process.alive?(pid) do
      GenServer.stop(pid)
    end
  end)
end
```

## 🗄️ Database Issues

### Database Connection Problems

**Symptoms:**
- `** (DBConnection.ConnectionError)`
- Database timeout errors
- Connection pool exhausted

**Solutions:**
```bash
# Reset database
mix ecto.reset

# Check database status
mix ecto.ping

# Verify connection configuration
mix run -e "
  config = Application.get_env(:wanderer_app, WandererApp.Repo)
  IO.inspect(config, label: 'Database Config')
"
```

### Sandbox Issues

**Problem: Tests interfere with each other**
```elixir
# ❌ Data persists between tests
test "creates user" do
  user = insert(:user, %{email: "test@example.com"})
  assert user.id
end

test "user email is unique" do
  # This might fail if previous test data persists
  assert_raise Ecto.ConstraintError, fn ->
    insert(:user, %{email: "test@example.com"})
  end
end
```

**Solution:**
```elixir
# ✅ Proper sandbox setup in test_helper.exs
Ecto.Adapters.SQL.Sandbox.mode(WandererApp.Repo, :manual)

# In test case
setup tags do
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WandererApp.Repo, shared: not tags[:async])
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  :ok
end
```

### Migration Issues

**Problem: Schema out of sync**
```bash
# Check migration status
mix ecto.migrations

# Reset if needed
mix ecto.drop
mix ecto.create
mix ecto.migrate

# Or rollback specific migration
mix ecto.rollback --step 1
```

## 🔐 Authentication Issues

### API Authentication Problems

**Problem: 401 Unauthorized errors**

**Check authentication setup:**
```elixir
# Verify API key setup
setup :setup_map_authentication

test "authenticated request", %{conn: conn} do
  # conn should have authorization header
  headers = conn.req_headers
  auth_header = Enum.find(headers, fn {name, _value} -> 
    String.downcase(name) == "authorization" 
  end)
  
  assert auth_header, "Missing authorization header"
end
```

**Manual authentication setup:**
```elixir
test "manual auth setup" do
  map = insert(:map)
  
  conn = build_conn()
    |> put_req_header("authorization", "Bearer #{map.public_api_key}")
    |> put_req_header("content-type", "application/json")
  
  # Use authenticated conn
end
```

### Session Issues

**Problem: Session data not persisting**
```elixir
# ✅ Proper session setup
conn = conn
  |> init_test_session(%{})
  |> put_session(:user_id, user.id)
```

## 🎭 Mock and Stub Issues

### Mock Not Working

**Problem:**
```elixir
test "calls external service" do
  expect(ExternalAPI.Mock, :call, fn -> {:ok, "response"} end)
  
  # ❌ Mock expectation not met
  result = MyModule.call_external_service()
  assert result == {:ok, "response"}
end
```

**Debug mocks:**
```elixir
test "debug mock calls" do
  # Verify mock is set up
  expect(ExternalAPI.Mock, :call, fn -> 
    IO.puts("Mock called!")  # Debug output
    {:ok, "response"} 
  end)
  
  # Verify the actual call path
  result = MyModule.call_external_service()
  
  # Verify mock was called
  verify!(ExternalAPI.Mock)
  
  assert result == {:ok, "response"}
end
```

### Stub Conflicts

**Problem: Multiple stubs for same function**
```elixir
# ❌ Conflicting stubs
stub(MyMock, :function, fn -> :first_result end)
stub(MyMock, :function, fn -> :second_result end)  # Overwrites first
```

**Solution:**
```elixir
# ✅ Use expect with different arguments
expect(MyMock, :function, fn :arg1 -> :first_result end)
expect(MyMock, :function, fn :arg2 -> :second_result end)

# or use different test contexts
describe "with first stub" do
  setup do
    stub(MyMock, :function, fn -> :first_result end)
    :ok
  end
  
  test "..." do
    # Test with first stub
  end
end
```

## 📊 Contract and OpenAPI Issues

### Schema Validation Failures

**Problem: Response doesn't match schema**
```
OpenAPI validation failed: Response does not match schema
```

**Debug schema issues:**
```elixir
test "debug schema validation" do
  conn = get(build_conn(), "/api/endpoint")
  response = json_response(conn, 200)
  
  # Print actual response structure
  IO.inspect(response, label: "Actual Response")
  
  # Check against schema manually
  schema = MyAPISpec.spec().paths["/api/endpoint"].get.responses["200"]
  IO.inspect(schema, label: "Expected Schema")
  
  # Use contract validation
  assert_schema(response, "EndpointResponse", MyAPISpec.spec())
end
```

### Schema Mismatch Solutions

```elixir
# Update schema to match implementation
defmodule MyAPISpec do
  def spec do
    %OpenApiSpex.OpenApi{
      # ... other config
      components: %OpenApiSpex.Components{
        schemas: %{
          "EndpointResponse" => %OpenApiSpex.Schema{
            type: :object,
            properties: %{
              data: %OpenApiSpex.Schema{type: :array},
              # Add missing fields found in debug output
              metadata: %OpenApiSpex.Schema{type: :object}
            }
          }
        }
      }
    }
  end
end
```

## 🔄 CI/CD Issues

### Tests Pass Locally But Fail in CI

**Common causes:**
1. **Environment differences**
2. **Timing issues** 
3. **Resource constraints**
4. **Parallel execution problems**

**Debug CI failures:**
```bash
# Run tests with CI-like settings locally
mix test --max-cases 1  # Disable parallelization
mix test --include integration  # Include all test types

# Check for environment-specific issues
MIX_ENV=test mix test

# Verify CI environment variables
env | grep -E "(MIX|DB|DATABASE)"
```

### Parallel Test Issues

**Problem: Tests fail when run in parallel**
```elixir
# ❌ Shared resources
test "updates global config" do
  Application.put_env(:my_app, :setting, :new_value)
  # This affects other parallel tests
end

# ✅ Isolated resources
test "updates config safely" do
  original_value = Application.get_env(:my_app, :setting)
  
  on_exit(fn ->
    Application.put_env(:my_app, :setting, original_value)
  end)
  
  Application.put_env(:my_app, :setting, :new_value)
  # Test logic
end
```

## 🛠️ Advanced Debugging Techniques

### Interactive Debugging

```elixir
test "debug with IEx" do
  data = create_test_data()
  
  # Break into IEx for debugging
  require IEx; IEx.pry
  
  result = process_data(data)
  assert result.status == :ok
end
```

### Logging and Tracing

```elixir
# Enable detailed logging in test
Logger.configure(level: :debug)

test "with detailed logging" do
  Logger.debug("Starting test with data: #{inspect(test_data)}")
  
  result = process_data(test_data)
  
  Logger.debug("Process result: #{inspect(result)}")
  
  assert result.status == :ok
end
```

### Test Profiling

```bash
# Profile test execution
mix profile.fprof test/path/to/test.exs

# Memory profiling
mix profile.eprof test/path/to/test.exs

# Custom profiling
mix test --profile time
```

## 📋 Troubleshooting Checklist

When tests fail, work through this checklist:

### Environment Check
- [ ] `mix deps.get` completed successfully
- [ ] `mix compile` shows no errors
- [ ] `mix ecto.migrate` applied all migrations
- [ ] Database connection works (`mix ecto.ping`)
- [ ] Environment variables are set correctly

### Test Isolation Check
- [ ] Tests pass when run individually
- [ ] Tests pass when run in different orders
- [ ] No shared state between tests
- [ ] Proper setup and teardown

### Performance Check
- [ ] Tests complete within reasonable time
- [ ] No memory leaks detected
- [ ] Database queries are optimized
- [ ] Parallel execution doesn't cause issues

### Mock and Integration Check
- [ ] All mocks are properly set up
- [ ] External dependencies are stubbed
- [ ] Authentication is configured correctly
- [ ] OpenAPI schemas match responses

## 🆘 Getting Help

### Escalation Path
1. **Check this troubleshooting guide**
2. **Search existing documentation** in `test/` directory
3. **Run diagnostic commands** from this guide
4. **Create minimal reproduction** of the issue
5. **Reach out to the team** with detailed information

### Information to Include When Asking for Help
- **Exact error message** (full stack trace)
- **Test file and line number** where failure occurs
- **Environment details** (Elixir version, OS, etc.)
- **Steps to reproduce** the issue
- **What you've already tried** from this guide

---

Remember: Most testing issues are environmental or related to test isolation. Start with the basics and work your way up to more complex debugging techniques.