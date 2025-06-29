#!/bin/bash

#==============================================================================
# Enhanced noVNC Multi-User Setup Tool
# Automatically sets up noVNC web interface with auto-repair capabilities
# Usage: ./setup-novnc-user-enhanced.sh [username] [optional_novnc_port]
#==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

print_repair() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "🌐 Enhanced noVNC Multi-User Setup Tool"
    echo "=================================================="
    echo -e "${NC}"
}

show_help() {
    print_header
    echo "Usage: $0 <username> [novnc_port] [options]"
    echo ""
    echo "Arguments:"
    echo "  username     - VNC username to set up noVNC for"
    echo "  novnc_port   - Optional: specific noVNC port to use"
    echo ""
    echo "Options:"
    echo "  --repair     - Force repair of existing service"
    echo "  --force      - Force recreation even if working"
    echo "  --help, -h   - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 x3              # Auto-assign port"
    echo "  $0 x4 6082         # Use specific port"
    echo "  $0 try01 --repair  # Repair existing service"
    echo "  $0 try01 6085 --force # Force recreation"
    echo ""
    echo "Features:"
    echo "  ✅ Auto-detects VNC port changes"
    echo "  ✅ Repairs mismatched configurations"
    echo "  ✅ Handles port conflicts intelligently"
    echo "  ✅ Creates robust systemd services"
    echo "  ✅ Validates setup thoroughly"
    echo ""
}

# Parse arguments
USERNAME=""
CUSTOM_PORT=""
REPAIR_MODE=false
FORCE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --repair)
            REPAIR_MODE=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$USERNAME" ]; then
                USERNAME="$1"
            elif [ -z "$CUSTOM_PORT" ]; then
                CUSTOM_PORT="$1"
            else
                print_error "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if user provided username
if [ -z "$USERNAME" ]; then
    show_help
    exit 1
fi

print_header

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    print_error "User '$USERNAME' does not exist!"
    exit 1
fi

print_info "Setting up noVNC for user: $USERNAME"

# Function to detect VNC server info
detect_vnc_server() {
    local user="$1"
    local vnc_info
    
    # Find VNC process for this user
    vnc_info=$(ps aux | grep "$user" | grep Xtigervnc | head -1)
    if [ -z "$vnc_info" ]; then
        return 1
    fi
    
    # Extract VNC port and display
    VNC_PORT=$(echo "$vnc_info" | grep -o 'rfbport [0-9]*' | cut -d' ' -f2)
    VNC_DISPLAY=$(echo "$vnc_info" | grep -o ':[0-9]*' | head -1 | cut -d':' -f2)
    
    if [ -z "$VNC_PORT" ] || [ -z "$VNC_DISPLAY" ]; then
        return 1
    fi
    
    return 0
}

# Function to get current service VNC port
get_service_vnc_port() {
    local service_name="$1"
    local service_vnc_port
    
    if systemctl list-unit-files 2>/dev/null | grep -q "$service_name.service"; then
        service_vnc_port=$(sudo systemctl show "$service_name.service" -p ExecStart 2>/dev/null | grep -o 'localhost:[0-9]*' | cut -d':' -f2)
        echo "$service_vnc_port"
        return 0
    fi
    return 1
}

# Function to get current service noVNC port
get_service_novnc_port() {
    local service_name="$1"
    local service_novnc_port
    
    if systemctl list-unit-files 2>/dev/null | grep -q "$service_name.service"; then
        service_novnc_port=$(sudo systemctl show "$service_name.service" -p ExecStart 2>/dev/null | grep -o 'listen [0-9]*' | cut -d' ' -f2)
        echo "$service_novnc_port"
        return 0
    fi
    return 1
}

# Detect current VNC server
if ! detect_vnc_server "$USERNAME"; then
    print_error "No VNC server found for user '$USERNAME'"
    print_info "Please start VNC server for this user first"
    exit 1
fi

print_success "Found VNC server for $USERNAME on port $VNC_PORT (display :$VNC_DISPLAY)"

# Check if service already exists
SERVICE_NAME="novnc-$USERNAME"
SERVICE_EXISTS=false
NEEDS_REPAIR=false

if systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE_NAME.service"; then
    SERVICE_EXISTS=true
    print_info "Existing service found: $SERVICE_NAME"
    
    # Check if service VNC port matches current VNC port
    CURRENT_SERVICE_VNC_PORT=$(get_service_vnc_port "$SERVICE_NAME")
    CURRENT_SERVICE_NOVNC_PORT=$(get_service_novnc_port "$SERVICE_NAME")
    
    if [ "$CURRENT_SERVICE_VNC_PORT" != "$VNC_PORT" ]; then
        NEEDS_REPAIR=true
        print_warning "Service VNC port mismatch detected!"
        print_warning "Service configured for port: $CURRENT_SERVICE_VNC_PORT"
        print_warning "Actual VNC server on port: $VNC_PORT"
    fi
    
    # Check if service is running
    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        if [ "$NEEDS_REPAIR" = true ]; then
            print_repair "Service is running but needs port repair"
        elif [ "$FORCE_MODE" = false ]; then
            print_success "Service is already running correctly!"
            print_info "Web URL: http://localhost:$CURRENT_SERVICE_NOVNC_PORT/vnc.html"
            print_info "Use --force to recreate or --repair to fix any issues"
            exit 0
        fi
    else
        print_warning "Service exists but is not running"
        NEEDS_REPAIR=true
    fi
fi

# Determine if we need to repair or create
if [ "$SERVICE_EXISTS" = true ] && ([ "$NEEDS_REPAIR" = true ] || [ "$REPAIR_MODE" = true ] || [ "$FORCE_MODE" = true ]); then
    print_repair "Repairing/updating existing service..."
    
    # Stop existing service
    print_info "Stopping existing service..."
    sudo systemctl stop "$SERVICE_NAME.service" 2>/dev/null || true
    
    # Get the current noVNC port if we want to keep it
    if [ -z "$CUSTOM_PORT" ] && [ -n "$CURRENT_SERVICE_NOVNC_PORT" ]; then
        CUSTOM_PORT="$CURRENT_SERVICE_NOVNC_PORT"
        print_info "Keeping existing noVNC port: $CUSTOM_PORT"
    fi
fi

# Determine noVNC port
if [ -n "$CUSTOM_PORT" ]; then
    NOVNC_PORT="$CUSTOM_PORT"
else
    # Auto-assign port based on VNC port (5901->6080, 5902->6081, etc.)
    NOVNC_PORT=$((VNC_PORT + 179))
fi

# Check if noVNC port is already in use (by another service)
if netstat -tlnp 2>/dev/null | grep -q ":$NOVNC_PORT " && ! sudo systemctl is-active --quiet "$SERVICE_NAME.service"; then
    print_error "Port $NOVNC_PORT is already in use by another service!"
    
    # Find what's using the port
    PORT_USER=$(netstat -tlnp 2>/dev/null | grep ":$NOVNC_PORT " | awk '{print $7}' | head -1)
    if [ -n "$PORT_USER" ]; then
        print_info "Port is being used by: $PORT_USER"
    fi
    
    # Suggest available ports
    print_info "Checking for available ports..."
    SUGGESTED_PORTS=""
    for port in {6080..6100}; do
        if ! netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            if [ -z "$SUGGESTED_PORTS" ]; then
                SUGGESTED_PORTS="$port"
            else
                SUGGESTED_PORTS="$SUGGESTED_PORTS, $port"
            fi
            # Only suggest first 5 available ports
            if [ $(echo "$SUGGESTED_PORTS" | tr ',' '\n' | wc -l) -ge 5 ]; then
                break
            fi
        fi
    done
    
    if [ -n "$SUGGESTED_PORTS" ]; then
        print_info "Available ports: $SUGGESTED_PORTS"
        echo ""
        echo "Try one of these commands:"
        for port in $(echo "$SUGGESTED_PORTS" | tr ',' '\n' | head -3); do
            port=$(echo "$port" | xargs) # trim whitespace
            echo "  $0 $USERNAME $port"
        done
    else
        print_warning "No available ports found in range 6080-6100"
    fi
    
    exit 1
fi

print_info "Will use noVNC port: $NOVNC_PORT"

# Install noVNC if not already installed
if ! command -v websockify &> /dev/null; then
    print_info "Installing noVNC and websockify..."
    sudo apt update
    sudo apt install -y novnc websockify python3-websockify
fi

# Create enhanced systemd service with auto-restart and monitoring
print_info "Creating enhanced systemd service: $SERVICE_NAME"
sudo tee "/etc/systemd/system/$SERVICE_NAME.service" > /dev/null << EOF
[Unit]
Description=noVNC Web Interface for $USERNAME (Enhanced)
After=network.target
Wants=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/usr/share/novnc/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp

# Resource limits
MemoryMax=256M
TasksMax=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=novnc-$USERNAME

[Install]
WantedBy=multi-user.target
EOF

# Create a monitoring script for this service
MONITOR_SCRIPT="/usr/local/bin/novnc-monitor-$USERNAME.sh"
print_info "Creating monitoring script: $MONITOR_SCRIPT"
sudo tee "$MONITOR_SCRIPT" > /dev/null << 'EOF'
#!/bin/bash
# Auto-generated monitoring script for noVNC service
# This script can detect and repair VNC port changes

USERNAME="$1"
SERVICE_NAME="novnc-$USERNAME"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

# Function to detect current VNC port
detect_current_vnc_port() {
    local vnc_info
    vnc_info=$(ps aux | grep "$USERNAME" | grep Xtigervnc | head -1)
    if [ -n "$vnc_info" ]; then
        echo "$vnc_info" | grep -o 'rfbport [0-9]*' | cut -d' ' -f2
    fi
}

# Function to get service configured VNC port
get_service_vnc_port() {
    sudo systemctl show "$SERVICE_NAME.service" -p ExecStart 2>/dev/null | grep -o 'localhost:[0-9]*' | cut -d':' -f2
}

CURRENT_VNC_PORT=$(detect_current_vnc_port)
SERVICE_VNC_PORT=$(get_service_vnc_port)

if [ -n "$CURRENT_VNC_PORT" ] && [ -n "$SERVICE_VNC_PORT" ] && [ "$CURRENT_VNC_PORT" != "$SERVICE_VNC_PORT" ]; then
    echo "VNC port mismatch detected for $USERNAME"
    echo "Current VNC port: $CURRENT_VNC_PORT"
    echo "Service configured for: $SERVICE_VNC_PORT"
    echo "Auto-repair needed - run: ./setup-novnc-user-enhanced.sh $USERNAME --repair"
    exit 1
fi

echo "VNC port configuration is correct for $USERNAME"
exit 0
EOF

sudo chmod +x "$MONITOR_SCRIPT"

# Enable and start service
print_info "Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME.service"
sudo systemctl start "$SERVICE_NAME.service"

# Wait a moment for service to start
sleep 3

# Comprehensive service validation
print_info "Validating service setup..."

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    print_success "Service is active and running!"
else
    print_error "Service failed to start!"
    print_info "Checking service status and logs..."
    sudo systemctl status "$SERVICE_NAME.service" --no-pager -l
    echo ""
    print_info "Recent logs:"
    journalctl -u "$SERVICE_NAME.service" -n 10 --no-pager
    exit 1
fi

# Verify port is listening
if netstat -tlnp 2>/dev/null | grep -q ":$NOVNC_PORT "; then
    print_success "noVNC is listening on port $NOVNC_PORT"
else
    print_warning "Port $NOVNC_PORT doesn't appear to be listening yet"
    print_info "Waiting 5 more seconds..."
    sleep 5
    if netstat -tlnp 2>/dev/null | grep -q ":$NOVNC_PORT "; then
        print_success "noVNC is now listening on port $NOVNC_PORT"
    else
        print_error "Port still not listening - check service logs"
    fi
fi

# Test web interface accessibility
print_info "Testing web interface..."
if curl -s -I "http://localhost:$NOVNC_PORT/vnc.html" | grep -q "200 OK"; then
    print_success "Web interface is accessible!"
else
    print_warning "Web interface test failed - may need a moment to fully start"
fi

# Display comprehensive connection information
echo ""
echo -e "${GREEN}🎉 Enhanced Setup Complete!${NC}"
echo "=================================================="
echo -e "${BLUE}Connection Information:${NC}"
echo "  User: $USERNAME"
echo "  VNC Display: :$VNC_DISPLAY"
echo "  VNC Port: $VNC_PORT"
echo "  noVNC Port: $NOVNC_PORT"
echo "  Service: $SERVICE_NAME.service"
echo ""
echo -e "${BLUE}Access Methods:${NC}"
echo "  🌐 Web Browser: http://localhost:$NOVNC_PORT/vnc.html"
echo "  🖥️  VNC Client: localhost:$VNC_PORT"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "  Status: sudo systemctl status $SERVICE_NAME.service"
echo "  Restart: sudo systemctl restart $SERVICE_NAME.service"
echo "  Logs: journalctl -u $SERVICE_NAME.service -f"
echo "  Monitor: $MONITOR_SCRIPT $USERNAME"
echo ""
echo -e "${BLUE}Repair Commands:${NC}"
echo "  Auto-repair: $0 $USERNAME --repair"
echo "  Force recreate: $0 $USERNAME --force"
echo ""
echo -e "${BLUE}For Remote Access (SSH Tunnel):${NC}"
echo "  ssh -L $NOVNC_PORT:localhost:$NOVNC_PORT user@server-ip"
echo "  Then access: http://localhost:$NOVNC_PORT/vnc.html"
echo "=================================================="

# Create a quick status check
echo ""
print_info "Quick status check in 3 seconds..."
sleep 3
"$MONITOR_SCRIPT" "$USERNAME"
