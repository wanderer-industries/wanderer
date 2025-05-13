#!/bin/bash
# test/manual/api/backup_restore_test.sh
# ─── Backup and Restore Test for Map Systems and Connections ────────────────────────
#
# Usage:
#   ./backup_restore_test.sh          # Run with default settings
#   ./backup_restore_test.sh -v       # Run in verbose mode
#   ./backup_restore_test.sh -h       # Show help
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
      echo "Usage: $0 [-v] [-h]"
      echo "  -v  Verbose mode (show detailed output)"
      echo "  -h  Show this help message"
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

# File to store backup data
BACKUP_FILE="/tmp/wanderer_map_backup.json"

# ─── UTILITY FUNCTIONS ─────────────────────────────────────────────────────

# Function to backup current map state
backup_map_state() {
  echo "==== Backing Up Map State ===="
  
  echo "Fetching current map state..."
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  local status=$(parse_status "$raw")
  
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local response=$(parse_response "$raw")
    echo "$response" > "$BACKUP_FILE"
    
    local system_count=$(echo "$response" | jq '.data.systems | length')
    local conn_count=$(echo "$response" | jq '.data.connections | length')
    
    echo "✅ Backed up $system_count systems and $conn_count connections to $BACKUP_FILE"
    [[ "$VERBOSE" == "true" ]] && echo "Backup data:" && cat "$BACKUP_FILE" | jq '.'
    return 0
  else
    echo "❌ Failed to backup map state. Status: $status"
    return 1
  fi
}

# Function to delete all systems (which will cascade to connections)
delete_all() {
  echo "==== Deleting All Systems ===="
  
  # Get current systems
  local raw=$(make_request GET "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
  local status=$(parse_status "$raw")
  
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local response=$(parse_response "$raw")
    local system_ids=$(echo "$response" | jq -r '.data.systems[].solar_system_id')
    
    if [ -z "$system_ids" ]; then
      echo "No systems to delete."
      return 0
    fi
    
    # Convert system IDs to JSON array and create payload
    local system_ids_json=$(echo "$system_ids" | jq -R . | jq -s .)
    local payload=$(jq -n --argjson system_ids "$system_ids_json" '{system_ids: $system_ids}')
    
    # Send batch delete request
    local raw=$(make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$payload")
    local status=$(parse_status "$raw")
    
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      echo "✅ Successfully deleted all systems and their connections"
      return 0
    else
      echo "❌ Failed to delete systems. Status: $status"
      [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
      return 1
    fi
  else
    echo "❌ Failed to fetch systems for deletion. Status: $status"
    return 1
  fi
}

# Function to restore map state from backup
restore_map_state() {
  echo "==== Restoring Map State ===="
  
  if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ No backup file found at $BACKUP_FILE"
    return 1
  fi
  
  local backup_data=$(cat "$BACKUP_FILE")
  local systems=$(echo "$backup_data" | jq '.data.systems')
  local connections=$(echo "$backup_data" | jq '.data.connections')
  
  # Create payload for batch upsert
  local payload="{\"systems\": $systems, \"connections\": $connections}"
  
  # Send batch upsert request
  local raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems" "$payload")
  local status=$(parse_status "$raw")
  
  if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
    local response=$(parse_response "$raw")
    local systems_created=$(echo "$response" | jq '.data.systems.created')
    local systems_updated=$(echo "$response" | jq '.data.systems.updated')
    local conns_created=$(echo "$response" | jq '.data.connections.created')
    local conns_updated=$(echo "$response" | jq '.data.connections.updated')
    
    echo "✅ Restore successful:"
    echo "   Systems: $systems_created created, $systems_updated updated"
    echo "   Connections: $conns_created created, $conns_updated updated"
    return 0
  else
    echo "❌ Failed to restore map state. Status: $status"
    [[ "$VERBOSE" == "true" ]] && echo "Response: $(parse_response "$raw")"
    return 1
  fi
}

# ─── MAIN EXECUTION FLOW ─────────────────────────────────────────────────

echo "Starting backup/restore test sequence..."

# Step 1: Backup current state
backup_map_state || { echo "Backup failed, aborting."; exit 1; }

echo -e "\nBackup complete. Press Enter to proceed with deletion..."
read -r

# Step 2: Delete everything
delete_all || { echo "Deletion failed, aborting."; exit 1; }

echo -e "\nDeletion complete. Press Enter to proceed with restore..."
read -r

# Step 3: Restore from backup
restore_map_state || { echo "Restore failed."; exit 1; }

echo -e "\nTest sequence completed."
exit 0 