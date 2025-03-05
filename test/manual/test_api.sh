#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE=".api_test_config"

# Configuration
HOST="http://localhost:4000"  # Default host
MAP_SLUG=""
MAP_API_KEY=""
ACL_API_KEY=""
SELECTED_ACL_ID=""
SELECTED_SYSTEM_ID=""
CHARACTER_EVE_ID=""

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Function to load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_success "Loading configuration from $CONFIG_FILE"
        # Source the config file to load variables
        source "$CONFIG_FILE"
        return 0
    else
        print_warning "No configuration file found. Using default values."
        return 1
    fi
}

# Function to save configuration to file
save_config() {
    print_success "Saving configuration to $CONFIG_FILE"
    
    # Create or overwrite the config file
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
    
    # Make the config file readable only by the owner
    chmod 600 "$CONFIG_FILE"
    
    print_success "Configuration saved successfully."
}

# Function to make API calls
call_api() {
    local method=$1
    local endpoint=$2
    local api_key=$3
    local data=$4
    
    local curl_cmd="curl -s -X $method"
    
    # Add headers
    curl_cmd+=" -H 'Content-Type: application/json'"
    if [ ! -z "$api_key" ]; then
        curl_cmd+=" -H 'Authorization: Bearer $api_key'"
    fi
    
    # Add data if provided
    if [ ! -z "$data" ]; then
        curl_cmd+=" -d '$data'"
    fi
    
    # Add URL
    curl_cmd+=" $HOST$endpoint"
    
    # Execute and format with jq if available
    if command -v jq &> /dev/null; then
        eval "$curl_cmd" | jq
    else
        eval "$curl_cmd"
    fi
}

# Function to check if required variables are set
check_required_vars() {
    local missing=false
    
    if [ $# -eq 0 ]; then
        # Default checks if no parameters provided
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
        # Check specific variables passed as parameters
        for var in "$@"; do
            if [ -z "${!var}" ]; then
                print_error "$var is not set. Please set it first."
                missing=true
            fi
        done
    fi
    
    if $missing; then
        return 1
    fi
    
    return 0
}

# Function to set configuration
set_config() {
    print_header "Configuration"
    
    echo -e "Current configuration:"
    if [ ! -z "$HOST" ]; then
        echo -e "  Host: ${BLUE}$HOST${NC}"
    fi
    if [ ! -z "$MAP_SLUG" ]; then
        echo -e "  Map Slug: ${BLUE}$MAP_SLUG${NC}"
    fi
    if [ ! -z "$MAP_API_KEY" ]; then
        echo -e "  Map API Key: ${BLUE}${MAP_API_KEY:0:8}...${NC}"
    fi
    if [ ! -z "$ACL_API_KEY" ]; then
        echo -e "  ACL API Key: ${BLUE}${ACL_API_KEY:0:8}...${NC}"
    fi
    if [ ! -z "$SELECTED_ACL_ID" ]; then
        echo -e "  Selected ACL ID: ${BLUE}$SELECTED_ACL_ID${NC}"
    fi
    if [ ! -z "$SELECTED_SYSTEM_ID" ]; then
        echo -e "  Selected System ID: ${BLUE}$SELECTED_SYSTEM_ID${NC}"
    fi
    if [ ! -z "$CHARACTER_EVE_ID" ]; then
        echo -e "  Character EVE ID: ${BLUE}$CHARACTER_EVE_ID${NC}"
    fi
    
    echo -e "\nWhat would you like to configure?"
    echo "1) Host"
    echo "2) Map Slug"
    echo "3) Map API Key"
    echo "4) Save configuration to file"
    echo "5) Return to main menu"
    
    read -p "Enter your choice: " choice
    
    case $choice in
        1) read -p "Enter host (e.g. http://localhost:4000): " HOST ;;
        2) read -p "Enter map slug: " MAP_SLUG ;;
        3) read -p "Enter map API key: " MAP_API_KEY ;;
        4) save_config ;;
        5) return ;;
        *) print_error "Invalid choice" ;;
    esac
    
    set_config
}

# Function to select a character from the list
select_character() {
    print_header "Selecting a character"
    
    # Get characters list
    local characters_response=$(call_api "GET" "/api/characters" "")
    
    if command -v jq &> /dev/null; then
        # Extract character IDs and names
        local character_count=$(echo "$characters_response" | jq '.data | length' 2>/dev/null)
        
        if [[ -z "$character_count" || ! "$character_count" =~ ^[0-9]+$ || "$character_count" -eq 0 ]]; then
            print_error "No characters found"
            return 1
        fi
        
        echo "Available characters:"
        echo "$characters_response" | jq -r '.data[] | "\(.eve_id): \(.name) (\(.corporation_name))"' | nl -w2 -s") "
        
        read -p "Select a character (number): " character_choice
        
        if [[ "$character_choice" =~ ^[0-9]+$ && "$character_choice" -gt 0 && "$character_choice" -le "$character_count" ]]; then
            # Get the selected character ID
            CHARACTER_EVE_ID=$(echo "$characters_response" | jq -r ".data[$(($character_choice-1))].eve_id")
            local character_name=$(echo "$characters_response" | jq -r ".data[$(($character_choice-1))].name")
            print_success "Selected character: $character_name (EVE ID: $CHARACTER_EVE_ID)"
            return 0
        else
            print_error "Invalid selection"
            return 1
        fi
    else
        print_error "jq is required for character selection"
        read -p "Enter character EVE ID manually: " CHARACTER_EVE_ID
        if [ -z "$CHARACTER_EVE_ID" ]; then
            return 1
        fi
        return 0
    fi
}

# Function to select a system from the list
select_system() {
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return 1
    fi
    
    print_header "Selecting a system"
    
    # Get systems list
    local systems_response=$(call_api "GET" "/api/map/systems?slug=$MAP_SLUG" "$MAP_API_KEY")
    
    if command -v jq &> /dev/null; then
        # Extract system IDs and names
        local system_count=$(echo "$systems_response" | jq '.data | length' 2>/dev/null)
        
        if [[ -z "$system_count" || ! "$system_count" =~ ^[0-9]+$ || "$system_count" -eq 0 ]]; then
            print_error "No systems found for this map"
            return 1
        fi
        
        echo "Available systems:"
        echo "$systems_response" | jq -r '.data[] | "\(.solar_system_id): \(.name)"' | nl -w2 -s") "
        
        read -p "Select a system (number): " system_choice
        
        if [[ "$system_choice" =~ ^[0-9]+$ && "$system_choice" -gt 0 && "$system_choice" -le "$system_count" ]]; then
            # Get the selected system ID
            SELECTED_SYSTEM_ID=$(echo "$systems_response" | jq -r ".data[$(($system_choice-1))].solar_system_id")
            local system_name=$(echo "$systems_response" | jq -r ".data[$(($system_choice-1))].name")
            print_success "Selected system: $system_name (ID: $SELECTED_SYSTEM_ID)"
            return 0
        else
            print_error "Invalid selection"
            return 1
        fi
    else
        print_error "jq is required for system selection"
        read -p "Enter system ID manually: " SELECTED_SYSTEM_ID
        if [ -z "$SELECTED_SYSTEM_ID" ]; then
            return 1
        fi
        return 0
    fi
}

# Map API functions
test_list_systems() {
    print_header "Testing GET /api/map/systems"
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return
    fi
    
    local response=$(call_api "GET" "/api/map/systems?slug=$MAP_SLUG" "$MAP_API_KEY")
    echo "$response"
    
    # Ask if user wants to select a system
    if command -v jq &> /dev/null; then
        local system_count=$(echo "$response" | jq '.data | length' 2>/dev/null)
        if [[ -n "$system_count" && "$system_count" =~ ^[0-9]+$ && "$system_count" -gt 0 ]]; then
            read -p "Would you like to select a system from this list? (y/n): " select_sys
            if [[ "$select_sys" == "y" ]]; then
                select_system
            fi
        fi
    fi
}

test_show_system() {
    print_header "Testing GET /api/map/system"
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return
    fi
    
    if [ -z "$SELECTED_SYSTEM_ID" ]; then
        print_warning "No system ID selected. Let's select one now."
        if ! select_system; then
            print_error "Failed to select a system"
            return
        fi
    fi
    
    call_api "GET" "/api/map/system?slug=$MAP_SLUG&id=$SELECTED_SYSTEM_ID" "$MAP_API_KEY"
}

test_tracked_characters() {
    print_header "Testing GET /api/map/characters"
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return
    fi
    
    call_api "GET" "/api/map/characters?slug=$MAP_SLUG" "$MAP_API_KEY"
}

test_structure_timers() {
    print_header "Testing GET /api/map/structure-timers"
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return
    fi
    
    local endpoint="/api/map/structure-timers?slug=$MAP_SLUG"
    
    read -p "Would you like to filter by system ID? (y/n): " filter_by_system
    if [[ "$filter_by_system" == "y" ]]; then
        if [ -z "$SELECTED_SYSTEM_ID" ]; then
            print_warning "No system ID selected. Let's select one now."
            if ! select_system; then
                print_error "Failed to select a system"
                return
            fi
        fi
        endpoint+="&system_id=$SELECTED_SYSTEM_ID"
    fi
    
    call_api "GET" "$endpoint" "$MAP_API_KEY"
}

test_systems_kills() {
    print_header "Testing GET /api/map/systems-kills"
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return
    fi
    
    local endpoint="/api/map/systems-kills?slug=$MAP_SLUG"
    
    read -p "Enter hours ago (optional, press enter to skip): " hours_ago
    if [ ! -z "$hours_ago" ]; then
        endpoint+="&hours_ago=$hours_ago"
    fi
    
    call_api "GET" "$endpoint" "$MAP_API_KEY"
}

# Function to select an ACL from the list
select_acl() {
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return 1
    fi
    
    print_header "Selecting an ACL"
    
    # Get ACLs list
    local acls_response=$(call_api "GET" "/api/map/acls?slug=$MAP_SLUG" "$MAP_API_KEY")
    
    if command -v jq &> /dev/null; then
        # Extract ACL IDs and names
        local acl_count=$(echo "$acls_response" | jq '.data | length')
        
        if [ "$acl_count" -eq 0 ]; then
            print_error "No ACLs found for this map"
            return 1
        fi
        
        echo "Available ACLs:"
        echo "$acls_response" | jq -r '.data[] | "\(.id): \(.name)"' | nl -w2 -s") "
        
        read -p "Select an ACL (number): " acl_choice
        
        if [[ "$acl_choice" =~ ^[0-9]+$ ]] && [ "$acl_choice" -gt 0 ] && [ "$acl_choice" -le "$acl_count" ]; then
            # Get the selected ACL ID
            SELECTED_ACL_ID=$(echo "$acls_response" | jq -r ".data[$(($acl_choice-1))].id")
            local acl_name=$(echo "$acls_response" | jq -r ".data[$(($acl_choice-1))].name")
            print_success "Selected ACL: $acl_name (ID: $SELECTED_ACL_ID)"
            
            # Ask if user wants to get the ACL details to retrieve the API key
            read -p "Would you like to retrieve the API key for this ACL? (y/n): " get_api_key
            if [[ "$get_api_key" == "y" ]]; then
                print_warning "You'll need to provide the ACL API key manually since it's only available when creating a new ACL."
                read -p "Enter ACL API key: " ACL_API_KEY
                if [ ! -z "$ACL_API_KEY" ]; then
                    print_success "API key set for selected ACL"
                fi
            fi
            
            return 0
        else
            print_error "Invalid selection"
            return 1
        fi
    else
        print_error "jq is required for ACL selection"
        read -p "Enter ACL ID manually: " SELECTED_ACL_ID
        if [ -z "$SELECTED_ACL_ID" ]; then
            return 1
        fi
        read -p "Enter ACL API key: " ACL_API_KEY
        return 0
    fi
}

# ACL API functions
test_list_acls() {
    print_header "Testing GET /api/map/acls"
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return
    fi
    
    local response=$(call_api "GET" "/api/map/acls?slug=$MAP_SLUG" "$MAP_API_KEY")
    echo "$response"
    
    # Ask if user wants to select an ACL
    if command -v jq &> /dev/null; then
        local acl_count=$(echo "$response" | jq '.data | length')
        if [ "$acl_count" -gt 0 ]; then
            read -p "Would you like to select an ACL from this list? (y/n): " select_acl_choice
            if [[ "$select_acl_choice" == "y" ]]; then
                select_acl
            fi
        fi
    fi
}

test_create_acl() {
    print_header "Testing POST /api/map/acls"
    
    if ! check_required_vars "MAP_SLUG" "MAP_API_KEY"; then
        return
    fi
    
    if [ -z "$CHARACTER_EVE_ID" ]; then
        print_warning "No character EVE ID selected. Let's select one now."
        if ! select_character; then
            print_error "Failed to select a character"
            return
        fi
    fi
    
    read -p "Enter ACL name: " acl_name
    read -p "Enter ACL description (optional): " acl_description
    
    local data="{\"acl\": {\"name\": \"$acl_name\", \"owner_eve_id\": $CHARACTER_EVE_ID"
    
    if [ ! -z "$acl_description" ]; then
        data+=", \"description\": \"$acl_description\""
    fi
    
    data+="}}"
    
    local response=$(call_api "POST" "/api/map/acls?slug=$MAP_SLUG" "$MAP_API_KEY" "$data")
    echo "$response"
    
    # Extract ACL ID and API key if jq is available
    if command -v jq &> /dev/null; then
        local new_acl_id=$(echo "$response" | jq -r '.data.id // empty')
        local new_api_key=$(echo "$response" | jq -r '.data.api_key // empty')
        
        if [ ! -z "$new_acl_id" ] && [ ! -z "$new_api_key" ]; then
            print_success "Created new ACL with ID: $new_acl_id"
            print_success "API Key: $new_api_key"
            
            # Automatically use the new ACL ID and API key
            SELECTED_ACL_ID=$new_acl_id
            ACL_API_KEY=$new_api_key
            print_success "Automatically selected the new ACL and set its API key for further operations"
        else
            print_error "Failed to extract ACL ID or API key from response"
        fi
    fi
}

test_show_acl() {
    print_header "Testing GET /api/acls/:id"
    
    if [ -z "$SELECTED_ACL_ID" ]; then
        print_warning "No ACL ID selected. Let's select one now."
        if ! select_acl; then
            print_error "Failed to select an ACL"
            return
        fi
    fi
    
    if [ -z "$ACL_API_KEY" ]; then
        print_error "No ACL API key available. Create a new ACL or set the API key manually."
        read -p "Enter ACL API key manually (or press enter to cancel): " ACL_API_KEY
        if [ -z "$ACL_API_KEY" ]; then
            return
        fi
    fi
    
    call_api "GET" "/api/acls/$SELECTED_ACL_ID" "$ACL_API_KEY"
}

test_update_acl() {
    print_header "Testing PUT /api/acls/:id"
    
    if [ -z "$SELECTED_ACL_ID" ]; then
        print_warning "No ACL ID selected. Let's select one now."
        if ! select_acl; then
            print_error "Failed to select an ACL"
            return
        fi
    fi
    
    if [ -z "$ACL_API_KEY" ]; then
        print_error "No ACL API key available. Create a new ACL or set the API key manually."
        read -p "Enter ACL API key manually (or press enter to cancel): " ACL_API_KEY
        if [ -z "$ACL_API_KEY" ]; then
            return
        fi
    fi
    
    read -p "Enter new ACL name (optional): " acl_name
    read -p "Enter new ACL description (optional): " acl_description
    
    local data="{\"acl\": {"
    local has_data=false
    
    if [ ! -z "$acl_name" ]; then
        data+="\"name\": \"$acl_name\""
        has_data=true
    fi
    
    if [ ! -z "$acl_description" ]; then
        if $has_data; then
            data+=", "
        fi
        data+="\"description\": \"$acl_description\""
        has_data=true
    fi
    
    data+="}}"
    
    if ! $has_data; then
        print_error "No data provided for update"
        return
    fi
    
    call_api "PUT" "/api/acls/$SELECTED_ACL_ID" "$ACL_API_KEY" "$data"
}

# Function to select a member from an ACL
select_member() {
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        return 1
    fi
    
    print_header "Selecting a member"
    
    # Get ACL details with members
    local acl_response=$(call_api "GET" "/api/acls/$SELECTED_ACL_ID" "$ACL_API_KEY")
    
    if command -v jq &> /dev/null; then
        # Extract member IDs and names
        local member_count=$(echo "$acl_response" | jq '.data.members | length')
        
        if [ "$member_count" -eq 0 ]; then
            print_error "No members found for this ACL"
            return 1
        fi
        
        echo "Available members:"
        echo "$acl_response" | jq -r '.data.members[] | "\(.id): \(.name) (\(.role))"' | nl -w2 -s") "
        
        read -p "Select a member (number): " member_choice
        
        if [[ "$member_choice" =~ ^[0-9]+$ ]] && [ "$member_choice" -gt 0 ] && [ "$member_choice" -le "$member_count" ]; then
            # Get the selected member ID
            local selected_member_id=$(echo "$acl_response" | jq -r ".data.members[$(($member_choice-1))].eve_character_id // .data.members[$(($member_choice-1))].eve_corporation_id // .data.members[$(($member_choice-1))].eve_alliance_id")
            local member_name=$(echo "$acl_response" | jq -r ".data.members[$(($member_choice-1))].name")
            print_success "Selected member: $member_name (ID: $selected_member_id)"
            echo "$selected_member_id"
            return 0
        else
            print_error "Invalid selection"
            return 1
        fi
    else
        print_error "jq is required for member selection"
        read -p "Enter member ID manually: " member_id
        if [ -z "$member_id" ]; then
            return 1
        fi
        echo "$member_id"
        return 0
    fi
}

test_create_acl_member() {
    print_header "Testing POST /api/acls/:acl_id/members"
    
    if [ -z "$SELECTED_ACL_ID" ]; then
        print_warning "No ACL ID selected. Let's select one now."
        if ! select_acl; then
            print_error "Failed to select an ACL"
            return
        fi
    fi
    
    if [ -z "$ACL_API_KEY" ]; then
        print_error "No ACL API key available. Create a new ACL or set the API key manually."
        read -p "Enter ACL API key manually (or press enter to cancel): " ACL_API_KEY
        if [ -z "$ACL_API_KEY" ]; then
            return
        fi
    fi
    
    echo "Select member type:"
    echo "1) Character"
    echo "2) Corporation"
    echo "3) Alliance"
    read -p "Enter your choice: " member_type
    
    local type_field=""
    case $member_type in
        1) 
            type_field="eve_character_id"
            # Offer to select a character from the API
            read -p "Would you like to select a character from the API? (y/n): " select_char
            if [[ "$select_char" == "y" ]]; then
                if ! select_character; then
                    print_error "Failed to select a character"
                    return
                fi
                entity_id=$CHARACTER_EVE_ID
            else
                read -p "Enter character EVE ID: " entity_id
            fi
            ;;
        2) type_field="eve_corporation_id"; read -p "Enter corporation ID: " entity_id ;;
        3) type_field="eve_alliance_id"; read -p "Enter alliance ID: " entity_id ;;
        *) print_error "Invalid choice"; return ;;
    esac
    
    echo "Select role:"
    echo "1) viewer (default)"
    echo "2) editor"
    if [ "$type_field" == "eve_character_id" ]; then
        echo "3) manager"
        echo "4) admin"
    fi
    read -p "Enter your choice: " role_choice
    
    local role="viewer"
    case $role_choice in
        2) role="editor" ;;
        3) 
            if [ "$type_field" == "eve_character_id" ]; then
                role="manager"
            else
                print_error "Invalid role for this member type"
                return
            fi
            ;;
        4)
            if [ "$type_field" == "eve_character_id" ]; then
                role="admin"
            else
                print_error "Invalid role for this member type"
                return
            fi
            ;;
    esac
    
    local data="{\"member\": {\"$type_field\": $entity_id, \"role\": \"$role\"}}"
    
    call_api "POST" "/api/acls/$SELECTED_ACL_ID/members" "$ACL_API_KEY" "$data"
}

test_update_acl_member() {
    print_header "Testing PUT /api/acls/:acl_id/members/:member_id"
    
    if [ -z "$SELECTED_ACL_ID" ]; then
        print_warning "No ACL ID selected. Let's select one now."
        if ! select_acl; then
            print_error "Failed to select an ACL"
            return
        fi
    fi
    
    if [ -z "$ACL_API_KEY" ]; then
        print_error "No ACL API key available. Create a new ACL or set the API key manually."
        read -p "Enter ACL API key manually (or press enter to cancel): " ACL_API_KEY
        if [ -z "$ACL_API_KEY" ]; then
            return
        fi
    fi
    
    print_warning "Select a member to update:"
    member_id=$(select_member)
    
    if [ -z "$member_id" ]; then
        read -p "Enter member ID manually: " member_id
        if [ -z "$member_id" ]; then
            print_error "No member ID provided"
            return
        fi
    fi
    
    echo "Select new role:"
    echo "1) viewer"
    echo "2) editor"
    echo "3) manager"
    echo "4) admin"
    read -p "Enter your choice: " role_choice
    
    local role="viewer"
    case $role_choice in
        2) role="editor" ;;
        3) role="manager" ;;
        4) role="admin" ;;
    esac
    
    local data="{\"member\": {\"role\": \"$role\"}}"
    
    call_api "PUT" "/api/acls/$SELECTED_ACL_ID/members/$member_id" "$ACL_API_KEY" "$data"
}

test_delete_acl_member() {
    print_header "Testing DELETE /api/acls/:acl_id/members/:member_id"
    
    if [ -z "$SELECTED_ACL_ID" ]; then
        print_warning "No ACL ID selected. Let's select one now."
        if ! select_acl; then
            print_error "Failed to select an ACL"
            return
        fi
    fi
    
    if [ -z "$ACL_API_KEY" ]; then
        print_error "No ACL API key available. Create a new ACL or set the API key manually."
        read -p "Enter ACL API key manually (or press enter to cancel): " ACL_API_KEY
        if [ -z "$ACL_API_KEY" ]; then
            return
        fi
    fi
    
    print_warning "Select a member to delete:"
    member_id=$(select_member)
    
    if [ -z "$member_id" ]; then
        read -p "Enter member ID manually: " member_id
        if [ -z "$member_id" ]; then
            print_error "No member ID provided"
            return
        fi
    fi
    
    read -p "Are you sure you want to delete this member? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_warning "Deletion cancelled"
        return
    fi
    
    call_api "DELETE" "/api/acls/$SELECTED_ACL_ID/members/$member_id" "$ACL_API_KEY"
}

# Character API functions
test_list_characters() {
    print_header "Testing GET /api/characters"
    
    local response=$(call_api "GET" "/api/characters" "")
    echo "$response"
    
    # Ask if user wants to use a character ID
    if command -v jq &> /dev/null; then
        read -p "Would you like to use a character ID from this list? (y/n): " use_char
        if [[ "$use_char" == "y" ]]; then
            select_character
        fi
    fi
}

# Common API functions
test_system_static_info() {
    print_header "Testing GET /api/common/system-static-info"
    
    call_api "GET" "/api/common/system-static-info" ""
}

# Main menu
show_main_menu() {
    while true; do
        print_header "Wanderer API Testing Tool"
        
        echo "Configuration:"
        if [ ! -z "$HOST" ]; then
            echo -e "  Host: ${BLUE}$HOST${NC}"
        fi
        if [ ! -z "$MAP_SLUG" ]; then
            echo -e "  Map Slug: ${BLUE}$MAP_SLUG${NC}"
        fi
        if [ ! -z "$MAP_API_KEY" ]; then
            echo -e "  Map API Key: ${BLUE}${MAP_API_KEY:0:8}...${NC}"
        fi
        if [ ! -z "$ACL_API_KEY" ]; then
            echo -e "  ACL API Key: ${BLUE}${ACL_API_KEY:0:8}...${NC}"
        fi
        if [ ! -z "$SELECTED_ACL_ID" ]; then
            echo -e "  Selected ACL ID: ${BLUE}$SELECTED_ACL_ID${NC}"
        fi
        if [ ! -z "$SELECTED_SYSTEM_ID" ]; then
            echo -e "  Selected System ID: ${BLUE}$SELECTED_SYSTEM_ID${NC}"
        fi
        if [ ! -z "$CHARACTER_EVE_ID" ]; then
            echo -e "  Character EVE ID: ${BLUE}$CHARACTER_EVE_ID${NC}"
        fi
        
        echo -e "\nAvailable tests:"
        echo "0) Set configuration"
        
        echo -e "\n${YELLOW}Map API:${NC}"
        echo "1) List systems"
        echo "2) Show system details"
        echo "3) List tracked characters"
        echo "4) Show structure timers"
        echo "5) Show systems kills"
        
        echo -e "\n${YELLOW}ACL API:${NC}"
        echo "6) List ACLs"
        echo "7) Create ACL"
        echo "8) Show ACL details"
        echo "9) Update ACL"
        echo "10) Create ACL member"
        echo "11) Update ACL member role"
        echo "12) Delete ACL member"
        
        echo -e "\n${YELLOW}Character API:${NC}"
        echo "13) List characters"
        
        echo -e "\n${YELLOW}Common API:${NC}"
        echo "14) Show system static info"
        
        echo -e "\n${YELLOW}Other:${NC}"
        echo "15) Select a system"
        echo "16) Select an ACL"
        echo "17) Select a character"
        echo "18) Save configuration"
        echo "q) Quit"
        
        read -p "Enter your choice: " choice
        
        case $choice in
            0) set_config ;;
            1) test_list_systems ;;
            2) test_show_system ;;
            3) test_tracked_characters ;;
            4) test_structure_timers ;;
            5) test_systems_kills ;;
            6) test_list_acls ;;
            7) test_create_acl ;;
            8) test_show_acl ;;
            9) test_update_acl ;;
            10) test_create_acl_member ;;
            11) test_update_acl_member ;;
            12) test_delete_acl_member ;;
            13) test_list_characters ;;
            14) test_system_static_info ;;
            15) select_system ;;
            16) select_acl ;;
            17) select_character ;;
            18) save_config ;;
            q|Q) 
                read -p "Save configuration before exiting? (y/n): " save_before_exit
                if [[ "$save_before_exit" == "y" ]]; then
                    save_config
                fi
                break 
                ;;
            *) print_error "Invalid choice" ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. JSON responses will not be formatted."
    print_warning "Install jq for better output formatting."
fi

# Load configuration from file if it exists
load_config

# Start the script
show_main_menu