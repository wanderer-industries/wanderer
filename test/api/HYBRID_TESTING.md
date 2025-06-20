# Hybrid API Testing Approach

## Overview

The hybrid testing approach combines the benefits of automated tests with real API tokens from an existing Wanderer instance. This allows us to test actual API functionality without dealing with the complexity of creating test data through the Ash framework.

## Quick Start

1. **Create a test map in Wanderer:**
   - Log into your Wanderer instance
   - Create a new map (or use an existing one)
   - Go to Map Settings → API
   - Enable "Public API"
   - Copy the API token

2. **Set up the test environment:**
   ```bash
   cd api-test
   ./setup_hybrid_tests.sh
   ```
   
   Or manually create `api-test/.env`:
   ```env
   API_TOKEN=your-map-api-token-here
   MAP_SLUG=your-map-slug-here
   ```

3. **Run the hybrid tests:**
   ```bash
   mix test api-test/controllers/hybrid_api_test.exs
   ```

## How It Works

The hybrid tests:
- Load authentication tokens from environment variables
- Test against a real map with real data
- Perform non-destructive operations (or clean up after themselves)
- Skip gracefully if environment variables are not set

## Available Tests

### Map Systems API
- ✅ List all systems in the map
- ✅ Create temporary test systems (with cleanup)
- ✅ Test error handling (invalid tokens, non-existent maps)

### Map Connections API
- ✅ List all connections in the map

### ACL API (if configured)
- ✅ Get ACL details
- ✅ List ACL members

### Common API
- ✅ Test public endpoints that don't require authentication

## Environment Variables

Required:
- `API_TOKEN` - Bearer token from your map's API settings
- `MAP_SLUG` - The URL slug of your map

Optional:
- `ACL_API_TOKEN` - Bearer token from an ACL (for ACL tests)
- `ACL_ID` - The ID of the ACL to test
- `API_BASE_URL` - Base URL of the API (defaults to http://localhost:4000)

## Benefits

1. **No Complex Setup** - Use existing maps and data
2. **Real Testing** - Tests actual API behavior, not mocks
3. **Flexible** - Can test against local or remote instances
4. **Safe** - Tests are designed to be non-destructive
5. **Easy Migration** - Same approach as manual shell tests

## Running Specific Test Groups

```bash
# Run only map tests
mix test api-test/controllers/hybrid_api_test.exs --only map

# Run only ACL tests (requires ACL env vars)
mix test api-test/controllers/hybrid_api_test.exs --only acl

# Run with verbose output
MIX_ENV=test mix test api-test/controllers/hybrid_api_test.exs --trace
```

## Comparison with Other Approaches

### vs. Direct Database Tests
- ✅ Works with Ash framework
- ✅ Tests real API behavior
- ❌ Requires manual setup

### vs. Manual Shell Scripts
- ✅ Integrated with ExUnit
- ✅ Better error reporting
- ✅ Can be part of CI/CD

### vs. Full Mock Tests
- ✅ Tests real implementation
- ✅ Catches integration issues
- ❌ Requires running instance

## Extending the Tests

To add new hybrid tests:

1. Add test functions to `hybrid_api_test.exs`
2. Use `authenticate_with_env_token()` for authentication
3. Use `test_map_slug()` to get the map slug
4. Clean up any data you create

Example:
```elixir
@tag :env_required
test "my new test", %{conn: conn} do
  map_slug = test_map_slug()
  
  conn = conn
         |> authenticate_with_env_token()
         |> get("/api/maps/#{map_slug}/some-endpoint")
  
  assert conn.status == 200
end
```

## Troubleshooting

**"Missing required environment variable"**
- Run `./setup_hybrid_tests.sh` or create `.env` manually

**401 Unauthorized**
- Check that your API token is correct
- Ensure the map's API is still enabled

**404 Not Found**
- Verify the MAP_SLUG matches your map's URL
- Check that the map still exists

## Next Steps

1. **CI/CD Integration** - Set up test maps in CI environment
2. **Test Data Seeding** - Script to create known test data
3. **Performance Tests** - Add load testing with the same tokens
4. **Contract Tests** - Validate API response schemas