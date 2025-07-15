# API Cleanup Implementation Plan

## Overview
This plan outlines the systematic cleanup of v1 API endpoints to restrict access to only the necessary HTTP methods for each resource. The goal is to improve security, reduce API surface area, and maintain consistency across the API.

## Resources and Allowed Methods

### Current State vs Target State

| Resource | Current Methods | Target Methods | Actions Required |
|----------|----------------|----------------|------------------|
| `user_transactions` | GET, POST, PUT, DELETE | GET | Remove POST, PUT, DELETE |
| `map_user_settings` | GET, POST, PUT, DELETE | GET | Remove POST, PUT, DELETE |
| `map_solar_system` | GET, POST, PUT, DELETE | None | Remove all routes |
| `characters` | GET, POST, PUT, DELETE | GET, DELETE | Remove POST, PUT |
| `map_character_settings` | GET, POST, PUT, DELETE | GET | Remove POST, PUT, DELETE |
| `map_subscriptions` | GET, POST, PUT, DELETE | GET | Remove POST, PUT, DELETE |
| `map_system_comments` | GET, POST, PUT, DELETE | GET | Remove POST, PUT, DELETE |
| `map_system_signatures` | GET, POST, PUT, DELETE | GET, DELETE | Remove POST, PUT |
| `users` | GET, POST, PUT, DELETE | None | Remove all routes |
| `map_transactions` | GET, POST, PUT, DELETE | GET | Remove POST, PUT, DELETE |
| `map_states` | GET, POST, PUT, DELETE | None | Remove all routes |
| `user_activities` | GET, POST, PUT, DELETE | GET | Remove POST, PUT, DELETE |
| `ship_type_info` | GET, POST, PUT, DELETE | None | Remove all routes |

## Implementation Tasks

### Phase 1: Analysis and Planning
- [x] Create implementation plan document
- [ ] Analyze current API routes and endpoints
- [ ] Identify all files that need modification
- [ ] Create backup of current state

### Phase 2: API Resource Modifications
- [ ] Update Ash API resources to remove unauthorized actions
- [ ] Modify action definitions in each resource file
- [ ] Update resource policies and validations

### Phase 3: Route Configuration Updates
- [ ] Update API router configurations
- [ ] Remove disabled routes from `lib/wanderer_app_web/api_v1_router.ex`
- [ ] Update route helpers and documentation

### Phase 4: Test Cleanup
- [ ] Remove tests for deleted endpoints
- [ ] Update existing tests to reflect new constraints
- [ ] Add tests to verify unauthorized methods return 405

### Phase 5: Documentation Updates
- [ ] Update OpenAPI specifications
- [ ] Remove deleted endpoints from API docs
- [ ] Update API modernization documentation
- [ ] Update inline documentation and comments

### Phase 6: New Feature Implementation
- [ ] Create combination systems and connections route
- [ ] Implement handler for combined endpoint
- [ ] Add tests for new combination endpoint
- [ ] Update documentation for new endpoint

## Detailed Implementation Steps

### Step 1: Ash API Resource Updates
For each resource, modify the `actions` block to only include allowed methods:

**Example for `user_transactions` (GET only):**
```elixir
actions do
  defaults [:read]  # Remove :create, :update, :destroy
end
```

**Example for `characters` (GET and DELETE only):**
```elixir
actions do
  defaults [:read, :destroy]  # Remove :create, :update
end
```

**Example for resources with no routes:**
```elixir
# Remove the resource from the API entirely or comment out actions
actions do
  # No actions - resource not exposed via API
end
```

### Step 2: Router Configuration Updates
Update `lib/wanderer_app_web/api_v1_router.ex`:

```elixir
# Remove resources that should have no routes
# resources "/map_solar_systems", MapSolarSystemController
# resources "/users", UserController
# resources "/map_states", MapStateController
# resources "/ship_type_info", ShipTypeInfoController

# Update resources to only include allowed methods
resources "/user_transactions", UserTransactionController, only: [:index, :show]
resources "/map_user_settings", MapUserSettingsController, only: [:index, :show]
resources "/characters", CharacterController, only: [:index, :show, :delete]
# ... etc for other resources
```

### Step 3: Test File Updates
For each modified resource:
- Remove test files for deleted endpoints
- Update existing test files to only test allowed methods
- Add tests to verify 405 Method Not Allowed for disabled methods

### Step 4: OpenAPI Specification Updates
Update `lib/wanderer_app_web/open_api_v1_spec.ex`:
- Remove path definitions for deleted endpoints
- Update remaining paths to only include allowed methods
- Update component schemas if needed

### Step 5: New Combination Endpoint
Create a new endpoint that combines systems and connections data:

```elixir
# In lib/wanderer_app_web/api_v1_router.ex
get "/maps/:map_id/systems_and_connections", MapSystemsConnectionsController, :show

# New controller: lib/wanderer_app_web/controllers/api/map_systems_connections_controller.ex
defmodule WandererAppWeb.Api.MapSystemsConnectionsController do
  use WandererAppWeb, :controller
  
  def show(conn, %{"map_id" => map_id}) do
    # Implementation to return both systems and connections
  end
end
```

## Files to Modify

### API Resources (lib/wanderer_app/api/)
- `user_transaction.ex`
- `map_user_settings.ex`
- `map_solar_system.ex`
- `character.ex`
- `map_character_settings.ex`
- `map_subscription.ex`
- `map_system_comment.ex`
- `map_system_signature.ex`
- `user.ex`
- `map_transaction.ex`
- `map_state.ex`
- `user_activity.ex`
- `ship_type_info.ex`

### Router Configuration
- `lib/wanderer_app_web/api_v1_router.ex`
- `lib/wanderer_app_web/router.ex` (if needed)

### Controllers (lib/wanderer_app_web/controllers/)
- Remove or modify controllers for restricted resources
- Create new `map_systems_connections_controller.ex`

### Tests (test/)
- Update or remove test files for modified resources
- Add new tests for combination endpoint

### Documentation
- `lib/wanderer_app_web/open_api_v1_spec.ex`
- `priv/posts/2025/07-15-api-modernization.md`
- Any other API documentation files

## Verification Steps

### Testing
1. Run test suite to ensure no broken tests
2. Test API endpoints manually or via automated tests
3. Verify 405 Method Not Allowed for disabled methods
4. Test new combination endpoint functionality

### Documentation
1. Verify OpenAPI spec generates correctly
2. Check Swagger UI reflects changes
3. Ensure documentation is up to date

### Performance
1. Monitor API performance after changes
2. Ensure no performance regressions
3. Test caching behavior for new endpoint

## Rollback Plan

If issues arise:
1. Revert API resource changes
2. Restore router configuration
3. Restore test files
4. Revert documentation changes
5. Monitor for any remaining issues

## Risk Assessment

### Low Risk
- Removing unused or unnecessary endpoints
- Updating documentation
- Adding new combination endpoint

### Medium Risk
- Modifying existing API behavior
- Updating test suites
- Router configuration changes

### Mitigation
- Thorough testing before deployment
- Gradual rollout if possible
- Monitor error rates and user feedback
- Have rollback plan ready

## Success Criteria

1. ✅ All specified resources only expose allowed HTTP methods
2. ✅ No broken tests or functionality
3. ✅ Updated documentation reflects actual API behavior
4. ✅ New combination endpoint works correctly
5. ✅ No performance regressions
6. ✅ Clean, maintainable code

## Timeline

- **Day 1**: Analysis and planning (Complete)
- **Day 2**: API resource modifications and router updates
- **Day 3**: Test cleanup and updates
- **Day 4**: Documentation updates and new endpoint implementation
- **Day 5**: Testing, verification, and deployment

This plan ensures a systematic approach to cleaning up the API while maintaining functionality and improving security posture.