#!/bin/bash
# test/manual/api/test_character_eve_id_fix.sh
# ─── Manual Test for Character EVE ID Fix (Issue #539) ────────────────────────
#
# This script tests the fix for GitHub issue #539 where character_eve_id
# was being ignored when creating/updating signatures via the REST API.
#
# Usage:
#   1. Create a .env file in this directory with:
#      API_TOKEN=your_map_public_api_key
#      API_BASE_URL=http://localhost:8000  # or your server URL
#      MAP_SLUG=your_map_slug
#      VALID_CHAR_ID=111111111  # A character that exists in your database
#      INVALID_CHAR_ID=999999999  # A character that does NOT exist
#
#   2. Run: ./test_character_eve_id_fix.sh
#
# Prerequisites:
#   - curl and jq must be installed
#   - A map must exist with a valid API token
#   - At least one system must be added to the map

set -eu

source "$(dirname "$0")/utils.sh"

echo "═══════════════════════════════════════════════════════════════════"
echo "Testing Character EVE ID Fix (GitHub Issue #539)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Check required environment variables
: "${API_BASE_URL:?Error: API_BASE_URL not set}"
: "${MAP_SLUG:?Error: MAP_SLUG not set}"
: "${VALID_CHAR_ID:?Error: VALID_CHAR_ID not set (provide a character eve_id that exists in DB)}"
: "${INVALID_CHAR_ID:?Error: INVALID_CHAR_ID not set (provide a non-existent character eve_id)}"

# Get a system to use for testing
echo "📋 Fetching available systems from map..."
SYSTEMS_RAW=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
SYSTEMS_STATUS=$(parse_status "$SYSTEMS_RAW")
SYSTEMS_RESPONSE=$(parse_response "$SYSTEMS_RAW")

if [ "$SYSTEMS_STATUS" != "200" ]; then
  echo "❌ Failed to fetch systems (HTTP $SYSTEMS_STATUS)"
  echo "$SYSTEMS_RESPONSE"
  exit 1
fi

# Extract first system's solar_system_id
SOLAR_SYSTEM_ID=$(echo "$SYSTEMS_RESPONSE" | jq -r '.data[0].solar_system_id // empty')

if [ -z "$SOLAR_SYSTEM_ID" ]; then
  echo "❌ No systems found in map. Please add at least one system first."
  exit 1
fi

echo "✅ Using solar_system_id: $SOLAR_SYSTEM_ID"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Test 1: Create signature with valid character_eve_id
# ═══════════════════════════════════════════════════════════════════════
echo "─────────────────────────────────────────────────────────────────"
echo "Test 1: Create signature with VALID character_eve_id"
echo "─────────────────────────────────────────────────────────────────"

PAYLOAD1=$(cat <<EOF
{
  "solar_system_id": $SOLAR_SYSTEM_ID,
  "eve_id": "TEST-001",
  "character_eve_id": "$VALID_CHAR_ID",
  "group": "wormhole",
  "kind": "cosmic_signature",
  "name": "Test Sig 1"
}
EOF
)

echo "Request:"
echo "$PAYLOAD1" | jq '.'
echo ""

RAW1=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" "$PAYLOAD1")
STATUS1=$(parse_status "$RAW1")
RESPONSE1=$(parse_response "$RAW1")

echo "Response (HTTP $STATUS1):"
echo "$RESPONSE1" | jq '.'
echo ""

if [ "$STATUS1" = "201" ]; then
  RETURNED_CHAR_ID=$(echo "$RESPONSE1" | jq -r '.data.character_eve_id')
  if [ "$RETURNED_CHAR_ID" = "$VALID_CHAR_ID" ]; then
    echo "✅ PASS: Signature created with correct character_eve_id: $RETURNED_CHAR_ID"
    SIG_ID_1=$(echo "$RESPONSE1" | jq -r '.data.id')
  else
    echo "❌ FAIL: Expected character_eve_id=$VALID_CHAR_ID, got $RETURNED_CHAR_ID"
  fi
else
  echo "❌ FAIL: Expected HTTP 201, got $STATUS1"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Test 2: Create signature with invalid character_eve_id
# ═══════════════════════════════════════════════════════════════════════
echo "─────────────────────────────────────────────────────────────────"
echo "Test 2: Create signature with INVALID character_eve_id"
echo "─────────────────────────────────────────────────────────────────"

PAYLOAD2=$(cat <<EOF
{
  "solar_system_id": $SOLAR_SYSTEM_ID,
  "eve_id": "TEST-002",
  "character_eve_id": "$INVALID_CHAR_ID",
  "group": "wormhole",
  "kind": "cosmic_signature"
}
EOF
)

echo "Request:"
echo "$PAYLOAD2" | jq '.'
echo ""

RAW2=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" "$PAYLOAD2")
STATUS2=$(parse_status "$RAW2")
RESPONSE2=$(parse_response "$RAW2")

echo "Response (HTTP $STATUS2):"
echo "$RESPONSE2" | jq '.'
echo ""

if [ "$STATUS2" = "422" ]; then
  ERROR_MSG=$(echo "$RESPONSE2" | jq -r '.error // empty')
  if [ "$ERROR_MSG" = "invalid_character" ]; then
    echo "✅ PASS: Correctly rejected invalid character_eve_id with error: $ERROR_MSG"
  else
    echo "⚠️  PARTIAL: Got HTTP 422 but unexpected error message: $ERROR_MSG"
  fi
else
  echo "❌ FAIL: Expected HTTP 422, got $STATUS2"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Test 3: Create signature WITHOUT character_eve_id (fallback test)
# ═══════════════════════════════════════════════════════════════════════
echo "─────────────────────────────────────────────────────────────────"
echo "Test 3: Create signature WITHOUT character_eve_id (fallback)"
echo "─────────────────────────────────────────────────────────────────"

PAYLOAD3=$(cat <<EOF
{
  "solar_system_id": $SOLAR_SYSTEM_ID,
  "eve_id": "TEST-003",
  "group": "data",
  "kind": "cosmic_signature",
  "name": "Test Sig 3"
}
EOF
)

echo "Request:"
echo "$PAYLOAD3" | jq '.'
echo ""

RAW3=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" "$PAYLOAD3")
STATUS3=$(parse_status "$RAW3")
RESPONSE3=$(parse_response "$RAW3")

echo "Response (HTTP $STATUS3):"
echo "$RESPONSE3" | jq '.'
echo ""

if [ "$STATUS3" = "201" ]; then
  RETURNED_CHAR_ID=$(echo "$RESPONSE3" | jq -r '.data.character_eve_id')
  echo "✅ PASS: Signature created with fallback character_eve_id: $RETURNED_CHAR_ID"
  echo "   (This should be the map owner's character)"
  SIG_ID_3=$(echo "$RESPONSE3" | jq -r '.data.id')
else
  echo "❌ FAIL: Expected HTTP 201, got $STATUS3"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Test 4: Update signature with valid character_eve_id
# ═══════════════════════════════════════════════════════════════════════
if [ -n "${SIG_ID_1:-}" ]; then
  echo "─────────────────────────────────────────────────────────────────"
  echo "Test 4: Update signature with VALID character_eve_id"
  echo "─────────────────────────────────────────────────────────────────"

  PAYLOAD4=$(cat <<EOF
{
  "name": "Updated Test Sig 1",
  "character_eve_id": "$VALID_CHAR_ID",
  "description": "Updated via API"
}
EOF
)

  echo "Request:"
  echo "$PAYLOAD4" | jq '.'
  echo ""

  RAW4=$(make_request PUT "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$SIG_ID_1" "$PAYLOAD4")
  STATUS4=$(parse_status "$RAW4")
  RESPONSE4=$(parse_response "$RAW4")

  echo "Response (HTTP $STATUS4):"
  echo "$RESPONSE4" | jq '.'
  echo ""

  if [ "$STATUS4" = "200" ]; then
    RETURNED_CHAR_ID=$(echo "$RESPONSE4" | jq -r '.data.character_eve_id')
    if [ "$RETURNED_CHAR_ID" = "$VALID_CHAR_ID" ]; then
      echo "✅ PASS: Signature updated with correct character_eve_id: $RETURNED_CHAR_ID"
    else
      echo "❌ FAIL: Expected character_eve_id=$VALID_CHAR_ID, got $RETURNED_CHAR_ID"
    fi
  else
    echo "❌ FAIL: Expected HTTP 200, got $STATUS4"
  fi
  echo ""
fi

# ═══════════════════════════════════════════════════════════════════════
# Test 5: Update signature with invalid character_eve_id
# ═══════════════════════════════════════════════════════════════════════
if [ -n "${SIG_ID_3:-}" ]; then
  echo "─────────────────────────────────────────────────────────────────"
  echo "Test 5: Update signature with INVALID character_eve_id"
  echo "─────────────────────────────────────────────────────────────────"

  PAYLOAD5=$(cat <<EOF
{
  "name": "Should Fail",
  "character_eve_id": "$INVALID_CHAR_ID"
}
EOF
)

  echo "Request:"
  echo "$PAYLOAD5" | jq '.'
  echo ""

  RAW5=$(make_request PUT "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$SIG_ID_3" "$PAYLOAD5")
  STATUS5=$(parse_status "$RAW5")
  RESPONSE5=$(parse_response "$RAW5")

  echo "Response (HTTP $STATUS5):"
  echo "$RESPONSE5" | jq '.'
  echo ""

  if [ "$STATUS5" = "422" ]; then
    ERROR_MSG=$(echo "$RESPONSE5" | jq -r '.error // empty')
    if [ "$ERROR_MSG" = "invalid_character" ]; then
      echo "✅ PASS: Correctly rejected invalid character_eve_id with error: $ERROR_MSG"
    else
      echo "⚠️  PARTIAL: Got HTTP 422 but unexpected error message: $ERROR_MSG"
    fi
  else
    echo "❌ FAIL: Expected HTTP 422, got $STATUS5"
  fi
  echo ""
fi

# ═══════════════════════════════════════════════════════════════════════
# Cleanup (optional)
# ═══════════════════════════════════════════════════════════════════════
echo "─────────────────────────────────────────────────────────────────"
echo "Cleanup"
echo "─────────────────────────────────────────────────────────────────"
echo "Created signature IDs: ${SIG_ID_1:-none} ${SIG_ID_3:-none}"
echo ""
echo "To clean up manually, delete these signatures via the UI or API:"
for sig_id in ${SIG_ID_1:-} ${SIG_ID_3:-}; do
  if [ -n "$sig_id" ]; then
    echo "  curl -X DELETE -H 'Authorization: Bearer \$API_TOKEN' \\"
    echo "    $API_BASE_URL/api/maps/$MAP_SLUG/signatures/$sig_id"
  fi
done
echo ""

echo "═══════════════════════════════════════════════════════════════════"
echo "Test Complete!"
echo "═══════════════════════════════════════════════════════════════════"
