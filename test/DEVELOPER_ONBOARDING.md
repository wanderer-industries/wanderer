# 👥 Developer Testing Onboarding Guide

Welcome to the WandererApp development team! This guide will help you understand our testing culture, practices, and how to contribute effectively to our test suite.

## 🎯 Our Testing Philosophy

### Why We Test

At WandererApp, testing isn't just about finding bugs—it's about:

1. **📚 Documentation**: Tests serve as living documentation of how our code works
2. **🛡️ Safety Net**: Tests give us confidence to refactor and add features
3. **🚀 Speed**: Good tests enable faster development cycles
4. **🤝 Collaboration**: Tests help team members understand each other's code
5. **💰 Quality**: Tests reduce production bugs and support costs

### Our Testing Culture

- **Test-First Mindset**: We write tests before or alongside implementation
- **Quality Over Quantity**: We prefer meaningful tests over high coverage numbers
- **Continuous Improvement**: We regularly refine our testing practices
- **Knowledge Sharing**: We learn from each other and share testing techniques
- **Performance Awareness**: We consider test performance as important as application performance

## 🏗️ Understanding Our Test Architecture

### Test Pyramid Structure

```
       🔺 E2E Tests (5%)
        Slow, Expensive, High Confidence
        Full user journeys, critical paths

      🔺 Integration Tests (20%)
       API endpoints, service interactions
       Database operations, external APIs

    🔺 Unit Tests (75%)
     Fast, Isolated, Low-level
     Business logic, pure functions
```

### Test Types We Use

| Test Type | Purpose | Speed | When to Use |
|-----------|---------|-------|-------------|
| **Unit** | Test individual functions/modules | ⚡ Very Fast | Business logic, utilities, pure functions |
| **Integration** | Test component interactions | 🚀 Fast | API endpoints, database operations |
| **Contract** | Validate API schemas | 🚀 Fast | API responses, OpenAPI compliance |
| **Performance** | Monitor execution speed | ⏱️ Varies | Critical paths, optimization validation |
| **E2E** | Test complete user flows | 🐌 Slow | Happy paths, critical user journeys |

## 🚀 Getting Started (Your First Week)

### Day 1: Environment Setup

1. **Clone and Setup**
   ```bash
   git clone <repository>
   cd wanderer-app
   mix setup
   ```

2. **Run Tests to Verify Setup**
   ```bash
   mix test                    # Basic test run
   mix test --include integration  # With integration tests
   PERFORMANCE_MONITORING=true mix test  # With performance monitoring
   ```

3. **Explore Test Structure**
   ```bash
   find test/ -name "*.exs" | head -10  # See test files
   ls test/                             # Understand structure
   ```

### Day 2-3: Understanding Existing Tests

1. **Study Examples**
   - Read [`test/QUICKSTART.md`](QUICKSTART.md) - 10-minute guide
   - Explore [`test/EXAMPLES.md`](EXAMPLES.md) - Comprehensive examples
   - Review [`test/unit/map/operations/systems_test.exs`](unit/map/operations/systems_test.exs) - Well-structured unit test

2. **Run Different Test Types**
   ```bash
   mix test test/unit/                    # Unit tests only
   mix test test/integration/             # Integration tests
   mix test.performance --dashboard       # Performance tests with dashboard
   ```

3. **Understand Test Helpers**
   - Study [`test/support/factory.ex`](support/factory.ex) - Test data creation
   - Review [`test/support/api_case.ex`](support/api_case.ex) - API testing utilities
   - Check [`test/support/data_case.ex`](support/data_case.ex) - Database testing setup

### Day 4-5: Writing Your First Tests

1. **Find a Simple Bug or Feature**
   - Look for `TODO` comments in the codebase
   - Find small functions without tests
   - Ask your mentor for a beginner-friendly task

2. **Write Your First Unit Test**
   ```elixir
   defmodule WandererApp.Utils.StringHelperTest do
     use WandererApp.DataCase, async: true
     
     alias WandererApp.Utils.StringHelper
     
     describe "capitalize_words/1" do
       test "capitalizes each word in a string" do
         # Arrange
         input = "hello world"
         
         # Act
         result = StringHelper.capitalize_words(input)
         
         # Assert
         assert result == "Hello World"
       end
       
       test "handles empty string" do
         assert StringHelper.capitalize_words("") == ""
       end
       
       test "handles single character" do
         assert StringHelper.capitalize_words("a") == "A"
       end
     end
   end
   ```

3. **Get Your First Test Reviewed**
   - Create a pull request with your test
   - Ask for feedback on structure and style
   - Learn from the review comments

## 📚 Learning Path by Experience Level

### 🌱 Beginner (Weeks 1-2)

**Goals**: Understand basic testing concepts and write simple unit tests

**Learning Tasks**:
- [ ] Read all documentation in `test/` directory
- [ ] Write 5 unit tests for utility functions
- [ ] Understand the factory system
- [ ] Learn basic assertion patterns
- [ ] Practice AAA (Arrange, Act, Assert) pattern

**Practice Exercises**:
```elixir
# Exercise 1: Test a simple function
def calculate_percentage(part, whole) do
  if whole == 0, do: 0, else: (part / whole) * 100
end

# Write tests for:
# - Normal case (part=25, whole=100 -> 25.0)
# - Edge case (part=0, whole=100 -> 0.0)
# - Edge case (part=50, whole=0 -> 0)
# - Boundary case (part=100, whole=100 -> 100.0)
```

**Recommended Reading**:
- [`test/QUICKSTART.md`](QUICKSTART.md) - Essential starter guide
- [`test/STANDARDS_CONSOLIDATED.md`](STANDARDS_CONSOLIDATED.md) - Testing patterns

### 🌿 Intermediate (Weeks 3-4)

**Goals**: Write integration tests, understand mocking, and work with databases

**Learning Tasks**:
- [ ] Write integration tests for API endpoints
- [ ] Learn to use factories effectively
- [ ] Understand and use mocking (Mox)
- [ ] Write database-related tests
- [ ] Learn authentication testing patterns

**Practice Exercises**:
```elixir
# Exercise 2: Test an API endpoint
describe "GET /api/maps/:slug/systems" do
  setup :setup_map_authentication
  
  test "returns systems for map", %{conn: conn, map: map} do
    # Create test data
    system = insert(:map_system, %{map_id: map.id})
    
    # Make request
    conn = get(conn, ~p"/api/maps/#{map.slug}/systems")
    
    # Verify response
    assert %{"data" => [returned_system]} = json_response(conn, 200)
    assert returned_system["id"] == system.id
  end
end
```

**Recommended Reading**:
- [`test/integration/api/`](integration/api/) - Real integration test examples
- [`test/support/mocks/`](support/mocks/) - Mocking patterns

### 🌳 Advanced (Weeks 5-8)

**Goals**: Master complex testing scenarios, performance testing, and test optimization

**Learning Tasks**:
- [ ] Write performance tests with budgets
- [ ] Create complex integration scenarios
- [ ] Use advanced mocking patterns
- [ ] Optimize test performance
- [ ] Debug flaky tests
- [ ] Contribute to testing infrastructure

**Practice Exercises**:
```elixir
# Exercise 3: Performance test with load testing
test "API handles concurrent load" do
  endpoint_config = %{
    method: :get,
    path: "/api/maps/#{map.slug}/systems",
    headers: [{"authorization", "Bearer #{api_key}"}],
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

**Recommended Reading**:
- [`test/performance/README.md`](performance/README.md) - Performance testing guide
- [`test/TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Advanced debugging

## 🎯 Team Collaboration and Standards

### Code Review Process

#### As a Reviewer
- **Check Test Quality**: Are tests clear, isolated, and meaningful?
- **Verify Coverage**: Are new features properly tested?
- **Performance Impact**: Do new tests run efficiently?
- **Standards Compliance**: Do tests follow our established patterns?

#### As an Author
- **Write Tests First**: Include tests in your initial PR
- **Follow Naming Conventions**: Use descriptive test names
- **Add Context**: Explain complex test scenarios in comments
- **Keep Tests Fast**: Ensure tests run quickly and don't slow down the suite

### Common Review Comments and How to Address Them

#### "This test is flaky"
```elixir
# ❌ Problem: Time-dependent test
test "operation completes quickly" do
  start_time = System.monotonic_time()
  perform_operation()
  end_time = System.monotonic_time()
  
  assert (end_time - start_time) < 1000  # Flaky!
end

# ✅ Solution: Remove time dependency
test "operation completes successfully" do
  assert {:ok, result} = perform_operation()
  assert result.status == :completed
end
```

#### "Test is hard to understand"
```elixir
# ❌ Problem: Unclear test intention
test "user test" do
  u = create_user()
  r = update_user(u, %{n: "new"})
  assert r == :ok
end

# ✅ Solution: Clear, descriptive test
test "updates user name successfully" do
  # Arrange
  user = insert(:user, %{name: "Original Name"})
  new_attributes = %{name: "Updated Name"}
  
  # Act
  result = UserService.update(user, new_attributes)
  
  # Assert
  assert {:ok, updated_user} = result
  assert updated_user.name == "Updated Name"
end
```

#### "Missing edge case coverage"
```elixir
# ❌ Problem: Only happy path tested
test "divides numbers" do
  assert Calculator.divide(10, 2) == 5
end

# ✅ Solution: Comprehensive coverage
describe "divide/2" do
  test "divides positive numbers correctly" do
    assert Calculator.divide(10, 2) == 5.0
    assert Calculator.divide(7, 3) == 2.333...
  end
  
  test "handles zero dividend" do
    assert Calculator.divide(0, 5) == 0.0
  end
  
  test "raises error for zero divisor" do
    assert_raise ArithmeticError, fn ->
      Calculator.divide(10, 0)
    end
  end
  
  test "handles negative numbers" do
    assert Calculator.divide(-10, 2) == -5.0
    assert Calculator.divide(10, -2) == -5.0
  end
end
```

### Team Communication

#### Daily Standups
- Mention if you're struggling with test-related issues
- Share insights about testing techniques you've learned
- Ask for help with complex testing scenarios

#### Knowledge Sharing Sessions
- Monthly testing technique sharing sessions
- "Test of the Week" - showcase particularly good tests
- Retrospectives on testing practices and improvements

#### Documentation Contributions
- Update documentation when you learn new patterns
- Add examples for complex scenarios you've solved
- Contribute to troubleshooting guides based on your experience

## 🛠️ Tools and Development Workflow

### Essential Tools

1. **Performance Monitoring**
   ```bash
   # Enable during development
   export PERFORMANCE_MONITORING=true
   
   # Use dashboard for real-time feedback
   mix test.performance --dashboard
   ```

2. **Test Development Workflow**
   ```bash
   # Watch tests during development
   mix test.watch
   
   # Run specific test file
   mix test test/unit/my_module_test.exs
   
   # Run specific test
   mix test test/unit/my_module_test.exs:42
   
   # Debug with IEx
   iex -S mix test test/unit/my_module_test.exs
   ```

3. **Quality Checks**
   ```bash
   # Check test coverage
   mix test --cover
   
   # Run quality report
   mix quality_report
   
   # Check for flaky tests
   mix test.stability test/integration/ --runs 10
   ```

### IDE Setup Recommendations

#### VS Code Extensions
- **ElixirLS**: Language server for Elixir
- **Test Explorer**: Visual test runner
- **GitLens**: For reviewing test changes

#### Vim/Neovim
- **vim-test**: Run tests from within editor
- **nvim-dap**: Debugging support

#### Editor Configuration
```json
// VS Code settings.json
{
  "elixirLS.testCodeLens": true,
  "elixirLS.suggestSpecs": false,
  "files.associations": {
    "*.exs": "elixir"
  }
}
```

## 🎨 Testing Anti-Patterns to Avoid

### 1. **The Kitchen Sink Test**
```elixir
# ❌ Tests too many things at once
test "user operations" do
  user = create_user()
  assert user.name == "Test"
  
  updated = update_user(user, %{email: "new@test.com"})
  assert updated.email == "new@test.com"
  
  deleted = delete_user(updated)
  assert deleted == :ok
  
  found = find_user(user.id)
  assert found == nil
end

# ✅ Split into focused tests
describe "user operations" do
  test "creates user with correct attributes" do
    user = create_user(%{name: "Test"})
    assert user.name == "Test"
  end
  
  test "updates user email" do
    user = insert(:user)
    {:ok, updated} = update_user(user, %{email: "new@test.com"})
    assert updated.email == "new@test.com"
  end
  
  test "deletes user successfully" do
    user = insert(:user)
    assert :ok = delete_user(user)
    assert nil == find_user(user.id)
  end
end
```

### 2. **The Mystery Test**
```elixir
# ❌ Unclear what is being tested
test "it works" do
  result = do_thing()
  assert result
end

# ✅ Clear test intention
test "user authentication returns success for valid credentials" do
  user = insert(:user, %{password: "secret123"})
  
  result = Auth.authenticate(user.email, "secret123")
  
  assert {:ok, authenticated_user} = result
  assert authenticated_user.id == user.id
end
```

### 3. **The Brittle Test**
```elixir
# ❌ Too tightly coupled to implementation
test "user creation calls database exactly 3 times" do
  expect(DB.Mock, :insert, 3, fn _ -> {:ok, %{}} end)
  
  create_user(%{name: "Test"})
  
  verify!(DB.Mock)
end

# ✅ Test behavior, not implementation
test "user creation persists user data" do
  user_attrs = %{name: "Test", email: "test@example.com"}
  
  {:ok, user} = create_user(user_attrs)
  
  assert user.name == "Test"
  assert user.email == "test@example.com"
  assert user.id  # Verify it was persisted
end
```

## 📈 Measuring Your Progress

### Week 1-2 Checklist
- [ ] Successfully run all test types
- [ ] Write 3 unit tests for simple functions
- [ ] Understand factory usage
- [ ] Get first test PR approved
- [ ] Identify and fix 1 test that violates standards

### Week 3-4 Checklist
- [ ] Write 2 integration tests for API endpoints
- [ ] Use mocking in at least 1 test
- [ ] Write tests for a database operation
- [ ] Debug 1 flaky test
- [ ] Contribute to test documentation

### Week 5-8 Checklist
- [ ] Write performance tests with budgets
- [ ] Create complex test scenarios with multiple dependencies
- [ ] Optimize slow test performance
- [ ] Mentor another developer in testing
- [ ] Contribute to testing infrastructure improvement

### Success Metrics
- **Test Quality**: Your tests should be clear, focused, and maintainable
- **Coverage**: New code you write should have appropriate test coverage
- **Performance**: Your tests should run efficiently
- **Team Impact**: Other developers can easily understand and modify your tests

## 🎓 Advanced Topics (Month 2+)

### Custom Test Utilities
Learn to create reusable test utilities:

```elixir
defmodule MyTestHelpers do
  def assert_user_has_permissions(user, permissions) do
    for permission <- permissions do
      assert permission in user.permissions,
        "User #{user.id} missing permission: #{permission}"
    end
  end
  
  def create_authenticated_conn(user) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{user.api_token}")
    |> put_req_header("content-type", "application/json")
  end
end
```

### Property-Based Testing
Explore property-based testing for complex scenarios:

```elixir
property "list sorting is idempotent" do
  check all list <- list_of(integer()) do
    sorted_once = Enum.sort(list)
    sorted_twice = Enum.sort(sorted_once)
    
    assert sorted_once == sorted_twice
  end
end
```

### Test Data Management
Master sophisticated test data patterns:

```elixir
def scenario(:user_with_premium_map) do
  user = insert(:user, %{subscription: :premium})
  character = insert(:character, %{user_id: user.id})
  map = insert(:map, %{owner_id: character.id, plan: :premium})
  
  %{user: user, character: character, map: map}
end
```

## 🤝 Getting Help and Support

### Where to Ask Questions
1. **Team Chat**: Quick questions about testing approach
2. **Code Reviews**: Specific feedback on your tests
3. **Documentation**: Check existing guides first
4. **Pair Programming**: Work with experienced team members

### Escalation Path
1. Check documentation in `test/` directory
2. Search existing tests for similar patterns
3. Ask team members in chat
4. Schedule pairing session for complex issues
5. Bring to team meeting for architectural decisions

### Office Hours
- **Weekly Testing Office Hours**: Tuesdays 2-3 PM
- **Monthly Testing Workshop**: First Friday of each month
- **Quarterly Testing Retrospective**: Review and improve practices

## 🎯 Your 30-Day Testing Journey

### Week 1: Foundation
- Day 1-2: Environment setup and exploration
- Day 3-4: Study existing tests and patterns
- Day 5: Write first simple unit tests

### Week 2: Building Skills
- Day 6-8: Write integration tests
- Day 9-10: Learn factory patterns and mocking
- Day 11-12: Debug and fix test issues

### Week 3: Advanced Concepts
- Day 13-15: Performance testing
- Day 16-17: Complex integration scenarios
- Day 18-19: Test optimization

### Week 4: Mastery and Contribution
- Day 20-22: Mentor another developer
- Day 23-24: Contribute to testing infrastructure
- Day 25-26: Lead a testing improvement initiative

### Month 2+: Leadership
- Become testing advocate on your team
- Contribute to testing standards and documentation
- Lead testing workshops and knowledge sharing
- Drive testing innovation and best practices

---

Welcome to the team! Our testing culture is one of our strongest assets, and we're excited to have you contribute to it. Remember: great tests make great software, and great software makes happy users. 🚀