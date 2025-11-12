# Manual cURL Testing for Character EVE ID Fix (Issue #539)

This guide provides standalone curl commands to manually test the character_eve_id fix.

## Prerequisites

1. **Get your Map's Public API Token:**
   - Log into Wanderer
   - Go to your map settings
   - Find the "Public API Key" section
   - Copy your API token

2. **Find your Map Slug:**
   - Look at your map URL: `https://your-instance.com/your-map-slug`
   - The slug is the last part of the URL

3. **Get a valid Character EVE ID:**
   ```bash
   # Option 1: Query your database
   psql $DATABASE_URL -c "SELECT eve_id, name FROM character_v1 WHERE deleted = false LIMIT 5;"

   # Option 2: Use the characters API
   curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     http://localhost:8000/api/characters
   ```

4. **Get a Solar System ID from your map:**
   ```bash
   curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     http://localhost:8000/api/maps/YOUR_SLUG/systems \
     | jq '.data[0].solar_system_id'
   ```

## Set Environment Variables (for convenience)

```bash
export API_BASE_URL="http://localhost:8000"
export MAP_SLUG="your-map-slug"
export API_TOKEN="your_api_token_here"
export SOLAR_SYSTEM_ID="30000142"  # Replace with actual system ID from your map
export VALID_CHAR_ID="111111111"    # Replace with real character eve_id
export INVALID_CHAR_ID="999999999"  # Non-existent character
```

---

## Test 1: Create Signature with Valid character_eve_id

**Expected Result:** HTTP 201, returned object has the submitted character_eve_id

```bash
curl -v -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "solar_system_id": '"$SOLAR_SYSTEM_ID"',
    "eve_id": "TEST-001",
    "character_eve_id": "'"$VALID_CHAR_ID"'",
    "group": "wormhole",
    "kind": "cosmic_signature",
    "name": "Test Signature 1"
  }' \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" | jq '.'
```

**Verification:**
```bash
# The response should contain:
# "character_eve_id": "111111111"  (your VALID_CHAR_ID)
```

---

## Test 2: Create Signature with Invalid character_eve_id

**Expected Result:** HTTP 422 with error "invalid_character"

```bash
curl -v -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "solar_system_id": '"$SOLAR_SYSTEM_ID"',
    "eve_id": "TEST-002",
    "character_eve_id": "'"$INVALID_CHAR_ID"'",
    "group": "wormhole",
    "kind": "cosmic_signature"
  }' \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" | jq '.'
```

**Expected Response:**
```json
{
  "error": "invalid_character"
}
```

---

## Test 3: Create Signature WITHOUT character_eve_id (Backward Compatibility)

**Expected Result:** HTTP 201, uses map owner's character_eve_id as fallback

```bash
curl -v -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "solar_system_id": '"$SOLAR_SYSTEM_ID"',
    "eve_id": "TEST-003",
    "group": "data",
    "kind": "cosmic_signature",
    "name": "Test Signature 3"
  }' \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" | jq '.'
```

**Verification:**
```bash
# The response should contain the map owner's character_eve_id
# This proves backward compatibility is maintained
```

---

## Test 4: Update Signature with Valid character_eve_id

**Expected Result:** HTTP 200, returned object has the submitted character_eve_id

```bash
# First, save a signature ID from Test 1 or 3
export SIG_ID="paste-signature-id-here"

curl -v -X PUT \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Signature Name",
    "character_eve_id": "'"$VALID_CHAR_ID"'",
    "description": "Updated via API"
  }' \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$SIG_ID" | jq '.'
```

**Verification:**
```bash
# The response should contain:
# "character_eve_id": "111111111"  (your VALID_CHAR_ID)
```

---

## Test 5: Update Signature with Invalid character_eve_id

**Expected Result:** HTTP 422 with error "invalid_character"

```bash
curl -v -X PUT \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Should Fail",
    "character_eve_id": "'"$INVALID_CHAR_ID"'"
  }' \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$SIG_ID" | jq '.'
```

**Expected Response:**
```json
{
  "error": "invalid_character"
}
```

---

## Cleanup

Delete test signatures:

```bash
# List all signatures to find IDs
curl -H "Authorization: Bearer $API_TOKEN" \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" | jq '.data[] | {id, eve_id, name}'

# Delete specific signature
export SIG_ID="signature-uuid-here"
curl -v -X DELETE \
  -H "Authorization: Bearer $API_TOKEN" \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$SIG_ID"
```

---

## Quick Debugging Tips

### View All Signatures
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" \
  | jq '.data[] | {id, eve_id, character_eve_id, name}'
```

### View All Characters in Database
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "$API_BASE_URL/api/characters" \
  | jq '.[] | {eve_id, name}'
```

### View All Systems in Map
```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "$API_BASE_URL/api/maps/$MAP_SLUG/systems" \
  | jq '.data[] | {id, solar_system_id, name}'
```

---

## Expected Behavior Summary

| Test Case | HTTP Status | character_eve_id in Response |
|-----------|-------------|------------------------------|
| Create with valid char ID | 201 | Matches submitted value |
| Create with invalid char ID | 422 | N/A (error returned) |
| Create without char ID | 201 | Map owner's char ID (fallback) |
| Update with valid char ID | 200 | Matches submitted value |
| Update with invalid char ID | 422 | N/A (error returned) |

---

## Troubleshooting

### "Unauthorized (invalid token for map)"
- Double-check your API_TOKEN matches the map's public API key
- Verify the token doesn't have extra spaces or newlines

### "Map not found"
- Verify your MAP_SLUG is correct
- Try using the map UUID instead of slug

### "System not found for solar_system_id"
- The system must already exist in your map
- Run the "View All Systems" command to find valid system IDs

### "invalid_character" when using what should be valid
- Verify the character exists: `SELECT * FROM character_v1 WHERE eve_id = 'YOUR_ID';`
- Make sure `deleted = false` for the character
