# Wanderer API Test Suite

This directory contains a dedicated test suite for testing the Wanderer API endpoints.

## Structure

```
api-test/
├── controllers/          # API endpoint tests
├── support/             # Test helpers and utilities
│   ├── api_case.ex     # Base test case for API tests
│   └── factory.ex      # ExMachina factories for test data
├── factories/          # Additional factory modules
├── config/             # Test-specific configuration
└── test_helper.exs     # Test suite initialization
```

## Running Tests

To run the API test suite:

```bash
mix test-api
```

To run a specific test file:

```bash
mix test-api api-test/controllers/map_api_test.exs
```

To run tests with coverage:

```bash
MIX_ENV=test mix coveralls api-test/
```

## Writing Tests

### Basic Test Structure

```elixir
defmodule WandererApp.YourApiTest do
  use WandererApp.ApiCase

  describe "GET /api/resource" do
    setup do
      user = insert(:user)
      resource = insert(:resource, owner: user)
      {:ok, user: user, resource: resource}
    end

    test "returns resource for authenticated user", %{conn: conn, user: user} do
      conn
      |> authenticate_user(user)
      |> get("/api/resource")
      |> assert_status(200)
      |> json_response(200)
    end
  end
end
```

### Available Helpers

The `ApiCase` module provides several helpers:

- `authenticate_user/2` - Add user authentication to connection
- `authenticate_api_key/2` - Add API key authentication
- `assert_status/2` - Assert HTTP status code
- `assert_json_response/3` - Assert JSON response structure
- `json_response/2` - Parse JSON response body
- `api_request/4` - Make API requests with proper headers
- `assert_error_response/3` - Assert error response structure
- `get_paginated/3` - Make paginated requests
- `assert_pagination/2` - Assert pagination metadata

### Factory Usage

Use ExMachina factories to create test data:

```elixir
# Create a user
user = insert(:user)

# Create a user with characters
user = insert(:user) |> with_characters(3)

# Create a map with systems
map = insert(:map) |> with_systems(5)

# Build without persisting
map_attrs = build(:map)
```

### Testing Authentication

```elixir
test "requires authentication", %{conn: conn} do
  conn
  |> get("/api/protected")
  |> assert_status(401)
end

test "accepts API key", %{conn: conn} do
  conn
  |> authenticate_api_key("valid-api-key")
  |> get("/api/protected")
  |> assert_status(200)
end
```

### Testing Pagination

```elixir
test "supports pagination", %{conn: conn, user: user} do
  # Create test data
  for _ <- 1..50, do: insert(:resource, owner: user)
  
  conn
  |> authenticate_user(user)
  |> get_paginated("/api/resources", %{page: 2, page_size: 10})
  |> assert_status(200)
  |> json_response(200)
  |> assert_pagination(%{page: 2, page_size: 10})
end
```

### Testing Error Responses

```elixir
test "returns validation errors", %{conn: conn, user: user} do
  conn
  |> authenticate_user(user)
  |> api_request(:post, "/api/resources", %{})
  |> assert_status(422)
  |> assert_error_response(422, :name)
end
```

## Configuration

Test-specific configuration is in `api-test/config/config.exs`. Key configurations:

- **Rate Limiting**: Configure test rate limits
- **Authentication**: Test API keys and tokens
- **External APIs**: All disabled by default
- **Feature Flags**: Control which features are enabled

## Best Practices

1. **Isolation**: Each test should be independent
2. **Setup**: Use `setup` blocks for common test data
3. **Factories**: Use factories instead of hardcoded data
4. **Assertions**: Use provided assertion helpers
5. **Performance**: Test response times for critical endpoints
6. **Coverage**: Aim for >80% coverage of API endpoints

## Debugging

To debug failing tests:

1. Add `IO.inspect` to see data
2. Use `IEx.pry` to pause execution
3. Check test logs in `logs/test.log`
4. Run with `--trace` for detailed output

```bash
mix test-api --trace api-test/controllers/map_api_test.exs:42
```