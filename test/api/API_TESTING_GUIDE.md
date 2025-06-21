# Wanderer API Testing Guide

## Overview

This guide provides practical information for running and writing API tests in the Wanderer application. The API tests are located in `/test/api/` and use a combination of automated testing with mock data and manual testing with real API instances.

## Quick Start

### Running API Tests

```bash
# Run all API tests
mix test test/api/

# Run specific test file
mix test test/api/controllers/maps_api_test.exs

# Run with specific line number
mix test test/api/controllers/maps_api_test.exs:42

# Use the test-api alias (includes DB setup)
mix test-api
```

### Manual Testing with Real API

For testing against a real Wanderer instance:

```bash
cd test/manual/api/

# Test map systems API
./system_api_tests.sh

# Test structures and signatures
./structure_signature_api_tests.sh
```

## Test Structure

```
test/
├── api/                          # API integration tests
│   ├── controllers/             # Endpoint tests
│   │   ├── maps_api_test.exs
│   │   ├── acls_api_test.exs
│   │   ├── systems_api_test.exs
│   │   └── connections_api_test.exs
│   ├── support/                 # Test helpers
│   │   ├── api_case.ex         # Base test case with helpers
│   │   └── env_helper.ex       # Environment variable loading
│   └── config/                  # Test configuration
├── support/
│   └── factory.ex              # Ash-based test data factories
└── manual/
    └── api/                    # Shell-based manual tests
```

## Writing API Tests

### Basic Test Structure

```elixir
defmodule WandererApp.YourApiTest do
  use WandererApp.ApiCase

  describe "GET /api/v1/your-endpoint" do
    setup do
      # Create test data using factories
      auth_data = create_authenticated_map_scenario()
      {:ok, auth_data}
    end

    test "returns data with valid authentication", %{conn: conn, api_key: api_key} do
      conn
      |> authenticate_map(api_key)
      |> get("/api/v1/your-endpoint")
      |> assert_json_response(200)
      |> assert_match(%{"data" => _})
    end
  end
end
```

### Available Test Helpers

The `ApiCase` module provides these helpers:

**Authentication:**
- `authenticate_user(conn, user)` - JWT user authentication
- `authenticate_character(conn, character)` - JWT character authentication
- `authenticate_map(conn, api_key)` - Map API key authentication
- `authenticate_acl(conn, api_key)` - ACL API key authentication

**Request & Response:**
- `json_response!(conn, status)` - Parse JSON response
- `assert_json_response(conn, expected_status)` - Assert status and parse JSON
- `assert_error_format(conn)` - Validate error response structure
- `validated_request(conn, method, path, params)` - Make request with OpenAPI validation

**Pagination:**
- `with_pagination(path, params, expected_count)` - Test paginated endpoints
- `assert_pagination(response, expected)` - Assert pagination metadata

### Using Test Factories

The test suite uses Ash-aware factories in `/test/support/factory.ex`:

```elixir
# Create a complete authentication scenario
auth_data = create_authenticated_map_scenario(%{
  user: %{name: "Test User"},
  character: %{name: "Test Character"},
  map: %{name: "Test Map"}
})
# Returns: %{user: user, character: character, map: map, api_key: api_key}

# Create individual resources
user = create_user(%{name: "Test User"})
character = create_character(%{user_id: user.id}, user)
map = create_map(%{owner_id: character.id}, character)

# Create map with systems and connections
map_data = create_map_with_systems_and_connections()
```

## Authentication Strategies

The API supports multiple authentication methods:

### 1. Map API Key
```elixir
conn |> put_req_header("authorization", "Bearer #{api_key}")
```

### 2. Character JWT
```elixir
token = AuthHelpers.generate_character_token(character)
conn |> put_req_header("authorization", "Bearer #{token}")
```

### 3. ACL API Key
```elixir
conn |> put_req_header("authorization", "Bearer #{acl_api_key}")
```

## Environment-Based Testing

### Setup for Real API Testing

1. Create a `.env` file in the test directory:
```bash
# Required
API_TOKEN=your-map-api-token-here
MAP_SLUG=your-map-slug-here

# Optional
ACL_API_TOKEN=your-acl-token
ACL_ID=your-acl-id
API_BASE_URL=http://localhost:4000
```

2. Use environment helpers in tests:
```elixir
@tag :env_required
test "works with real API", %{conn: conn} do
  case EnvHelper.load_env_config() do
    {:ok, config} ->
      conn
      |> put_req_header("authorization", "Bearer #{config.api_token}")
      |> get("/api/maps/#{config.map_slug}/systems")
      |> assert_json_response(200)
    
    {:error, _} ->
      # Skip test if env not configured
      :ok
  end
end
```

## Manual Shell Testing

The `/test/manual/api/` directory contains bash scripts for testing:

### Available Scripts:
- `utils.sh` - Common functions and utilities
- `system_api_tests.sh` - Test system endpoints
- `structure_signature_api_tests.sh` - Test structures and signatures
- `backup_restore_tests.sh` - Test backup/restore functionality

### Running Manual Tests:
```bash
# Set environment variables
export API_TOKEN="your-token"
export MAP_SLUG="your-map"
export API_BASE_URL="http://localhost:4000"

# Run tests
./system_api_tests.sh
```

## Common Test Patterns

### Testing CRUD Operations

```elixir
describe "Map Systems CRUD" do
  setup do
    auth_data = create_authenticated_map_scenario()
    {:ok, auth_data}
  end

  test "creates system", %{conn: conn, api_key: api_key, map: map} do
    params = %{
      "solar_system_id" => 30000142,
      "name" => "Jita"
    }

    conn
    |> authenticate_map(api_key)
    |> post("/api/v1/maps/#{map.slug}/systems", params)
    |> assert_json_response(201)
    |> assert_match(%{"data" => %{"solar_system_id" => 30000142}})
  end
end
```

### Testing Error Responses

```elixir
test "returns 404 for non-existent map", %{conn: conn} do
  conn
  |> authenticate_map("valid-key")
  |> get("/api/maps/non-existent/systems")
  |> assert_json_response(404)
  |> assert_error_format()
end
```

### Testing Pagination

```elixir
test "paginates results", %{conn: conn, api_key: api_key, map: map} do
  # Create test data
  for i <- 1..25 do
    create_map_system(%{solar_system_id: 30000000 + i}, map)
  end

  response = 
    conn
    |> authenticate_map(api_key)
    |> with_pagination("/api/v1/maps/#{map.slug}/systems", %{limit: 10}, 25)
  
  assert length(response["data"]) == 10
  assert response["meta"]["total"] == 25
end
```

## OpenAPI Validation

All API responses are automatically validated against the OpenAPI specification:

```elixir
# Automatic validation with validated_request/4
conn
|> validated_request(:get, "/api/v1/maps", %{})
|> assert_json_response(200)

# Manual validation
response = json_response!(conn, 200)
OpenApiAssert.assert_response_conforms!(conn, response)
```

## Debugging Tips

1. **Add IO.inspect for debugging:**
   ```elixir
   response |> IO.inspect(label: "API Response")
   ```

2. **Check test logs:**
   ```bash
   tail -f logs/test.log
   ```

3. **Run single test with trace:**
   ```bash
   mix test --trace test/api/controllers/maps_api_test.exs:42
   ```

4. **Use IEx.pry for breakpoints:**
   ```elixir
   require IEx
   IEx.pry()
   ```

## Best Practices

1. **Use factories** instead of hardcoding test data
2. **Test both success and error cases** for each endpoint
3. **Validate response structure** using pattern matching
4. **Clean up test data** in tests that modify state
5. **Tag environment-dependent tests** with `@tag :env_required`
6. **Use OpenAPI validation** to ensure API compliance
7. **Test authentication failures** for protected endpoints

## Troubleshooting

**"Missing required environment variable"**
- Check that `.env` file exists with required variables
- Or run tests without `:env_required` tag

**401 Unauthorized Errors**
- Verify API key is correct
- Check that map/ACL still exists and API is enabled
- Ensure proper authentication header format

**Factory Errors**
- Make sure to pass proper actor for Ash operations
- Check required fields for resource creation

**OpenAPI Validation Failures**
- Response doesn't match specification
- Check `/api/openapi` endpoint for current schema
- Update test expectations to match API changes