#!/bin/bash
# test/manual/api/improved_api_tests.sh
# ─── Improved API Tests for Map System and Connection APIs ────────────────────────
# 
# Usage:
#   ./improved_api_tests.sh          # Run all tests with menu selection
#   ./improved_api_tests.sh create   # Run only creation tests
#   ./improved_api_tests.sh update   # Run only update tests
#   ./improved_api_tests.sh delete   # Run only deletion tests
#   ./improved_api_tests.sh -v       # Run in verbose mode
#
source "$(dirname "$0")/utils.sh"

# Set to "true" to see detailed output, "false" for minimal output
VERBOSE=${VERBOSE:-false}

# Parse command line options
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

# File to store system and connection IDs for persistence between command runs
SYSTEMS_FILE="/tmp/wanderer_test_systems.txt"
CONNECTIONS_FILE="/tmp/wanderer_test_connections.txt"

# Track created IDs for cleanup
CREATED_SYSTEM_IDS=""
CREATED_CONNECTION_IDS=""

# Array of valid EVE system IDs and names (first 5 for individual creation)
declare -a EVE_SYSTEMS=(
  "30005304:Alentene"
  "30003380:Alf"
  "30003811:Algasienan"
  "30004972:Algogille"
  "30002698:Aliette"
)

# Next 5 for batch upsert
declare -a BATCH_EVE_SYSTEMS=(
  "30002754:Alikara"
  "30002712:Alillere"
  "30003521:Alkabsi"
  "30000034:Alkez"
  "30004995:Allamotte"
)

# ─── UTILITY FUNCTIONS ─────────────────────────────────────────────────────

# Function to save created system IDs to file
save_systems() {
  echo "$CREATED_SYSTEM_IDS" > "$SYSTEMS_FILE"
  [[ "$VERBOSE" == "true" ]] && echo "Saved $(wc -w < "$SYSTEMS_FILE") systems to $SYSTEMS_FILE"
}

# Function to load system IDs from file
load_systems() {
  if [ -f "$SYSTEMS_FILE" ]; then
    CREATED_SYSTEM_IDS=$(cat "$SYSTEMS_FILE")
    [[ "$VERBOSE" == "true" ]] && echo "Loaded $(wc -w < "$SYSTEMS_FILE") systems from $SYSTEMS_FILE"
  else
    echo "No systems file found at $SYSTEMS_FILE. Run creation tests first."
    CREATED_SYSTEM_IDS=""
  fi
}

# Function to save created connection IDs to file
save_connections() {
  echo "$CREATED_CONNECTION_IDS" > "$CONNECTIONS_FILE"
  [[ "$VERBOSE" == "true" ]] && echo "Saved $(wc -w < "$CONNECTIONS_FILE") connections to $CONNECTIONS_FILE"
}

# Function to load connection IDs from file
load_connections() {
  if [ -f "$CONNECTIONS_FILE" ]; then
    CREATED_CONNECTION_IDS=$(cat "$CONNECTIONS_FILE")
    [[ "$VERBOSE" == "true" ]] && echo "Loaded $(wc -w < "$CONNECTIONS_FILE") connections from $CONNECTIONS_FILE"
  else
    echo "No connections file found at $CONNECTIONS_FILE. Run creation tests first."
    CREATED_CONNECTION_IDS=""
  fi
}

# Function to add item to space-delimited list
add_to_list() {
  local list="$1"
  local item="$2"
  if [ -z "$list" ]; then
    echo "$item"
  else
    echo "$list $item"
  fi
}

# ─── TEST FUNCTIONS ─────────────────────────────────────────────────────

# FUNCTION: Create systems
create_systems() {
  echo "==== Creating Systems ===="
  local system_count=0
  local center_x=500
  local center_y=500
  local radius=250

  # Only clear the systems file if we're starting fresh
  > "$SYSTEMS_FILE"
  CREATED_SYSTEM_IDS=""

  # Build all system payloads as a JSON array
  local systems_payload="["
  local num_systems=${#EVE_SYSTEMS[@]}
  for i in $(seq 0 $((num_systems-1))); do
    IFS=':' read -r system_id system_name <<< "${EVE_SYSTEMS[$i]}"
    local angle=$(echo "scale=6; $i * 6.28318 / $num_systems" | bc -l)
    local x=$(echo "scale=2; $center_x + $radius * c($angle)" | bc -l)
    local y=$(echo "scale=2; $center_y + $radius * s($angle)" | bc -l)
    local system_json=$(jq -n \
      --argjson sid "$system_id" \
      --arg name "$system_name" \
      --argjson x "$x" \
      --argjson y "$y" \
      '{
        solar_system_id: $sid,
        solar_system_name: $name,
        position_x: $x,
        position_y: $y,
        status: "clear",
        visible: true,
        description: "Test system",
        tag: "TEST",
        locked: false
      }')
    systems_payload+="$system_json"
    if [ $i -lt $((num_systems-1)) ]; then
      systems_payload+="," 
    fi
  done
  systems_payload+="]"

  # Wrap in the 'systems' key
  local payload="{\"systems\": $systems_payload}"

  # Send the batch create request
  local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$payload")
  local status=$(parse_status "$raw")

  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "✅ Created all systems in batch"
    # Track the system IDs for later cleanup
    for i in $(seq 0 $((num_systems-1))); do
      IFS=':' read -r system_id _ <<< "${EVE_SYSTEMS[$i]}"
      CREATED_SYSTEM_IDS=$(add_to_list "$CREATED_SYSTEM_IDS" "$system_id")
      system_count=$((system_count+1))
    done
  else
    echo "❌ Failed to create systems in batch. Status: $status"
    [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
  fi

  echo "Total systems created: $system_count/$num_systems"
  save_systems

  # Validate actual state after creation
  echo "Validating systems after dedicated creation:"
  list_systems_and_connections
}

# FUNCTION: Create connections
create_connections() {
  echo "==== Creating Connections ===="
  load_systems
  if [ -z "$CREATED_SYSTEM_IDS" ]; then
    echo "No systems available. Run system creation first."
    return 1
  fi
  > "$CONNECTIONS_FILE"
  CREATED_CONNECTION_IDS=""
  local connection_count=0
  local total_connections=0
  local system_array=($CREATED_SYSTEM_IDS)

  echo "Testing dedicated connection endpoints..."
  # Create connections one by one using the dedicated endpoint
  for i in $(seq 0 $((${#system_array[@]}-1))); do
    local source=${system_array[$i]}
    local target=${system_array[$(( (i+1) % ${#system_array[@]} ))]}
    total_connections=$((total_connections+1))
    
    # Create single connection payload
    local payload=$(jq -n \
      --argjson source "$source" \
      --argjson target "$target" \
      '{
        solar_system_source: $source,
        solar_system_target: $target,
        type: 0,
        mass_status: 0,
        time_status: 0,
        ship_size_type: 1,
        wormhole_type: "K162",
        count_of_passage: 0
      }')
    
    # Send create request to dedicated endpoint
    local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/connections" "$payload")
    local status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Created connection from $source to $target"
      local response=$(parse_response "$raw")
      # Store source and target for later use
      CREATED_CONNECTION_IDS=$(add_to_list "$CREATED_CONNECTION_IDS" "${source}:${target}")
      connection_count=$((connection_count+1))
    else
      echo "❌ Failed to create connection from $source to $target. Status: $status"
      [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
    fi
  done
  
  echo "Total connections created via dedicated endpoint: $connection_count/$total_connections"
  save_connections

  # Always validate actual state after connection creation
  echo "Validating connections after dedicated creation:"
  list_systems_and_connections

  echo -e "\nTesting batch upsert functionality..."
  # Build batch upsert payload using BATCH_EVE_SYSTEMS
  local batch_systems_json="["
  local batch_connections_json="["
  local num_batch_systems=${#BATCH_EVE_SYSTEMS[@]}
  for i in $(seq 0 $((num_batch_systems-1))); do
    IFS=':' read -r system_id system_name <<< "${BATCH_EVE_SYSTEMS[$i]}"
    local angle=$(echo "scale=6; $i * 6.28318 / $num_batch_systems" | bc -l)
    local x=$(echo "scale=2; 500 + 250 * c($angle)" | bc -l)
    local y=$(echo "scale=2; 500 + 250 * s($angle)" | bc -l)
    local system_json=$(jq -n \
      --argjson sid "$system_id" \
      --arg name "$system_name" \
      --argjson x "$x" \
      --argjson y "$y" \
      '{
        solar_system_id: $sid,
        solar_system_name: $name,
        position_x: $x,
        position_y: $y,
        status: "clear",
        visible: true,
        description: "Test system (batch)",
        tag: "BATCH",
        locked: false
      }')
    batch_systems_json+="$system_json"
    if [ $i -lt $((num_batch_systems-1)) ]; then
      batch_systems_json+="," 
    fi
    # Build connections in a ring
    local source=$system_id
    local next_index=$(( (i+1) % num_batch_systems ))
    IFS=':' read -r target_id _ <<< "${BATCH_EVE_SYSTEMS[$next_index]}"
    batch_connections_json+="{\"solar_system_source\":$source,\"solar_system_target\":$target_id,\"mass_status\":0,\"ship_size_type\":1,\"type\":0}"
    if [ $i -lt $((num_batch_systems-1)) ]; then
      batch_connections_json+="," 
    fi
  done
  batch_systems_json+="]"
  batch_connections_json+="]"

  echo "[SCRIPT] Batch upsert systems: $batch_systems_json"
  echo "[SCRIPT] Batch upsert connections: $batch_connections_json"

  # Check for API_TOKEN
  if [ -z "$API_TOKEN" ]; then
    echo "❌ API_TOKEN is not set. Please export API_TOKEN before running the script."
    return 1
  fi

  # Send batch upsert request
  local response=$(curl -s -X POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -d "{\"systems\":$batch_systems_json,\"connections\":$batch_connections_json}")

  echo "[SCRIPT] Batch upsert response: $response"
  
  # Debug: List all connections after batch upsert
  echo "[SCRIPT] Listing all connections after batch upsert:"
  local list_raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  local list_status=$(parse_status "$list_raw")
  if [[ "$list_status" =~ ^2[0-9][0-9]$ ]]; then
    local list_response=$(parse_response "$list_raw")
    echo "$list_response" | jq -c '.data.connections[] | {id: .id, source: .solar_system_source, target: .solar_system_target, mass_status: .mass_status, ship_size_type: .ship_size_type, type: .type}'
  else
    echo "[SCRIPT] Failed to list connections after batch upsert. Status: $list_status"
  fi

  # Add batch system IDs to CREATED_SYSTEM_IDS
  for i in $(seq 0 $((num_batch_systems-1))); do
    IFS=':' read -r system_id _ <<< "${BATCH_EVE_SYSTEMS[$i]}"
    CREATED_SYSTEM_IDS=$(add_to_list "$CREATED_SYSTEM_IDS" "$system_id")
  done

  # Add batch connection pairs to CREATED_CONNECTION_IDS
  for i in $(seq 0 $((num_batch_systems-1))); do
    IFS=':' read -r source _ <<< "${BATCH_EVE_SYSTEMS[$i]}"
    next_index=$(( (i+1) % num_batch_systems ))
    IFS=':' read -r target _ <<< "${BATCH_EVE_SYSTEMS[$next_index]}"
    CREATED_CONNECTION_IDS=$(add_to_list "$CREATED_CONNECTION_IDS" "${source}:${target}")
  done
  save_systems
  save_connections

  list_systems_and_connections
  
  echo "Total connections updated: $connection_count/${#system_array[@]}"
}

# FUNCTION: Update systems
update_systems() {
  echo "==== Updating Systems ===="
  load_systems
  
  if [ -z "$CREATED_SYSTEM_IDS" ]; then
    echo "No systems available. Run system creation first."
    return 1
  fi
  
  local update_count=0
  local system_array=($CREATED_SYSTEM_IDS)
  local num_systems=${#system_array[@]}
  
  for i in $(seq 0 $((num_systems-1))); do
    local system_id=${system_array[$i]}
    
    # Get system name from EVE_SYSTEMS array if available
    local system_name="System $system_id"
    for j in $(seq 0 $((${#EVE_SYSTEMS[@]}-1))); do
      IFS=':' read -r curr_id curr_name <<< "${EVE_SYSTEMS[$j]}"
      if [ "$curr_id" = "$system_id" ]; then
        system_name=$curr_name
        break
      fi
    done
    
    echo "Updating system $((i+1))/$num_systems: $system_name (ID: $system_id)"
    
    # Create update payload with new values
    local status_values=("clear" "friendly" "hostile" "occupied")
    local status=${status_values[$((RANDOM % 4))]}
    local desc="Updated description for $system_name"
    local tag="UPDATED"
    
    local payload=$(jq -n \
      --arg status "$status" \
      --arg desc "$desc" \
      --arg tag "$tag" \
      '{
        status: $status,
        description: $desc,
        tag: $tag,
        locked: false
      }')
    
    # Send the update request
    local raw=$(make_request PUT "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$system_id" "$payload")
    local status_code=$(parse_status "$raw")
    
    if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Updated system $system_name with status: $status"
      update_count=$((update_count+1))
    else
      echo "❌ Failed to update system $system_name. Status: $status_code"
      [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
    fi
  done
  
  echo "Total systems updated: $update_count/$num_systems"
}

# FUNCTION: Update connections
update_connections() {
  echo "==== Updating Connections ===="
  load_systems
  load_connections
  
  if [ -z "$CREATED_SYSTEM_IDS" ] || [ -z "$CREATED_CONNECTION_IDS" ]; then
    echo "No systems or connections available. Run creation tests first."
    return 1
  fi

  echo "Testing connection updates..."
  local update_count=0
  local conn_array=($CREATED_CONNECTION_IDS)
  
  for triple in "${conn_array[@]}"; do
    local source=$(echo $triple | cut -d: -f1)
    local target=$(echo $triple | cut -d: -f2)
    
    # Create update payload
    local mass_values=(0 1 2)
    local ship_values=(0 1 2 3)
    local mass=${mass_values[$((RANDOM % 3))]}
    local ship=${ship_values[$((RANDOM % 4))]}
    local payload=$(jq -n \
      --argjson mass "$mass" \
      --argjson ship "$ship" \
      '{
        mass_status: $mass,
        ship_size_type: $ship
      }')
    
    # Try source/target update
    local raw=$(make_request PATCH "$API_BASE_URL/api/maps/$MAP_SLUG/connections?solar_system_source=$source&solar_system_target=$target" "$payload")
    local status_code=$(parse_status "$raw")
    
    if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Updated connection $source->$target"
      update_count=$((update_count+1))
    else
      echo "❌ Failed to update connection $source->$target. Status: $status_code"
      [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
    fi
  done
  
  echo "Total connections updated: $update_count/${#conn_array[@]}"
  
  echo -e "\nTesting batch connection updates..."
  # Create batch update payload for all connections
  local batch_connections="["
  local first=true
  for triple in "${conn_array[@]}"; do
    local source=$(echo $triple | cut -d: -f1)
    local target=$(echo $triple | cut -d: -f2)
    
    local mass=${mass_values[$((RANDOM % 3))]}
    local ship=${ship_values[$((RANDOM % 4))]}
    
    if [ "$first" = true ]; then
      first=false
    else
      batch_connections+=","
    fi
    
    batch_connections+=$(jq -n \
      --argjson source "$source" \
      --argjson target "$target" \
      --argjson mass "$mass" \
      --argjson ship "$ship" \
      '{
        solar_system_source: $source,
        solar_system_target: $target,
        mass_status: $mass,
        ship_size_type: $ship
      }')
  done
  batch_connections+="]"
  
  local batch_payload="{\"connections\": $batch_connections}"
  local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$batch_payload")
  local status=$(parse_status "$raw")
  
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local response=$(parse_response "$raw")
    local updated_count=$(echo "$response" | jq '.data.connections.updated')
    if [ "$updated_count" != "null" ]; then
      echo "✅ Batch update successful - Updated connections: $updated_count"
    else
      echo "❌ Batch update returned null for updated count"
    fi
  else
    echo "❌ Batch update failed. Status: $status"
    [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
  fi
}

# FUNCTION: List systems and connections
list_systems_and_connections() {
  echo "==== Listing Systems and Connections ===="
  load_systems
  if [ -z "$CREATED_SYSTEM_IDS" ]; then
    echo "No systems available. Run system creation first."
    return 1
  fi
  echo "Testing list all systems and connections endpoint"
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  local status=$(parse_status "$raw")
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local response=$(parse_response "$raw")
    local system_count=$(echo "$response" | jq '.data.systems | length')
    local conn_count=$(echo "$response" | jq '.data.connections | length')
    echo "✅ Listed $system_count systems and $conn_count connections"
    [[ "$VERBOSE" == "true" ]] && echo "$response" | jq '.'
    return 0
  else
    echo "❌ Failed to list systems and connections. Status: $status"
    return 1
  fi
}

# FUNCTION: Delete connections and systems
delete_everything() {
  echo "==== Deleting Connections and Systems ===="
  load_connections
  load_systems

  echo "Cleaning up connections..."
  # Delete connections using source/target pairs
  local conn_array=($CREATED_CONNECTION_IDS)
  for triple in "${conn_array[@]}"; do
    local source=$(echo $triple | cut -d: -f1)
    local target=$(echo $triple | cut -d: -f2)
    
    local raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/connections?solar_system_source=$source&solar_system_target=$target")
    local status=$(parse_status "$raw")
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Deleted connection $source->$target"
    else
      echo "❌ Failed to delete connection $source->$target. Status: $status"
      [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
    fi
  done

  echo "Cleaning up systems..."
  # Use batch delete for systems
  local system_array=($CREATED_SYSTEM_IDS)
  echo "Attempting batch delete of systems..."
  echo "System ${system_array[@]}"
  
  local system_ids_json=$(printf '%s\n' "${system_array[@]}" | jq -R . | jq -s .)
  local payload=$(jq -n --argjson system_ids "$system_ids_json" '{system_ids: $system_ids}')
  local raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$payload")
  local status=$(parse_status "$raw")
  
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "✅ Batch delete successful for all systems"
    > "$SYSTEMS_FILE"
    > "$CONNECTIONS_FILE"
    CREATED_SYSTEM_IDS=""
    CREATED_CONNECTION_IDS=""
  else
    echo "❌ Batch delete failed. Status: $status"
    [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
  fi
}

# ─── MENU AND INTERACTION LOGIC ─────────────────────────────────────────

show_menu() {
  echo "===== Map System and Connection API Tests ====="
  echo "1. Run all tests in sequence (with pauses)"
  echo "2. Create systems"
  echo "3. Create connections"
  echo "4. Update systems"
  echo "5. Update connections"
  echo "6. List systems and connections"
  echo "7. Delete everything"
  echo "8. Exit"
  echo "================================================"
  echo "Enter your choice [1-8]: "
}

# ─── MAIN EXECUTION FLOW ─────────────────────────────────────────────────

# Main execution based on command
case "$COMMAND" in
  "all")
    # If no specific command was provided, show the menu
    if [ -t 0 ]; then  # Only show menu if running interactively
      # Interactive mode with menu
      while true; do
        show_menu
        read -r choice
        
        case $choice in
          1)
            # Run all tests in sequence with pauses
            create_systems || echo "System creation failed/skipped"
            echo "Press Enter to continue with connection creation..."
            read -r
            
            create_connections || echo "Connection creation failed/skipped"
            echo "Press Enter to continue with system updates..."
            read -r
            
            update_systems || echo "System update failed/skipped"
            echo "Press Enter to continue with connection updates..."
            read -r
            
            update_connections || echo "Connection update failed/skipped"
            echo "Press Enter to continue with listing tests..."
            read -r
            
            list_systems_and_connections || echo "Listing failed/skipped"
            echo "Press Enter to continue with deletion..."
            read -r
            
            delete_everything || echo "Cleanup failed/skipped"
            echo "All tests completed."
            ;;
          2)
            create_systems
            ;;
          3)
            create_connections
            ;;
          4)
            update_systems
            ;;
          5)
            update_connections
            ;;
          6)
            list_systems_and_connections
            ;;
          7)
            delete_everything
            ;;
          8)
            # Offer to clean up before exiting
            read -p "Clean up any remaining test data before exiting? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
              delete_everything
            fi
            exit 0
            ;;
          *)
            echo "Invalid option. Please try again."
            ;;
        esac
      done
    else
      # Non-interactive mode, run all tests in sequence
      create_systems || echo "System creation failed/skipped"
      create_connections || echo "Connection creation failed/skipped"
      update_systems || echo "System update failed/skipped"
      update_connections || echo "Connection update failed/skipped"
      list_systems_and_connections || echo "Listing failed/skipped"
      delete_everything || echo "Cleanup failed/skipped"
    fi
    ;;
  "create")
    create_systems
    create_connections
    ;;
  "update")
    update_systems
    update_connections
    list_systems_and_connections
    ;;
  "delete")
    delete_everything
    ;;
  *)
    echo "Invalid command: $COMMAND"
    echo "Use -h for help"
    exit 1
    ;;
esac

exit 0 