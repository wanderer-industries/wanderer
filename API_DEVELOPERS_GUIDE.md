# API Developer's Guide

## Overview

This guide outlines the naming conventions, style guidelines, and testing standards for developing APIs in the Wanderer EVE Online mapping application. The codebase uses Elixir/Phoenix with Ash Framework for resources and JSON:API endpoints.

## Authentication & Authorization

### Authentication Strategies
- **Character JWT**: Guardian JWT tokens for authenticated users
- **Map API Keys**: API key authentication for map access 
- **ACL Keys**: Access Control List based authentication
- **Feature Flags**: Runtime feature toggles via AuthPipeline

### Authentication Pipeline
Use `AuthPipeline` instead of legacy plugs:
```elixir
plug WandererAppWeb.Auth.AuthPipeline,
  strategies: [:character_jwt, :map_api_key],
  required: true
```

## Naming Conventions

### Controllers
- Legacy controllers: `MapAPIController`, `AccessListAPIController`
- Domain modules: `WandererApp.Domain.Maps`, `WandererApp.Domain.AccessLists`
- Operations modules: `WandererApp.Map.Operations.Systems`

### API Endpoints
- REST paths: `/api/map/tracked-characters`, `/api/map/structure-timers`
- JSON:API paths: `/api/v1/access_lists`, `/api/v1/map_connections`
- Parameter naming: `map_id`, `solar_system_id`, `character_id`

### File Organization
```
lib/wanderer_app_web/
├── controllers/           # Phoenix controllers (being deprecated)
├── auth/                 # Authentication strategies and pipelines
├── plugs/               # Custom plugs (ResolveMapIdentifier, SubscriptionGuard)
├── validations/         # Input validation modules
└── schemas/             # OpenAPI schema definitions

lib/wanderer_app/
├── domain/              # Business logic modules
└── map/operations/      # Map-specific operations
```

## Code Style Guidelines

### Input Validation
Use `ApiValidations` module for consistent validation:
```elixir
# Good
{:ok, validated} <- ApiValidations.validate_days_param(params)

# Avoid
case params["days"] do
  nil -> %{days: 7}
  val -> # manual validation
end
```

### Error Handling
Use `FallbackController` for consistent error responses:
```elixir
# In controller
action_fallback WandererAppWeb.FallbackController

# Return changesets for 422 responses
{:error, changeset} = ApiValidations.validate_role(params)
```

### OpenAPI Schemas
Use centralized schemas from `WandererAppWeb.Schemas`:
```elixir
@character_schema ApiSchemas.character_schema()
@response_schema ApiSchemas.data_wrapper(@character_schema)
```

### Map Access Patterns
Use `Map.get/3` instead of dot notation for optional fields:
```elixir
# Good
eve_corp_id = Map.get(validated, :eve_corporation_id)

# Avoid (causes KeyError)
eve_corp_id = validated.eve_corporation_id
```

### Security
- Use `Plug.Crypto.secure_compare/2` for token comparisons
- Never log or expose API keys or secrets
- Validate all user inputs with proper changesets

## Testing Standards

### Test Organization (Four-Layer Pyramid)

#### 1. Unit Tests (`:unit` tag)
- Pure functions and calculations
- No external dependencies or database
- Runtime budget: <1 second

```elixir
@tag :unit
test "parse_and_validate_integer/2 with valid integer string" do
  assert {:ok, 42} = ApiValidations.parse_and_validate_integer("42", :days)
end
```

#### 2. Ash Action Tests (`:ash` tag)  
- Resource actions, validations, business rules
- Real database with sandbox, mock external APIs
- Runtime budget: <10 seconds

```elixir
@tag :ash
test "create access list member with valid role" do
  assert {:ok, member} = AccessListMember.create(%{role: "admin", ...})
end
```

#### 3. API Tests (`:api` tag)
- HTTP endpoints, authentication, serialization
- Real database and Phoenix, mock external APIs
- Runtime budget: <30 seconds

```elixir
@tag :api
test "GET /api/map/tracked-characters requires authentication" do
  conn = get(conn, "/api/map/tracked-characters")
  assert json_response(conn, 401)
end
```

#### 4. End-to-End Tests (`:e2e` tag)
- Complete workflows with real environment
- Minimal mocking, real external APIs when available
- Runtime budget: <2 minutes

```elixir
@tag :e2e
test "full map creation and character tracking workflow" do
  # Complete integration test
end
```

### Test Data Management

#### ExMachina-Ash Factories
Use proper Ash factories instead of raw database inserts:
```elixir
# Good
map = Factory.insert!(:map)
character = Factory.insert!(:character, user: user)

# Avoid
Repo.insert_all("maps", [%{id: "123", ...}])
```

#### Authentication Helpers
Use standardized auth setup:
```elixir
# API key authentication
{:ok, conn} = AuthHelpers.setup_auth(conn, :map_api_key, map: map)

# JWT authentication  
{:ok, conn} = AuthHelpers.setup_auth(conn, :character_jwt, character: character)
```

### Property-Based Testing
Use StreamData for edge case discovery:
```elixir
property "API never crashes with malformed input" do
  check all params <- malformed_query_params() do
    conn = get(conn, "/api/map/systems", params)
    assert conn.status in 200..499  # Never 5xx
  end
end
```

### Mock External Dependencies
Mock EVE ESI API calls in tests:
```elixir
# In test setup
ESIMock.expect_character_lookup(character_id, character_data)
ESIMock.expect_corporation_lookup(corp_id, corp_data)
```

## API Conventions

### Request/Response Format
- Use JSON for all API requests/responses
- Follow OpenAPI 3.0 specification
- Consistent error response format via `FallbackController`

### Query Parameters
- `map_id`: UUID for map identification
- `slug`: Human-readable map identifier
- `hours`/`days`: Time-based filtering parameters
- `limit`/`offset`: Pagination parameters

### HTTP Status Codes
- `200`: Successful GET/PUT requests
- `201`: Successful POST requests  
- `400`: Bad request (validation errors)
- `401`: Authentication required
- `403`: Forbidden (insufficient permissions)
- `404`: Resource not found
- `422`: Unprocessable entity (validation failures)

### Response Envelope
Wrap responses in consistent envelope:
```json
{
  "data": [...],
  "meta": {
    "total": 42,
    "page": 1
  }
}
```

## Migration Guidelines

### Legacy to Modern API
- Legacy controllers marked `@deprecated` with removal dates
- Migrate clients to `/api/v1/*` JSON:API endpoints
- Extract business logic to `Domain.*` modules

### Authentication Migration
- Replace individual auth plugs with `AuthPipeline`
- Use feature flags for gradual rollouts
- Maintain backward compatibility during transitions

## Performance Considerations

### Database Queries
- Use Ash queries with proper loading strategies
- Preload associations: `Ash.Query.load(:character)`
- Filter at database level: `Ash.Query.filter(map_id == ^map_id)`

### Caching
- Use `KillsCache` for EVE kill data
- Map server state management via GenServer
- Cache static data (system information)

## Development Workflow

### Adding New APIs
1. Define OpenAPI schema in `WandererAppWeb.Schemas`
2. Create input validation in `ApiValidations`
3. Implement business logic in `Domain.*` modules
4. Add controller action with proper auth pipeline
5. Write comprehensive tests at all pyramid levels
6. Update API documentation

### Code Quality
- Run Credo for style consistency: `mix credo`
- Fix all compilation warnings
- Maintain >85% test coverage
- Use `mix test.api` for API-specific testing

This guide ensures consistent, maintainable, and well-tested API development across the Wanderer application.