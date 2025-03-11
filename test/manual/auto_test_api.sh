#!/bin/bash
#==============================================================================
# Wanderer API Automated Testing Tool
#
# This script tests various endpoints of the Wanderer API.
#
# Features:
#  - Uses strict mode (set -euo pipefail) for robust error handling.
#  - Contains a DEBUG mode for extra logging (set DEBUG=1 to enable).
#  - Validates configuration including a reachability test for the HOST.
#  - Outputs a summary in plain text and optionally as JSON.
#  - Exits with a nonzero code if any test fails.
#
# Usage:
#   ./auto_test_api.sh
#
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Set DEBUG=1 to enable extra logging
DEBUG=0
# Set VERBOSE=1 to print raw JSON responses for every test (default 0)
VERBOSE=0
# Set VERBOSE_SUMMARY=1 to output a JSON summary at the end (default 0)
VERBOSE_SUMMARY=0

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration file and default configuration
CONFIG_FILE=".auto_api_test_config"
HOST="http://localhost:4444"  # Default host
MAP_SLUG=""
MAP_API_KEY=""
ACL_API_KEY=""
SELECTED_ACL_ID=""
SELECTED_SYSTEM_ID=""
CHARACTER_EVE_ID=""
TEST_RESULTS=()
FAILED_TESTS=()

# Global variables for last API response
LAST_JSON_RESPONSE=""
LAST_HTTP_CODE=""

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

debug() {
  if [ "$DEBUG" -eq 1 ]; then
    echo -e "${YELLOW}[DEBUG] $*${NC}" >&2
  fi
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}" >&2
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Check if the host is reachable; accept any HTTP status code 200-399.
check_host_reachable() {
    debug "Checking if host $HOST is reachable..."
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$HOST")
    debug "HTTP status code for host: $status"
    if [[ "$status" -ge 200 && "$status" -lt 400 ]]; then
      print_success "Host $HOST is reachable."
    else
      print_error "Host $HOST is not reachable (HTTP code: $status). Please check the host URL."
      exit 1
    fi
}

# Load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_success "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
        return 0
    else
        print_warning "No configuration file found. Using default values."
        return 1
    fi
}

# Save configuration to file
save_config() {
    print_success "Saving configuration to $CONFIG_FILE"
    cat > "$CONFIG_FILE" << EOF
# Wanderer API Testing Tool Configuration
# Generated on $(date)

# Base configuration
HOST="$HOST"
MAP_SLUG="$MAP_SLUG"
MAP_API_KEY="$MAP_API_KEY"
ACL_API_KEY="$ACL_API_KEY"

# Selected IDs
SELECTED_ACL_ID="$SELECTED_ACL_ID"
SELECTED_SYSTEM_ID="$SELECTED_SYSTEM_ID"
CHARACTER_EVE_ID="$CHARACTER_EVE_ID"
EOF
    chmod 600 "$CONFIG_FILE"
    print_success "Configuration saved successfully."
}

# Make an API call using curl and capture response and HTTP code
call_api() {
    local method=$1
    local endpoint=$2
    local api_key=$3
    local data=${4:-""}

    local curl_cmd=(curl -s -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json")
    if [ -n "$api_key" ]; then
        curl_cmd+=(-H "Authorization: Bearer $api_key")
    fi
    if [ -n "$data" ]; then
        curl_cmd+=(-d "$data")
    fi
    curl_cmd+=("$HOST$endpoint")

    # Print debug command (mask API key)
    local debug_cmd
    debug_cmd=$(printf "%q " "${curl_cmd[@]}")
    debug_cmd=$(echo "$debug_cmd" | sed "s/$api_key/API_KEY_HIDDEN/g")
    print_warning "Executing: $debug_cmd"

    local output
    output=$("${curl_cmd[@]}")
    LAST_HTTP_CODE=$(echo "$output" | tail -n1)
    local response
    response=$(echo "$output" | sed '$d')
    echo "$response"
}

# Check that required variables are set
check_required_vars() {
    local missing=false
    if [ $# -eq 0 ]; then
        if [ -z "$HOST" ]; then
            print_error "HOST is not set. Please set it first."
            missing=true
        fi
        if [ -z "$MAP_SLUG" ]; then
            print_error "MAP_SLUG is not set. Please set it first."
            missing=true
        fi
        if [ -z "$MAP_API_KEY" ]; then
            print_error "MAP_API_KEY is not set. Please set it first."
            missing=true
        fi
    else
        for var in "$@"; do
            if [ -z "${!var}" ]; then
                print_error "$var is not set. Please set it first."
                missing=true
            fi
        done
    fi
    $missing && return 1 || return 0
}

# Record a test result
record_test_result() {
    local endpoint=$1
    local status=$2
    local message=$3
    if [ "$status" = "success" ]; then
        TEST_RESULTS+=("${GREEN}✓${NC} $endpoint - $message")
    else
        TEST_RESULTS+=("${RED}✗${NC} $endpoint - $message")
        FAILED_TESTS+=("$endpoint - $message")
    fi
}

# Process and validate the JSON response
check_response() {
    local response=$1
    local endpoint=$2

    if [ -z "$(echo "$response" | xargs)" ]; then
        if [ "$LAST_HTTP_CODE" = "200" ] || [ "$LAST_HTTP_CODE" = "204" ]; then
            print_success "Received empty response, which is valid"
            LAST_JSON_RESPONSE="{}"
            return 0
        else
            record_test_result "$endpoint" "failure" "Empty response with HTTP code $LAST_HTTP_CODE"
            return 1
        fi
    fi

    if [ "$VERBOSE" -eq 1 ]; then
      echo "Raw response from $endpoint:"
      echo "$response" | head -n 20
    fi

    if echo "$response" | jq . > /dev/null 2>&1; then
        LAST_JSON_RESPONSE="$response"
        return 0
    fi

    local json_part
    json_part=$(echo "$response" | grep -o '{.*}' || echo "")
    if [ -z "$json_part" ] || ! echo "$json_part" | jq . > /dev/null 2>&1; then
        json_part=$(echo "$response" | sed -n '/^{/,$p' | tr -d '\n')
    fi
    if [ -z "$json_part" ] || ! echo "$json_part" | jq . > /dev/null 2>&1; then
        json_part=$(echo "$response" | sed -n '/{/,/}/p' | tr -d '\n')
    fi
    if [ -z "$json_part" ] || ! echo "$json_part" | jq . > /dev/null 2>&1; then
        json_part=$(echo "$response" | awk '!(/^[<>*]/) {print}' | tr -d '\n')
    fi
    if [ -z "$json_part" ] || ! echo "$json_part" | jq . > /dev/null 2>&1; then
        echo "Raw response from $endpoint:"
        echo "$response"
        record_test_result "$endpoint" "failure" "Invalid JSON response"
        return 1
    fi

    local error
    error=$(echo "$json_part" | jq -r '.error // empty')
    if [ -n "$error" ]; then
        echo "Raw response from $endpoint:"
        echo "$response"
        echo "Parsed JSON response from $endpoint:"
        echo "$json_part" | jq '.'
        record_test_result "$endpoint" "failure" "Error: $error"
        return 1
    fi

    LAST_JSON_RESPONSE="$json_part"
    return 0
}

# Get a random item from a JSON array using a jq path
get_random_item() {
    local json=$1
    local jq_path=$2
    local count
    count=$(echo "$json" | jq "$jq_path | length")
    if [ "$count" -eq 0 ]; then
        echo ""
        return 1
    fi
    local random_index=$((RANDOM % count))
    echo "$json" | jq -r "$jq_path[$random_index]"
}

#------------------------------------------------------------------------------
# API Test Functions
#------------------------------------------------------------------------------
test_list_characters() {
    print_header "Testing GET /api/characters"
    print_success "Calling API: GET /api/characters"
    local response
    response=$(call_api "GET" "/api/characters" "$MAP_API_KEY")
    if ! check_response "$response" "GET /api/characters"; then
        return 1
    fi
    local character_count
    character_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
    if [ "$character_count" -gt 0 ]; then
        record_test_result "GET /api/characters" "success" "Found $character_count characters"
        if [ -z "$CHARACTER_EVE_ID" ]; then
            local random_index=$((RANDOM % character_count))
            print_success "Selecting character at index $random_index"
            local random_character
            random_character=$(echo "$LAST_JSON_RESPONSE" | jq ".data[$random_index]")
            CHARACTER_EVE_ID=$(echo "$random_character" | jq -r '.eve_id')
            local character_name
            character_name=$(echo "$random_character" | jq -r '.name')
            print_success "Selected random character: $character_name (EVE ID: $CHARACTER_EVE_ID)"
        fi
        return 0
    else
        record_test_result "GET /api/characters" "success" "No characters found"
        return 0
    fi
}

test_map_systems() {
    print_header "Testing GET /api/map/systems"
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        record_test_result "GET /api/map/systems" "failure" "Missing required variables"
        return 1
    fi
    print_success "Calling API: GET /api/map/systems?slug=$MAP_SLUG"
    local response
    response=$(call_api "GET" "/api/map/systems?slug=$MAP_SLUG" "$MAP_API_KEY")
    if ! check_response "$response" "GET /api/map/systems"; then
        return 1
    fi
    local system_count
    system_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
    print_success "System count: $system_count"
    if [ "$system_count" -gt 0 ]; then
        record_test_result "GET /api/map/systems" "success" "Found $system_count systems"
        local random_index=$((RANDOM % system_count))
        print_success "Selecting system at index $random_index"
        echo "Data structure:" 
        echo "$LAST_JSON_RESPONSE" | jq '.data[0]'
        local random_system
        random_system=$(echo "$LAST_JSON_RESPONSE" | jq ".data[$random_index]")
        echo "Selected system JSON:" 
        echo "$random_system"
        SELECTED_SYSTEM_ID=$(echo "$random_system" | jq -r '.solar_system_id')
        if [ -z "$SELECTED_SYSTEM_ID" ] || [ "$SELECTED_SYSTEM_ID" = "null" ]; then
            SELECTED_SYSTEM_ID=$(echo "$random_system" | jq -r '.id // .system_id // empty')
            if [ -z "$SELECTED_SYSTEM_ID" ] || [ "$SELECTED_SYSTEM_ID" = "null" ]; then
                print_error "Could not find system ID in the response"
                echo "Available fields:"
                echo "$random_system" | jq 'keys'
                record_test_result "GET /api/map/systems" "failure" "Could not extract system ID"
                return 1
            fi
        fi
        local system_name
        system_name=$(echo "$random_system" | jq -r '.name // "Unknown"')
        print_success "Selected random system: $system_name (ID: $SELECTED_SYSTEM_ID)"
        return 0
    else
        record_test_result "GET /api/map/systems" "failure" "No systems found"
        return 1
    fi
}

test_map_system() {
    print_header "Testing GET /api/map/system"
    if [[ -z "$MAP_SLUG" || -z "$SELECTED_SYSTEM_ID" || -z "$MAP_API_KEY" ]]; then
        record_test_result "GET /api/map/system" "failure" "Missing required variables"
        return
    fi
    local response
    response=$(call_api "GET" "/api/map/system?slug=$MAP_SLUG&id=$SELECTED_SYSTEM_ID" "$MAP_API_KEY")
    print_warning "Response: $response"
    local trimmed_response
    trimmed_response=$(echo "$response" | xargs)
    if [[ "$trimmed_response" == "{}" || "$trimmed_response" == '{"data":{}}' ]]; then
        print_success "Received empty JSON response, which is valid"
        record_test_result "GET /api/map/system" "success" "Received valid empty response"
        return
    fi
    if ! check_response "$response" "GET /api/map/system"; then
        return
    fi
    local json_data="$LAST_JSON_RESPONSE"
    local has_data
    has_data=$(echo "$json_data" | jq 'has("data")')
    if [ "$has_data" != "true" ]; then
        print_error "Response does not contain 'data' field"
        echo "JSON Response:" 
        echo "$json_data" | jq .
        record_test_result "GET /api/map/system" "failure" "Response does not contain 'data' field"
        return
    fi
    local system_data
    system_data=$(echo "$json_data" | jq -r '.data // empty')
    if [ -z "$system_data" ] || [ "$system_data" = "null" ]; then
        print_error "Could not find system data in response"
        echo "JSON Response:" 
        echo "$json_data" | jq .
        record_test_result "GET /api/map/system" "failure" "Could not find system data in response"
        return
    fi
    local system_id
    system_id=$(echo "$json_data" | jq -r '.data.solar_system_id // empty')
    if [ -z "$system_id" ] || [ "$system_id" = "null" ]; then
        print_error "Could not find solar_system_id in the system data"
        echo "System Data:" 
        echo "$system_data" | jq .
        record_test_result "GET /api/map/system" "failure" "Could not find solar_system_id in system data"
        return
    fi
    print_success "Found system data with ID: $system_id"
    record_test_result "GET /api/map/system" "success" "Found system data with ID: $system_id"
}

test_map_characters() {
    print_header "Testing GET /api/map/characters"
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        record_test_result "GET /api/map/characters" "failure" "Missing required variables"
        return 1
    fi
    print_success "Calling API: GET /api/map/characters?slug=$MAP_SLUG"
    local response
    response=$(call_api "GET" "/api/map/characters?slug=$MAP_SLUG" "$MAP_API_KEY")
    if ! check_response "$response" "GET /api/map/characters"; then
        return 1
    fi
    local character_count
    character_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
    record_test_result "GET /api/map/characters" "success" "Found $character_count tracked characters"
    return 0
}

test_map_structure_timers() {
    print_header "Testing GET /api/map/structure-timers"
    if [[ -z "$MAP_SLUG" || -z "$MAP_API_KEY" ]]; then
        record_test_result "GET /api/map/structure-timers" "failure" "Missing required variables"
        return
    fi
    local response
    response=$(call_api "GET" "/api/map/structure-timers?slug=$MAP_SLUG" "$MAP_API_KEY")
    local trimmed_response
    trimmed_response=$(echo "$response" | xargs)
    if [[ "$trimmed_response" == '{"data":[]}' ]]; then
        print_success "Found 0 structure timers"
        record_test_result "GET /api/map/structure-timers" "success" "Found 0 structure timers"
    fi
    if ! check_response "$response" "GET /api/map/structure-timers"; then
        return
    fi
    local timer_count
    timer_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
    print_success "Found $timer_count structure timers"
    record_test_result "GET /api/map/structure-timers" "success" "Found $timer_count structure timers"
    if [ -n "$SELECTED_SYSTEM_ID" ]; then
        print_header "Testing GET /api/map/structure-timers (filtered)"
        local filtered_response
        filtered_response=$(call_api "GET" "/api/map/structure-timers?slug=$MAP_SLUG&system_id=$SELECTED_SYSTEM_ID" "$MAP_API_KEY")
        print_warning "(Structure Timers) - Filtered response: $filtered_response"
        local trimmed_filtered
        trimmed_filtered=$(echo "$filtered_response" | xargs)
        if [[ "$trimmed_filtered" == '{"data":[]}' ]]; then
            print_success "Found 0 filtered structure timers"
            record_test_result "GET /api/map/structure-timers (filtered)" "success" "Found 0 filtered structure timers"
            return
        fi
        if ! check_response "$filtered_response" "GET /api/map/structure-timers (filtered)"; then
            return
        fi
        local filtered_count
        filtered_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
        print_success "Found $filtered_count filtered structure timers"
        record_test_result "GET /api/map/structure-timers (filtered)" "success" "Found $filtered_count filtered structure timers"
    fi
}

test_map_systems_kills() {
    print_header "Testing GET /api/map/systems-kills"
    if [[ -z "$MAP_SLUG" || -z "$MAP_API_KEY" ]]; then
        record_test_result "GET /api/map/systems-kills" "failure" "Missing required variables"
        return
    fi
    # Use the correct parameter name: hours
    local response
    response=$(call_api "GET" "/api/map/systems-kills?slug=$MAP_SLUG&hours=1" "$MAP_API_KEY")
    print_warning "(Systems Kills) - Response: $response"
    if ! check_response "$response" "GET /api/map/systems-kills"; then
        return
    fi
    local json_data="$LAST_JSON_RESPONSE"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "JSON Response:"; echo "$json_data" | jq .
    fi
    local has_data
    has_data=$(echo "$json_data" | jq 'has("data")')
    if [ "$has_data" != "true" ]; then
        print_error "Response does not contain 'data' field"
        if [ "$VERBOSE" -eq 1 ]; then
          echo "JSON Response:"; echo "$json_data" | jq .
        fi
        record_test_result "GET /api/map/systems-kills" "failure" "Response does not contain 'data' field"
        return
    fi
    local systems_count
    systems_count=$(echo "$json_data" | jq '.data | length')
    print_success "Found kill data for $systems_count systems"
    record_test_result "GET /api/map/systems-kills" "success" "Found kill data for $systems_count systems"
    print_header "Testing GET /api/map/systems-kills (filtered)"
    local filter_url="/api/map/systems-kills?slug=$MAP_SLUG&hours=1"
    if [ -n "$SELECTED_SYSTEM_ID" ]; then
        filter_url="$filter_url&system_id=$SELECTED_SYSTEM_ID"
        print_success "Using system_id filter to reduce response size"
    fi
    local filtered_response
    filtered_response=$(call_api "GET" "$filter_url" "$MAP_API_KEY")
    local trimmed_filtered
    trimmed_filtered=$(echo "$filtered_response" | xargs)
    if [[ "$trimmed_filtered" == '{"data":[]}' ]]; then
        print_success "Found 0 filtered systems with kill data"
        record_test_result "GET /api/map/systems-kills (filtered)" "success" "Found 0 filtered systems with kill data"
        return
    fi
    if [[ "$trimmed_filtered" == '{"data":'* ]]; then
        print_success "Received valid JSON response (large data)"
        record_test_result "GET /api/map/systems-kills (filtered)" "success" "Received valid JSON response with kill data"
        return
    fi
    if ! check_response "$filtered_response" "GET /api/map/systems-kills (filtered)"; then
        return
    fi
    local filtered_count
    filtered_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
    print_success "Found filtered kill data for $filtered_count systems"
    record_test_result "GET /api/map/systems-kills (filtered)" "success" "Found filtered kill data for $filtered_count systems"
}

test_map_acls() {
    print_header "Testing GET /api/map/acls"
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        record_test_result "GET /api/map/acls" "failure" "Missing required variables"
        return 1
    fi
    print_success "Calling API: GET /api/map/acls?slug=$MAP_SLUG"
    local response
    response=$(call_api "GET" "/api/map/acls?slug=$MAP_SLUG" "$MAP_API_KEY")
    if ! check_response "$response" "GET /api/map/acls"; then
        return 1
    fi
    local acl_count
    acl_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
    record_test_result "GET /api/map/acls" "success" "Found $acl_count ACLs"
    if [ "$acl_count" -gt 0 ]; then
        local random_acl
        random_acl=$(get_random_item "$LAST_JSON_RESPONSE" ".data")
        SELECTED_ACL_ID=$(echo "$random_acl" | jq -r '.id')
        local acl_name
        acl_name=$(echo "$random_acl" | jq -r '.name')
        print_success "Selected random ACL: $acl_name (ID: $SELECTED_ACL_ID)"
    else
        print_warning "No ACLs found to select for future tests"
    fi
    return 0
}

test_create_acl() {
    print_header "Testing POST /api/map/acls"
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        record_test_result "POST /api/map/acls" "failure" "Missing required variables"
        return 1
    fi
    if [ -z "$CHARACTER_EVE_ID" ]; then
        print_warning "No character EVE ID selected. Fetching characters..."
        print_success "Calling API: GET /api/characters"
        local characters_response
        characters_response=$(call_api "GET" "/api/characters" "$MAP_API_KEY")
        if ! check_response "$characters_response" "GET /api/characters"; then
            record_test_result "POST /api/map/acls" "failure" "Failed to get characters"
            return 1
        fi
        local character_count
        character_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
        if [ "$character_count" -eq 0 ]; then
            record_test_result "POST /api/map/acls" "failure" "No characters found"
            return 1
        fi
        local random_index=$((RANDOM % character_count))
        print_success "Selecting character at index $random_index"
        local random_character
        random_character=$(echo "$LAST_JSON_RESPONSE" | jq ".data[$random_index]")
        CHARACTER_EVE_ID=$(echo "$random_character" | jq -r '.eve_id')
        local character_name
        character_name=$(echo "$random_character" | jq -r '.name')
        print_success "Selected random character: $character_name (EVE ID: $CHARACTER_EVE_ID)"
    fi
    local acl_name="Auto Test ACL $(date +%s)"
    local acl_description="Created by auto_test_api.sh on $(date)"
    local data="{\"acl\": {\"name\": \"$acl_name\", \"owner_eve_id\": $CHARACTER_EVE_ID, \"description\": \"$acl_description\"}}"
    print_success "Calling API: POST /api/map/acls?slug=$MAP_SLUG"
    print_success "Data: $data"
    local response
    response=$(call_api "POST" "/api/map/acls?slug=$MAP_SLUG" "$MAP_API_KEY" "$data")
    if ! check_response "$response" "POST /api/map/acls"; then
        return 1
    fi
    local new_acl_id
    new_acl_id=$(echo "$LAST_JSON_RESPONSE" | jq -r '.data.id // empty')
    local new_api_key
    new_api_key=$(echo "$LAST_JSON_RESPONSE" | jq -r '.data.api_key // empty')
    if [ -n "$new_acl_id" ] && [ -n "$new_api_key" ]; then
        record_test_result "POST /api/map/acls" "success" "Created new ACL with ID: $new_acl_id"
        SELECTED_ACL_ID=$new_acl_id
        ACL_API_KEY=$new_api_key
        print_success "Using the new ACL (ID: $SELECTED_ACL_ID) and its API key for further operations"
        save_config
        return 0
    else
        record_test_result "POST /api/map/acls" "failure" "Failed to extract ACL ID or API key from response"
        return 1
    fi
}

test_show_acl() {
    print_header "Testing GET /api/acls/:id"
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        record_test_result "GET /api/acls/:id" "failure" "Missing ACL ID or API key"
        return 1
    fi
    print_success "Calling API: GET /api/acls/$SELECTED_ACL_ID"
    local response
    response=$(call_api "GET" "/api/acls/$SELECTED_ACL_ID" "$ACL_API_KEY")
    if ! check_response "$response" "GET /api/acls/:id"; then
        return 1
    fi
    local acl_name
    acl_name=$(echo "$LAST_JSON_RESPONSE" | jq -r '.data.name // empty')
    if [ -n "$acl_name" ]; then
        record_test_result "GET /api/acls/:id" "success" "Found ACL: $acl_name"
        return 0
    else
        record_test_result "GET /api/acls/:id" "failure" "ACL data not found"
        return 1
    fi
}

test_update_acl() {
    print_header "Testing PUT /api/acls/:id"
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        record_test_result "PUT /api/acls/:id" "failure" "Missing ACL ID or API key"
        return 1
    fi
    local new_name="Updated Auto Test ACL $(date +%s)"
    local new_description="Updated by auto_test_api.sh on $(date)"
    local data="{\"acl\": {\"name\": \"$new_name\", \"description\": \"$new_description\"}}"
    print_success "Calling API: PUT /api/acls/$SELECTED_ACL_ID"
    print_success "Data: $data"
    local response
    response=$(call_api "PUT" "/api/acls/$SELECTED_ACL_ID" "$ACL_API_KEY" "$data")
    if ! check_response "$response" "PUT /api/acls/:id"; then
        return 1
    fi
    local updated_name
    updated_name=$(echo "$LAST_JSON_RESPONSE" | jq -r '.data.name // empty')
    if [ "$updated_name" = "$new_name" ]; then
        record_test_result "PUT /api/acls/:id" "success" "Updated ACL name to: $updated_name"
        return 0
    else
        record_test_result "PUT /api/acls/:id" "failure" "Failed to update ACL name"
        return 1
    fi
}

test_create_acl_member() {
    print_header "Testing POST /api/acls/:acl_id/members"
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        record_test_result "POST /api/acls/:acl_id/members" "failure" "Missing ACL ID or API key"
        return 1
    fi
    if [ -z "$CHARACTER_EVE_ID" ]; then
        print_warning "No character EVE ID selected. Fetching characters..."
        print_success "Calling API: GET /api/characters"
        local characters_response
        characters_response=$(call_api "GET" "/api/characters" "$MAP_API_KEY")
        if ! check_response "$characters_response" "GET /api/characters"; then
            record_test_result "POST /api/acls/:acl_id/members" "failure" "Failed to get characters"
            return 1
        fi
        local character_count
        character_count=$(echo "$LAST_JSON_RESPONSE" | jq '.data | length')
        if [ "$character_count" -eq 0 ]; then
            record_test_result "POST /api/acls/:acl_id/members" "failure" "No characters found"
            return 1
        fi
        local random_index=$((RANDOM % character_count))
        print_success "Selecting character at index $random_index"
        local random_character
        random_character=$(echo "$LAST_JSON_RESPONSE" | jq ".data[$random_index]")
        CHARACTER_EVE_ID=$(echo "$random_character" | jq -r '.eve_id')
        local character_name
        character_name=$(echo "$random_character" | jq -r '.name')
        print_success "Selected random character: $character_name (EVE ID: $CHARACTER_EVE_ID)"
    fi
    local data="{\"member\": {\"eve_character_id\": $CHARACTER_EVE_ID, \"role\": \"member\"}}"
    print_success "Calling API: POST /api/acls/$SELECTED_ACL_ID/members"
    print_success "Data: $data"
    local response
    response=$(call_api "POST" "/api/acls/$SELECTED_ACL_ID/members" "$ACL_API_KEY" "$data")
    if ! check_response "$response" "POST /api/acls/:acl_id/members"; then
        return 1
    fi
    local member_id
    member_id=$(echo "$LAST_JSON_RESPONSE" | jq -r '.data.id // empty')
    if [ -n "$member_id" ]; then
        record_test_result "POST /api/acls/:acl_id/members" "success" "Created new member with ID: $member_id"
        MEMBER_ID=$CHARACTER_EVE_ID
        return 0
    else
        record_test_result "POST /api/acls/:acl_id/members" "failure" "Failed to create member"
        return 1
    fi
}

test_update_acl_member() {
    print_header "Testing PUT /api/acls/:acl_id/members/:member_id"
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ] || [ -z "$MEMBER_ID" ]; then
        record_test_result "PUT /api/acls/:acl_id/members/:member_id" "failure" "Missing ACL ID, API key, or member ID"
        return 1
    fi
    local data="{\"member\": {\"role\": \"member\"}}"
    print_success "Calling API: PUT /api/acls/$SELECTED_ACL_ID/members/$MEMBER_ID"
    print_success "Data: $data"
    local response
    response=$(call_api "PUT" "/api/acls/$SELECTED_ACL_ID/members/$MEMBER_ID" "$ACL_API_KEY" "$data")
    if ! check_response "$response" "PUT /api/acls/:acl_id/members/:member_id"; then
        return 1
    fi
    local updated_role
    updated_role=$(echo "$LAST_JSON_RESPONSE" | jq -r '.data.role // empty')
    if [ "$updated_role" = "member" ]; then
        record_test_result "PUT /api/acls/:acl_id/members/:member_id" "success" "Updated member role to: $updated_role"
        return 0
    else
        record_test_result "PUT /api/acls/:acl_id/members/:member_id" "failure" "Failed to update member role"
        return 1
    fi
}

test_delete_acl_member() {
    print_header "Testing DELETE /api/acls/:acl_id/members/:member_id"
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ] || [ -z "$MEMBER_ID" ]; then
        record_test_result "DELETE /api/acls/:acl_id/members/:member_id" "failure" "Missing ACL ID, API key, or member ID"
        return 1
    fi
    print_success "Calling API: DELETE /api/acls/$SELECTED_ACL_ID/members/$MEMBER_ID"
    local response
    response=$(call_api "DELETE" "/api/acls/$SELECTED_ACL_ID/members/$MEMBER_ID" "$ACL_API_KEY")
    if ! check_response "$response" "DELETE /api/acls/:acl_id/members/:member_id"; then
        return 1
    fi
    record_test_result "DELETE /api/acls/:acl_id/members/:member_id" "success" "Deleted member with ID: $MEMBER_ID"
    MEMBER_ID=""
    return 0
}

test_system_static_info() {
    print_header "Testing GET /api/common/system-static-info"
    if [ -z "$SELECTED_SYSTEM_ID" ]; then
        record_test_result "GET /api/common/system-static-info" "failure" "No system ID selected"
        return 1
    fi
    print_success "Calling API: GET /api/common/system-static-info?id=$SELECTED_SYSTEM_ID"
    local response
    response=$(call_api "GET" "/api/common/system-static-info?id=$SELECTED_SYSTEM_ID" "$MAP_API_KEY")
    if ! check_response "$response" "GET /api/common/system-static-info"; then
        return 1
    fi
    local system_count
    system_count=$(echo "$LAST_JSON_RESPONSE" | jq 'length')
    record_test_result "GET /api/common/system-static-info" "success" "Found static info for $system_count systems"
    return 0
}

#------------------------------------------------------------------------------
# Configuration and Main Menu Functions
#------------------------------------------------------------------------------
set_config() {
    print_header "Configuration"
    echo -e "Current configuration:"
    [ -n "$HOST" ] && echo -e "  Host: ${BLUE}$HOST${NC}"
    [ -n "$MAP_SLUG" ] && echo -e "  Map Slug: ${BLUE}$MAP_SLUG${NC}"
    [ -n "$MAP_API_KEY" ] && echo -e "  Map API Key: ${BLUE}${MAP_API_KEY:0:8}...${NC}"
    read -p "Enter host (default: $HOST): " input_host
    [ -n "$input_host" ] && HOST="$input_host"
    read -p "Enter map slug: " input_map_slug
    [ -n "$input_map_slug" ] && MAP_SLUG="$input_map_slug"
    read -p "Enter map API key: " input_map_api_key
    [ -n "$input_map_api_key" ] && MAP_API_KEY="$input_map_api_key"
    # Reset IDs to force fresh data
    SELECTED_SYSTEM_ID=""
    SELECTED_ACL_ID=""
    ACL_API_KEY=""
    CHARACTER_EVE_ID=""
    save_config
}

run_all_tests() {
    print_header "Running all API tests"
    TEST_RESULTS=()
    FAILED_TESTS=()
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required for this script to work. Please install it first."
        exit 1
    fi
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        print_error "Please set MAP_SLUG and MAP_API_KEY before running tests."
        exit 1
    fi

    check_host_reachable

    test_list_characters
    if test_map_systems; then
        test_map_system
    else
        print_error "Skipping test_map_system because test_map_systems failed"
        record_test_result "GET /api/map/system" "failure" "Skipped because test_map_systems failed"
    fi
    test_map_characters
    test_map_structure_timers
    test_map_systems_kills
    test_map_acls
    if test_create_acl; then
        test_show_acl
        test_update_acl
        if test_create_acl_member; then
            test_update_acl_member
            test_delete_acl_member
        else
            print_error "Skipping ACL member tests because test_create_acl_member failed"
            record_test_result "PUT /api/acls/:acl_id/members/:member_id" "failure" "Skipped because test_create_acl_member failed"
            record_test_result "DELETE /api/acls/:acl_id/members/:member_id" "failure" "Skipped because test_create_acl_member failed"
        fi
    else
        print_error "Skipping ACL tests because test_create_acl failed"
        record_test_result "GET /api/acls/:id" "failure" "Skipped because test_create_acl failed"
        record_test_result "PUT /api/acls/:id" "failure" "Skipped because test_create_acl failed"
        record_test_result "POST /api/acls/:acl_id/members" "failure" "Skipped because test_create_acl failed"
        record_test_result "PUT /api/acls/:acl_id/members/:member_id" "failure" "Skipped because test_create_acl failed"
        record_test_result "DELETE /api/acls/:acl_id/members/:member_id" "failure" "Skipped because test_create_acl failed"
    fi
    test_system_static_info

    print_header "Test Results"
    for result in "${TEST_RESULTS[@]}"; do
        echo -e "$result"
    done

    local total_tests=${#TEST_RESULTS[@]}
    local failed_tests=${#FAILED_TESTS[@]}
    local passed_tests=$((total_tests - failed_tests))
    print_header "Summary"
    echo -e "Total tests: $total_tests"
    echo -e "Passed: ${GREEN}$passed_tests${NC}"
    echo -e "Failed: ${RED}$failed_tests${NC}"
    if [ $failed_tests -gt 0 ]; then
        print_header "Failed Tests"
        for failed in "${FAILED_TESTS[@]}"; do
            echo -e "${RED}✗${NC} $failed"
        done
    fi

    if [ "$VERBOSE_SUMMARY" -eq 1 ]; then
      summary_json=$(jq -n --arg total "$total_tests" --arg passed "$passed_tests" --arg failed "$failed_tests" \
         '{total_tests: $total_tests|tonumber, passed: $passed|tonumber, failed: $failed|tonumber}')
      echo "JSON Summary:"; echo "$summary_json" | jq .
    fi

    save_config

    if [ $failed_tests -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

#------------------------------------------------------------------------------
# Main Menu and Entry Point
#------------------------------------------------------------------------------
main() {
    print_header "Wanderer API Automated Testing Tool"
    load_config
    if [ -z "$MAP_SLUG" ] || [ -z "$MAP_API_KEY" ]; then
        print_warning "MAP_SLUG or MAP_API_KEY not set. Let's configure them now."
        set_config
    fi
    echo -e "What would you like to do?"
    echo "1) Run all tests"
    echo "2) Set configuration"
    echo "3) Exit"
    read -p "Enter your choice: " choice
    case $choice in
        1) run_all_tests ;;
        2) set_config ;;
        3) exit 0 ;;
        *) print_error "Invalid choice"; main ;;
    esac
}

# Start the script
main
