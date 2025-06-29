#!/bin/bash

#==============================================================================
# noVNC Multi-User Setup Tool
# Automatically sets up noVNC web interface for any VNC user
# Usage: ./setup-novnc-user.sh [username] [optional_novnc_port]
#==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "🌐 noVNC Multi-User Setup Tool"
    echo "=================================================="
    echo -e "${NC}"
}

show_help() {
    print_header
    echo "Usage: $0 <username> [novnc_port]"
    echo ""
    echo "Arguments:"
    echo "  username     - VNC username to set up noVNC for"
    echo "  novnc_port   - Optional: specific noVNC port to use"
    echo ""
    echo "Examples:"
    echo "  $0 x3              # Auto-assign port"
    echo "  $0 x4 6082         # Use specific port"
    echo "  $0 try01           # Auto-assign port for try01"
    echo "  $0 try01 6085      # Use port 6085 for try01"
    echo ""
    echo "Options:"
    echo "  --help, -h   - Show this help message"
    echo ""
    echo "Notes:"
    echo "  - The VNC server must already be running for the user"
    echo "  - Ports are auto-assigned if not specified"
    echo "  - Port conflicts are detected and reported"
    echo ""
}

# Check for help option
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Check if user provided username
if [ -z "$1" ]; then
    show_help
    exit 1
fi

USERNAME="$1"
CUSTOM_PORT="$2"

print_header

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    print_error "User '$USERNAME' does not exist!"
    exit 1
fi

print_info "Setting up noVNC for user: $USERNAME"

# Find VNC process for this user
VNC_INFO=$(ps aux | grep "$USERNAME" | grep Xtigervnc | head -1)
if [ -z "$VNC_INFO" ]; then
    print_error "No VNC server found for user '$USERNAME'"
    print_info "Please start VNC server for this user first"
    exit 1
fi

# Extract VNC port from process info
VNC_PORT=$(echo "$VNC_INFO" | grep -o 'rfbport [0-9]*' | cut -d' ' -f2)
VNC_DISPLAY=$(echo "$VNC_INFO" | grep -o ':[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$VNC_PORT" ]; then
    print_error "Could not determine VNC port for user '$USERNAME'"
    exit 1
fi

print_success "Found VNC server for $USERNAME on port $VNC_PORT (display :$VNC_DISPLAY)"

# Determine noVNC port
if [ -n "$CUSTOM_PORT" ]; then
    NOVNC_PORT="$CUSTOM_PORT"
else
    # Auto-assign port based on VNC port (5901->6080, 5902->6081, etc.)
    NOVNC_PORT=$((VNC_PORT + 179))
fi

# Check if noVNC port is already in use
if netstat -tlnp 2>/dev/null | grep -q ":$NOVNC_PORT "; then
    print_error "Port $NOVNC_PORT is already in use!"
    
    # Suggest available ports
    print_info "Checking for available ports..."
    SUGGESTED_PORTS=""
    for port in {6080..6090}; do
        if ! netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            if [ -z "$SUGGESTED_PORTS" ]; then
                SUGGESTED_PORTS="$port"
            else
                SUGGESTED_PORTS="$SUGGESTED_PORTS, $port"
            fi
            # Only suggest first 3 available ports
            if [ $(echo "$SUGGESTED_PORTS" | tr ',' '\n' | wc -l) -ge 3 ]; then
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
        print_warning "No available ports found in range 6080-6090"
    fi
    
    exit 1
fi

print_info "Will use noVNC port: $NOVNC_PORT"

# Check if service already exists
SERVICE_NAME="novnc-$USERNAME"
if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
    print_warning "Service $SERVICE_NAME already exists"
    print_info "Stopping and removing existing service..."
    sudo systemctl stop "$SERVICE_NAME.service" 2>/dev/null || true
    sudo systemctl disable "$SERVICE_NAME.service" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    sudo systemctl daemon-reload
    print_info "Existing service removed, creating new one..."
fi

# Install noVNC if not already installed
if ! command -v websockify &> /dev/null; then
    print_info "Installing noVNC and websockify..."
    sudo apt update
    sudo apt install -y novnc websockify python3-websockify
fi

# Create systemd service
print_info "Creating systemd service: $SERVICE_NAME"
sudo tee "/etc/systemd/system/$SERVICE_NAME.service" > /dev/null << EOF
[Unit]
Description=noVNC Web Interface for $USERNAME
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/share/novnc/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
print_info "Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME.service"
sudo systemctl start "$SERVICE_NAME.service"

# Wait a moment for service to start
sleep 2

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    print_success "Service started successfully!"
else
    print_error "Service failed to start!"
    print_info "Checking service status..."
    sudo systemctl status "$SERVICE_NAME.service" --no-pager
    exit 1
fi

# Verify port is listening
if netstat -tlnp 2>/dev/null | grep -q ":$NOVNC_PORT "; then
    print_success "noVNC is listening on port $NOVNC_PORT"
else
    print_warning "Port $NOVNC_PORT doesn't appear to be listening yet"
fi

# Display connection information
echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo "=================================================="
echo -e "${BLUE}Connection Information:${NC}"
echo "  User: $USERNAME"
echo "  VNC Port: $VNC_PORT"
echo "  noVNC Port: $NOVNC_PORT"
echo ""
echo -e "${BLUE}Access Methods:${NC}"
echo "  🌐 Web Browser: http://localhost:$NOVNC_PORT/vnc.html"
echo "  🖥️  VNC Client: localhost:$VNC_PORT"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "  Status: sudo systemctl status $SERVICE_NAME.service"
echo "  Restart: sudo systemctl restart $SERVICE_NAME.service"
echo "  Logs: journalctl -u $SERVICE_NAME.service -f"
echo ""
echo -e "${BLUE}For Remote Access (SSH Tunnel):${NC}"
echo "  ssh -L $NOVNC_PORT:localhost:$NOVNC_PORT -L $VNC_PORT:localhost:$VNC_PORT user@server-ip"
echo "=================================================="
