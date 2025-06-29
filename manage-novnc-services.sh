#!/bin/bash

#==============================================================================
# Manage noVNC Services
# Start, stop, restart, or check status of all noVNC services
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
    echo "🔧 noVNC Services Manager"
    echo "=================================================="
    echo -e "${NC}"
}

show_usage() {
    echo "Usage: $0 <action> [service_name]"
    echo ""
    echo "Actions:"
    echo "  status    - Show detailed status of all noVNC services"
    echo "  summary   - Show brief status summary of all services"
    echo "  start     - Start all noVNC services (or specific service)"
    echo "  stop      - Stop all noVNC services (or specific service)"
    echo "  restart   - Restart all noVNC services (or specific service)"
    echo "  logs      - Show logs for all services (or specific service)"
    echo "  enable    - Enable all services for auto-start (or specific service)"
    echo "  disable   - Disable auto-start for all services (or specific service)"
    echo ""
    echo "Examples:"
    echo "  $0 summary                    # Show status of all services"
    echo "  $0 restart                   # Restart all services"
    echo "  $0 enable try01              # Enable auto-start for try01 only"
    echo "  $0 start x2                  # Start x2 service only"
    echo "  $0 logs dev-rf1              # Show logs for dev-rf1 only"
    echo ""
}

get_novnc_services() {
    systemctl list-unit-files | grep "novnc.*\.service" | awk '{print $1}' | grep -v "^novnc\.service$"
}

ACTION="$1"
TARGET_USER="$2"

if [ -z "$ACTION" ]; then
    print_header
    show_usage
    exit 1
fi

print_header

# Get all noVNC services (excluding the main novnc.service)
ALL_SERVICES=$(get_novnc_services)

if [ -z "$ALL_SERVICES" ]; then
    print_warning "No noVNC user services found"
    print_info "Use ./setup-novnc-user.sh to create services for users"
    exit 0
fi

# Determine which services to operate on
if [ -n "$TARGET_USER" ]; then
    # Single service operation
    TARGET_SERVICE="novnc-$TARGET_USER.service"
    if echo "$ALL_SERVICES" | grep -q "^$TARGET_SERVICE$"; then
        SERVICES="$TARGET_SERVICE"
        print_info "Operating on service: $TARGET_SERVICE"
    else
        print_error "Service '$TARGET_SERVICE' not found!"
        echo ""
        print_info "Available services:"
        for service in $ALL_SERVICES; do
            username=$(echo "$service" | sed 's/novnc-\(.*\)\.service/\1/')
            echo "  $username (service: $service)"
        done
        exit 1
    fi
else
    # All services operation
    SERVICES="$ALL_SERVICES"
    print_info "Operating on all noVNC services..."
fi

case "$ACTION" in
    "status")
        if [ -n "$TARGET_USER" ]; then
            print_info "Checking status of noVNC service for $TARGET_USER..."
        else
            print_info "Checking status of all noVNC services..."
        fi
        echo ""
        for service in $SERVICES; do
            echo -e "${BLUE}Service: $service${NC}"
            sudo systemctl status "$service" --no-pager -l
            echo ""
        done
        ;;
        
    "summary")
        if [ -n "$TARGET_USER" ]; then
            print_info "Service status for $TARGET_USER:"
        else
            print_info "Service status summary:"
        fi
        echo "=================================================="
        for service in $SERVICES; do
            if systemctl is-active --quiet "$service"; then
                status="ACTIVE"
                status_color="${GREEN}ACTIVE${NC}"
            else
                status="INACTIVE"
                status_color="${RED}INACTIVE${NC}"
            fi
            
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                enabled="ENABLED"
                enabled_color="${GREEN}ENABLED${NC}"
            else
                enabled="DISABLED"
                enabled_color="${YELLOW}DISABLED${NC}"
            fi
            
            printf "%-20s Status: " "$service"
            echo -e "$status_color Auto-start: $enabled_color"
        done
        ;;
        
    "start")
        if [ -n "$TARGET_USER" ]; then
            print_info "Starting noVNC service for $TARGET_USER..."
        else
            print_info "Starting all noVNC services..."
        fi
        for service in $SERVICES; do
            print_info "Starting $service..."
            if sudo systemctl start "$service"; then
                print_success "$service started"
            else
                print_error "Failed to start $service"
            fi
        done
        ;;
        
    "stop")
        if [ -n "$TARGET_USER" ]; then
            print_info "Stopping noVNC service for $TARGET_USER..."
        else
            print_info "Stopping all noVNC services..."
        fi
        for service in $SERVICES; do
            print_info "Stopping $service..."
            if sudo systemctl stop "$service"; then
                print_success "$service stopped"
            else
                print_error "Failed to stop $service"
            fi
        done
        ;;
        
    "restart")
        if [ -n "$TARGET_USER" ]; then
            print_info "Restarting noVNC service for $TARGET_USER..."
        else
            print_info "Restarting all noVNC services..."
        fi
        for service in $SERVICES; do
            print_info "Restarting $service..."
            if sudo systemctl restart "$service"; then
                print_success "$service restarted"
            else
                print_error "Failed to restart $service"
            fi
        done
        ;;
        
    "logs")
        if [ -n "$TARGET_USER" ]; then
            print_info "Showing logs for $TARGET_USER..."
        else
            print_info "Showing logs for all noVNC services..."
        fi
        echo ""
        for service in $SERVICES; do
            echo -e "${BLUE}=== Logs for $service ===${NC}"
            journalctl -u "$service" --no-pager -n 10
            echo ""
        done
        ;;
        
    "enable")
        if [ -n "$TARGET_USER" ]; then
            print_info "Enabling auto-start for $TARGET_USER..."
        else
            print_info "Enabling auto-start for all noVNC services..."
        fi
        for service in $SERVICES; do
            print_info "Enabling $service..."
            if sudo systemctl enable "$service"; then
                print_success "$service enabled"
            else
                print_error "Failed to enable $service"
            fi
        done
        ;;
        
    "disable")
        if [ -n "$TARGET_USER" ]; then
            print_info "Disabling auto-start for $TARGET_USER..."
        else
            print_info "Disabling auto-start for all noVNC services..."
        fi
        for service in $SERVICES; do
            print_info "Disabling $service..."
            if sudo systemctl disable "$service"; then
                print_success "$service disabled"
            else
                print_error "Failed to disable $service"
            fi
        done
        ;;
        
    *)
        print_error "Unknown action: $ACTION"
        echo ""
        show_usage
        exit 1
        ;;
esac

# Show summary at the end for most commands (except summary itself)
if [ "$ACTION" != "summary" ] && [ "$ACTION" != "logs" ]; then
    echo ""
    print_info "Current service status:"
    echo "=================================================="
    for service in $SERVICES; do
        if systemctl is-active --quiet "$service"; then
            status="ACTIVE"
            status_color="${GREEN}ACTIVE${NC}"
        else
            status="INACTIVE"
            status_color="${RED}INACTIVE${NC}"
        fi
        
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            enabled="ENABLED"
            enabled_color="${GREEN}ENABLED${NC}"
        else
            enabled="DISABLED"
            enabled_color="${YELLOW}DISABLED${NC}"
        fi
        
        printf "%-20s Status: " "$service"
        echo -e "$status_color Auto-start: $enabled_color"
    done
fi
