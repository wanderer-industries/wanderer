%{
  title: "New Feature: Map Duplication API",
  author: "Wanderer Team",
  cover_image_uri: "/images/news/07-13-map-duplication/duplicate-map.png",
  tags: ~w(maps duplication api guide interface),
  description: "Introducing the new Map Duplication API that allows you to programmatically copy existing maps with all their systems, connections, and optionally ACLs, user settings, and signatures."
}

---

## Introduction

We're excited to announce a powerful new feature for Wanderer: **Map Duplication via API**! This enhancement allows you to programmatically create copies of existing maps, including all their systems, connections, and optionally their access control lists (ACLs), user settings, and signatures.

Whether you're managing multiple similar mapping operations, creating templates for your corp, or need to backup and restore map configurations, the Map Duplication API provides a seamless way to:

- **Duplicate entire maps** with all systems and connections preserved
- **Selectively copy components** like ACLs, user settings, and signatures
- **Customize the new map** with a different name and description
- **Maintain ownership** as the duplicated map is created under your account

This feature is perfect for fleet commanders, corp leaders, and anyone who manages multiple maps with similar structures.

---

## Authentication

The Map Duplication API requires a valid **Map API Token**. You can generate this token from your map settings page. Pass it in the `Authorization` header:

```bash
Authorization: Bearer <MAP_API_TOKEN>
```

![Generate Map API Key](/images/news/01-05-map-public-api/generate-key.png "Generate Map API Key")

**Important:** Only the map owner can duplicate their maps. If you attempt to duplicate a map you don't own, you'll receive a `403 Forbidden` error.

---

## API Endpoint

### Duplicate a Map

```bash
POST /api/maps/{map_identifier}/duplicate
```

- **Description:** Creates a complete copy of an existing map with customizable options for what components to include.
- **Authentication:** Requires the Map API Token for the source map.
- **Path Parameter:** `map_identifier` can be either the map's UUID or its slug.

#### Request Body

```json
{
  "name": "New Map Name",
  "description": "Optional description for the duplicated map",
  "copy_acls": true,
  "copy_user_settings": true,
  "copy_signatures": true
}
```

**Parameters:**
- `name` *(required)*: Name for the duplicated map (3-20 characters)
- `description` *(optional)*: Description for the duplicated map
- `copy_acls` *(optional, default: true)*: Whether to copy access control lists
- `copy_user_settings` *(optional, default: true)*: Whether to copy user/character settings
- `copy_signatures` *(optional, default: true)*: Whether to copy system signatures

#### Example Request (using map slug)

```bash
curl -X POST \
  -H "Authorization: Bearer <MAP_API_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Backup Map",
        "description": "Backup of our main exploration map",
        "copy_acls": true,
        "copy_user_settings": true,
        "copy_signatures": false
      }' \
  "https://wanderer.example.com/api/maps/main-exploration-map/duplicate"
```

#### Example Request (using map UUID)

```bash
curl -X POST \
  -H "Authorization: Bearer <MAP_API_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Operation Echo",
        "description": "Duplicate for secondary operations",
        "copy_acls": false,
        "copy_user_settings": true,
        "copy_signatures": true
      }' \
  "https://wanderer.example.com/api/maps/550e8400-e29b-41d4-a716-446655440000/duplicate"
```

#### Example Response

```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "Backup Map",
    "slug": "backup-map-ae3f",
    "description": "Backup of our main exploration map"
  }
}
```

**Response Fields:**
- `id`: UUID of the newly created map
- `name`: Name of the duplicated map
- `slug`: Auto-generated slug for the duplicated map
- `description`: Description of the duplicated map

---

## What Gets Copied

When you duplicate a map, the following components are **always** copied:

### Core Map Data
- **Map metadata** (name, description, settings)
- **All systems** that were visible on the original map
- **All connections** between systems (including connection types, mass status, etc.)

### Optional Components

Depending on your request parameters:

- **Access Control Lists (ACLs)** - All ACLs and their members (`copy_acls: true`)
- **User Settings** - Character tracking preferences, main character settings (`copy_user_settings: true`) 
- **System Signatures** - All signatures discovered in the systems (`copy_signatures: true`)

### What's NOT Copied

- **Map ownership** - You become the owner of the duplicated map
- **Real-time character locations** - Character positions are not preserved
- **Map statistics** - Activity data and usage statistics start fresh

---

## Error Responses

### 400 Bad Request
```json
{
  "error": "Name must be at least 3 characters long"
}
```

### 403 Forbidden
```json
{
  "error": "Only the map owner can duplicate maps"
}
```

### 404 Not Found
```json
{
  "error": "Map not found"
}
```

### 422 Unprocessable Entity
```json
{
  "error": "Validation failed",
  "errors": [
    {
      "field": "name",
      "message": "has already been taken",
      "value": "Existing Map Name"
    }
  ]
}
```

---

## Use Cases

### 1. Creating Map Templates
```bash
# Create a base template map, then duplicate it for different operations
curl -X POST \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Exploration Team Alpha",
        "copy_acls": true,
        "copy_user_settings": false,
        "copy_signatures": false
      }' \
  "https://wanderer.example.com/api/maps/base-template/duplicate"
```

### 2. Map Backups
```bash
# Create a backup before major changes
curl -X POST \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Main Map Backup 2025-02-21",
        "description": "Backup before major restructuring",
        "copy_acls": true,
        "copy_user_settings": true,
        "copy_signatures": true
      }' \
  "https://wanderer.example.com/api/maps/main-operations/duplicate"
```

### 3. Testing Environments
```bash
# Create a test copy without sensitive ACLs
curl -X POST \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Test Environment",
        "description": "Safe testing area",
        "copy_acls": false,
        "copy_user_settings": false,
        "copy_signatures": true
      }' \
  "https://wanderer.example.com/api/maps/production-map/duplicate"
```

---

## Integration with Existing APIs

The Map Duplication API works seamlessly with existing Wanderer APIs:

1. **Use the [Systems API](/news/map-public-api-systems)** to manage systems on your duplicated map
2. **Use the [Connections API](/news/map-public-api-connections)** to modify connections
3. **Use the [ACL API](/news/acl-api)** to manage permissions on the new map
4. **Access via the [Web Interface](/)** - duplicated maps appear immediately in your map list

---

## Conclusion

The Map Duplication API provides a powerful way to:

1. **Create backups** of your important maps before major changes
2. **Generate templates** for recurring operations or team structures
3. **Set up testing environments** safely separated from production maps
4. **Scale operations** by quickly creating similar map configurations

With flexible options for what to copy and full API integration, map duplication streamlines complex mapping workflows and provides peace of mind for critical operations.

Ready to start duplicating? Check out the full API documentation in our [SwaggerUI interface](/swaggerui) for interactive testing and complete parameter details.

---

Fly safe,  
**The Wanderer Team**

---