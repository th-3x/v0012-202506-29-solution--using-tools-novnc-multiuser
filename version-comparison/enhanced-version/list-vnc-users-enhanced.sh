#!/bin/bash

#==============================================================================
# Enhanced List VNC Users and noVNC Status
# Shows all VNC users with detailed status and mismatch detection
#==============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "🖥️  Enhanced VNC Users and noVNC Status"
    echo "=================================================="
    echo -e "${NC}"
}

show_help() {
    print_header
    echo "Usage: $0 [options]"
    echo ""
    echo "Description:"
    echo "  Enhanced display of VNC sessions with mismatch detection and repair suggestions"
    echo ""
    echo "Options:"
    echo "  --help, -h     - Show this help message"
    echo "  --check-all    - Check all services for mismatches"
    echo "  --repair-all   - Show repair commands for all issues"
    echo "  --json         - Output in JSON format"
    echo ""
    echo "Output columns:"
    echo "  USER           - VNC username"
    echo "  DISPLAY        - VNC display number"
    echo "  VNC_PORT       - Actual VNC server port"
    echo "  NOVNC_PORT     - noVNC web interface port"
    echo "  SVC_VNC_PORT   - Service configured VNC port"
    echo "  STATUS         - Service status with issue indicators"
    echo "  WEB_URL        - Direct web access URL"
    echo ""
    echo "Status Indicators:"
    echo "  ✅ ACTIVE      - Service running correctly"
    echo "  ❌ MISMATCH    - VNC port mismatch detected"
    echo "  ⚠️  INACTIVE   - Service exists but stopped"
    echo "  📵 NO_SERVICE - No noVNC service configured"
    echo ""
}

# Parse arguments
CHECK_ALL=false
REPAIR_ALL=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --check-all)
            CHECK_ALL=true
            shift
            ;;
        --repair-all)
            REPAIR_ALL=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to get service VNC port
get_service_vnc_port() {
    local service_name="$1"
    if systemctl list-unit-files 2>/dev/null | grep -q "$service_name.service"; then
        sudo systemctl show "$service_name.service" -p ExecStart 2>/dev/null | grep -o 'localhost:[0-9]*' | cut -d':' -f2
    fi
}

# Function to get service noVNC port
get_service_novnc_port() {
    local service_name="$1"
    if systemctl list-unit-files 2>/dev/null | grep -q "$service_name.service"; then
        sudo systemctl show "$service_name.service" -p ExecStart 2>/dev/null | grep -o 'listen [0-9]*' | cut -d' ' -f2
    fi
}

# Function to test web interface
test_web_interface() {
    local port="$1"
    if [ -n "$port" ] && curl -s -I "http://localhost:$port/vnc.html" 2>/dev/null | grep -q "200 OK"; then
        echo "OK"
    else
        echo "FAIL"
    fi
}

if [ "$JSON_OUTPUT" = false ]; then
    print_header
fi

# Get all unique VNC users with their main process info
declare -A user_info
declare -a repair_commands

while IFS= read -r line; do
    if [ -n "$line" ]; then
        USER=$(echo "$line" | awk '{print $1}')
        VNC_PORT=$(echo "$line" | grep -o 'rfbport [0-9]*' | cut -d' ' -f2)
        DISPLAY=$(echo "$line" | grep -o ':[0-9]*' | head -1)
        
        # Only process main Xtigervnc processes (not session scripts)
        if echo "$line" | grep -q "/usr/bin/Xtigervnc" && [ -n "$VNC_PORT" ] && [ -n "$DISPLAY" ]; then
            # Store the entry for each user (will overwrite if multiple, keeping the last one)
            user_info[$USER]="$USER|$DISPLAY|$VNC_PORT"
        fi
    fi
done <<< "$(ps aux | grep Xtigervnc | grep -v grep)"

if [ ${#user_info[@]} -eq 0 ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        echo '{"vnc_sessions": [], "message": "No VNC servers found running"}'
    else
        echo -e "${YELLOW}No VNC servers found running${NC}"
    fi
    exit 0
fi

if [ "$JSON_OUTPUT" = true ]; then
    echo '{"vnc_sessions": ['
    first_entry=true
fi

if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BLUE}Active VNC Sessions:${NC}"
    echo "=================================================================="
    printf "%-10s %-8s %-8s %-12s %-12s %-15s %s\n" "USER" "DISPLAY" "VNC_PORT" "NOVNC_PORT" "SVC_VNC_PORT" "STATUS" "WEB_URL"
    echo "=================================================================="
fi

for user_data in "${user_info[@]}"; do
    IFS='|' read -r USER DISPLAY VNC_PORT <<< "$user_data"
    
    # Check for corresponding noVNC service
    SERVICE_NAME="novnc-$USER"
    SERVICE_VNC_PORT=""
    NOVNC_PORT=""
    STATUS=""
    STATUS_COLOR=""
    WEB_URL=""
    WEB_TEST=""
    ISSUE_DETECTED=false
    
    if systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE_NAME.service"; then
        SERVICE_VNC_PORT=$(get_service_vnc_port "$SERVICE_NAME")
        NOVNC_PORT=$(get_service_novnc_port "$SERVICE_NAME")
        
        if systemctl is-active --quiet "$SERVICE_NAME.service" 2>/dev/null; then
            # Check for VNC port mismatch
            if [ -n "$SERVICE_VNC_PORT" ] && [ "$SERVICE_VNC_PORT" != "$VNC_PORT" ]; then
                STATUS="MISMATCH"
                STATUS_COLOR="${RED}❌ MISMATCH${NC}"
                ISSUE_DETECTED=true
                repair_commands+=("./setup-novnc-user-enhanced.sh $USER --repair  # Fix VNC port mismatch ($SERVICE_VNC_PORT -> $VNC_PORT)")
            else
                STATUS="ACTIVE"
                STATUS_COLOR="${GREEN}✅ ACTIVE${NC}"
            fi
            
            if [ -n "$NOVNC_PORT" ]; then
                WEB_URL="http://localhost:$NOVNC_PORT/vnc.html"
                if [ "$CHECK_ALL" = true ]; then
                    WEB_TEST=$(test_web_interface "$NOVNC_PORT")
                    if [ "$WEB_TEST" = "FAIL" ]; then
                        STATUS_COLOR="${YELLOW}⚠️  ACTIVE(WEB_FAIL)${NC}"
                        ISSUE_DETECTED=true
                        repair_commands+=("./setup-novnc-user-enhanced.sh $USER --repair  # Fix web interface issue")
                    fi
                fi
            else
                WEB_URL="N/A"
            fi
        else
            STATUS="INACTIVE"
            STATUS_COLOR="${RED}⚠️  INACTIVE${NC}"
            NOVNC_PORT="${NOVNC_PORT:-N/A}"
            WEB_URL="N/A"
            ISSUE_DETECTED=true
            repair_commands+=("sudo systemctl start $SERVICE_NAME.service  # Start inactive service")
        fi
    else
        STATUS="NO_SERVICE"
        STATUS_COLOR="${YELLOW}📵 NO_SERVICE${NC}"
        SERVICE_VNC_PORT="N/A"
        NOVNC_PORT="N/A"
        WEB_URL="N/A"
        repair_commands+=("./setup-novnc-user-enhanced.sh $USER  # Create noVNC service")
    fi
    
    if [ "$JSON_OUTPUT" = true ]; then
        if [ "$first_entry" = false ]; then
            echo ","
        fi
        first_entry=false
        
        cat << EOF
  {
    "user": "$USER",
    "display": "$DISPLAY",
    "vnc_port": $VNC_PORT,
    "novnc_port": "${NOVNC_PORT//N\/A/null}",
    "service_vnc_port": "${SERVICE_VNC_PORT//N\/A/null}",
    "status": "$STATUS",
    "web_url": "${WEB_URL//N\/A/null}",
    "issue_detected": $ISSUE_DETECTED
  }
EOF
    else
        # Clean output without embedded color codes in printf
        printf "%-10s %-8s %-8s %-12s %-12s " "$USER" "$DISPLAY" "$VNC_PORT" "$NOVNC_PORT" "$SERVICE_VNC_PORT"
        echo -e "$STATUS_COLOR $WEB_URL"
    fi
done

if [ "$JSON_OUTPUT" = true ]; then
    echo ""
    echo '],'
    echo '"repair_commands": ['
    first_cmd=true
    for cmd in "${repair_commands[@]}"; do
        if [ "$first_cmd" = false ]; then
            echo ","
        fi
        first_cmd=false
        echo "  \"$cmd\""
    done
    echo ']}'
    exit 0
fi

echo ""
echo -e "${BLUE}Legend:${NC}"
echo -e "  ${GREEN}✅ ACTIVE${NC}       - noVNC service running correctly"
echo -e "  ${RED}❌ MISMATCH${NC}     - VNC port mismatch detected (needs repair)"
echo -e "  ${RED}⚠️  INACTIVE${NC}    - noVNC service exists but stopped"
echo -e "  ${YELLOW}📵 NO_SERVICE${NC}  - No noVNC service configured"

# Show issues and repair commands
if [ ${#repair_commands[@]} -gt 0 ]; then
    echo ""
    echo -e "${PURPLE}🔧 Issues Detected - Repair Commands:${NC}"
    echo "=================================================================="
    for cmd in "${repair_commands[@]}"; do
        echo -e "${CYAN}$cmd${NC}"
    done
    
    if [ "$REPAIR_ALL" = true ]; then
        echo ""
        echo -e "${PURPLE}Auto-repair all issues? (y/N):${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Running auto-repair for all detected issues...${NC}"
            for cmd in "${repair_commands[@]}"; do
                # Extract just the command part (before the #)
                actual_cmd=$(echo "$cmd" | cut -d'#' -f1 | xargs)
                echo -e "${CYAN}Executing: $actual_cmd${NC}"
                eval "$actual_cmd"
                echo ""
            done
        fi
    fi
else
    echo ""
    echo -e "${GREEN}🎉 All services are running correctly!${NC}"
fi

echo ""
echo -e "${BLUE}Quick Actions:${NC}"
echo "  Setup noVNC: ./setup-novnc-user-enhanced.sh <username>"
echo "  Repair service: ./setup-novnc-user-enhanced.sh <username> --repair"
echo "  Check all: $0 --check-all"
echo "  Auto-repair: $0 --repair-all"
