#!/bin/bash

#==============================================================================
# Quick Setup - One-command setup for all VNC users
# Automatically detects all VNC users and sets up noVNC for each
#==============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "🚀 Quick Setup - Auto-configure All VNC Users"
    echo "=================================================="
    echo -e "${NC}"
}

print_header

# Get all VNC users
VNC_USERS=$(ps aux | grep Xtigervnc | grep -v grep | awk '{print $1}' | sort -u)

if [ -z "$VNC_USERS" ]; then
    print_warning "No VNC users found running"
    exit 0
fi

print_info "Found VNC users: $(echo $VNC_USERS | tr '\n' ' ')"
echo ""

for user in $VNC_USERS; do
    print_info "Setting up noVNC for user: $user"
    
    # Check if service already exists
    if systemctl list-unit-files | grep -q "novnc-$user.service"; then
        if systemctl is-active --quiet "novnc-$user.service"; then
            print_success "$user already has active noVNC service"
            continue
        else
            print_info "$user has inactive service, restarting..."
            sudo systemctl start "novnc-$user.service"
            continue
        fi
    fi
    
    # Run setup for this user
    ./setup-novnc-user.sh "$user"
    echo ""
done

print_success "Quick setup completed!"
echo ""
print_info "Run './list-vnc-users.sh' to see all connections"
