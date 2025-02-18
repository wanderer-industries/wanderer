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
ACL_ID=$(echo "$ACL_LIST_JSON" | jq -r '.data[0].id // empty')
ACL_TOKEN=$(echo "$ACL_LIST_JSON" | jq -r '.data[0].api_key // empty')

#############################################
# 3) If no ACL exists, create a new one
#############################################
if [ -z "$ACL_ID" ] || [ "$ACL_ID" = "null" ]; then
  echo "No ACL found for map slug: $MAP_SLUG"
  echo "Creating a new ACL for this map..."

  NEW_ACL_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $MAP_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
          "acl": {
            "name": "Auto-Created ACL",
            "description": "Created because none existed for this map",
            "owner_eve_id": "'"$EVE_CHARACTER_ID"'"
          }
        }' \
    "$BASE_URL/api/map/acls?slug=$MAP_SLUG")

  echo "New ACL creation response:"
  echo "$NEW_ACL_RESPONSE" | jq

  # Parse out the new ACL’s ID & token
  ACL_ID=$(echo "$NEW_ACL_RESPONSE" | jq -r '.data.id // empty')
  ACL_TOKEN=$(echo "$NEW_ACL_RESPONSE" | jq -r '.data.api_key // empty')

  if [ -z "$ACL_ID" ] || [ "$ACL_ID" = "null" ]; then
    echo "Failed to create an ACL. Exiting..."
    exit 1
  fi

  echo "Newly created ACL_ID: $ACL_ID"
  echo "Newly created ACL_TOKEN: $ACL_TOKEN"
else
  echo "Parsed ACL_ID from existing ACL: $ACL_ID"
  echo "Parsed ACL_TOKEN from existing ACL: $ACL_TOKEN"
fi

#############################################
# 4) Show the details of that ACL
#############################################
echo
echo "=== 4) Show ACL Details ==="
curl -s \
  -H "Authorization: Bearer $ACL_TOKEN" \
  "$BASE_URL/api/acls/$ACL_ID" | jq

#############################################
# 5) Create a new ACL member
#############################################
echo
echo "=== 5) Create a New ACL Member (viewer) ==="
curl -s -X POST \
  -H "Authorization: Bearer $ACL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "member": {
          "eve_character_id": "'"$EVE_CHARACTER_ID"'",
          "role": "viewer"
        }
      }' \
  "$BASE_URL/api/acls/$ACL_ID/members" | jq

#############################################
# 6) Update the member's role (e.g., admin)
#############################################
echo
echo "=== 6) Update Member Role to 'admin' ==="
curl -s -X PUT \
  -H "Authorization: Bearer $ACL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "member": {
          "role": "admin"
        }
      }' \
  "$BASE_URL/api/acls/$ACL_ID/members/$EVE_CHARACTER_ID" | jq

#############################################
# 7) Delete the member
#############################################
echo
echo "=== 7) Delete the Member ==="
curl -s -X DELETE \
  -H "Authorization: Bearer $ACL_TOKEN" \
  "$BASE_URL/api/acls/$ACL_ID/members/$EVE_CHARACTER_ID" | jq

#############################################
# 8) (Optional) Update the ACL itself
#############################################
echo
echo "=== 8) Update the ACL’s name/description ==="
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

echo "$UPDATED_ACL" | jq

echo
echo "=== Done! ==="
