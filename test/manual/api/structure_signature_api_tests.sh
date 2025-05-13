#!/bin/bash
# test/manual/api/structure_signature_api_tests.sh
# ─── Manual API Tests for Map Structure and Signature APIs ────────────────
#
# Usage:
#   ./structure_signature_api_tests.sh          # Run all tests with menu selection
#   ./structure_signature_api_tests.sh create   # Run only creation tests
#   ./structure_signature_api_tests.sh update   # Run only update tests
#   ./structure_signature_api_tests.sh delete   # Run only deletion tests
#   ./structure_signature_api_tests.sh -v       # Run in verbose mode
#
source "$(dirname "$0")/utils.sh"

echo "DEBUG: Script started"

#set -x  # Enable shell debug output

VERBOSE=${VERBOSE:-false}

trap 'echo -e "\n❌ ERROR: Script failed at line $LINENO. Last command: $BASH_COMMAND" >&2' ERR

while getopts "vh" opt; do
  case $opt in
    v)
      VERBOSE=true
      ;;
    h)
      echo "Usage: $0 [-v] [-h] [all|create|update|delete]"
      echo "  -v  Verbose mode (show detailed test output)"
      echo "  -h  Show this help message"
      echo "  all     Run all tests (default with menu)"
      echo "  create  Run only creation tests"
      echo "  update  Run only update tests"
      echo "  delete  Run only deletion tests"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Use -h for help"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))
COMMAND=${1:-"all"}

STRUCTURES_FILE="/tmp/wanderer_test_structures.txt"
SIGNATURES_FILE="/tmp/wanderer_test_signatures.txt"
CREATED_STRUCTURE_IDS=""
CREATED_SIGNATURE_IDS=""

save_structures() {
  echo "DEBUG: Entering save_structures"
  if ! echo "$CREATED_STRUCTURE_IDS" > "$STRUCTURES_FILE"; then
    echo "ERROR: Failed to write to $STRUCTURES_FILE" >&2
    exit 1
  fi
  echo "DEBUG: Successfully wrote to $STRUCTURES_FILE"
  if [[ "$VERBOSE" == "true" ]]; then echo "Saved $(wc -w < "$STRUCTURES_FILE") structures to $STRUCTURES_FILE"; fi
}
load_structures() {
  if [ -f "$STRUCTURES_FILE" ]; then
    CREATED_STRUCTURE_IDS=$(cat "$STRUCTURES_FILE")
    if [[ "$VERBOSE" == "true" ]]; then echo "Loaded $(wc -w < "$STRUCTURES_FILE") structures from $STRUCTURES_FILE"; fi
  else
    CREATED_STRUCTURE_IDS=""
  fi
}
save_signatures() {
  echo "$CREATED_SIGNATURE_IDS" > "$SIGNATURES_FILE"
  if [[ "$VERBOSE" == "true" ]]; then echo "Saved $(wc -w < "$SIGNATURES_FILE") signatures to $SIGNATURES_FILE"; fi
}
load_signatures() {
  if [ -f "$SIGNATURES_FILE" ]; then
    CREATED_SIGNATURE_IDS=$(cat "$SIGNATURES_FILE")
    if [[ "$VERBOSE" == "true" ]]; then echo "Loaded $(wc -w < "$SIGNATURES_FILE") signatures from $SIGNATURES_FILE"; fi
  else
    CREATED_SIGNATURE_IDS=""
  fi
}
add_to_list() {
  local list="$1"
  local item="$2"
  if [ -z "$list" ]; then
    echo "$item"
  else
    echo "$list $item"
  fi
}

# Fetch the first available system (ID and name) from the API
get_first_system() {
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local response=$(parse_response "$raw")
    # Try .data as array
    local count=$(echo "$response" | jq -er 'if (.data | type == "array") then (.data | length) else 0 end' 2>/dev/null)
    for i in $(seq 0 $((count-1))); do
      local uuid=$(echo "$response" | jq -er ".data[$i].id // empty" 2>/dev/null)
      local eve_id=$(echo "$response" | jq -er ".data[$i].solar_system_id // empty" 2>/dev/null)
      local name=$(echo "$response" | jq -er ".data[$i].name // .data[$i].solar_system_name // empty" 2>/dev/null)
      if [[ -n "$uuid" && -n "$eve_id" && -n "$name" ]]; then
        echo "$uuid:$eve_id:$name"
        return 0
      fi
    done
    # Try .data.systems as array
    local count2=$(echo "$response" | jq -er 'if (.data.systems | type == "array") then (.data.systems | length) else 0 end' 2>/dev/null)
    for i in $(seq 0 $((count2-1))); do
      local uuid=$(echo "$response" | jq -er ".data.systems[$i].id // empty" 2>/dev/null)
      local eve_id=$(echo "$response" | jq -er ".data.systems[$i].solar_system_id // empty" 2>/dev/null)
      local name=$(echo "$response" | jq -er ".data.systems[$i].name // .data.systems[$i].solar_system_name // empty" 2>/dev/null)
      if [[ -n "$uuid" && -n "$eve_id" && -n "$name" ]]; then
        echo "$uuid:$eve_id:$name"
        return 0
      fi
    done
    echo "ERROR: No valid system found in API response. Available systems:" >&2
    echo "$response" | jq '.' >&2
    exit 1
  else
    echo "ERROR: Failed to fetch systems (status $status)" >&2
    exit 1
  fi
}

# ─── STRUCTURE TESTS ─────────────────────────────────────────────
create_structure() {
  local sys_info=$(get_first_system)
  local system_uuid=$(echo "$sys_info" | cut -d: -f1)
  local eve_system_id=$(echo "$sys_info" | cut -d: -f2)
  local system_name=$(echo "$sys_info" | cut -d: -f3-)
  echo "==== Creating Structure in system $system_name ($eve_system_id, $system_uuid) ===="
  local payload=$(jq -n --arg sid "$eve_system_id" --arg name "$system_name" '{
    system_id: "sys-uuid-1",
    solar_system_name: $name,
    solar_system_id: ($sid|tonumber),
    structure_type_id: "35832",
    structure_type: "Astrahus",
    character_eve_id: "123456789",
    name: "Jita Trade Hub",
    notes: "Main market structure",
    owner_name: "Wanderer Corp",
    owner_ticker: "WANDR",
    owner_id: "corp-uuid-1",
    status: "anchoring",
    end_time: "2025-05-05T12:00:00Z"
  }')
  local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/structures" "$payload")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local id=$(parse_response "$raw" | jq -r '.data.id')
    CREATED_STRUCTURE_IDS=$(add_to_list "$CREATED_STRUCTURE_IDS" "$id")
    echo "✅ Created structure with ID: $id"
  else
    echo -e "\n❌ ERROR: Failed to create structure. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
  save_structures
  echo "DEBUG: End of create_structure, about to return"
}

list_structures() {
  echo "==== Listing Structures ===="
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/structures")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local count=$(parse_response "$raw" | jq '.data | length')
    echo "✅ Listed $count structures"
    if [[ "$VERBOSE" == "true" ]]; then echo "$(parse_response "$raw")" | jq '.'; fi
  else
    echo -e "\n❌ ERROR: Failed to list structures. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

show_structure() {
  load_structures
  local id=$(echo "$CREATED_STRUCTURE_IDS" | awk '{print $1}')
  if [ -z "$id" ]; then
    echo -e "\n❌ ERROR: No structure ID found. Run creation first." >&2
    exit 1
  fi
  echo "==== Show Structure $id ===="
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/structures/$id")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local data=$(parse_response "$raw")
    local name=$(echo "$data" | jq -r '.data.name')
    local status_val=$(echo "$data" | jq -r '.data.status')
    local notes=$(echo "$data" | jq -r '.data.notes')
    echo "✅ Showed structure $id: name='$name', status='$status_val', notes='$notes'"
    if [[ "$VERBOSE" == "true" ]]; then echo "$data" | jq '.'; fi
  else
    echo -e "\n❌ ERROR: Failed to show structure $id. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

update_structure() {
  load_structures
  local id=$(echo "$CREATED_STRUCTURE_IDS" | awk '{print $1}')
  if [ -z "$id" ]; then
    echo -e "\n❌ ERROR: No structure ID found. Run creation first." >&2
    exit 1
  fi
  echo "==== Updating Structure $id ===="
  local payload=$(jq -n '{status: "anchored", notes: "Updated via test"}')
  local raw=$(make_request PUT "$API_BASE_URL/api/maps/$MAP_SLUG/structures/$id" "$payload")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "✅ Updated structure $id"
  else
    echo -e "\n❌ ERROR: Failed to update structure $id. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

delete_structure() {
  load_structures
  local id=$(echo "$CREATED_STRUCTURE_IDS" | awk '{print $1}')
  if [ -z "$id" ]; then
    echo -e "\n❌ ERROR: No structure ID found. Run creation first." >&2
    exit 1
  fi
  echo "==== Deleting Structure $id ===="
  local raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/structures/$id")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "✅ Deleted structure $id"
    CREATED_STRUCTURE_IDS=""
    save_structures
  else
    echo -e "\n❌ ERROR: Failed to delete structure $id. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

# ─── SIGNATURE TESTS ─────────────────────────────────────────────
create_signature() {
  local sys_info=$(get_first_system)
  echo "DEBUG: sys_info='$sys_info'"
  local system_uuid=$(echo "$sys_info" | cut -d: -f1)
  local system_id=$(echo "$sys_info" | cut -d: -f2)
  local system_name=$(echo "$sys_info" | cut -d: -f3-)
  echo "DEBUG: system_id='$system_id' (should be a number like 31001394)"
  if [[ -z "$system_id" ]]; then
    echo "ERROR: system_id is empty. sys_info='$sys_info'" >&2
    exit 1
  fi
  # Generate a unique, valid-looking eve_id (e.g., ABC-123)
  local eve_id=$(cat /dev/urandom | tr -dc 'A-Z' | fold -w 3 | head -n 1)-$(shuf -i 100-999 -n 1)
  echo "==== Creating Signature in system $system_name ($system_id, $system_uuid) with eve_id $eve_id ===="
  local payload=$(jq -n --arg sid "$system_id" --arg name "$system_name" --arg eve_id "$eve_id" '{
    eve_id: $eve_id,
    name: "Wormhole K162",
    description: "Leads to unknown space",
    type: "Wormhole",
    linked_system_id: 30000144,
    kind: "cosmic_signature",
    group: "wormhole",
    custom_info: "Fresh",
    solar_system_id: ($sid|tonumber),
    solar_system_name: $name
  }')
  echo "DEBUG: payload=$payload"
  local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/signatures" "$payload")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    # Now list signatures and find the one with this eve_id
    local list_raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/signatures")
    local id=$(parse_response "$list_raw" | jq -r --arg eve_id "$eve_id" '.data[] | select(.eve_id == $eve_id) | .id' | head -n 1)
    if [[ -z "$id" ]]; then
      echo "❌ ERROR: Created signature not found in list (eve_id: $eve_id)" >&2
      exit 1
    fi
    CREATED_SIGNATURE_IDS=$(add_to_list "$CREATED_SIGNATURE_IDS" "$id")
    save_signatures
    echo "✅ Created signature with eve_id: $eve_id and ID: $id"
  else
    echo "❌ ERROR: Failed to create signature (status $status)" >&2
    echo "$raw" | parse_response | jq . >&2
    exit 1
  fi
}

list_signatures() {
  echo "==== Listing Signatures ===="
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/signatures")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local count=$(parse_response "$raw" | jq '.data | length')
    echo "✅ Listed $count signatures"
    if [[ "$VERBOSE" == "true" ]]; then echo "$(parse_response "$raw")" | jq '.'; fi
  else
    echo -e "\n❌ ERROR: Failed to list signatures. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

show_signature() {
  load_signatures
  local id=$(echo "$CREATED_SIGNATURE_IDS" | awk '{print $1}')
  if [ -z "$id" ]; then
    echo -e "\n❌ ERROR: No signature ID found. Run creation first." >&2
    exit 1
  fi
  echo "==== Show Signature $id ===="
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$id")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local data=$(parse_response "$raw")
    local eve_id=$(echo "$data" | jq -r '.data.eve_id')
    local name=$(echo "$data" | jq -r '.data.name')
    local description=$(echo "$data" | jq -r '.data.description')
    local custom_info=$(echo "$data" | jq -r '.data.custom_info')
    echo "✅ Showed signature $id: eve_id='$eve_id', name='$name', description='$description', custom_info='$custom_info'"
    if [[ "$VERBOSE" == "true" ]]; then echo "$data" | jq '.'; fi
  else
    echo -e "\n❌ ERROR: Failed to show signature $id. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

update_signature() {
  load_signatures
  local id=$(echo "$CREATED_SIGNATURE_IDS" | awk '{print $1}')
  if [ -z "$id" ]; then
    echo -e "\n❌ ERROR: No signature ID found. Run creation first." >&2
    exit 1
  fi
  # Get the EVE system ID for the update payload
  local sys_info=$(get_first_system)
  local system_id=$(echo "$sys_info" | cut -d: -f2)
  echo "==== Updating Signature $id ===="
  local payload=$(jq -n --arg sid "$system_id" '{description: "Updated via test", custom_info: "Updated info", solar_system_id: ($sid|tonumber) }')
  local raw=$(make_request PUT "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$id" "$payload")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "✅ Updated signature $id"
  else
    echo -e "\n❌ ERROR: Failed to update signature $id. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

delete_signature() {
  load_signatures
  local id=$(echo "$CREATED_SIGNATURE_IDS" | awk '{print $1}')
  if [ -z "$id" ]; then
    echo -e "\n❌ ERROR: No signature ID found. Run creation first." >&2
    exit 1
  fi
  echo "==== Deleting Signature $id ===="
  local raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/signatures/$id")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "✅ Deleted signature $id"
    CREATED_SIGNATURE_IDS=""
    save_signatures
  else
    echo -e "\n❌ ERROR: Failed to delete signature $id. Status: $status" >&2
    if [[ "$VERBOSE" == "true" ]]; then echo "Response: $(parse_response "$raw")" >&2; fi
    exit 1
  fi
}

show_menu() {
  echo "===== Map Structure & Signature API Tests ====="
  echo "1. Run all tests in sequence (with pauses)"
  echo "2. Create structure"
  echo "3. List structures"
  echo "4. Show structure"
  echo "5. Update structure"
  echo "6. Delete structure"
  echo "7. Create signature"
  echo "8. List signatures"
  echo "9. Show signature"
  echo "10. Update signature"
  echo "11. Delete signature"
  echo "12. Exit"
  echo "==============================================="
  echo "Enter your choice [1-12]: "
}

case "$COMMAND" in
  "all")
    if [ -t 0 ]; then
      while true; do
        show_menu
        read -r choice
        case $choice in
          1)
            create_structure
            echo "DEBUG: After calling create_structure in menu, exit code $?"
            echo "DEBUG: After create_structure, exit code $?"; read -p "Press Enter to continue..."
            list_structures; echo "DEBUG: After list_structures, exit code $?"; read -p "Press Enter to continue..."
            show_structure; echo "DEBUG: After show_structure, exit code $?"; read -p "Press Enter to continue..."
            update_structure; echo "DEBUG: After update_structure, exit code $?"; read -p "Press Enter to continue..."
            show_structure; echo "DEBUG: After show_structure (post-update), exit code $?"; read -p "Press Enter to continue..."
            delete_structure; echo "DEBUG: After delete_structure, exit code $?"; read -p "Press Enter to continue..."
            create_signature; echo "DEBUG: After create_signature, exit code $?"; read -p "Press Enter to continue..."
            list_signatures; echo "DEBUG: After list_signatures, exit code $?"; read -p "Press Enter to continue..."
            show_signature; echo "DEBUG: After show_signature, exit code $?"; read -p "Press Enter to continue..."
            update_signature; echo "DEBUG: After update_signature, exit code $?"; read -p "Press Enter to continue..."
            show_signature; echo "DEBUG: After show_signature (post-update), exit code $?"; read -p "Press Enter to continue..."
            delete_signature; echo "DEBUG: After delete_signature, exit code $?"; read -p "Press Enter to continue..."
            echo "All tests completed."
            show_menu
            read -r choice
            continue
            ;;
          2) create_structure ;;
          3) list_structures ;;
          4) show_structure ;;
          5) update_structure ;;
          6) delete_structure ;;
          7) create_signature ;;
          8) list_signatures ;;
          9) show_signature ;;
          10) update_signature ;;
          11) delete_signature ;;
          12)
            read -p "Clean up any remaining test data before exiting? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
              delete_structure
              delete_signature
            fi
            exit 0
            ;;
          *) echo "Invalid option. Please try again." ;;
        esac
      done
    else
      create_structure; list_structures; show_structure; update_structure; show_structure; delete_structure
      create_signature; list_signatures; show_signature; update_signature; show_signature; delete_signature
    fi
    ;;
  "create")
    create_structure; create_signature ;;
  "update")
    update_structure; update_signature ;;
  "delete")
    delete_structure; delete_signature ;;
  *)
    echo "Invalid command: $COMMAND"
    echo "Use -h for help"
    exit 1
    ;;
esac

exit 0 
echo "DEBUG: End of script reached" 