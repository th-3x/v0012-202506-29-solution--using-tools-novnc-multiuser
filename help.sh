#!/bin/bash

#==============================================================================
# noVNC Multi-User Tools - Help Overview
# Shows all available tools and their usage
#==============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=================================================="
echo "🌐 noVNC Multi-User Tools - Help Overview"
echo "=================================================="
echo -e "${NC}"

echo -e "${BLUE}Available Tools:${NC}"
echo ""

echo -e "${GREEN}📊 ./list-vnc-users.sh${NC}"
echo "   Display all VNC users and their noVNC status"
echo "   Usage: ./list-vnc-users.sh [--help]"
echo ""

echo -e "${GREEN}🔧 ./setup-novnc-user.sh${NC}"
echo "   Set up noVNC web interface for a VNC user"
echo "   Usage: ./setup-novnc-user.sh <username> [port]"
echo "   Example: ./setup-novnc-user.sh x3 6085"
echo ""

echo -e "${GREEN}🔧 ./manage-novnc-services.sh${NC}"
echo "   Manage all noVNC services (start/stop/restart/status)"
echo "   Usage: ./manage-novnc-services.sh <action> [username]"
echo "   Actions: status, summary, start, stop, restart, logs, enable, disable"
echo "   Examples: ./manage-novnc-services.sh restart x2"
echo ""

echo -e "${GREEN}🗑️  ./remove-novnc-user.sh${NC}"
echo "   Remove noVNC setup for a specific user"
echo "   Usage: ./remove-novnc-user.sh <username>"
echo ""

echo -e "${GREEN}🚀 ./quick-setup.sh${NC}"
echo "   Automatically set up noVNC for all VNC users"
echo "   Usage: ./quick-setup.sh"
echo ""

echo -e "${BLUE}Quick Start Examples:${NC}"
echo ""
echo "# See all VNC users and their status"
echo "./list-vnc-users.sh"
echo ""
echo "# Set up noVNC for a new user"
echo "./setup-novnc-user.sh username"
echo ""
echo "# Set up noVNC for all users at once"
echo "./quick-setup.sh"
echo ""
echo "# Check status of all services"
echo "./manage-novnc-services.sh summary"
echo ""
echo "# Restart specific user service"
echo "./manage-novnc-services.sh restart x2"
echo ""

echo -e "${BLUE}Current Status:${NC}"
./list-vnc-users.sh

echo ""
echo -e "${YELLOW}💡 Tip: Use --help or -h with any script for detailed help${NC}"
echo "Example: ./setup-novnc-user.sh --help"
