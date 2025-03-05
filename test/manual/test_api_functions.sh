#!/bin/bash
# File: test_api_functions.sh

# Source the core functions
source ./test_api_core.sh

# Map API Tests
test_list_systems() {
    print_header "Testing GET /api/map/systems"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/map/systems?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    print_header "Testing GET $endpoint"
    
    local response=$(call_api "GET" "$endpoint" "$headers")
    
    # Ask if user wants to select a system
    if command -v jq &> /dev/null; then
        local system_count=$(echo "$response" | jq '.data | length' 2>/dev/null)
        if [[ -n "$system_count" && "$system_count" -gt 0 ]]; then
            read -p "Would you like to select a system from this list? (y/n): " select_sys
            if [[ "$select_sys" == "y" ]]; then
                select_system
            fi
        fi
    fi
    
    read -p "Press Enter to continue..."
}

test_show_system() {
    print_header "Testing GET /api/map/system"
    
    if ! check_required_vars; then
        return 1
    fi
    
    if [ -z "$SELECTED_SYSTEM_ID" ]; then
        print_warning "No system selected. Let's select one first."
        select_system
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    local endpoint="/api/map/system?slug=$MAP_SLUG&id=$SELECTED_SYSTEM_ID"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    print_header "Testing GET $endpoint"
    
    call_api "GET" "$endpoint" "$headers"
    
    read -p "Press Enter to continue..."
}

test_tracked_characters() {
    print_header "Testing GET /api/map/characters"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/map/characters?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    call_api "GET" "$endpoint" "$headers"
}

test_structure_timers() {
    print_header "Testing GET /api/map/structure-timers"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/map/structure-timers?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    # Ask if user wants to filter by system
    read -p "Filter by system? (y/n): " filter_by_system
    
    if [[ $filter_by_system == "y" ]]; then
        if [ -z "$SELECTED_SYSTEM_ID" ]; then
            print_warning "No system selected. Let's select one first."
            select_system
            if [ $? -ne 0 ]; then
                return 1
            fi
        fi
        
        endpoint="$endpoint&system_id=$SELECTED_SYSTEM_ID"
    fi
    
    call_api "GET" "$endpoint" "$headers"
}

test_systems_kills() {
    print_header "Testing GET /api/map/systems-kills"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/map/systems-kills?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    # Ask if user wants to filter by hours
    read -p "Filter by hours ago (leave empty for no filter): " hours_ago
    
    if [ ! -z "$hours_ago" ]; then
        endpoint="$endpoint&hours_ago=$hours_ago"
    fi
    
    call_api "GET" "$endpoint" "$headers"
}

# ACL API Tests
test_list_acls() {
    print_header "Testing GET /api/map/acls"
    
    if ! check_required_vars; then
        return 1
    fi
    
    local endpoint="/api/map/acls?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    
    call_api "GET" "$endpoint" "$headers"
}

test_create_acl() {
    print_header "Testing POST /api/map/acls"
    
    if ! check_required_vars; then
        return 1
    fi
    
    if [ -z "$CHARACTER_EVE_ID" ]; then
        print_warning "No character selected. Let's select one first."
        select_character
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    read -p "Enter ACL name: " acl_name
    read -p "Enter ACL description (optional): " acl_description
    
    local endpoint="/api/map/acls?slug=$MAP_SLUG"
    local headers="X-Map-API-Key: $MAP_API_KEY"
    local data="{\"acl\":{\"owner_eve_id\":\"$CHARACTER_EVE_ID\",\"name\":\"$acl_name\",\"description\":\"$acl_description\"}}"
    
    local response=$(call_api "POST" "$endpoint" "$headers" "$data")
    
    # Extract ACL ID and API key from the response
    if [[ $response == *"\"id\":"* && $response == *"\"api_key\":"* ]]; then
        SELECTED_ACL_ID=$(echo "$response" | jq -r '.data.id' 2>/dev/null)
        ACL_API_KEY=$(echo "$response" | jq -r '.data.api_key' 2>/dev/null)
        
        if [ ! -z "$SELECTED_ACL_ID" ] && [ ! -z "$ACL_API_KEY" ]; then
            print_success "Created ACL with ID: $SELECTED_ACL_ID"
            print_success "ACL API Key: ${ACL_API_KEY:0:8}..."
        else
            print_error "Failed to extract ACL ID or API key from response"
        fi
    else
        print_error "Failed to extract ACL ID or API key from response"
    fi
}

test_show_acl() {
    print_header "Testing GET /api/acls/:id"
    
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        print_warning "No ACL selected or API key missing. Let's select one first."
        select_acl
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    local endpoint="/api/acls/$SELECTED_ACL_ID"
    local headers="X-ACL-API-Key: $ACL_API_KEY"
    
    call_api "GET" "$endpoint" "$headers"
}

test_update_acl() {
    print_header "Testing PUT /api/acls/:id"
    
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        print_warning "No ACL selected or API key missing. Let's select one first."
        select_acl
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    read -p "Enter new ACL name: " acl_name
    read -p "Enter new ACL description (optional): " acl_description
    
    local endpoint="/api/acls/$SELECTED_ACL_ID"
    local headers="X-ACL-API-Key: $ACL_API_KEY"
    local data="{\"acl\":{\"name\":\"$acl_name\",\"description\":\"$acl_description\"}}"
    
    call_api "PUT" "$endpoint" "$headers" "$data"
}

test_create_acl_member() {
    print_header "Testing POST /api/acls/:acl_id/members"
    
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        print_warning "No ACL selected or API key missing. Let's select one first."
        select_acl
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    if [ -z "$CHARACTER_EVE_ID" ]; then
        print_warning "No character selected. Let's select one first."
        select_character
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    read -p "Enter role (admin, manager, editor, viewer) [default: viewer]: " role
    if [ -z "$role" ]; then
        role="viewer"
    fi
    
    local endpoint="/api/acls/$SELECTED_ACL_ID/members"
    local headers="X-ACL-API-Key: $ACL_API_KEY"
    local data="{\"member\":{\"eve_character_id\":\"$CHARACTER_EVE_ID\",\"role\":\"$role\"}}"
    
    call_api "POST" "$endpoint" "$headers" "$data"
}

test_update_acl_member() {
    print_header "Testing PUT /api/acls/:acl_id/members/:member_id"
    
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        print_warning "No ACL selected or API key missing. Let's select one first."
        select_acl
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    local member_id=$(select_member)
    if [ -z "$member_id" ]; then
        return 1
    fi
    
    read -p "Enter new role (admin, manager, editor, viewer): " role
    
    local endpoint="/api/acls/$SELECTED_ACL_ID/members/$member_id"
    local headers="X-ACL-API-Key: $ACL_API_KEY"
    local data="{\"member\":{\"role\":\"$role\"}}"
    
    call_api "PUT" "$endpoint" "$headers" "$data"
}

test_delete_acl_member() {
    print_header "Testing DELETE /api/acls/:acl_id/members/:member_id"
    
    if [ -z "$SELECTED_ACL_ID" ] || [ -z "$ACL_API_KEY" ]; then
        print_warning "No ACL selected or API key missing. Let's select one first."
        select_acl
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    local member_id=$(select_member)
    if [ -z "$member_id" ]; then
        return 1
    fi
    
    local endpoint="/api/acls/$SELECTED_ACL_ID/members/$member_id"
    local headers="X-ACL-API-Key: $ACL_API_KEY"
    
    call_api "DELETE" "$endpoint" "$headers"
}

# Character API Tests
test_list_characters() {
    print_header "Testing GET /api/characters"
    
    if [ -z "$HOST" ]; then
        print_error "HOST is not set. Please set it first."
        return 1
    fi
    
    local endpoint="/api/characters"
    local headers="Accept: application/json"
    
    local response=$(call_api "GET" "$endpoint" "$headers")
    
    # Offer to select a character
    if [[ $response == *"\"data\":"* ]]; then
        read -p "Would you like to select a character? (y/n): " select_char
        if [[ $select_char == "y" ]]; then
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
            else
                print_error "Invalid selection."
            fi
        fi
    fi
}

# Common API Tests
test_system_static_info() {
    print_header "Testing GET /api/common/system-static-info"
    
    if [ -z "$HOST" ]; then
        print_error "HOST is not set. Please set it first."
        return 1
    fi
    
    if [ -z "$SELECTED_SYSTEM_ID" ]; then
        print_warning "No system selected. Let's select one first."
        select_system
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    local endpoint="/api/common/system-static-info?id=$SELECTED_SYSTEM_ID"
    local headers="Accept: application/json"
    
    call_api "GET" "$endpoint" "$headers"
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