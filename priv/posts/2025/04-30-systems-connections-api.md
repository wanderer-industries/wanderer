%{
  title: "Guide: Systems and Connections API",
  author: "Wanderer Team",
  cover_image_uri: "/images/news/03-06-systems/api-endpoints.png",
  tags: ~w(api map systems connections documentation),
  description: "Detailed guide for Wanderer's systems and connections API endpoints, including batch operations, updates, and deletions."
}

---

# Guide to Wanderer's Systems and Connections API

## Introduction

This guide covers Wanderer's dedicated API endpoints for managing systems and connections on your maps. These endpoints provide fine-grained control over individual systems and connections, as well as batch operations for efficient updates.

With these APIs, you can:

- Create, update, and delete individual systems
- Create, update, and delete individual connections
- Perform batch operations on systems and connections
- Query system and connection details

---

## Authentication

All endpoints require a Map API Token, which you can generate in your map settings. Pass the token in the Authorization header:

```bash
Authorization: Bearer <YOUR_MAP_TOKEN>
```

---

## Systems Endpoints

### 1. List Systems

```bash
GET /api/maps/:map_identifier/systems
```

- **Description:** Retrieves all systems and their connections for the specified map.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.

#### Example Request

```bash
curl -H "Authorization: Bearer <YOUR_TOKEN>" \
     "https://wanderer.example.com/api/maps/your-map-slug/systems"
```

#### Example Response

```json
{
  "data": {
    "systems": [
      {
        "id": "<SYSTEM_UUID>",
        "solar_system_id": 30000142,
        "solar_system_name": "Jita",
        "position_x": 100.5,
        "position_y": 200.3,
        "status": "clear",
        "visible": true,
        "description": "Trade hub",
        "tag": "TRADE",
        "locked": false,
        "labels": ["market", "highsec"],
        "map_id": "<MAP_UUID>"
      }
    ],
    "connections": [
      {
        "id": "<CONNECTION_UUID>",
        "solar_system_source": 30000142,
        "solar_system_target": 30000144,
        "type": 0,
        "mass_status": 0,
        "time_status": 0,
        "ship_size_type": 1,
        "wormhole_type": "K162",
        "count_of_passage": 0,
        "locked": false,
        "custom_info": "Fresh hole"
      }
    ]
  }
}
```

### 2. Show Single System

```bash
GET /api/maps/:map_identifier/systems/:id
```

- **Description:** Retrieves details for a specific system.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.
  - `id` (required) — the system's solar_system_id.

#### Example Request

```bash
curl -H "Authorization: Bearer <YOUR_TOKEN>" \
     "https://wanderer.example.com/api/maps/your-map-slug/systems/30000142"
```

#### Example Response

```json
{
  "data": {
    "id": "<SYSTEM_UUID>",
    "solar_system_id": 30000142,
    "solar_system_name": "Jita",
    "position_x": 100.5,
    "position_y": 200.3,
    "status": "clear",
    "visible": true,
    "description": "Trade hub",
    "tag": "TRADE",
    "locked": false,
    "labels": ["market", "highsec"],
    "map_id": "<MAP_UUID>"
  }
}
```

### 3. Create/Update System

```bash
POST /api/maps/:map_identifier/systems
PUT /api/maps/:map_identifier/systems/:id
```

- **Description:** Creates a new system or updates an existing one.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.
  - `id` (required for PUT) — the system's solar_system_id.

#### Example Create Request

```bash
curl -X POST \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{
       "solar_system_id": 30000142,
       "solar_system_name": "Jita",
       "position_x": 100.5,
       "position_y": 200.3,
       "status": "clear",
       "visible": true,
       "description": "Trade hub",
       "tag": "TRADE",
       "locked": false,
       "labels": ["market", "highsec"]
     }' \
     "https://wanderer.example.com/api/maps/your-map-slug/systems"
```

#### Example Update Request

```bash
curl -X PUT \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{
       "status": "hostile",
       "description": "Hostiles reported",
       "tag": "DANGER"
     }' \
     "https://wanderer.example.com/api/maps/your-map-slug/systems/30000142"
```

### 4. Delete System

```bash
DELETE /api/maps/:map_identifier/systems/:id
```

- **Description:** Deletes a specific system and its associated connections.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.
  - `id` (required) — the system's solar_system_id.

#### Example Request

```bash
curl -X DELETE \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     "https://wanderer.example.com/api/maps/your-map-slug/systems/30000142"
```

### 5. Batch Delete Systems

```bash
DELETE /api/maps/:map_identifier/systems
```

- **Description:** Deletes multiple systems and their connections in a single operation.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.

#### Example Request

```bash
curl -X DELETE \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{
       "system_ids": [30000142, 30000144, 30000145]
     }' \
     "https://wanderer.example.com/api/maps/your-map-slug/systems"
```

---

## Connections Endpoints

### 1. List Connections

```bash
GET /api/maps/:map_identifier/connections
```

- **Description:** Retrieves all connections for the specified map.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.

#### Example Request

```bash
curl -H "Authorization: Bearer <YOUR_TOKEN>" \
     "https://wanderer.example.com/api/maps/your-map-slug/connections"
```

#### Example Response

```json
{
  "data": [
    {
      "id": "<CONNECTION_UUID>",
      "solar_system_source": 30000142,
      "solar_system_target": 30000144,
      "type": 0,
      "mass_status": 0,
      "time_status": 0,
      "ship_size_type": 1,
      "wormhole_type": "K162",
      "count_of_passage": 0,
      "locked": false,
    }
  ]
}
```

### 2. Create Connection

```bash
POST /api/maps/:map_identifier/connections
```

- **Description:** Creates a new connection between two systems.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.

#### Example Request

```bash
curl -X POST \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{
       "solar_system_source": 30000142,
       "solar_system_target": 30000144,
       "type": 0,
       "mass_status": 0,
       "time_status": 0,
       "ship_size_type": 1,
       "locked": false,
     }' \
     "https://wanderer.example.com/api/maps/your-map-slug/connections"
```

### 3. Update Connection

```bash
PATCH /api/maps/:map_identifier/connections
```

- **Description:** Updates an existing connection's properties.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.
  - Query parameters:
    - `solar_system_source` (required) — source system ID
    - `solar_system_target` (required) — target system ID

#### Example Request

```bash
curl -X PATCH \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{
       "mass_status": 1,
       "time_status": 1,
     }' \
     "https://wanderer.example.com/api/maps/your-map-slug/connections?solar_system_source=30000142&solar_system_target=30000144"
```

### 4. Delete Connection

```bash
DELETE /api/maps/:map_identifier/connections
```

- **Description:** Deletes a connection between two systems.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.
  - Query parameters:
    - `solar_system_source` (required) — source system ID
    - `solar_system_target` (required) — target system ID

#### Example Request

```bash
curl -X DELETE \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     "https://wanderer.example.com/api/maps/your-map-slug/connections?solar_system_source=30000142&solar_system_target=30000144"
```

---

## Batch Operations

### 1. Batch Upsert Systems and Connections

```bash
POST /api/maps/:map_identifier/systems
```

- **Description:** Creates or updates multiple systems and connections in a single operation.
- **Authentication:** Requires Map API Token.
- **Parameters:**
  - `map_identifier` (required) — the map's slug or UUID.

#### Example Request

```bash
curl -X POST \
     -H "Authorization: Bearer <YOUR_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{
       "systems": [
         {
           "solar_system_id": 30000142,
           "solar_system_name": "Jita",
           "position_x": 100.5,
           "position_y": 200.3,
           "status": "clear"
         },
         {
           "solar_system_id": 30000144,
           "solar_system_name": "Perimeter",
           "position_x": 150.5,
           "position_y": 250.3,
           "status": "clear"
         }
       ],
       "connections": [
         {
           "solar_system_source": 30000142,
           "solar_system_target": 30000144,
           "type": 0,
           "mass_status": 0,
           "ship_size_type": 1
         }
       ]
     }' \
     "https://wanderer.example.com/api/maps/your-map-slug/systems"
```

#### Example Response

```json
{
  "data": {
    "systems": {
      "created": 2,
      "updated": 0
    },
    "connections": {
      "created": 1,
      "updated": 0,
      "deleted": 0
    }
  }
}
```

The response includes counts for:
- Systems created and updated
- Connections created, updated, and deleted (if any)

Note: The `deleted` count in connections will be 0 for batch operations as deletion is handled through separate endpoints.

---

## Practical Examples

### Backup and Restore Map State

We provide a utility script that demonstrates how to use these endpoints to backup and restore your map state:

```bash
#!/bin/bash
# backup_restore_test.sh

# 1. Backup current state
curl -H "Authorization: Bearer <YOUR_TOKEN>" \
     "https://wanderer.example.com/api/maps/your-map-slug/systems" \
     > map_backup.json

# 2. Delete everything (after confirmation)
read -p "Delete all systems? (y/N) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  # Get system IDs
  systems=$(cat map_backup.json | jq -r '.data.systems[].solar_system_id')
  
  # Create deletion payload
  payload=$(jq -n --argjson ids "$(echo "$systems" | jq -R . | jq -s .)" \
           '{system_ids: $ids}')
  
  # Delete all systems
  curl -X DELETE \
       -H "Authorization: Bearer <YOUR_TOKEN>" \
       -H "Content-Type: application/json" \
       -d "$payload" \
       "https://wanderer.example.com/api/maps/your-map-slug/systems"
fi

# 3. Restore from backup (after confirmation)
read -p "Restore from backup? (y/N) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  # Extract systems and connections
  backup_data=$(cat map_backup.json)
  systems=$(echo "$backup_data" | jq '.data.systems')
  connections=$(echo "$backup_data" | jq '.data.connections')
  
  # Create restore payload
  payload="{\"systems\": $systems, \"connections\": $connections}"
  
  # Restore everything
  curl -X POST \
       -H "Authorization: Bearer <YOUR_TOKEN>" \
       -H "Content-Type: application/json" \
       -d "$payload" \
       "https://wanderer.example.com/api/maps/your-map-slug/systems"
fi
```

This script demonstrates a practical application of the batch operations endpoints for backing up and restoring map data.

---

## Conclusion

These endpoints provide powerful tools for managing your map's systems and connections programmatically. Key features include:

1. Individual system and connection management
2. Efficient batch operations
3. Flexible update options
4. Robust error handling
5. Consistent response formats

For the most up-to-date and interactive documentation, remember to check the Swagger UI at `/swaggerui`.

If you have questions about these endpoints or need assistance, please reach out to the Wanderer Team.

----

Fly safe,
**The Wanderer Team**

---- 