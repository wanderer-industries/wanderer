# API Versioning Strategy

## Overview

The Wanderer API has been restructured to support versioning and future evolution while maintaining backward compatibility. This document outlines the versioning strategy and migration path.

## Architecture

### Versioned Domains

- **`WandererApp.Api.V1`** - V1 API domain containing all current resources
- **`WandererApp.Api.V2`** - V2 API domain (prepared for future breaking changes)
- **`WandererApp.Api`** - Legacy domain (deprecated, alias to V1 for backward compatibility)

### Versioned Routers

- **`WandererAppWeb.Routers.ApiV1Router`** - V1 JSON:API routes
- **`WandererAppWeb.Routers.ApiV2Router`** - V2 JSON:API routes (prepared)
- **`WandererAppWeb.AshJsonApiRouter`** - Legacy router (deprecated)

### URL Structure

- **V1 API**: `/api/v1/` - Current stable API
- **V2 API**: `/api/v2/` - Future API version (not yet active)
- **Legacy**: `/api/` - Deprecated routes with sunset headers

## Versioning Principles

### Backward Compatibility

- V1 API maintains strict backward compatibility
- No breaking changes in V1 resource schemas
- Deprecation warnings before removal

### Version Lifecycle

1. **Current (V1)**: Active development and maintenance
2. **Deprecated**: 12-month sunset period with deprecation headers
3. **Removed**: Complete removal after sunset period

### Breaking Changes

Breaking changes require a new API version:
- Removing fields from response schemas
- Changing field types or formats
- Modifying required field sets
- Changing endpoint behavior

## Migration Path

### For API Consumers

1. **Current**: Continue using `/api/v1/` endpoints
2. **Future**: Migrate to `/api/v2/` when available
3. **Legacy**: Update any `/api/` usage to `/api/v1/`

### For Developers

1. **New Features**: Add to appropriate version (V1 for backward compatible, V2 for breaking)
2. **Bug Fixes**: Apply to all active versions
3. **Resource Evolution**: Create V2 resources for breaking schema changes

## Implementation Details

### Resource Versioning

Resources are shared between versions unless breaking changes require evolution:

```elixir
# V1 Domain
defmodule WandererApp.Api.V1 do
  resources do
    resource WandererApp.Api.Map  # Shared resource
    resource WandererApp.Api.User # Shared resource
  end
end

# V2 Domain (future)
defmodule WandererApp.Api.V2 do
  resources do
    resource WandererApp.Api.V2.Map  # Evolved resource with breaking changes
    resource WandererApp.Api.User    # Shared resource (no changes needed)
  end
end
```

### Router Structure

Each version has its own router mounted at the appropriate path:

```elixir
# Main Router
scope "/api/v1" do
  forward "/", WandererAppWeb.Routers.ApiV1Router
end

scope "/api/v2" do
  forward "/", WandererAppWeb.Routers.ApiV2Router
end
```

### Custom Endpoints

Custom business logic endpoints are versioned alongside JSON:API routes:

```elixir
scope "/api/v1", WandererAppWeb do
  # Custom endpoints
  get "/maps/:id/audit", MapAuditAPIController, :index
  
  # JSON:API routes
  forward "/", WandererAppWeb.Routers.ApiV1Router
end
```

## Deprecation Strategy

### Timeline

- **Immediate**: V1 becomes the primary API
- **6 months**: Add deprecation warnings to legacy `/api/` routes
- **12 months**: Remove legacy routes
- **Future**: When V2 is ready, begin V1 deprecation cycle

### Communication

- OpenAPI documentation updates
- Deprecation headers in responses
- Migration guides and examples
- Client library updates

## Monitoring

### Metrics

- API version usage statistics
- Deprecated endpoint usage tracking
- Error rates by version
- Performance comparison between versions

### Alerts

- High usage of deprecated endpoints
- New API version adoption rates
- Version-specific error spikes

## Future Considerations

### V2 Development

When ready for V2:
1. Define breaking changes needed
2. Create evolved resource definitions
3. Implement V2-specific business logic
4. Begin client migration planning

### Long-term Evolution

- Consider semantic versioning for minor updates
- Evaluate GraphQL for complex query requirements
- Plan for mobile-specific optimizations
- Consider real-time API improvements

## Resources

- [JSON:API Specification](https://jsonapi.org/)
- [AshJsonApi Documentation](https://ash-hq.org/docs/guides/ash_json_api/latest/tutorials/getting-started-with-ash-json-api)
- [Phoenix Router Guide](https://hexdocs.pm/phoenix/routing.html)