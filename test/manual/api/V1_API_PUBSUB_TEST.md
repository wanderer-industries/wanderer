# V1 API with PubSub Broadcasting - Test Guide

This guide provides curl commands to test the V1 JSON:API endpoints with real-time PubSub broadcasting.

## Authentication & Map Context

The V1 API uses **token-only authentication**. Your Bearer token identifies both:
- Your user account
- The specific map you're working with

**You do NOT need to provide `map_id` or `map_identifier` in:**
- Request body
- Query parameters
- URL path

The map is automatically determined from your API token. This simplifies integration and improves security by ensuring you can only access the map associated with your token.

## Prerequisites

1. **Get your Map's API Token:**
   ```bash
   # Via UI: Map Settings → Public API Key
   # Or via database:
   psql $DATABASE_URL -c "SELECT id, name, public_api_key FROM map_v1 WHERE name = 'Your Map Name';"
   ```

2. **Set Environment Variables:**
   ```bash
   export API_BASE_URL="http://localhost:4444"
   export API_TOKEN="your-api-token-here"
   ```

3. **Find a valid solar system ID:**
   ```bash
   # Jita = 30000142, Amarr = 30002187
   export SOLAR_SYSTEM_ID="30000142"
   ```

**Note:** The `map_id` is automatically determined from your API token, so you don't need to track or provide it.

---

## Monitoring PubSub Broadcasts

To verify broadcasts are working, you can monitor Phoenix PubSub in two ways:

### Option 1: Via IEx Console
```elixir
# Start the server in IEx mode
iex -S mix phx.server

# Subscribe to your map's PubSub topic
Phoenix.PubSub.subscribe(WandererApp.PubSub, "maps:YOUR_MAP_ID")

# You'll now see messages like:
# %{event: :add_system, payload: %WandererApp.Api.MapSystem{...}}
# %{event: :update_connection, payload: %WandererApp.Api.MapConnection{...}}
```

### Option 2: Via LiveView (if you have map open)
Open your map in a browser and watch for real-time updates as you make API calls.

---

## Part 1: Systems API (Tests :add_system, :update_system, :systems_removed)

### 1.1 Create a System (broadcasts :add_system)

**JSON:API format:**
```bash
curl -X POST "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "solar_system_id": '"$SOLAR_SYSTEM_ID"',
        "name": "Jita",
        "position_x": 100.0,
        "position_y": 200.0,
        "status": "friendly",
        "visible": true
      }
    }
  }' | jq '.'
```

**Expected PubSub Broadcast:**
```elixir
%{event: :add_system, payload: %MapSystem{
  map_id: "...",
  solar_system_id: 30000142,
  name: "Jita",
  position_x: 100.0,
  position_y: 200.0,
  status: "friendly"
}}
```

**Save the system ID:**
```bash
export SYSTEM_ID="paste-id-from-response"
```

### 1.2 Update a System (broadcasts :update_system)

```bash
curl -X PATCH "$API_BASE_URL/api/v1/map_systems/$SYSTEM_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "id": "'"$SYSTEM_ID"'",
      "attributes": {
        "status": "hostile",
        "description": "Updated via API",
        "tag": "danger"
      }
    }
  }' | jq '.'
```

**Expected PubSub Broadcast:**
```elixir
%{event: :update_system, payload: %MapSystem{
  id: "...",
  status: "hostile",
  description: "Updated via API",
  tag: "danger"
}}
```

### 1.3 Delete a System (broadcasts :systems_removed)

```bash
curl -X DELETE "$API_BASE_URL/api/v1/map_systems/$SYSTEM_ID" \
  -H "Authorization: Bearer $API_TOKEN"
```

**Expected PubSub Broadcast:**
```elixir
%{event: :systems_removed, payload: [30000142]}
```

**Note:** Systems are soft-deleted (visible: false), not physically deleted.

### 1.4 Query Systems

```bash
# Returns all systems on the map associated with your token
curl "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" | jq '.data[] | {id, solar_system_id, name, status}'
```

---

## Part 2: Connections API (Tests :add_connection, :update_connection, :remove_connections)

### 2.1 Create Two Systems First

```bash
# Create source system
curl -X POST "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "solar_system_id": 30000142,
        "name": "Jita",
        "position_x": 100.0,
        "position_y": 100.0
      }
    }
  }' | jq -r '.data.id'

# Create target system
curl -X POST "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "solar_system_id": 30002187,
        "name": "Amarr",
        "position_x": 300.0,
        "position_y": 100.0
      }
    }
  }' | jq -r '.data.id'
```

### 2.2 Create a Connection (broadcasts :add_connection)

```bash
curl -X POST "$API_BASE_URL/api/v1/map_connections" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_connections",
      "attributes": {
        "solar_system_source": 30000142,
        "solar_system_target": 30002187,
        "type": 0,
        "ship_size_type": 2,
        "mass_status": 0,
        "time_status": 0
      }
    }
  }' | jq '.'
```

**Expected PubSub Broadcast:**
```elixir
%{event: :add_connection, payload: %MapConnection{
  map_id: "...",
  solar_system_source: 30000142,
  solar_system_target: 30002187,
  type: 0,
  ship_size_type: 2
}}
```

**Save the connection ID:**
```bash
export CONNECTION_ID="paste-id-from-response"
```

### 2.3 Update a Connection (broadcasts :update_connection)

```bash
curl -X PATCH "$API_BASE_URL/api/v1/map_connections/$CONNECTION_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_connections",
      "id": "'"$CONNECTION_ID"'",
      "attributes": {
        "mass_status": 1,
        "time_status": 1,
        "locked": true
      }
    }
  }' | jq '.'
```

**Expected PubSub Broadcast:**
```elixir
%{event: :update_connection, payload: %MapConnection{
  id: "...",
  mass_status: 1,
  time_status: 1,
  locked: true
}}
```

### 2.4 Delete a Connection (broadcasts :remove_connections)

```bash
curl -X DELETE "$API_BASE_URL/api/v1/map_connections/$CONNECTION_ID" \
  -H "Authorization: Bearer $API_TOKEN"
```

**Expected PubSub Broadcast:**
```elixir
%{event: :remove_connections, payload: [%MapConnection{id: "..."}]}
```

### 2.5 Query Connections

```bash
# Returns all connections on the map associated with your token
curl "$API_BASE_URL/api/v1/map_connections" \
  -H "Authorization: Bearer $API_TOKEN" | jq '.data[] | {id, solar_system_source, solar_system_target, mass_status}'
```

---

## Part 3: Signatures API (Tests :signatures_updated)

### 3.1 Create a Signature (broadcasts :signatures_updated)

```bash
curl -X POST "$API_BASE_URL/api/v1/map_system_signatures" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_system_signatures",
      "attributes": {
        "system_id": "'"$SYSTEM_ID"'",
        "eve_id": "ABC-123",
        "character_eve_id": "1234567890",
        "name": "Test Wormhole",
        "group": "wormhole",
        "kind": "cosmic_signature",
        "type": "K162"
      }
    }
  }' | jq '.'
```

**Expected PubSub Broadcast:**
```elixir
%{event: :signatures_updated, payload: 30000142}  # solar_system_id
```

**Save the signature ID:**
```bash
export SIGNATURE_ID="paste-id-from-response"
```

### 3.2 Update a Signature (broadcasts :signatures_updated)

```bash
curl -X PATCH "$API_BASE_URL/api/v1/map_system_signatures/$SIGNATURE_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_system_signatures",
      "id": "'"$SIGNATURE_ID"'",
      "attributes": {
        "type": "C140",
        "description": "Leads to C2"
      }
    }
  }' | jq '.'
```

**Expected PubSub Broadcast:**
```elixir
%{event: :signatures_updated, payload: 30000142}  # solar_system_id
```

### 3.3 Delete a Signature (broadcasts :signatures_updated)

```bash
curl -X DELETE "$API_BASE_URL/api/v1/map_system_signatures/$SIGNATURE_ID" \
  -H "Authorization: Bearer $API_TOKEN"
```

**Expected PubSub Broadcast:**
```elixir
%{event: :signatures_updated, payload: 30000142}  # solar_system_id
```

### 3.4 Query Signatures (filter by system_id)

```bash
curl "$API_BASE_URL/api/v1/map_system_signatures?filter[system_id]=$SYSTEM_ID" \
  -H "Authorization: Bearer $API_TOKEN" | jq '.data[] | {id, eve_id, name, type, group}'
```

---

## Part 4: Bulk Operations

### 4.1 Create Multiple Systems at Once

```bash
curl -X POST "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": [
      {
        "type": "map_systems",
        "attributes": {
          "solar_system_id": 30000142,
          "name": "Jita",
          "position_x": 100.0,
          "position_y": 100.0
        }
      },
      {
        "type": "map_systems",
        "attributes": {
          "solar_system_id": 30002187,
          "name": "Amarr",
          "position_x": 300.0,
          "position_y": 100.0
        }
      },
      {
        "type": "map_systems",
        "attributes": {
          "solar_system_id": 30002659,
          "name": "Dodixie",
          "position_x": 500.0,
          "position_y": 100.0
        }
      }
    ]
  }' | jq '.data[] | {id, name, solar_system_id}'
```

**Expected PubSub Broadcasts:**
```elixir
# Three separate broadcasts, one for each system
%{event: :add_system, payload: %MapSystem{solar_system_id: 30000142}}
%{event: :add_system, payload: %MapSystem{solar_system_id: 30002187}}
%{event: :add_system, payload: %MapSystem{solar_system_id: 30002659}}
```

---

## Part 5: Testing UI and API Integration

### 5.1 Monitor Real-Time Updates

1. **Open your map in browser** (make sure you're logged in)
2. **Run API commands** from terminal
3. **Watch for real-time updates** on the map UI

**Example test flow:**
```bash
# 1. Add a system via API
curl -X POST "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "solar_system_id": 30000142,
        "name": "Jita",
        "position_x": 100.0,
        "position_y": 100.0
      }
    }
  }'

# 2. You should see the system appear on the map immediately!

# 3. Update it via API
curl -X PATCH "$API_BASE_URL/api/v1/map_systems/$SYSTEM_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "status": "hostile"
      }
    }
  }'

# 4. Watch the system's status update in real-time!
```

---

## Part 6: Error Cases

### 6.1 Missing Authentication

```bash
curl -X GET "$API_BASE_URL/api/v1/map_systems"
```

**Expected:** HTTP 401 Unauthorized

### 6.2 Invalid API Token

```bash
curl -X GET "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer invalid-token-here"
```

**Expected:** HTTP 401 Unauthorized

### 6.3 Invalid Solar System ID

```bash
curl -X POST "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "solar_system_id": 99999999,
        "name": "Invalid System"
      }
    }
  }'
```

**Expected:** HTTP 422 Unprocessable Entity (invalid solar_system_id)

---

## Part 7: Verification Checklist

After running the tests, verify:

- [ ] **Systems** appear in real-time when created via API
- [ ] **System updates** (status, description, etc.) reflect immediately
- [ ] **Systems disappear** when deleted via API
- [ ] **Connections** appear between systems when created
- [ ] **Connection updates** (mass, time, locked) reflect immediately
- [ ] **Connections disappear** when deleted
- [ ] **Signature counts** update on systems when added/removed
- [ ] **No duplicate broadcasts** (check IEx console)
- [ ] **External events** still fire (webhooks, if configured)

---

## Debugging Tips

### View PubSub Messages in IEx

```elixir
# Subscribe to all map events
Phoenix.PubSub.subscribe(WandererApp.PubSub, "maps:#{your_map_id}")

# Subscribe with a custom handler
defmodule MyHandler do
  def handle_info(msg, state) do
    IO.inspect(msg, label: "PubSub Message")
    {:noreply, state}
  end
end
```

### Check Database Directly

```bash
# First, find your map_id from the API token
psql $DATABASE_URL -c "SELECT id, name FROM map_v1 WHERE public_api_key = '$API_TOKEN';"

# Then use that map_id to view systems (replace YOUR_MAP_ID with the actual UUID)
psql $DATABASE_URL -c "SELECT id, map_id, solar_system_id, name, status, visible FROM map_systems_v1 WHERE map_id = 'YOUR_MAP_ID';"

# View connections
psql $DATABASE_URL -c "SELECT id, map_id, solar_system_source, solar_system_target, mass_status FROM map_connections_v1 WHERE map_id = 'YOUR_MAP_ID';"

# View signatures
psql $DATABASE_URL -c "SELECT id, system_id, eve_id, name, type, deleted FROM map_system_signatures_v1 WHERE system_id IN (SELECT id FROM map_systems_v1 WHERE map_id = 'YOUR_MAP_ID');"
```

### Enable Debug Logging

```elixir
# In config/dev.exs or IEx
Logger.configure(level: :debug)

# You'll see broadcasts logged:
# [debug] [BroadcastMapUpdate] Broadcasting add_system for WandererApp.Api.MapSystem on map abc123...
```

---

## Troubleshooting

### "No PubSub broadcasts received"

1. Verify you're subscribed to the correct topic: `"maps:#{map_id}"`
2. Check the map_id matches exactly
3. Ensure Phoenix.PubSub is running: `Process.whereis(WandererApp.PubSub)`

### "Broadcasts are duplicated"

This should NOT happen after Part 2 of the implementation. If you see duplicates:
1. Check server logs for duplicate `Impl.broadcast!` calls
2. Verify manual broadcasts were removed from Server.Impl modules

### "UI doesn't update"

1. Check browser console for JavaScript errors
2. Verify LiveView socket is connected
3. Check that the map is subscribed to PubSub events

---

## Quick Test Script

Save this as `test_v1_api.sh`:

```bash
#!/bin/bash
set -e

export API_BASE_URL="http://localhost:4444"
export API_TOKEN="your-token-here"

echo "Creating system..."
SYSTEM_RESPONSE=$(curl -s -X POST "$API_BASE_URL/api/v1/map_systems" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "solar_system_id": 30000142,
        "name": "Test System",
        "position_x": 100.0,
        "position_y": 100.0
      }
    }
  }')

SYSTEM_ID=$(echo "$SYSTEM_RESPONSE" | jq -r '.data.id')
echo "Created system: $SYSTEM_ID"

echo "Updating system..."
curl -s -X PATCH "$API_BASE_URL/api/v1/map_systems/$SYSTEM_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "map_systems",
      "attributes": {
        "status": "hostile"
      }
    }
  }' | jq '.data.attributes | {status, name}'

echo "Deleting system..."
curl -s -X DELETE "$API_BASE_URL/api/v1/map_systems/$SYSTEM_ID" \
  -H "Authorization: Bearer $API_TOKEN"

echo "✅ Test complete! Check your IEx console for PubSub broadcasts."
```

Run with:
```bash
chmod +x test_v1_api.sh
./test_v1_api.sh
```
