# API Test Implementation Issues and Solutions

## Current Issues

The enhanced API tests are failing because:

1. **Database Schema Mismatch**: The test factory tries to insert directly into database tables, but the table structure doesn't match what we expected.

2. **Authentication Setup**: The API requires valid API keys that are tied to maps and ACLs created through the Ash framework, not direct database inserts.

3. **Ash Framework Complexity**: The application uses Ash framework which has its own way of managing data, making direct database inserts problematic.

## Why Manual Tests Work

The manual shell script tests (`test/manual/api/`) work because:
- They use a real API token from an existing map (`API_TOKEN` environment variable)
- They test against a running application with real data
- They don't try to create test data, just use existing maps

## Recommended Solution

### Option 1: Use Ash Resources (Recommended)

Instead of direct database inserts, use Ash resources to create test data:

```elixir
# In test setup
{:ok, user} = WandererApp.Api.User.create(%{
  name: "Test User",
  # ... other fields
})

{:ok, character} = WandererApp.Api.Character.create(%{
  user_id: user.id,
  eve_id: 95_000_001,
  name: "Test Character"
})

{:ok, map} = WandererApp.Api.Map.create(%{
  owner_id: character.id,
  name: "Test Map",
  slug: "test-map-#{System.unique_integer([:positive])}"
})

# Enable API and get the key
{:ok, map} = WandererApp.Api.Map.enable_public_api(map)
api_key = map.public_api_key
```

### Option 2: Use Existing Test Patterns

Look at how the existing tests in `test/` create data and follow those patterns.

### Option 3: Integration Tests with Real Instance

1. Start a test instance of the application
2. Create a map through the UI or API
3. Get the API token
4. Run tests against the real instance

## Quick Fix for Current Tests

To make the current tests work immediately:

1. **Fix the factory to use Ash resources** instead of direct DB inserts
2. **Or use fixtures** - pre-create test maps/ACLs and use their API keys
3. **Or mock the authentication** - bypass the auth check in test environment

## Example Working Test Pattern

```elixir
defmodule WandererApp.ApiTestWithAsh do
  use WandererApp.DataCase
  use Phoenix.ConnTest
  
  @endpoint WandererAppWeb.Endpoint
  
  setup do
    # Use Ash to create test data
    # This needs to be implemented based on actual Ash resources
    
    {:ok, conn: build_conn()}
  end
  
  test "authenticated request with Ash-created data" do
    # Would use actual Ash resources here
  end
end
```

## Environment-Specific Testing

The manual tests use environment variables:
- `API_TOKEN` - Bearer token for authentication
- `API_BASE_URL` - Base URL of the API
- `MAP_SLUG` - Slug of the test map

These could be set up in a test environment file for integration tests.

## Next Steps

1. **Investigate Ash Resources**: Find the actual Ash resource modules and their create actions
2. **Look at Existing Tests**: See how other tests in the codebase create test data
3. **Consider Test Levels**:
   - Unit tests: Mock the authentication
   - Integration tests: Use Ash to create real data
   - E2E tests: Use the manual test approach with real API tokens

The enhanced test structure is solid, but needs to be adapted to work with Ash framework rather than direct database manipulation.