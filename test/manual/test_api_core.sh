#!/bin/bash
# File: test_api_core.sh

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE=".api_test_config"

# Configuration variables
HOST=""
MAP_SLUG=""
MAP_API_KEY=""
ACL_API_KEY=""
SELECTED_ACL_ID=""
SELECTED_SYSTEM_ID=""
CHARACTER_EVE_ID=""

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

# Helper functions
print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
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

# Function to make API calls
call_api() {
    local method=$1
    local endpoint=$2
    local headers=()
    local data=""
    
    # Add headers if provided
    if [ ! -z "$3" ]; then
        headers+=(-H "$3")
    fi
    
    # Add data if provided
    if [ ! -z "$4" ]; then
        data="-d '$4'"
    fi
    
    # Construct the full URL
    local url="${HOST}${endpoint}"
    
    # Debug info
    echo -e "Calling: ${BLUE}${method} ${url}${NC}"
    if [ ${#headers[@]} -gt 0 ]; then
        echo -e "Headers: ${BLUE}${headers[@]}${NC}"
    fi
    if [ ! -z "$data" ]; then
        echo -e "Data: ${BLUE}${data}${NC}"
    fi
    echo ""
    
    # Make the API call
    local response
    if [ "$method" = "GET" ]; then
        response=$(curl -s -X GET "${url}" "${headers[@]}")
    elif [ "$method" = "POST" ]; then
        response=$(curl -s -X POST "${url}" "${headers[@]}" -d "$4")
    elif [ "$method" = "PUT" ]; then
        response=$(curl -s -X PUT "${url}" "${headers[@]}" -d "$4")
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -X DELETE "${url}" "${headers[@]}")
    fi
    
    # Format the response with jq if available
    if command -v jq &> /dev/null && [ ! -z "$response" ]; then
        echo "$response" | jq '.'
    else
        echo "$response"
    fi
    
    # Return the response for further processing
    echo "$response"
}

# Check if required variables are set
check_required_vars() {
    local missing=false
    
    if [ -z "$HOST" ]; then
        print_error "HOST is not set. Please set it first."
        missing=true
    fi
    
    # Fix: Don't use integer comparison for string variables
    if [ -z "$MAP_SLUG" ] && [ -z "${1:-}" ]; then
        print_error "MAP_SLUG is not set. Please set it first."
        missing=true
    fi
    
    if [ -z "$MAP_API_KEY" ] && [ -z "${2:-}" ]; then
        print_error "MAP_API_KEY is not set. Please set it first."
        missing=true
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
        1) read -p "Enter host (e.g. http://localhost:4000): " new_host
           if [ ! -z "$new_host" ]; then
               HOST=$new_host
               print_success "Host updated."
           fi
           ;;
        2) read -p "Enter map slug: " new_map_slug
           if [ ! -z "$new_map_slug" ]; then
               MAP_SLUG=$new_map_slug
               print_success "Map Slug updated."
           fi
           ;;
        3) read -p "Enter map API key: " new_map_api_key
           if [ ! -z "$new_map_api_key" ]; then
               MAP_API_KEY=$new_map_api_key
               print_success "Map API Key updated."
           fi
           ;;
        4) save_config ;;
        5) return ;;
        *) print_error "Invalid choice" ;;
    esac
    
    # Recursively call set_config to allow multiple configurations
    set_config
}

# Function to select a character from the list
select_character() {
    print_header "Select a Character"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/characters"
    local headers="Accept: application/json"
    
    print_header "Testing GET $endpoint"
    
    local response=$(call_api "GET" "$endpoint" "$headers")
    
    # Check if the response contains data
    if [[ $response == *"\"data\":"* ]]; then
        # Extract characters from the response
        local characters=$(echo "$response" | jq -r '.data[] | "\(.eve_id) - \(.name)"' 2>/dev/null)
        
        if [ -z "$characters" ]; then
            print_error "No characters found or could not parse the response."
            return 1
        fi
        
        echo "Available characters:"
        local i=1
        local char_ids=()
        local char_names=()
        
        while IFS= read -r line; do
            echo "$i) $line"
            char_ids+=($(echo "$line" | cut -d' ' -f1))
            char_names+=($(echo "$line" | cut -d' ' -f3-))
            ((i++))
        done <<< "$characters"
        
        read -p "Select a character (1-$((i-1))): " choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le $((i-1)) ]; then
            CHARACTER_EVE_ID=${char_ids[$((choice-1))]}
            print_success "Selected character: ${char_names[$((choice-1))]} (EVE ID: $CHARACTER_EVE_ID)"
            return 0
        else
            print_error "Invalid selection."
            return 1
        fi
    else
        print_error "Failed to retrieve characters."
        return 1
    fi
}

# Function to select a system from the list
select_system() {
    print_header "Select a System"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/map/systems?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    print_header "Testing GET $endpoint"
    
    local response=$(call_api "GET" "$endpoint" "$headers")
    
    # Check if the response contains data
    if [[ $response == *"\"data\":"* ]]; then
        # Extract systems from the response
        local systems=$(echo "$response" | jq -r '.data[] | "\(.solar_system_id) - \(.name)"' 2>/dev/null)
        
        if [ -z "$systems" ]; then
            print_error "No systems found or could not parse the response."
            return 1
        fi
        
        echo "Available systems:"
        local i=1
        local sys_ids=()
        local sys_names=()
        
        while IFS= read -r line; do
            echo "$i) $line"
            sys_ids+=($(echo "$line" | cut -d' ' -f1))
            sys_names+=($(echo "$line" | cut -d' ' -f3-))
            ((i++))
        done <<< "$systems"
        
        read -p "Select a system (1-$((i-1))): " choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le $((i-1)) ]; then
            SELECTED_SYSTEM_ID=${sys_ids[$((choice-1))]}
            print_success "Selected system: ${sys_names[$((choice-1))]} (ID: $SELECTED_SYSTEM_ID)"
            return 0
        else
            print_error "Invalid selection."
            return 1
        fi
    else
        print_error "Failed to retrieve systems."
        return 1
    fi
}

# Function to select an ACL from the list
select_acl() {
    print_header "Select an ACL"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/map/acls?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    print_header "Testing GET $endpoint"
    
    local response=$(call_api "GET" "$endpoint" "$headers")
    
    # Check if the response contains data
    if [[ $response == *"\"data\":"* ]]; then
        # Extract ACLs from the response
        local acls=$(echo "$response" | jq -r '.data[] | "\(.id) - \(.name)"' 2>/dev/null)
        
        if [ -z "$acls" ]; then
            print_error "No ACLs found or could not parse the response."
            return 1
        fi
        
        echo "Available ACLs:"
        local i=1
        local acl_ids=()
        local acl_names=()
        
        while IFS= read -r line; do
            echo "$i) $line"
            acl_ids+=($(echo "$line" | cut -d' ' -f1))
            acl_names+=($(echo "$line" | cut -d' ' -f3-))
            ((i++))
        done <<< "$acls"
        
        read -p "Select an ACL (1-$((i-1))): " choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le $((i-1)) ]; then
            SELECTED_ACL_ID=${acl_ids[$((choice-1))]}
            
            # Now get the ACL details to extract the API key
            local acl_endpoint="/api/acls/$SELECTED_ACL_ID"
            local acl_headers="X-ACL-API-Key: $ACL_API_KEY"
            
            if [ -z "$ACL_API_KEY" ]; then
                print_warning "ACL API Key not set. Attempting to retrieve ACL without API key."
                acl_headers=""
            fi
            
            local acl_response=$(call_api "GET" "$acl_endpoint" "$acl_headers")
            
            if [[ $acl_response == *"\"api_key\":"* ]]; then
                ACL_API_KEY=$(echo "$acl_response" | jq -r '.data.api_key' 2>/dev/null)
                print_success "Selected ACL: ${acl_names[$((choice-1))]} (ID: $SELECTED_ACL_ID, API Key: ${ACL_API_KEY:0:8}...)"
                return 0
            else
                print_warning "Selected ACL: ${acl_names[$((choice-1))]} (ID: $SELECTED_ACL_ID)"
                print_warning "Could not retrieve ACL API Key. Some operations may fail."
                return 0
            fi
        else
            print_error "Invalid selection."
            return 1
        fi
    else
        print_error "Failed to retrieve ACLs."
        return 1
    fi
}

# Function to select a member from an ACL
select_member() {
    print_header "Select a Member"
    
    if [ -z "$SELECTED_ACL_ID" ]; then
        print_error "No ACL selected. Please select an ACL first."
        return 1
    fi
    
    if [ -z "$ACL_API_KEY" ]; then
        print_error "ACL API Key not set. Please select an ACL first."
        return 1
    fi
    
    local endpoint="/api/acls/$SELECTED_ACL_ID"
    local headers="X-ACL-API-Key: $ACL_API_KEY"
    
    print_header "Testing GET $endpoint"
    
    local response=$(call_api "GET" "$endpoint" "$headers")
    
    # Check if the response contains members
    if [[ $response == *"\"members\":"* ]]; then
        # Extract members from the response
        local members=$(echo "$response" | jq -r '.data.members[] | "\(.eve_character_id) - \(.name) (\(.role))"' 2>/dev/null)
        
        if [ -z "$members" ]; then
            print_error "No members found or could not parse the response."
            return 1
        fi
        
        echo "Available members:"
        local i=1
        local member_ids=()
        local member_names=()
        
        while IFS= read -r line; do
            echo "$i) $line"
            member_ids+=($(echo "$line" | cut -d' ' -f1))
            member_names+=($(echo "$line" | cut -d' ' -f3-))
            ((i++))
        done <<< "$members"
        
        read -p "Select a member (1-$((i-1))): " choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le $((i-1)) ]; then
            local selected_member_id=${member_ids[$((choice-1))]}
            print_success "Selected member: ${member_names[$((choice-1))]} (ID: $selected_member_id)"
            echo "$selected_member_id"
            return 0
        else
            print_error "Invalid selection."
            return 1
        fi
    else
        print_error "Failed to retrieve members."
        return 1
    fi
}