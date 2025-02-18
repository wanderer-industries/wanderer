#!/usr/bin/env bash
#
# Example script to test your Map & ACL endpoints using curl.
# Requires `jq` to parse JSON responses.

# If any command fails, this script will exit immediately
set -e

#############################################
# Environment Variables (must be set before)
#############################################
: "${BASE_URL:?Need to set BASE_URL, e.g. http://localhost:4444}"
: "${MAP_TOKEN:?Need to set MAP_TOKEN (Bearer token for map requests)}"
: "${MAP_SLUG:?Need to set MAP_SLUG (slug for the map to test)}"
: "${EVE_CHARACTER_ID:?Need to set EVE_CHARACTER_ID (e.g. from /api/characters)}"

echo "Using BASE_URL = $BASE_URL"
echo "Using MAP_TOKEN = $MAP_TOKEN"
echo "Using MAP_SLUG = $MAP_SLUG"
echo "Using EVE_CHARACTER_ID = $EVE_CHARACTER_ID"
echo "-------------------------------------"

#############################################
# 1) Get list of characters (just to confirm they exist)
#############################################
echo
echo "=== 1) Get All Characters (for reference) ==="
curl -s "$BASE_URL/api/characters" | jq

#############################################
# 2) Get ACLs for the given map slug
#############################################
echo
echo "=== 2) List ACLs for Map Slug '$MAP_SLUG' ==="
ACL_LIST_JSON=$(curl -s -H "Authorization: Bearer $MAP_TOKEN" \
  "$BASE_URL/api/map/acls?slug=$MAP_SLUG")

echo "$ACL_LIST_JSON" | jq

# Attempt to parse out the first ACL ID and token from the JSON data array:
FIRST_ACL_ID=$(echo "$ACL_LIST_JSON" | jq -r '.data[0].id // empty')
FIRST_ACL_TOKEN=$(echo "$ACL_LIST_JSON" | jq -r '.data[0].api_key // empty')

#############################################
# 3) Decide whether to use an existing ACL or create a new one
#############################################
if [ -z "$FIRST_ACL_ID" ] || [ "$FIRST_ACL_ID" = "null" ]; then
  echo "No existing ACL found for map slug: $MAP_SLUG."
  USE_EXISTING_ACL=false
else
  # We found at least one ACL. But does it have a token?
  if [ -z "$FIRST_ACL_TOKEN" ] || [ "$FIRST_ACL_TOKEN" = "null" ]; then
    echo "Found an ACL with ID $FIRST_ACL_ID but no api_key in the response."
    echo "We cannot do membership actions on it without a token."
    USE_EXISTING_ACL=false
  else
    echo "Parsed ACL_ID from existing ACL: $FIRST_ACL_ID"
    echo "Parsed ACL_TOKEN from existing ACL: $FIRST_ACL_TOKEN"
    USE_EXISTING_ACL=true
  fi
fi

#############################################
# 4) If we cannot use an existing ACL, create a new one
#############################################
if [ "$USE_EXISTING_ACL" = false ]; then
  echo
  echo "=== Creating a new ACL for membership testing ==="
  NEW_ACL_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $MAP_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
          "acl": {
            "name": "Auto-Created ACL",
            "description": "Created because none with a token was found",
            "owner_eve_id": "'"$EVE_CHARACTER_ID"'"
          }
        }' \
    "$BASE_URL/api/map/acls?slug=$MAP_SLUG")

  echo "New ACL creation response:"
  echo "$NEW_ACL_RESPONSE" | jq

  ACL_ID=$(echo "$NEW_ACL_RESPONSE" | jq -r '.data.id // empty')
  ACL_TOKEN=$(echo "$NEW_ACL_RESPONSE" | jq -r '.data.api_key // empty')

  if [ -z "$ACL_ID" ] || [ "$ACL_ID" = "null" ] || \
     [ -z "$ACL_TOKEN" ] || [ "$ACL_TOKEN" = "null" ]; then
    echo "Failed to create an ACL with a valid token. Exiting..."
    exit 1
  fi

  echo "Newly created ACL_ID: $ACL_ID"
  echo "Newly created ACL_TOKEN: $ACL_TOKEN"

else
  # Use the existing ACL's details
  ACL_ID="$FIRST_ACL_ID"
  ACL_TOKEN="$FIRST_ACL_TOKEN"
fi

#############################################
# 5) Show the details of that ACL
#############################################
echo
echo "=== 5) Show ACL Details ==="
ACL_DETAILS=$(curl -s \
  -H "Authorization: Bearer $ACL_TOKEN" \
  "$BASE_URL/api/acls/$ACL_ID")

echo "$ACL_DETAILS" | jq || {
  echo "ACL details response is not valid JSON. Raw response:"
  echo "$ACL_DETAILS"
  exit 1
}

#############################################
# 6) Create a new ACL member (viewer)
#############################################
echo
echo "=== 6) Create a New ACL Member (viewer) ==="
CREATE_MEMBER_RESP=$(curl -s -X POST \
  -H "Authorization: Bearer $ACL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "member": {
          "eve_character_id": "'"$EVE_CHARACTER_ID"'",
          "role": "viewer"
        }
      }' \
  "$BASE_URL/api/acls/$ACL_ID/members")

echo "$CREATE_MEMBER_RESP" | jq || {
  echo "Create member response is not valid JSON. Raw response:"
  echo "$CREATE_MEMBER_RESP"
  exit 1
}

#############################################
# 7) Update the member's role (e.g., admin)
#############################################
echo
echo "=== 7) Update Member Role to 'admin' ==="
UPDATE_MEMBER_RESP=$(curl -s -X PUT \
  -H "Authorization: Bearer $ACL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "member": {
          "role": "admin"
        }
      }' \
  "$BASE_URL/api/acls/$ACL_ID/members/$EVE_CHARACTER_ID")

echo "$UPDATE_MEMBER_RESP" | jq || {
  echo "Update member response is not valid JSON. Raw response:"
  echo "$UPDATE_MEMBER_RESP"
  exit 1
}

#############################################
# 8) Delete the member
#############################################
echo
echo "=== 8) Delete the Member ==="
DELETE_MEMBER_RESP=$(curl -s -X DELETE \
  -H "Authorization: Bearer $ACL_TOKEN" \
  "$BASE_URL/api/acls/$ACL_ID/members/$EVE_CHARACTER_ID")

echo "$DELETE_MEMBER_RESP" | jq || {
  echo "Delete member response is not valid JSON. Raw response:"
  echo "$DELETE_MEMBER_RESP"
  exit 1
}

#############################################
# 9) (Optional) Update the ACL itself
#############################################
echo
echo "=== 9) Update the ACL’s name/description ==="
UPDATED_ACL=$(curl -s -X PUT \
  -H "Authorization: Bearer $ACL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "acl": {
          "name": "Updated ACL Name (script)",
          "description": "An updated description from test script"
        }
      }' \
  "$BASE_URL/api/acls/$ACL_ID")

echo "$UPDATED_ACL" | jq || {
  echo "Update ACL response is not valid JSON. Raw response:"
  echo "$UPDATED_ACL"
  exit 1
}

echo
echo "=== Done! ==="
