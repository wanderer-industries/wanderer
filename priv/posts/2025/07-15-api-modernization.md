%{
title: "API Modernization: JSON:API v1 and Enhanced Developer Experience",
author: "Wanderer Team",
cover_image_uri: "/images/news/07-15-api-modernization/api-hero.png",
tags: ~w(api json-api v1 modernization developer-experience backwards-compatibility ash-framework),
description: "Introducing Wanderer's new JSON:API v1 endpoints with enhanced developer experience, comprehensive versioning, and enterprise-grade security - all while maintaining 100% backward compatibility."
}

---

# API Modernization: JSON:API v1 and Enhanced Developer Experience

We're excited to announce the launch of Wanderer's modernized API v1, a comprehensive overhaul that brings JSON:API compliance, advanced security features, and enhanced developer experience to our API ecosystem. This modernization represents months of careful planning and implementation, all while maintaining 100% backward compatibility with existing integrations.

The new API v1 leverages the power of the Ash Framework and AshJsonApi to provide a standards-compliant, feature-rich API that scales with your needs. Whether you're building complex integrations, mobile applications, or automated tools, our new API provides the modern foundation you need.

## What's New?

### JSON:API Compliance
- **Standards-compliant** JSON:API specification implementation
- **Consistent response formats** across all endpoints
- **Relationship management** with compound documents
- **Advanced filtering and sorting** capabilities
- **Offset-based pagination** for select high-volume resources

### Simplified API Versioning
- **Consolidated v1 API** with all features included
- **Flexible version detection** via URL, headers, or query parameters
- **Graceful fallback** for unsupported versions
- **Comprehensive feature set** in a single stable version

### Enhanced Security & Authentication
- **Bearer token authentication** using map-specific API keys
- **Secure authentication** with comprehensive access controls

## Getting Started with API v1

### Base URL Structure
Our new API v1 is available at:
```
https://your-wanderer-instance.com/api/v1/
```

### API Documentation
Interactive API documentation is available at:
- **Swagger UI**: `https://your-wanderer-instance.com/swaggerui/v1`
- **OpenAPI Spec**: `https://your-wanderer-instance.com/api/v1/open_api`
- **Combined API Docs**: `https://your-wanderer-instance.com/swaggerui` (includes both legacy and v1)

### Version Detection
The API supports multiple version detection methods:

**URL Path (Recommended):**
```
GET /api/v1/maps
```

**Headers:**
```
API-Version: 1
Accept: application/vnd.wanderer.v1+json
```

**Query Parameters:**
```
GET /api/v1/maps?version=1
```

### Authentication
API v1 uses Bearer token authentication with your map's public API key:

**Bearer Token Authentication:**
```bash
curl -H "Authorization: Bearer your-map-api-key" \
  https://your-wanderer-instance.com/api/v1/maps
```

**Getting Your API Key:**
You can find or generate your map's API key in the map settings within the Wanderer web interface. Each map has its own unique API key for secure access.

**Session Authentication:**
Web clients can also use session-based authentication for interactive use, maintaining compatibility with existing browser-based integrations.

## JSON:API Features

### Resource Relationships
Fetch related data in a single request:
```bash
# Get maps with their owner, characters, and access lists
GET /api/v1/maps?include=owner,characters,acls

# Get characters with their user information
GET /api/v1/characters?include=user

# Get access lists with their members
GET /api/v1/access_lists?include=members
```

### Advanced Filtering
Powerful filtering capabilities for precise data retrieval:
```bash
# Filter maps by scope
GET /api/v1/maps?filter[scope]=public

# Filter characters by name
GET /api/v1/characters?filter[name]=Alice

# Filter multiple criteria
GET /api/v1/map_systems?filter[status]=friendly&filter[map_id]=your-map-id
```

### Sorting and Pagination
Flexible sorting with offset-based pagination (available on select resources):
```bash
# Sort by creation date (newest first) then by name
GET /api/v1/maps?sort=-inserted_at,name

# Offset-based pagination (available on map_systems, map_system_signatures, user_activities)
GET /api/v1/map_systems?page[limit]=100&page[offset]=0

# Combined filtering, sorting, and pagination
GET /api/v1/map_system_signatures?filter[kind]=wormhole&sort=-updated_at&page[limit]=50&page[offset]=0

# Combined systems and connections endpoint (new convenience endpoint)
GET /api/v1/maps/{map_id}/systems_and_connections
```

### Advanced Features
Additional capabilities for optimizing your API usage:
```bash
# Include relationships in a single request
GET /api/v1/maps?include=owner,characters,acls

# Combine includes with filtering
GET /api/v1/characters?include=user&filter[name]=Alice

# Filter and sort user activities with pagination
GET /api/v1/user_activities?include=character&sort=-inserted_at&page[limit]=15&page[offset]=0
```

## Available Resources

The API v1 provides access to over 25 resources through the Ash Framework. Here are the primary resources:

### Core Resources
- **Maps** (`/api/v1/maps`) - Map management with full CRUD operations
- **Characters** (`/api/v1/characters`) - Character tracking and management (GET, DELETE only)
- **Access Lists** (`/api/v1/access_lists`) - ACL management and permissions
- **Access List Members** (`/api/v1/access_list_members`) - ACL member management

### Map Resources
- **Map Systems** (`/api/v1/map_systems`) - Solar system data and metadata
- **Map Connections** (`/api/v1/map_connections`) - Wormhole connections
- **Map Signatures** (`/api/v1/map_system_signatures`) - Signature scanning data (GET, DELETE only)
- **Map Structures** (`/api/v1/map_system_structures`) - Structure information
- **Map Subscriptions** (`/api/v1/map_subscriptions`) - Subscription management (GET only)
- **Map Systems and Connections** (`/api/v1/maps/{map_id}/systems_and_connections`) - Combined endpoint (GET only)

### System Resources
- **Map System Comments** (`/api/v1/map_system_comments`) - System annotations (GET only)

### User Resources
- **User Activities** (`/api/v1/user_activities`) - User activity tracking (GET only)
- **Map Character Settings** (`/api/v1/map_character_settings`) - Character preferences (GET only)
- **Map User Settings** (`/api/v1/map_user_settings`) - User map preferences (GET only)

### Additional Resources
- **Map Webhook Subscriptions** (`/api/v1/map_webhook_subscriptions`) - Webhook management
- **Map Invites** (`/api/v1/map_invites`) - Map invitation system
- **Map Pings** (`/api/v1/map_pings`) - In-game ping tracking
- **Corp Wallet Transactions** (`/api/v1/corp_wallet_transactions`) - Corporation finances

*Note: Some resources have been restricted to read-only access for security and consistency. Resources marked as "(GET only)" support only read operations, while "(GET, DELETE only)" support read and delete operations.*

## API v1 Feature Set

Our consolidated API v1 provides a comprehensive feature set:
- Full CRUD operations for supported resources
- Advanced filtering and sorting capabilities
- Relationship includes and sparse fieldsets
- Offset-based pagination for select resources
- Bearer token authentication
- Webhook integration
- Real-time event streaming via SSE
- Advanced security features and audit logging
- Bulk operations for efficient data management
- Enhanced error handling with detailed suggestions

*Note: All features are available in v1, providing a complete and stable API surface for integrations.*

## Real-Time Integration

### Server-Sent Events
API v1 maintains compatibility with our existing SSE implementation while adding JSON:API formatted events:

```bash
# Connect to SSE with JSON:API formatting
curl -H "Accept: application/vnd.wanderer.v1+json" \
  https://your-wanderer-instance.com/api/v1/maps/123/events/stream
```

### Webhook Integration
Enhanced webhook support with JSON payloads. Webhooks currently use a simple JSON format (JSON:API formatting is planned for a future release):

**Character Updated Event Example:**
```json
{
  "event_type": "character_updated",
  "map_id": "map-uuid-789",
  "character_id": "char-uuid-123",
  "data": {
    "ship_type_id": 670,
    "ship_name": "Capsule",
    "solar_system_id": 30000142,
    "online": true
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**System Metadata Changed Event Example:**
```json
{
  "event_type": "system_metadata_changed",
  "map_id": "map-uuid-789", 
  "system_id": "system-uuid-456",
  "data": {
    "locked": true,
    "tag": "staging",
    "priority": 1,
    "name": "J123456"
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

*Note: JSON:API formatted webhook payloads are planned for a future release to match the SSE event format.*

## Performance and Reliability

The API v1 is designed for high performance and reliability:
- Optimized database queries with efficient caching
- Streamlined authentication flows
- Robust error handling and graceful degradation
- Compiled route patterns for faster request routing
- Enhanced similarity detection for helpful error suggestions

## Migration Guide

### Backward Compatibility
**Your existing API integrations continue to work unchanged.** All current `/api/*` endpoints remain fully functional with identical behavior.

### Gradual Migration
We recommend a gradual migration approach:

1. **Test Integration** - Start with read-only operations on non-critical data
2. **Parallel Operation** - Run both old and new integrations side by side
3. **Feature Enhancement** - Leverage new JSON:API features incrementally
4. **Complete Migration** - Transition fully to v1 endpoints

### Migration Benefits
- **Reduced API calls** through relationship includes
- **Improved performance** with sparse fieldsets and compiled routing
- **Better error handling** with standardized error responses and route suggestions
- **Enhanced security** with robust authentication and access controls
- **Simplified versioning** with a single stable API version
- **Better developer experience** with comprehensive introspection and documentation

## Security Enhancements

### Enhanced Authentication
- Map-specific API key authentication
- API key management and regeneration
- Secure session handling

### Access Control
- Resource-level permissions
- Role-based access controls
- CORS configuration for secure cross-origin requests

## Developer Experience Improvements

### Interactive Documentation
- **Auto-generated OpenAPI specifications** for all endpoints
- **Interactive Swagger UI** available at `/swaggerui/v1` for live API testing
- **Comprehensive examples** for common use cases
- **Machine-readable OpenAPI spec** at `/api/v1/open_api` for client generation

### Error Handling
Enhanced error responses with helpful suggestions:
```json
{
  "error": {
    "code": "ROUTE_NOT_FOUND",
    "message": "The requested route is not available in version 1",
    "details": {
      "requested_path": "/api/v1/map",
      "requested_method": "GET",
      "requested_version": "1",
      "available_versions": ["1"],
      "suggested_routes": [
        {
          "version": "1",
          "method": "GET", 
          "path": "/api/v1/maps",
          "description": "List all maps with full feature set"
        }
      ]
    }
  }
}
```

### Future Enhancements
- **Rate Limiting**: Transparent rate limiting with informative headers (planned)
- **Enhanced Webhook Formats**: JSON:API formatted webhook payloads (planned)
- **Advanced Analytics**: Detailed usage analytics and insights (planned)
- **Route Introspection**: Advanced route discovery and documentation APIs

## Getting Help

### Community Support
- **Discord**: Join our developer community
- **GitHub Issues**: Report bugs and request features


## Conclusion

The API v1 modernization represents a significant leap forward in Wanderer's API ecosystem. By consolidating multiple versions into a single, feature-complete API with JSON:API compliance, enhanced security, and enterprise-grade performance, we've created a robust foundation for the future of EVE Online mapping integrations.

The simplified versioning approach eliminates confusion while providing all advanced features in a single stable version. Enhanced error handling with route suggestions, compiled routing for better performance, and comprehensive introspection capabilities make the API more developer-friendly than ever.

The zero-downtime migration, comprehensive backward compatibility, and gradual rollout capabilities ensure that your existing integrations continue to work while providing a clear path to leverage advanced features.

We're excited to see what you build with these new capabilities. The combination of real-time events, comprehensive filtering, relationship management, performance optimization, and intelligent error handling opens up possibilities for more sophisticated and responsive EVE Online tools.

Start exploring the new API v1 today and experience the difference that modern, standards-compliant APIs with intelligent routing can make for your EVE Online mapping workflows.
