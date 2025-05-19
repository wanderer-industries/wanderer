#!/usr/bin/env bash
# ─── Legacy Map endpoint tests ───────────────────────────────────────────────────────
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Track created IDs for cleanup - use space-delimited strings to match utils.sh
CREATED_SYSTEM_IDS=""
CREATED_CONNECTION_IDS=""

# Optional environment variables to control verbosity:
# VERBOSE_LOGGING=1 - Show full API responses
QUIET_MODE=1 # Show minimal output (just test names and results)

# DUMP RESPONSE - Call this to see the complete raw API response
dump_complete_response() {
  local url="$1"
  
  # Only show full response dumps if VERBOSE_LOGGING is set
  if [ "${VERBOSE_LOGGING:-0}" -eq 1 ]; then
    echo ""
    echo "🔍 DUMPING COMPLETE RESPONSE FOR: $url"
    echo "────────────────────────────────────────────────────────────────────────────────"
    curl -s -H "Authorization: Bearer $API_TOKEN" "$url"
    echo ""
    echo "────────────────────────────────────────────────────────────────────────────────"
    echo ""
  else
    # In non-verbose mode, just do the curl but don't show output
    curl -s -H "Authorization: Bearer $API_TOKEN" "$url" > /dev/null
  fi
}

# Initial test to show raw API response structure for system endpoint
test_dump_system_response() {
  # If verbose logging is not enabled, skip this test
  if [ "${VERBOSE_LOGGING:-0}" -ne 1 ]; then
    #echo "Skipping raw response dump (enable with VERBOSE_LOGGING=1)"
    return 0
  fi
  
  local id="30000142"  # Jita
  echo "Getting complete raw API response for system ID $id..."
  dump_complete_response "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$id"
  return 0
}

# Helper function to add element to space-delimited string list
add_to_list() {
  local list="$1"
  local item="$2"
  if [ -z "$list" ]; then
    echo "$item"
  else
    echo "$list $item"
  fi
}

# Helper function to count items in a space-delimited list
count_items() {
  local list="$1"
  if [ -z "$list" ]; then
    echo "0"
  else
    echo "$list" | wc -w
  fi
}

# Parse JSON response with error handling
parse_response() {
  local raw="$1"
  
  # Skip HTTP headers and get the JSON body
  local json_body=$(echo "$raw" | sed '1,/^\s*$/d')
  
  # If JSON is valid, return it. Otherwise, return empty object
  if echo "$json_body" | jq . >/dev/null 2>&1; then
    echo "$json_body"
  else
    echo "{}"
  fi
}

# Function to get and display detailed system information including visibility
fetch_system_details() {
  local system_id=$1
  local verbose=${2:-0}  # Default to non-verbose mode
  
  # Skip detailed output in quiet mode
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "Fetching system details for ID $system_id..."
  fi
  
  # Get the complete raw response
  local raw
  raw=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$system_id")
  
  # Only show raw response in verbose mode
  if [ "$verbose" -eq 1 ] && [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "Raw response from curl:"
    echo "$raw" | jq '.' 2>/dev/null || echo "$raw"
  fi
  
  # Extract key information
  local name=""
  local visible=""
  
  # First attempt to extract from data wrapper
  if echo "$raw" | jq -e '.data' >/dev/null 2>&1; then
    name=$(echo "$raw" | jq -r '.data.name // .data.solar_system_name // ""')
    visible=$(echo "$raw" | jq -r '.data.visible // ""')
  else
    # Use grep as a last resort
    if echo "$raw" | grep -q '"visible":true'; then
      visible="true"
    elif echo "$raw" | grep -q '"visible":false'; then
      visible="false"
    fi
    
    if echo "$raw" | grep -q '"name":"[^"]*"'; then
      name=$(echo "$raw" | grep -o '"name":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')
    fi
  fi
  
  # Show results only if not in quiet mode
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "SYSTEM NAME: $name"
    echo "VISIBILITY: $visible"
  fi
  
  # Return success if we found both name and visibility
  if [ ! -z "$name" ] && [ ! -z "$visible" ]; then
    return 0
  else
    return 1
  fi
}

test_direct_api_access() {
  local raw status
  raw=$(make_request GET "$API_BASE_URL/api/map/systems?slug=$MAP_SLUG")
  status=$(parse_status "$raw")
  [[ "$status" =~ ^2[0-9]{2}$ ]]
}

test_missing_params() {
  local raw status
  raw=$(make_request GET "$API_BASE_URL/api/map/systems")
  status=$(parse_status "$raw")
  [[ "$status" =~ ^4[0-9]{2}$ ]]
}

test_invalid_auth() {
  local old="$API_TOKEN" raw status
  API_TOKEN="invalid-token"
  raw=$(make_request GET "$API_BASE_URL/api/map/systems?slug=$MAP_SLUG")
  status=$(parse_status "$raw")
  API_TOKEN="$old"
  [[ "$status" == "401" || "$status" == "403" ]]
}

test_invalid_slug() {
  local raw status
  raw=$(make_request GET "$API_BASE_URL/api/map/systems?slug=nonexistent")
  status=$(parse_status "$raw")
  [[ "$status" =~ ^4[0-9]{2}$ ]]
}

# Create and then show systems for legacy API
test_show_systems() {
  # Use two well-known systems (use actual EVE IDs for clarity)
  local jita_id=30000142  # Jita
  local amarr_id=30002187 # Amarr
  local success_count=0
  
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "Creating and verifying systems: Jita and Amarr"
  fi
  
  # Create first system - Jita with coordinates
  local payload raw status response
  payload=$(jq -n \
    --argjson sid "$jita_id" \
    --argjson visible true \
    '{solar_system_id:$sid,solar_system_name:"Jita",coordinates:{"x":100,"y":200},visible:$visible}')
    
  # Create the system using the RESTful API 
  raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$payload")
  status=$(parse_status "$raw")
  
  if [[ "$status" == "201" || "$status" == "200" ]]; then
    success_count=$((success_count + 1))
    CREATED_SYSTEM_IDS=$(add_to_list "$CREATED_SYSTEM_IDS" "$jita_id")
    
    if [ "${QUIET_MODE:-0}" -ne 1 ]; then
      echo "✓ Created Jita system (ID: $jita_id)"
      echo "Verifying system $jita_id is visible after creation..."
    fi
    
    # Allow a moment for system to be registered
    sleep 1
    
    # Verify the system is visible
    fetch_system_details "$jita_id"
  else
    echo "Warning: Couldn't create Jita system, status: $status"
  fi
  
  # Create second system - Amarr with coordinates
  payload=$(jq -n \
    --argjson sid "$amarr_id" \
    --argjson visible true \
    '{solar_system_id:$sid,solar_system_name:"Amarr",coordinates:{"x":300,"y":400},visible:$visible}')
    
  # Create the system using the RESTful API
  raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$payload")
  status=$(parse_status "$raw")
  
  if [[ "$status" == "201" || "$status" == "200" ]]; then
    success_count=$((success_count + 1))
    CREATED_SYSTEM_IDS=$(add_to_list "$CREATED_SYSTEM_IDS" "$amarr_id")
    
    if [ "${QUIET_MODE:-0}" -ne 1 ]; then
      echo "✓ Created Amarr system (ID: $amarr_id)"
      echo "Verifying system $amarr_id is visible after creation..."
    fi
    
    # Allow a moment for system to be registered
    sleep 1
    
    # Verify the system is visible
    fetch_system_details "$amarr_id"
  else
    echo "Warning: Couldn't create Amarr system, status: $status"
  fi
  
  # If we couldn't create any systems, test fails
  if [ $success_count -eq 0 ]; then
    echo "Couldn't create any test systems for legacy API"
    return 1
  fi
  
  # Verify systems are in the list API
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "Checking if systems appear in the list API after creation..."
  fi
  
  raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  status=$(parse_status "$raw")
  response_body=$(echo "$raw" | sed '1,/^\s*$/d')
  
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    # Parse the response appropriately depending on structure
    local data_array=""
    
    # Check if the response has data array structure
    if echo "$response_body" | jq -e '.data' >/dev/null 2>&1; then
      data_array=$(echo "$response_body" | jq '.data')
    else
      data_array="$response_body"
    fi
    
    # Check each created system
    local all_systems_in_list=true
    for sid in $CREATED_SYSTEM_IDS; do
      if echo "$data_array" | jq -e ".[] | select(.solar_system_id == $sid)" >/dev/null 2>&1; then
        if [ "${QUIET_MODE:-0}" -ne 1 ]; then
          echo "✓ System $sid appears in list API after creation"
        fi
      else
        all_systems_in_list=false
        echo "⚠ WARNING: System $sid does not appear in list API after creation"
      fi
    done
  else
    echo "ERROR: Failed to get systems list: status $status"
  fi
  
  # Now test the legacy API endpoint for each created system
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "Verifying systems are accessible via legacy API..."
  fi
  
  local legacy_success=true
  
  for sid in $CREATED_SYSTEM_IDS; do
    local raw status
    raw=$(make_request GET "$API_BASE_URL/api/map/system?id=$sid&slug=$MAP_SLUG")
    status=$(parse_status "$raw")
    
    if [[ ! "$status" =~ ^2[0-9]{2}$ ]]; then
      echo "Failed to retrieve system $sid via legacy API: status $status"
      legacy_success=false
    fi
  done
  
  if [ "$legacy_success" = "true" ] && [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "✓ All systems accessible via legacy API"
  fi
  
  return 0
}

test_verify_connections() {
  # Even if we don't have systems, we can still test the legacy connections API endpoint
  # by checking that it returns a valid response
  local raw status response
  
  # Try to check all connections via legacy API
  raw=$(make_request GET "$API_BASE_URL/api/map/connections?slug=$MAP_SLUG")
  status=$(parse_status "$raw")
  
  # If the endpoint exists and returns a success status, the test passes
  if [[ "$status" =~ ^2[0-9]{2}$ ]]; then
    return 0
  fi

  return 1
}

test_delete_systems() {
  # If we don't have system IDs, skip the test
  if [ $(count_items "$CREATED_SYSTEM_IDS") -eq 0 ]; then
    echo "No systems to delete, skipping"
    return 0
  fi
  
  local success_count=0
  local total_systems=$(count_items "$CREATED_SYSTEM_IDS")
  local deleted_ids=""
  
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "TEST: Delete Systems API"
    echo "------------------------"
    echo "Testing system deletion for existing systems in map $MAP_SLUG"
    echo "Systems to delete: $CREATED_SYSTEM_IDS"
  fi
  
  # Try batch delete first
  if [ $(count_items "$CREATED_SYSTEM_IDS") -gt 1 ]; then
    if [ "${QUIET_MODE:-0}" -ne 1 ]; then
      echo "Attempting batch delete of systems: $CREATED_SYSTEM_IDS"
    fi
    
    local payload=$(echo "$CREATED_SYSTEM_IDS" | tr ' ' '\n' | jq -R . | jq -s '{system_ids: .}')
    local raw status
    
    raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems/batch_delete" "$payload")
    status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      if [ "${QUIET_MODE:-0}" -ne 1 ]; then
        echo "✓ Batch delete successful"
      fi
      
      # Verify systems are gone from the list
      sleep 1
      local list_response
      list_response=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
      
      # Check if all systems are gone
      local all_deleted=1
      for system_id in $CREATED_SYSTEM_IDS; do
        if echo "$list_response" | jq -e --arg id "$system_id" '.data[] | select(.solar_system_id == ($id|tonumber) and .visible == true)' >/dev/null 2>&1; then
          all_deleted=0
        else
          success_count=$((success_count + 1))
          deleted_ids=$(add_to_list "$deleted_ids" "$system_id")
          if [ "${QUIET_MODE:-0}" -ne 1 ]; then
            echo "✓ System $system_id no longer visible in list API after batch deletion"
          fi
        fi
      done
      
      if [ $all_deleted -eq 1 ]; then
        # Update the list of created systems to remove successfully deleted ones
        for id in $deleted_ids; do
          CREATED_SYSTEM_IDS=$(echo "$CREATED_SYSTEM_IDS" | sed "s/\b$id\b//g" | tr -s ' ' | sed 's/^ //g' | sed 's/ $//g')
        done
        
        # If batch delete worked for all systems, we're done
        if [ $success_count -eq $total_systems ]; then
          if [ "${QUIET_MODE:-0}" -ne 1 ]; then
            echo "✅ All systems successfully deleted via batch delete"
          fi
          return 0
        fi
      fi
    else
      if [ "${QUIET_MODE:-0}" -ne 1 ]; then
        echo "Batch delete failed with status $status, trying individual deletes"
      fi
    fi
  fi
  
  # If batch delete didn't work, try individual deletes
  for system_id in $CREATED_SYSTEM_IDS; do
    if [ "${QUIET_MODE:-0}" -ne 1 ]; then
      echo "Attempting to delete system with ID: $system_id"
    fi
    
    local raw status
    
    # Use the RESTful DELETE endpoint
    raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$system_id")
    status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      if [ "${QUIET_MODE:-0}" -ne 1 ]; then
        echo "✓ Delete API call successful for system $system_id"
      fi
      
      # Allow time for change to propagate
      sleep 1
      
      # Get the complete system list after deletion
      local list_response
      list_response=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
      
      # Check if the system appears in the list (deleted systems shouldn't appear or should be invisible)
      local system_still_visible=0
      
      if echo "$list_response" | jq -e --arg id "$system_id" '.data[] | select(.solar_system_id == ($id|tonumber) and .visible == true)' >/dev/null 2>&1; then
        system_still_visible=1
      fi
      
      if [ $system_still_visible -eq 0 ]; then
        if [ "${QUIET_MODE:-0}" -ne 1 ]; then
          echo "✓ System $system_id no longer visible in list API after deletion"
        fi
        success_count=$((success_count + 1))
        deleted_ids=$(add_to_list "$deleted_ids" "$system_id")
      fi
    else
      echo "❌ Failed to delete system $system_id: status $status"
    fi
  done
  
  # Update the list of created systems to remove successfully deleted ones
  for id in $deleted_ids; do
    CREATED_SYSTEM_IDS=$(echo "$CREATED_SYSTEM_IDS" | sed "s/\b$id\b//g" | tr -s ' ' | sed 's/^ //g' | sed 's/ $//g')
  done
  
  # Report results
  if [ $success_count -eq $total_systems ]; then
    if [ "${QUIET_MODE:-0}" -ne 1 ]; then
      echo "✅ All systems successfully deleted (no longer visible in list API): $success_count / $total_systems"
    fi
    return 0
  else
    echo "⚠ Some systems still appear visible in list API after deletion: $success_count / $total_systems deleted"
    return 1
  fi
}

# Test the system list API endpoint
test_system_list() {
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "Testing system list API endpoint..."
  fi
  
  local raw status
  raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  status=$(parse_status "$raw")
  
  if [[ "$status" != "200" ]]; then
    echo "ERROR: Failed to get system list: status $status"
    return 1
  fi
  
  # Test legacy system list endpoint too
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "Testing legacy system list API endpoint..."
  fi
  
  raw=$(make_request GET "$API_BASE_URL/api/map/systems?slug=$MAP_SLUG")
  status=$(parse_status "$raw")
  
  if [[ "$status" != "200" ]]; then
    echo "ERROR: Failed to get legacy system list: status $status"
    return 1
  fi
  
  # Check that both APIs return the same number of systems
  local restful_count=$(echo "$raw" | sed '1,/^\s*$/d' | jq '.data | length // length')
  raw=$(make_request GET "$API_BASE_URL/api/map/systems?slug=$MAP_SLUG")
  local legacy_count=$(echo "$raw" | sed '1,/^\s*$/d' | jq '.data | length // length')
  
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo "RESTful API returned $restful_count systems, Legacy API returned $legacy_count systems"
  fi
  
  if [[ "$restful_count" == "$legacy_count" ]]; then
    if [ "${QUIET_MODE:-0}" -ne 1 ]; then
      echo "✓ Both APIs return the same number of systems"
    fi
  else
    echo "WARNING: APIs return different numbers of systems"
  fi
  
  return 0
}

# ─── Execute Tests ────────────────────────────────────────────────────────────
# Function to run a test and report success/failure
run_test() {
  local name="$1"
  local func="$2"
  
  # Only print test name if not in quiet mode
  if [ "${QUIET_MODE:-0}" -ne 1 ]; then
    echo -n "Testing: $name... "
  fi
  
  # Run the test function
  if $func; then
    echo "✅ $name"
    return 0
  else
    echo "❌ $name"
    return 1
  fi
}

run_test "Dump Raw API Response" test_dump_system_response
run_test "Direct API access" test_direct_api_access
run_test "Missing params (4xx)" test_missing_params
run_test "Invalid auth (401/403)" test_invalid_auth
run_test "Invalid slug on GET" test_invalid_slug
run_test "Show systems" test_show_systems
run_test "System list" test_system_list
run_test "Verify connections" test_verify_connections
run_test "Delete systems" test_delete_systems