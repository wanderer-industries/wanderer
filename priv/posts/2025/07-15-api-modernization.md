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

### Improved API Documentation
- **Streamlined Swagger UI** with automatic redirect to v1 documentation
- **Separated documentation** - Clear distinction between v1 and legacy APIs
- **Interactive testing** - Try endpoints directly in your browser
- **No more confusion** - Eliminated mixed API views with non-functional accordions

## Getting Started with API v1

### Base URL Structure
Our new API v1 is available at:
```
https://your-wanderer-instance.com/api/v1/
```

### API Documentation
Interactive API documentation is available at:
- **Swagger UI (v1 - Recommended)**: `https://your-wanderer-instance.com/swaggerui` (redirects to v1)
- **Swagger UI (v1 Direct)**: `https://your-wanderer-instance.com/swaggerui/v1`
- **Swagger UI (Legacy)**: `https://your-wanderer-instance.com/swaggerui/legacy`
- **OpenAPI Spec**: `https://your-wanderer-instance.com/api/v1/open_api`

*Note: The root `/swaggerui` URL now automatically redirects to the recommended v1 API documentation for a cleaner developer experience.*

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

### Authentication: Token-Only Simplicity

API v1 uses **token-only authentication** - a simplified approach where your Bearer token identifies both your user account and the specific map you're working with.

#### How It Works

**One Token = One Map**
- Each map has a unique API key
- The token automatically identifies which map you're accessing
- You **never** need to provide `map_id` in your requests
- Impossible to accidentally access the wrong map

**Bearer Token Authentication:**
```bash
# Simple! Just the token - no map_id needed
curl -H "Authorization: Bearer your-map-api-key" \
  https://your-wanderer-instance.com/api/v1/map_systems
```

**Getting Your API Key:**
You can find or generate your map's API key in the map settings within the Wanderer web interface. Each map has its own unique API key for secure access.

**Session Authentication:**
Web clients can also use session-based authentication for interactive use, maintaining compatibility with existing browser-based integrations.

#### Key Benefits

- **Simpler Requests** - No need to track or specify map IDs
- **Better Security** - Token scoping prevents cross-map access
- **Less Error-Prone** - Impossible to provide wrong map_id
- **Cleaner Code** - Fewer parameters to manage

#### Security Model

Your API token provides:
- **Authentication** - Verifies your identity
- **Map Context** - Automatically determines which map you're accessing
- **Authorization** - Enforces map-level permissions

All API operations are automatically scoped to the map identified by your token. This means:
- Creating resources (systems, connections, etc.) automatically uses your token's map
- Reading resources only returns data from your token's map
- Updating/deleting resources only affects data on your token's map

## API Architecture: v1 vs Legacy

Wanderer maintains two API surfaces to support different use cases and migration paths:

### API v1 (JSON:API Standard) - **RECOMMENDED**

- **Base Path:** `/api/v1/*`
- **Format:** JSON:API compliant responses
- **Authentication:** Bearer token using map's public API key
- **Features:**
  - Standardized request/response format
  - Advanced filtering and sorting
  - Relationship includes
  - Sparse fieldsets
  - Consistent error handling
- **Documentation:** `/swaggerui/v1`

**Available Resources:**
- Maps, Map Systems, Map Connections
- Map Signatures, Map Structures
- Map Subscriptions, Map Comments
- Access Lists, Access List Members
- Map Webhook Subscriptions
- Map Invites, Map Pings
- User Activities, User Settings
- And more...

### Legacy API (Plain JSON) - **MAINTENANCE MODE**

- **Base Path:** `/api/*`
- **Format:** Plain JSON (non-standard)
- **Authentication:** Session or Bearer token
- **Status:** Maintained for backward compatibility only

**Legacy Endpoints:**
- Characters (`/api/characters`) - **DEPRECATED** (use Access Lists API)
- Map Webhooks (`/api/maps/:id/webhooks`) - **Use v1 instead**
- Map Events (`/api/maps/:id/events`)

**Important Notes:**
- Legacy endpoints receive security fixes but no new features
- New integrations should use API v1
- Existing integrations continue to work unchanged
- Migration to v1 recommended for all new development

### When to Use Which API

| Use Case | Recommended API | Endpoint |
|----------|----------------|----------|
| List maps | ✅ API v1 | `/api/v1/maps` |
| Get map systems | ✅ API v1 | `/api/v1/map_systems` |
| Manage webhooks | ✅ API v1 | `/api/v1/map_webhook_subscriptions` |
| Create map invites | ✅ API v1 | `/api/v1/map_invites` |
| Get character info | ✅ API v1 | `/api/v1/access_lists` |
| Real-time events | Legacy (for now) | `/api/maps/:id/events/stream` |

### Migration Timeline

- **Now:** Both APIs fully supported
- **Next 3 months:** Deprecation warnings on legacy endpoints
- **Next 6 months:** Legacy endpoint removal dates announced
- **Future:** Legacy API sunset (specific dates TBD)

**Recommendation:** Start new integrations with API v1 and plan migration for existing integrations.

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

# Filter systems by status (map_id automatically scoped from token)
GET /api/v1/map_systems?filter[status]=friendly
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

The API v1 provides access to 21+ resources through the Ash Framework, all following JSON:API specifications. Here are the primary resources:

### Core Resources
- **Maps** (`/api/v1/maps`) - Map management with full CRUD operations
  - Custom route: `GET /api/v1/maps/:slug` - Get map by slug instead of ID
- **Access Lists** (`/api/v1/access_lists`) - ACL management and permissions with full CRUD operations
- **Access List Members** (`/api/v1/access_list_members`) - ACL member management with full CRUD operations (paginated: default 100, max 500)

### Map Resources
- **Map Systems** (`/api/v1/map_systems`) - Solar system data and metadata with full CRUD operations (paginated: default 100, max 500)
- **Map Connections** (`/api/v1/map_connections`) - Wormhole connections with full CRUD operations
- **Map Signatures** (`/api/v1/map_system_signatures`) - Signature scanning data with full CRUD operations (paginated: default 50, max 200)
- **Map Structures** (`/api/v1/map_system_structures`) - Structure information with full CRUD operations (paginated: default 100, max 500)
  - Custom route: `GET /api/v1/map_system_structures/active` - List all active structures
  - Custom route: `GET /api/v1/map_system_structures/by_system/:system_id` - Filter by system
- **Map Subscriptions** (`/api/v1/map_subscriptions`) - Subscription management (read-only, paginated: default 100, max 500)
- **Map Default Settings** (`/api/v1/map_default_settings`) - Default map configurations with full CRUD operations
- **Map Systems and Connections** (`/api/v1/maps/{map_id}/systems_and_connections`) - Combined endpoint (read-only)
- **Map Pings** (`/api/v1/map_pings`) - System notification pings with full CRUD operations (paginated: default 100, max 500)
  - Custom route: `PATCH /api/v1/map_pings/:id/acknowledge` - Acknowledge a ping
- **Map Invites** (`/api/v1/map_invites`) - Map invitation management with full CRUD operations (paginated: default 100, max 500)
  - Custom route: `PATCH /api/v1/map_invites/:id/revoke` - Revoke an invite
- **Map Access Lists** (`/api/v1/map_access_lists`) - Map-to-ACL associations with full CRUD operations (paginated: default 100, max 500)
  - Custom route: `GET /api/v1/map_access_lists/by_map/:map_id` - Filter by map
  - Custom route: `GET /api/v1/map_access_lists/by_acl/:acl_id` - Filter by ACL

### Integration Resources
- **Map Webhook Subscriptions** (`/api/v1/map_webhook_subscriptions`) - Webhook configuration for receiving event notifications with full CRUD operations (paginated: default 100, max 500)

### System Resources
- **Map System Comments** (`/api/v1/map_system_comments`) - System annotations (read-only, paginated: default 100, max 500)
  - Custom route: `GET /api/v1/map_system_comments/by_system/:system_id` - Filter comments by system

### User Resources
- **User Activities** (`/api/v1/user_activities`) - User activity tracking (read-only, paginated: default 15)
- **Map Character Settings** (`/api/v1/map_character_settings`) - Character preferences (read-only)
- **Map User Settings** (`/api/v1/map_user_settings`) - User map preferences (read-only)

*Note: Resources marked as "full CRUD operations" support create, read, update, and delete. Resources marked as "read-only" support only GET operations. Resources marked as "read and delete only" support GET and DELETE operations. Pagination limits are configurable via `page[limit]` and `page[offset]` parameters where supported.*

### ⚠️ Important Security Note: Characters API

**The legacy Characters endpoint (`/api/characters`) has been deprecated due to critical security concerns.**

**Why Deprecated:**
- **Privacy Risk:** This endpoint exposed ALL character data from the entire database globally
- **No Scoping:** Character information was not scoped to specific maps or user permissions
- **Excessive Data Exposure:** Returned corporation, alliance, location, and wallet data for all users
- **No Valid Use Case:** No legitimate integration required a global character list

**What Changed:**
- The endpoint remains accessible but returns deprecation warnings
- Response includes `X-API-Deprecated` headers with migration guidance
- Usage is logged for security auditing
- All responses include migration instructions in the response body

**Secure Alternative - Use Access Lists API:**

Access Lists provide character information with proper scoping and permissions:

```bash
# Get characters for your map (automatically scoped from token)
GET /api/v1/access_lists?include=members

# Get specific access list with members
GET /api/v1/access_lists/<acl-id>?include=members

# Get individual member details
GET /api/v1/access_list_members/<member-id>?include=character
```

**Migration Guide:**

If you were using the Characters endpoint, here's how to migrate:

**Before (Deprecated - Insecure):**
```bash
# DON'T USE - Exposes all characters globally
GET /api/characters
```

**After (Secure - Map-scoped):**
```bash
# Get characters with automatic map scoping from token
GET /api/v1/access_lists?include=members

# Response includes only characters with access to YOUR map (determined by token)
{
  "data": [{
    "type": "access_lists",
    "id": "acl-123",
    "relationships": {
      "members": {
        "data": [
          {"type": "access_list_members", "id": "member-456"}
        ]
      }
    }
  }],
  "included": [{
    "type": "access_list_members",
    "id": "member-456",
    "attributes": {
      "character_eve_id": "123456",
      "character_name": "John Doe",
      "corporation_ticker": "CORP"
    }
  }]
}
```

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
API v1 provides SSE streaming with JSON:API formatted events:

```bash
# v1 SSE endpoint with JSON:API formatting
curl -H "Authorization: Bearer your-map-api-key" \
  "https://your-wanderer-instance.com/api/v1/maps/your-map-slug/events/stream?format=jsonapi"

# Legacy SSE endpoint (also available)
curl -H "Authorization: Bearer your-map-api-key" \
  "https://your-wanderer-instance.com/api/maps/your-map-slug/events/stream?format=jsonapi"
```

**Available Endpoints:**
- **v1** (Recommended): `/api/v1/maps/{map_identifier}/events/stream`
- **Legacy** (Maintained): `/api/maps/{map_identifier}/events/stream`

Both endpoints accept the same parameters:
- `format=jsonapi` - Use JSON:API formatted events (default: legacy format)
- `events=add_system,map_kill` - Filter specific event types
- `last_event_id=<ulid>` - Resume from last event for backfill

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

### Webhook Management API

The Webhook Management API allows you to programmatically manage webhook subscriptions for your maps using JSON:API compliant endpoints.

**Endpoint:** `/api/v1/map_webhook_subscriptions`

**Authentication:** Bearer token required (use your map's API key)

#### Creating a Webhook Subscription

```bash
curl -X POST \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_webhook_subscriptions",
      "attributes": {
        "url": "https://example.com/webhook",
        "events": ["add_system", "character_updated", "connection_added"],
        "active": true
      }
    }
  }' \
  https://your-instance.com/api/v1/map_webhook_subscriptions
```

**Note:** The `map_id` is automatically determined from your Bearer token - no need to specify it!

**Features:**
- **Auto-generated secrets**: Each webhook receives a unique secret for signature verification
- **HTTPS enforcement**: Only HTTPS URLs are accepted for security
- **Event filtering**: Subscribe to specific events or use `["*"]` for all events
- **Flexible event types**: `add_system`, `character_updated`, `connection_added`, `map_kill`, and more

#### Listing Webhook Subscriptions

```bash
# List all webhooks for your map (automatically scoped from token)
GET /api/v1/map_webhook_subscriptions

# Include map relationship data
GET /api/v1/map_webhook_subscriptions?include=map
```

#### Updating a Webhook

```bash
curl -X PATCH \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_webhook_subscriptions",
      "id": "webhook-id",
      "attributes": {
        "active": false,
        "events": ["add_system"]
      }
    }
  }' \
  https://your-instance.com/api/v1/map_webhook_subscriptions/webhook-id
```

#### Deleting a Webhook

```bash
curl -X DELETE \
  -H "Authorization: Bearer your-api-key" \
  https://your-instance.com/api/v1/map_webhook_subscriptions/webhook-id
```

**Response Format:**
```json
{
  "data": {
    "type": "map_webhook_subscriptions",
    "id": "webhook-uuid",
    "attributes": {
      "url": "https://example.com/webhook",
      "events": ["add_system", "character_updated"],
      "active": true,
      "secret": "generated-secret-key",
      "last_delivery_at": "2025-01-15T10:30:00Z",
      "last_error": null,
      "consecutive_failures": 0
    },
    "relationships": {
      "map": {
        "data": {"type": "maps", "id": "map-uuid"}
      }
    }
  }
}
```

**Security Features:**
- Map owners can create, update, and delete webhooks
- Map members with write access can create webhooks
- Only HTTPS URLs accepted (private IPs blocked)
- Automatic secret generation for signature verification
- Delivery tracking with error logging

**Legacy Endpoint (Deprecated):**
The legacy webhook endpoint at `/api/maps/:map_identifier/webhooks` is still available for backward compatibility but is deprecated. New integrations should use `/api/v1/map_webhook_subscriptions`.

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

### Token-Only Authentication: Before & After

One of the biggest improvements in API v1 is the elimination of redundant `map_id` parameters. Here's what changed:

#### Creating a Map System

**Before (Complex - Required map_id in multiple places):**
```bash
curl -X POST \
  "https://your-instance.com/api/v1/map_systems?filter[map_id]=817f8d93-de01-479e-950f-a1e905658940" \
  -H "Authorization: Bearer 32adcbf7-c9db-4a75-a9da-050950370ab6" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "map_id": "817f8d93-de01-479e-950f-a1e905658940",
        "solar_system_id": 30000142,
        "name": "Jita",
        "visible": true
      }
    }
  }'
```

**After (Simple - Token handles everything):**
```bash
curl -X POST \
  "https://your-instance.com/api/v1/map_systems" \
  -H "Authorization: Bearer 32adcbf7-c9db-4a75-a9da-050950370ab6" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "solar_system_id": 30000142,
        "name": "Jita",
        "visible": true
      }
    }
  }'
```

**Benefits:**
- **3 fewer parameters** to manage (no map_id in query, body, or URL)
- **Impossible to use wrong map** - Token guarantees correct map context
- **Cleaner code** - Less boilerplate in every request
- **Better security** - No risk of accidentally accessing another map

#### API Comparison Table

| Feature | Old Approach | New Approach (v1) |
|---------|-------------|-------------------|
| **Authentication** | Token identifies user | Token identifies user **and map** |
| **Map Context** | Manually specify `map_id` | Automatic from token |
| **Parameters per Request** | Token + map_id (query/body) | Token only |
| **Error Possibility** | Can provide wrong map_id | Impossible - token enforces correct map |
| **Security** | Manual validation needed | Automatic scoping |
| **Code Complexity** | High - track map IDs everywhere | Low - token handles it |
| **Migration Difficulty** | N/A | Easy - just remove map_id parameters |

### Migrating to Token-Only Authentication

If you have existing integrations that provide `map_id` in requests, here's how to migrate:

#### Step 1: Identify Current Usage

Find all places in your code where you're providing `map_id`:
```javascript
// Common patterns to search for:
// - Query parameters: ?filter[map_id]=...
// - Request body: "map_id": "..."
// - URL paths: /api/v1/maps/{map_id}/...
```

#### Step 2: Remove map_id Parameters

**From Query Parameters:**
```javascript
// Before
const url = `/api/v1/map_systems?filter[map_id]=${mapId}&filter[status]=friendly`;

// After
const url = `/api/v1/map_systems?filter[status]=friendly`;
```

**From Request Bodies:**
```javascript
// Before
const payload = {
  data: {
    type: "map_systems",
    attributes: {
      map_id: mapId,          // Remove this
      solar_system_id: 30000142,
      name: "Jita"
    }
  }
};

// After
const payload = {
  data: {
    type: "map_systems",
    attributes: {
      solar_system_id: 30000142,
      name: "Jita"
    }
  }
};
```

#### Step 3: Verify Token Configuration

Ensure your Bearer token is correctly set:
```javascript
// Make sure you're using the correct map's API token
const headers = {
  'Authorization': `Bearer ${YOUR_MAP_API_TOKEN}`,
  'Content-Type': 'application/vnd.api+json'
};
```

#### Step 4: Test Incrementally

1. **Update read operations first** - Safest to start with GET requests
2. **Test with non-critical data** - Verify behavior before production
3. **Update create/update operations** - Once confident with reads
4. **Monitor for errors** - Check that operations affect the correct map

#### Backward Compatibility Note

**Good news:** If you forget to remove `map_id` from your requests, the API will silently ignore it and use the token's map instead. This means:
- **No breaking changes** for existing integrations
- **Gradual migration possible** - Update at your own pace
- **Safety net** - Wrong map_id in request won't cause issues

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

## Best Practices for API v1

### Token Management

**Use Environment Variables**
```javascript
// Good - Token stored securely
const API_TOKEN = process.env.WANDERER_API_TOKEN;

// Bad - Hardcoded token (security risk)
const API_TOKEN = "abc123-hardcoded-token";
```

**One Token per Map**
- Each map should have its own unique API token
- Never share tokens between different maps or applications
- Rotate tokens regularly for enhanced security
- Store tokens securely (environment variables, secrets management)

### Request Optimization

**Use Relationship Includes**
```bash
# Good - Single request with related data
GET /api/v1/map_systems?include=signatures,connections

# Bad - Multiple requests
GET /api/v1/map_systems
GET /api/v1/map_system_signatures
GET /api/v1/map_connections
```

**Filter on the Server**
```bash
# Good - Server-side filtering
GET /api/v1/map_systems?filter[status]=friendly

# Bad - Fetch all, filter client-side
GET /api/v1/map_systems
# Then filter in JavaScript
```

**Use Pagination for Large Datasets**
```bash
# Good - Paginated requests
GET /api/v1/map_systems?page[limit]=100&page[offset]=0

# Bad - Fetch everything at once
GET /api/v1/map_systems
```

### Token-Only Authentication Best Practices

**Do:**
- ✅ Trust the token to identify your map
- ✅ Remove all `map_id` parameters from requests
- ✅ Use one token per integration/application
- ✅ Store tokens securely in environment variables
- ✅ Regenerate tokens if compromised

**Don't:**
- ❌ Include `map_id` in query parameters (redundant)
- ❌ Include `map_id` in request bodies (will be ignored)
- ❌ Try to access multiple maps with one token
- ❌ Share tokens across different applications
- ❌ Store tokens in version control or client-side code

### Error Handling

**Always Check Response Status**
```javascript
const response = await fetch(url, {
  headers: { 'Authorization': `Bearer ${token}` }
});

if (!response.ok) {
  const error = await response.json();
  console.error('API Error:', error);
  // Handle error appropriately
}

const data = await response.json();
```

**Handle Rate Limits Gracefully**
```javascript
if (response.status === 429) {
  const retryAfter = response.headers.get('Retry-After');
  console.log(`Rate limited. Retry after ${retryAfter} seconds`);
  // Implement exponential backoff
}
```

### Security Best Practices

**Always Use HTTPS**
```javascript
// Good
const baseUrl = 'https://your-instance.com/api/v1';

// Bad - Insecure!
const baseUrl = 'http://your-instance.com/api/v1';
```

**Validate SSL Certificates**
```javascript
// Don't disable SSL verification in production
// Bad example - NEVER do this in production:
// fetch(url, { rejectUnauthorized: false })
```

**Monitor Token Usage**
- Regularly audit which applications are using your tokens
- Revoke unused or compromised tokens immediately
- Set up alerts for unusual API activity

### Performance Best Practices

**Batch Operations When Possible**
```javascript
// Good - Batch create if API supports it
POST /api/v1/map_systems
// With array of systems

// Less optimal - Individual requests
// Multiple POST /api/v1/map_systems calls
```

**Cache Static Data**
```javascript
// Cache system static info (doesn't change)
const systemInfoCache = new Map();

async function getSystemInfo(systemId) {
  if (systemInfoCache.has(systemId)) {
    return systemInfoCache.get(systemId);
  }

  const info = await fetch(`/api/v1/map_systems/${systemId}`);
  systemInfoCache.set(systemId, info);
  return info;
}
```

**Use Webhooks for Real-Time Updates**
```javascript
// Good - Webhooks push updates to you
POST /api/v1/map_webhook_subscriptions
// Subscribe to events

// Less efficient - Polling
// setInterval(() => fetch('/api/v1/map_systems'), 5000)
```

### Integration Patterns

**Multi-Map Applications**

If you need to work with multiple maps:

```javascript
// Good - Separate clients per map
class WandererClient {
  constructor(mapToken) {
    this.token = mapToken;
  }

  async getMapSystems() {
    return fetch('/api/v1/map_systems', {
      headers: { 'Authorization': `Bearer ${this.token}` }
    });
  }
}

const map1Client = new WandererClient(MAP1_TOKEN);
const map2Client = new WandererClient(MAP2_TOKEN);
```

**Webhook Integration**

```javascript
// Verify webhook signatures for security
function verifyWebhookSignature(payload, signature, secret) {
  const expectedSig = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSig)
  );
}

app.post('/webhook', (req, res) => {
  const signature = req.headers['x-wanderer-signature'];

  if (!verifyWebhookSignature(req.body, signature, WEBHOOK_SECRET)) {
    return res.status(401).send('Invalid signature');
  }

  // Process webhook event
  handleWebhookEvent(req.body);
  res.status(200).send('OK');
});
```

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
- **Streamlined Swagger UI** - `/swaggerui` now redirects to the recommended v1 API documentation
- **Separated API docs** - Clear distinction between v1 (`/swaggerui/v1`) and legacy (`/swaggerui/legacy`) endpoints
- **Live API testing** - Try endpoints directly in the browser with interactive Swagger UI
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
