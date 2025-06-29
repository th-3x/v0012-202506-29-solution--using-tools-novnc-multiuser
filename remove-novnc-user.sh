#!/bin/bash

#==============================================================================
# Remove noVNC Setup for User
# Safely removes noVNC service for a specific user
#==============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "🗑️  Remove noVNC User Setup"
    echo "=================================================="
    echo -e "${NC}"
}

if [ -z "$1" ]; then
    print_header
    print_error "Usage: $0 <username>"
    echo ""
    echo "This will remove the noVNC service for the specified user."
    echo "The VNC server itself will NOT be affected."
    echo ""
    exit 1
fi

USERNAME="$1"
SERVICE_NAME="novnc-$USERNAME"

print_header
print_info "Removing noVNC setup for user: $USERNAME"

# Check if service exists
if ! systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
    print_error "No noVNC service found for user '$USERNAME'"
    exit 1
fi

# Show current status
print_info "Current service status:"
sudo systemctl status "$SERVICE_NAME.service" --no-pager -l

echo ""
print_warning "This will:"
echo "  - Stop the noVNC service for $USERNAME"
echo "  - Disable auto-start"
echo "  - Remove the service file"
echo "  - The VNC server will continue running"

echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Operation cancelled"
    exit 0
fi

# Stop the service
print_info "Stopping service..."
if sudo systemctl stop "$SERVICE_NAME.service"; then
    print_success "Service stopped"
else
    print_warning "Service may already be stopped"
fi

# Disable the service
print_info "Disabling service..."
if sudo systemctl disable "$SERVICE_NAME.service"; then
    print_success "Service disabled"
else
    print_warning "Service may already be disabled"
fi

# Remove service file
print_info "Removing service file..."
if sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"; then
    print_success "Service file removed"
else
    print_error "Failed to remove service file"
fi

# Reload systemd
print_info "Reloading systemd..."
sudo systemctl daemon-reload

print_success "noVNC setup removed for user '$USERNAME'"

echo ""
print_info "Summary:"
echo "  ✅ Service stopped and removed"
echo "  ✅ Auto-start disabled"
echo "  ℹ️  VNC server for $USERNAME is still running"
echo ""
print_info "To set up noVNC again: ./setup-novnc-user.sh $USERNAME"
