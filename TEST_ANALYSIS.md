# Wanderer App Test Suite Analysis

## Overview

This document provides a comprehensive analysis of the test scenarios, test cases, and testing approach used in the Wanderer application codebase. The application follows a multi-layered testing strategy that includes unit tests, integration tests, API tests, and property-based tests.

## Test Suite Structure

### Directory Organization

```
test/
├── api/                          # API integration tests
│   ├── controllers/             # API endpoint tests
│   ├── support/                 # API test helpers and utilities
│   └── config/                  # API test configuration
├── property/                    # Property-based tests using StreamData
├── support/                     # Shared test helpers and utilities
├── unit/                        # Unit tests
├── wanderer_app/               # Core application tests
├── wanderer_app_web/           # Web layer tests
└── manual/                     # Manual testing scripts
```

## Test Categories and Types

### 1. Unit Tests (`/test/unit/`)

**Purpose**: Test individual functions, modules, and components in isolation.

**Key Test Files**:
- `guardian_jwt_test.exs` - JWT token generation and validation
- `map_api_controller_test.exs` - Standalone controller logic testing
- `tracking_utils_test.exs` - Utility function testing
- `open_api_assert_test.exs` - OpenAPI assertion helper testing

**Testing Patterns**:
- Mock dependencies using custom mock modules
- Test pure functions without external dependencies
- Validate business logic in isolation
- Test error handling and edge cases

**Example Test Scenario**:
```elixir
# JWT Token Generation and Validation
test "generates and validates user JWT token" do
  user = create_user(%{name: "Test User", hash: "test-hash"})
  token = AuthHelpers.generate_jwt_token(user)
  
  # Validate token format (should be JWT format)
  assert String.contains?(token, ".")
  parts = String.split(token, ".")
  assert length(parts) == 3
  
  # Decode and verify token
  {:ok, claims} = AuthHelpers.decode_jwt_token(token)
  assert claims["sub"] == "user:#{user.id}"
end
```

### 2. Integration Tests (`/test/api/`)

**Purpose**: Test complete API workflows and endpoint behavior with authentication and data persistence.

**Key Test Files**:
- `maps_api_test.exs` - Map management API testing
- `acls_api_test.exs` - Access Control List API testing
- `systems_api_test.exs` - System management testing
- `connections_api_test.exs` - Connection management testing

**Testing Patterns**:
- Full HTTP request/response cycle testing
- Authentication strategy verification
- Database integration through Ash framework
- OpenAPI specification compliance validation
- CRUD operations testing using scaffolding

**Example Test Scenario**:
```elixir
# Map Systems API with Authentication
test "GET /api/maps/:slug/systems - retrieves map systems with valid authentication" do
  map_data = create_map_with_systems_and_connections()
  
  response =
    conn
    |> authenticate_map(map_data.api_key)
    |> get("/api/maps/#{map_data.map.slug}/systems")
    |> assert_success_response(200)
  
  assert length(response["data"]["systems"]) == 3
  assert Enum.all?(response["data"]["systems"], &(&1["map_id"] == map_data.map.id))
end
```

### 3. Property-Based Tests (`/test/property/`)

**Purpose**: Test system invariants and business rules across a wide range of generated inputs.

**Key Test Files**:
- `map_property_test.exs` - Map domain logic properties
- `systems_property_test.exs` - System management properties
- `api_validations_property_test.exs` - API validation properties
- `acls_property_test.exs` - Access control properties

**Testing Patterns**:
- Input generation using StreamData
- Invariant verification
- Business rule validation
- Edge case discovery through property testing

**Example Test Scenario**:
```elixir
# Map Slug Generation Properties
property "slugs are always lowercase and URL-safe" do
  check all name <- map_name() do
    slug = generate_slug(name)
    
    assert slug == String.downcase(slug)
    assert slug =~ ~r/^[a-z0-9-]*$/
    assert !String.contains?(slug, " ")
  end
end
```

### 4. Authentication and Authorization Tests

**Purpose**: Comprehensive testing of authentication strategies and authorization policies.

**Key Test Files**:
- `auth_pipeline_test.exs` - Authentication pipeline testing
- Various API tests with auth scenarios

**Authentication Strategies Tested**:
- JWT User Authentication
- JWT Character Authentication  
- Map API Key Authentication
- ACL API Key Authentication

**Example Test Scenario**:
```elixir
# Multiple Authentication Strategy Testing
test "tries multiple strategies in order" do
  # First strategy will skip (no ACL), second should succeed
  conn =
    conn
    |> assign(:map, map)
    |> put_req_header("authorization", "Bearer test-api-key")
    |> AuthPipeline.call(AuthPipeline.init(strategies: [:acl_key, :map_api_key]))
  
  assert conn.assigns.authenticated_by == :map_api_key
  refute conn.halted
end
```

### 5. Web Layer Tests (`/test/wanderer_app_web/`)

**Purpose**: Test Phoenix controllers, views, and web-specific functionality.

**Key Test Files**:
- `error_json_test.exs` - Error response formatting
- `error_html_test.exs` - Error page rendering

## Test Infrastructure and Support

### Test Factories (`/test/support/factory.ex`)

**Purpose**: Consistent test data creation using ExMachina with Ash framework integration.

**Key Features**:
- Ash-aware resource creation
- Actor-based authentication
- Complex scenario builders
- Cache and mock integration

**Example Factory**:
```elixir
def create_authenticated_map_scenario(attrs \\ %{}) do
  user = create_user(attrs[:user] || %{})
  character = create_character(attrs[:character] || %{user_id: user.id}, user)
  map = create_map(attrs[:map] || %{owner_id: character.id}, character)
  
  # Update map with API key
  api_key = "api-key-#{System.unique_integer([:positive])}"
  {:ok, map} = Ash.update(map, %{public_api_key: api_key}, actor: character, action: :update_api_key)
  
  %{user: user, character: character, map: map, api_key: map.public_api_key}
end
```

### CRUD Test Scaffolding (`/test/support/crud_test_scaffolding.ex`)

**Purpose**: Reusable test patterns for consistent CRUD operation testing.

**Features**:
- Standardized CRUD operation tests
- Validation scenario testing
- Authorization scenario testing
- Edge case and concurrency testing

**Example Usage**:
```elixir
test_crud_operations("ACL", "/api/acls", :character, %{
  setup_auth: fn ->
    owner = create_character(%{name: "ACL Owner"})
    acl_data = create_test_acl_with_auth(%{character: owner})
    Map.put(acl_data, :owner, owner) |> Map.put(:character, owner)
  end,
  create_params: fn ->
    %{"acl" => %{"name" => "Test ACL Creation", "description" => "Created via API test"}}
  end,
  update_params: fn ->
    %{"acl" => %{"name" => "Updated ACL Name", "description" => "Updated description"}}
  end,
  invalid_params: fn ->
    %{"acl" => %{"name" => ""}}
  end
})
```

### OpenAPI Testing (`/test/support/open_api_assert.ex`)

**Purpose**: Validate API responses against OpenAPI specifications.

**Features**:
- Response schema validation
- Request parameter validation
- Automatic operation detection
- Error formatting and reporting

**Example Usage**:
```elixir
conn
|> api_request(:get, "/api/maps")
|> assert_conforms!(200)  # Validates against OpenAPI spec
```

### Mock Infrastructure

**Map Server Mock** (`/test/support/map_server_mock.ex`):
- Lightweight replacement for GenServer-based map servers
- Cache-based state management
- System and connection mocking

**ESI Mock** (`/test/support/esi_mock.ex`):
- EVE ESI API response mocking
- Configurable character/corporation/alliance data
- Error scenario simulation

## Test Coverage Areas

### 1. API Endpoints

**Map Management**:
- Map CRUD operations
- System management (add, remove, update)
- Connection management
- Character tracking
- Access control integration

**Access Control Lists (ACLs)**:
- ACL CRUD operations
- Member management (characters, corporations, alliances)
- Role-based permissions
- API key authentication

**Systems API**:
- System information retrieval
- Static data integration
- Filtering and pagination

### 2. Authentication and Authorization

**Authentication Methods**:
- JWT user tokens
- JWT character tokens
- Map API keys
- ACL API keys

**Authorization Scenarios**:
- Owner permissions
- Member permissions
- Guest access restrictions
- API key scope validation

### 3. Data Validation

**Input Validation**:
- Required field validation
- Data type validation
- Format validation (slugs, IDs, etc.)
- Business rule validation

**API Response Validation**:
- OpenAPI schema compliance
- Response format consistency
- Error message formatting

### 4. Business Logic

**Map Management**:
- Slug generation and uniqueness
- Character limits and enforcement
- Hub management
- Scope validation (public, private, corporation, alliance)

**System and Connection Logic**:
- System placement and positioning
- Connection type validation
- Mass and time status management
- Visibility rules

## Testing Patterns and Best Practices

### 1. Test Isolation

- Each test runs in isolation using Ecto sandbox
- Factory-based test data creation
- Mock services for external dependencies
- Cleanup procedures for persistent state

### 2. Authentication Testing

```elixir
# Standard authentication helper pattern
def authenticate_map(conn, api_key) do
  conn |> put_req_header("authorization", "Bearer #{api_key}")
end

def authenticate_character(conn, character) do
  token = generate_character_token(character)
  conn |> put_req_header("authorization", "Bearer #{token}")
end
```

### 3. Response Validation

```elixir
# Comprehensive response validation
def assert_success_response(conn, expected_status \\ 200) do
  assert conn.status == expected_status
  
  # Always validate against OpenAPI spec
  OpenApiAssert.assert_conforms!(conn, expected_status)
  
  # Handle 204 No Content responses
  if expected_status == 204 do
    nil
  else
    json_response!(conn, expected_status)
  end
end
```

### 4. Property-Based Testing Pattern

```elixir
# Invariant testing with generated data
property "character limit must be positive or unlimited" do
  check all limit <- character_limit() do
    assert limit == 0 or limit > 0
    
    # 0 means unlimited
    if limit == 0 do
      assert character_limit_valid?(limit, 9999)
    else
      assert character_limit_valid?(limit, limit - 1)
      refute character_limit_valid?(limit, limit + 1)
    end
  end
end
```

## Test Configuration and Environment

### Test Database Setup

- Uses Ecto sandbox for transaction isolation
- PostgreSQL for production-like testing
- Automated schema migrations
- Test-specific configuration

### Mock Configuration

- External API calls mocked by default
- Configurable mock responses
- ESI API mocking for EVE Online integration
- Map server process mocking

### Feature Flags and Environment

- Test-specific feature flag configuration
- Environment variable support for hybrid testing
- Rate limiting disabled in tests
- Debug logging configuration

## Hybrid Testing Approach

### Real API Testing

The test suite includes a hybrid testing approach that can test against real API instances:

- Environment-based configuration
- Real authentication tokens
- Non-destructive operations
- Graceful fallback when environment not configured

### Manual Testing Scripts

Located in `/test/manual/api/`, these scripts provide:
- Bash-based API testing
- System and structure API testing
- Backup and restore testing
- Legacy API compatibility testing

## Metrics and Quality Assurance

### Test Coverage Areas

- **Unit Tests**: Individual function and module testing
- **Integration Tests**: Full API workflow testing  
- **Property Tests**: Business rule and invariant testing
- **Authentication Tests**: Security and access control
- **Validation Tests**: Input and output validation
- **Error Handling**: Edge cases and failure scenarios

### Testing Frameworks Used

- **ExUnit**: Primary testing framework
- **ExUnitProperties**: Property-based testing with StreamData
- **ExMachina**: Test data factories
- **Phoenix.ConnTest**: HTTP connection testing
- **Mox**: Mock and stub creation
- **OpenApiSpex**: API specification validation

## Conclusion

The Wanderer application employs a comprehensive, multi-layered testing strategy that ensures:

1. **Reliability**: Through extensive unit and integration testing
2. **Security**: Via thorough authentication and authorization testing
3. **Compliance**: Using OpenAPI specification validation
4. **Robustness**: Through property-based testing and edge case coverage
5. **Maintainability**: Via reusable test patterns and scaffolding
6. **Real-world Validation**: Through hybrid testing with actual API instances

The test suite demonstrates mature testing practices with strong emphasis on:
- Test isolation and repeatability
- Comprehensive coverage of business logic
- Security-first authentication testing
- API contract validation
- Performance and concurrency considerations

This testing approach provides confidence in the application's reliability and helps maintain code quality as the system evolves.