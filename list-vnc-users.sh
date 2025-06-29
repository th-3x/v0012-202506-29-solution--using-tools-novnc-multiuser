#!/bin/bash

#==============================================================================
# List VNC Users and noVNC Status
# Shows all VNC users and their noVNC setup status
#==============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "🖥️  VNC Users and noVNC Status"
    echo "=================================================="
    echo -e "${NC}"
}

show_help() {
    print_header
    echo "Usage: $0 [options]"
    echo ""
    echo "Description:"
    echo "  Displays all active VNC sessions and their noVNC web interface status"
    echo ""
    echo "Options:"
    echo "  --help, -h   - Show this help message"
    echo ""
    echo "Output columns:"
    echo "  USER         - VNC username"
    echo "  DISPLAY      - VNC display number"
    echo "  VNC_PORT     - VNC server port"
    echo "  NOVNC_PORT   - noVNC web interface port"
    echo "  STATUS       - Service status (ACTIVE/INACTIVE/NO_SERVICE)"
    echo "  WEB_URL      - Direct web access URL"
    echo ""
}

# Check for help option
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

print_header

# Get all unique VNC users with their main process info
declare -A user_info
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
    echo -e "${YELLOW}No VNC servers found running${NC}"
    exit 0
fi

echo -e "${BLUE}Active VNC Sessions:${NC}"
echo "=================================================="
printf "%-10s %-8s %-8s %-12s %-12s %s\n" "USER" "DISPLAY" "VNC_PORT" "NOVNC_PORT" "STATUS" "WEB_URL"
echo "=================================================="

for user_data in "${user_info[@]}"; do
    IFS='|' read -r USER DISPLAY VNC_PORT <<< "$user_data"
    
    # Check for corresponding noVNC service
    SERVICE_NAME="novnc-$USER"
    if systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE_NAME.service"; then
        if systemctl is-active --quiet "$SERVICE_NAME.service" 2>/dev/null; then
            STATUS_COLOR="${GREEN}ACTIVE${NC}"
            # Try to find noVNC port from service
            NOVNC_PORT=$(sudo systemctl show "$SERVICE_NAME.service" -p ExecStart 2>/dev/null | grep -o 'listen [0-9]*' | cut -d' ' -f2)
            if [ -z "$NOVNC_PORT" ]; then
                NOVNC_PORT="Unknown"
                WEB_URL="N/A"
            else
                WEB_URL="http://localhost:$NOVNC_PORT/vnc.html"
            fi
        else
            STATUS_COLOR="${RED}INACTIVE${NC}"
            NOVNC_PORT="N/A"
            WEB_URL="N/A"
        fi
    else
        STATUS_COLOR="${YELLOW}NO_SERVICE${NC}"
        NOVNC_PORT="N/A"
        WEB_URL="N/A"
    fi
    
    # Clean output without embedded color codes in printf
    printf "%-10s %-8s %-8s %-12s " "$USER" "$DISPLAY" "$VNC_PORT" "$NOVNC_PORT"
    echo -e "$STATUS_COLOR $WEB_URL"
done

echo ""
echo -e "${BLUE}Legend:${NC}"
echo -e "  ${GREEN}ACTIVE${NC}     - noVNC service is running"
echo -e "  ${RED}INACTIVE${NC}   - noVNC service exists but stopped"
echo -e "  ${YELLOW}NO_SERVICE${NC} - No noVNC service configured"

echo ""
echo -e "${BLUE}Quick Actions:${NC}"
echo "  Setup noVNC for user: ./setup-novnc-user.sh <username>"
echo "  Manage services: ./manage-novnc-services.sh"
echo "  Remove noVNC: ./remove-novnc-user.sh <username>"
