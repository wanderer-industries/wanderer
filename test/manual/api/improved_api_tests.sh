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

# Array of real EVE Online system IDs and names (10 systems for testing)
# Format: "system_id:system_name"
EVE_SYSTEMS=(
  "30000142:Jita"        # Trade hub
  "30002187:Amarr"       # Trade hub
  "30000144:New Caldari" # Near Jita
  "30002053:Hek"         # Trade hub
  "30002659:Dodixie"     # Trade hub
  "30002510:Rens"        # Trade hub
  "30001161:Derelik"     # Random system
  "30004712:Delve"       # Player territory
  "30002079:Tash-Murkon" # Amarr space
  "30003489:Pure Blind"  # Null sec
)

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
  
  # Create each system in a circle
  for i in $(seq 0 $((${#EVE_SYSTEMS[@]}-1))); do
    # Parse system ID and name
    IFS=':' read -r system_id system_name <<< "${EVE_SYSTEMS[$i]}"
    
    # Calculate position in circle
    local angle=$(echo "scale=6; $i * 6.28318 / ${#EVE_SYSTEMS[@]}" | bc -l)
    local x=$(echo "scale=2; $center_x + $radius * c($angle)" | bc -l)
    local y=$(echo "scale=2; $center_y + $radius * s($angle)" | bc -l)
    
    echo "Creating system $((i+1))/${#EVE_SYSTEMS[@]}: $system_name (ID: $system_id)"
    
    # Create system payload
    local payload=$(jq -n \
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
    
    # Send the create request
    local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$payload")
    local status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Created system $system_name"
      # Track the system ID for later cleanup
      CREATED_SYSTEM_IDS=$(add_to_list "$CREATED_SYSTEM_IDS" "$system_id")
      system_count=$((system_count+1))
    else
      echo "❌ Failed to create system $system_name. Status: $status"
      [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
    fi
  done
  
  echo "Total systems created: $system_count/${#EVE_SYSTEMS[@]}"
  save_systems
}

# FUNCTION: Create connections
create_connections() {
  echo "==== Creating Connections ===="
  load_systems
  
  if [ -z "$CREATED_SYSTEM_IDS" ]; then
    echo "No systems available. Run system creation first."
    return 1
  fi
  
  # Only clear the connections file if we're starting fresh
  > "$CONNECTIONS_FILE"
  CREATED_CONNECTION_IDS=""
  
  local connection_count=0
  local total_connections=0
  local system_array=($CREATED_SYSTEM_IDS)
  
  # Create connections in a circular pattern
  for i in $(seq 0 $((${#system_array[@]}-1))); do
    local source=${system_array[$i]}
    local target=${system_array[$(( (i+1) % ${#system_array[@]} ))]}
    total_connections=$((total_connections+1))
    
    # Get system names for better logging
    IFS=':' read -r _ source_name <<< "${EVE_SYSTEMS[$i]}"
    local target_idx=$(( (i+1) % ${#system_array[@]} ))
    IFS=':' read -r _ target_name <<< "${EVE_SYSTEMS[$target_idx]}"
    
    echo "Creating connection $((i+1))/${#system_array[@]}: $source_name → $target_name"
    
    # Create connection payload
    local payload=$(jq -n \
      --argjson source "$source" \
      --argjson target "$target" \
      '{
        solar_system_source: $source,
        solar_system_target: $target,
        type: 0,
        mass_status: 0,
        time_status: 0,
        ship_size_type: 0,
        locked: false
      }')
    
    # Send the create request
    local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$source/connections" "$payload")
    local status=$(parse_status "$raw")
    local response=$(parse_response "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Created connection $source → $target"
      
      # Try to extract connection ID from response
      local conn_id=""
      if echo "$response" | jq -e '.data.id' &>/dev/null; then
        conn_id=$(echo "$response" | jq -r '.data.id')
      elif echo "$response" | jq -e '.id' &>/dev/null; then
        conn_id=$(echo "$response" | jq -r '.id')
      fi
      
      if [ -n "$conn_id" ]; then
        CREATED_CONNECTION_IDS=$(add_to_list "$CREATED_CONNECTION_IDS" "${conn_id}:${source}:${target}")
      else
        # If we couldn't extract the ID, we'll try to retrieve connections later
        echo "⚠️ Connection created but couldn't extract ID from response"
      fi
      
      connection_count=$((connection_count+1))
    else
      echo "❌ Failed to create connection. Status: $status"
      [[ "$VERBOSE" == "true" ]] && echo "Response: $response"
    fi
  done
  
  # If we couldn't extract connection IDs, try to retrieve them
  if [ -z "$CREATED_CONNECTION_IDS" ] && [ $connection_count -gt 0 ]; then
    echo "Retrieving connection IDs..."
    # Get the first system ID to retrieve its connections
    local first_system=${system_array[0]}
    local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$first_system/connections")
    local status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      local response=$(parse_response "$raw")
      if echo "$response" | jq -e '.data' &>/dev/null; then
        for row in $(echo "$response" | jq -c '.data[]'); do
          id=$(echo "$row" | jq -r '.id')
          src=$(echo "$row" | jq -r '.solar_system_source')
          tgt=$(echo "$row" | jq -r '.solar_system_target')
          CREATED_CONNECTION_IDS=$(add_to_list "$CREATED_CONNECTION_IDS" "${id}:${src}:${tgt}")
        done
      fi
    fi
  fi
  
  echo "Total connections created: $connection_count/$total_connections"
  save_connections
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
  
  for i in $(seq 0 $((${#system_array[@]}-1))); do
    local system_id=${system_array[$i]}
    
    # Get system name for better logging
    IFS=':' read -r _ system_name <<< "${EVE_SYSTEMS[$i]}"
    
    echo "Updating system $((i+1))/${#system_array[@]}: $system_name (ID: $system_id)"
    
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
  
  echo "Total systems updated: $update_count/${#system_array[@]}"
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
  
  local update_count=0
  local conn_array=($CREATED_CONNECTION_IDS)
  local system_array=($CREATED_SYSTEM_IDS)
  
  for i in $(seq 0 $((${#conn_array[@]}-1))); do
    local triple=${conn_array[$i]}
    local conn_id=$(echo $triple | cut -d: -f1)
    local source=$(echo $triple | cut -d: -f2)
    # Find the system name by source system ID
    local source_name="Unknown"
    for entry in "${EVE_SYSTEMS[@]}"; do
      IFS=':' read -r sys_id sys_name <<< "$entry"
      if [ "$sys_id" = "$source" ]; then
        source_name="$sys_name"
        break
      fi
    done
    echo "Updating connection $((i+1))/${#conn_array[@]} from $source_name"
    
    # Create update payload with new values
    local mass_values=(0 1 2 3)
    local ship_values=(0 1 2 3)
    local mass=${mass_values[$((RANDOM % 4))]}
    local ship=${ship_values[$((RANDOM % 4))]}
    
    local payload=$(jq -n \
      --argjson mass "$mass" \
      --argjson ship "$ship" \
      '{
        mass_status: $mass,
        ship_size_type: $ship,
        locked: false,
        custom_info: "Test update"
      }')
    
    # Send the update request
    local raw=$(make_request PATCH "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$source/connections/$conn_id" "$payload")
    local status_code=$(parse_status "$raw")
    
    if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Updated connection $conn_id with mass: $mass, ship: $ship"
      update_count=$((update_count+1))
    else
      echo "❌ Failed to update connection $conn_id. Status: $status_code"
      break
    fi
  done
  
  if [ $update_count -eq 0 ]; then
    echo "Connection updates might not be supported or require a different endpoint"
  else
    echo "Total connections updated: $update_count/${#conn_array[@]}"
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
  
  # Test listing all systems
  echo "Testing list all systems endpoint"
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  local status=$(parse_status "$raw")
  
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local response=$(parse_response "$raw")
    local system_count=0
    
    if echo "$response" | jq -e '.data' &>/dev/null; then
      system_count=$(echo "$response" | jq '.data | length')
    else
      system_count=$(echo "$response" | jq 'length')
    fi
    
    echo "✅ Listed $system_count systems"
    [[ "$VERBOSE" == "true" ]] && echo "$(echo "$response" | jq '.')"
  else
    echo "❌ Failed to list systems. Status: $status"
  fi
  
  # Test listing connections for first system
  local first_system=$(echo "$CREATED_SYSTEM_IDS" | tr ' ' '\n' | head -n 1)
  if [ -n "$first_system" ]; then
    echo "Testing connections for system $first_system"
    local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$first_system/connections")
    local status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      local response=$(parse_response "$raw")
      local conn_count=0
      
      if echo "$response" | jq -e '.data' &>/dev/null; then
        conn_count=$(echo "$response" | jq '.data | length')
      else
        conn_count=$(echo "$response" | jq 'length')
      fi
      
      echo "✅ Listed $conn_count connections for system $first_system"
      [[ "$VERBOSE" == "true" ]] && echo "$(echo "$response" | jq '.')"
    else
      echo "❌ Failed to list connections. Status: $status"
    fi
  fi
  
  # Test getting details for a single system
  if [ -n "$first_system" ]; then
    echo "Testing get single system details for $first_system"
    local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$first_system")
    local status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Retrieved system details for $first_system"
      [[ "$VERBOSE" == "true" ]] && echo "$(parse_response "$raw" | jq '.')"
    else
      echo "❌ Failed to get system details. Status: $status"
    fi
  fi
}

# FUNCTION: Delete connections and systems
delete_everything() {
  echo "==== Deleting Connections and Systems ===="
  load_connections
  load_systems
  
  # Delete connections first
  if [ -n "$CREATED_CONNECTION_IDS" ]; then
    echo "Deleting connections..."
    local delete_count=0
    local conn_array=($CREATED_CONNECTION_IDS)
    local system_array=($CREATED_SYSTEM_IDS)
    
    for i in $(seq 0 $((${#conn_array[@]}-1))); do
      local triple=${conn_array[$i]}
      local conn_id=$(echo $triple | cut -d: -f1)
      local source=$(echo $triple | cut -d: -f2)
      
      echo "Deleting connection $((i+1))/${#conn_array[@]}: $conn_id"
      
      # Make delete request
      local raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$source/connections/$conn_id")
      local status=$(parse_status "$raw")
      
      if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
        echo "✅ Deleted connection $conn_id"
        delete_count=$((delete_count+1))
      else
        echo "❌ Failed to delete connection $conn_id. Status: $status"
      fi
    done
    
    echo "Total connections deleted: $delete_count/${#conn_array[@]}"
    # Clear the connections file
    > "$CONNECTIONS_FILE"
    CREATED_CONNECTION_IDS=""
  else
    echo "No connections to delete"
  fi
  
  # Then delete systems
  if [ -n "$CREATED_SYSTEM_IDS" ]; then
    echo "Deleting systems..."
    
    # First try batch delete
    echo "Attempting batch delete of systems..."
    local system_array=($CREATED_SYSTEM_IDS)
    
    # Create batch delete payload
    local payload=$(jq -n \
      --argjson systems "$(echo "$CREATED_SYSTEM_IDS" | tr ' ' '\n' | jq -R . | jq -s .)" \
      '{system_ids: $systems}')
    
    local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems/batch_delete" "$payload")
    local status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      local response=$(parse_response "$raw")
      local deleted_count=0
      
      if echo "$response" | jq -e '.data.deleted_count' &>/dev/null; then
        deleted_count=$(echo "$response" | jq '.data.deleted_count')
      elif echo "$response" | jq -e '.deleted_count' &>/dev/null; then
        deleted_count=$(echo "$response" | jq '.deleted_count')
      fi
      
      echo "✅ Batch deleted $deleted_count/${#system_array[@]} systems"
      # Clear the systems file
      > "$SYSTEMS_FILE"
      CREATED_SYSTEM_IDS=""
    else
      echo "❌ Batch delete failed. Status: $status"
      
      # Fall back to individual deletes
      echo "Falling back to individual system deletions..."
      local delete_count=0
      
      for system_id in ${system_array[@]}; do
        echo "Deleting system $system_id..."
        
        # Make delete request
        local raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$system_id")
        local status=$(parse_status "$raw")
        
        if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
          echo "System $system_id no longer found (deletion worked)"
          delete_count=$((delete_count+1))
        else
          echo "⚠️ Failed to delete system $system_id. Status: $status"
        fi
      done
      
      echo "Total systems deleted: $delete_count/${#system_array[@]}"
      # Clear the systems file
      > "$SYSTEMS_FILE"
      CREATED_SYSTEM_IDS=""
    fi
  else
    echo "No systems to delete"
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