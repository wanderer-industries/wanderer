#!/bin/bash
set -eu

# ─── Dependencies ─────────────────────────────────────────────────────────────
for cmd in curl jq; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "Error: '$cmd' is required" >&2
    exit 1
  fi
done


# ─── Load .env if present ─────────────────────────────────────────────────────
load_env_file() {
  echo "📄 Loading env file: $1"
  set -o allexport
  source "$1"
  set +o allexport
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
  load_env_file "$SCRIPT_DIR/.env"
fi

# Check if API_TOKEN is set
: "${API_TOKEN:?Error: API_TOKEN environment variable not set}"

# ─── HTTP Request Helper ──────────────────────────────────────────────────────
make_request() {
  local method=$1 url=$2 data=${3:-}
  local curl_cmd=(curl -s -w $'\n%{http_code}' -H "Authorization: Bearer $API_TOKEN")

  if [ "$method" != "GET" ]; then
    curl_cmd+=(-X "$method" -H "Content-Type: application/json")
  fi

  if [ -n "$data" ]; then
    curl_cmd+=(-d "$data")
  fi

  "${curl_cmd[@]}" "$url"
}

# ─── Response Parsers ─────────────────────────────────────────────────────────
parse_response() {   # strips the final newline+status line
  local raw="$1"
  echo "${raw%$'\n'*}"
}

parse_status() {     # returns only the status code (last line)
  local raw="$1"
  echo "${raw##*$'\n'}"
}

# ─── Assertion Helper ─────────────────────────────────────────────────────────
verify_http_code() {
  local got=$1 want=$2 label=$3
  if [ "$got" -eq "$want" ]; then
    return 0
  else
    echo "🚫 $label: expected HTTP $want, got $got" >&2
    return 1
  fi
}

# ─── Test Runner & Summary ────────────────────────────────────────────────────
# Only initialize counters once to accumulate across multiple suite sources
if [ -z "${TOTAL_TESTS+x}" ]; then
  TOTAL_TESTS=0
  PASSED_TESTS=0
  FAILED_TESTS=0
  FAILED_LIST=""
fi

run_test() {
  local label=$1 fn=$2
  TOTAL_TESTS=$((TOTAL_TESTS+1))
  if "$fn"; then
    echo "✅ $label"
    PASSED_TESTS=$((PASSED_TESTS+1))
  else
    echo "❌ $label"
    FAILED_TESTS=$((FAILED_TESTS+1))
    FAILED_LIST="$FAILED_LIST $label"
  fi
}

# ─── Cleanup on Exit ──────────────────────────────────────────────────────────
CREATED_SYSTEM_IDS=""
CREATED_CONNECTION_IDS=""

cleanup_map_systems() {
  # First delete connections
  if [ -n "$CREATED_CONNECTION_IDS" ]; then
    echo "Cleaning up connections..."
    for conn_id in $CREATED_CONNECTION_IDS; do
      # Try with a direct DELETE request to the connection endpoint
      make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/connections/$conn_id" > /dev/null 2>&1 || true
    done
  fi
  
  # Then delete systems
  if [ -n "$CREATED_SYSTEM_IDS" ]; then
    echo "Cleaning up systems..."
    
    # First try batch delete if we have multiple systems
    if [ $(echo "$CREATED_SYSTEM_IDS" | wc -w) -gt 1 ]; then
      echo "Attempting batch delete of systems..."
      
      # Use the official batch_delete endpoint
      local payload=$(echo "$CREATED_SYSTEM_IDS" | tr ' ' '\n' | jq -R . | jq -s '{system_ids: .}')
      local raw
      raw=$(make_request POST "$API_BASE_URL/api/maps/$MAP_SLUG/systems/batch_delete" "$payload" 2>/dev/null) || true
      
      # Check if batch delete was successful by looking for systems
      sleep 1
      local success=1
      
      for sys_id in $CREATED_SYSTEM_IDS; do
        # Check if system still exists and is visible
        local check=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
        if echo "$check" | grep -q "\"solar_system_id\":$sys_id"; then
          if echo "$check" | grep -q "\"solar_system_id\":$sys_id.*\"visible\":true"; then
            success=0
          else
            echo "System $sys_id exists but is not visible (batch delete worked)"
          fi
        else
          echo "System $sys_id no longer found (batch delete worked)"
        fi
      done
      
      # If batch delete was successful for all systems, we're done
      if [ $success -eq 1 ]; then
        echo "✅ Batch delete successful for all systems"
        return 0
      fi
    fi
    
    # If batch delete failed or we have only one system, try individual deletes
    echo "Performing individual system deletions..."
    
    for sys_id in $CREATED_SYSTEM_IDS; do
      echo "Deleting system $sys_id..."
      
      # Try standard DELETE request
      make_request DELETE "$API_BASE_URL/api/maps/$MAP_SLUG/systems/$sys_id" > /dev/null 2>&1 || true
      
      # Verify the system was deleted or at least made invisible
      sleep 1
      local check=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$API_BASE_URL/api/maps/$MAP_SLUG/systems")
      
      if echo "$check" | grep -q "\"solar_system_id\":$sys_id"; then
        if echo "$check" | grep -q "\"solar_system_id\":$sys_id.*\"visible\":true"; then
          echo "⚠️ System $sys_id is still visible after all deletion attempts"
        else
          echo "System $sys_id exists but is not visible (deletion worked)"
        fi
      else
        echo "System $sys_id no longer found (deletion worked)"
      fi
    done
  fi
}
#trap cleanup_map_systems EXIT
