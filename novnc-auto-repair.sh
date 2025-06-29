#!/bin/bash

#==============================================================================
# noVNC Auto-Repair Daemon
# Continuously monitors and auto-repairs VNC port mismatches
# Usage: ./novnc-auto-repair.sh [start|stop|status|install]
#==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_NAME="novnc-auto-repair"
PID_FILE="/var/run/$DAEMON_NAME.pid"
LOG_FILE="/var/log/$DAEMON_NAME.log"
CHECK_INTERVAL=30  # Check every 30 seconds

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

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

show_help() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "🔧 noVNC Auto-Repair Daemon"
    echo "=================================================="
    echo -e "${NC}"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start    - Start the auto-repair daemon"
    echo "  stop     - Stop the auto-repair daemon"
    echo "  status   - Show daemon status"
    echo "  install  - Install as systemd service"
    echo "  logs     - Show recent logs"
    echo ""
    echo "Features:"
    echo "  ✅ Monitors VNC port changes every $CHECK_INTERVAL seconds"
    echo "  ✅ Auto-repairs port mismatches"
    echo "  ✅ Restarts failed services"
    echo "  ✅ Logs all activities"
    echo "  ✅ Can run as systemd service"
    echo ""
}

# Function to detect VNC server info for a user
detect_vnc_server() {
    local user="$1"
    local vnc_info
    
    vnc_info=$(ps aux | grep "$user" | grep Xtigervnc | head -1)
    if [ -n "$vnc_info" ]; then
        echo "$vnc_info" | grep -o 'rfbport [0-9]*' | cut -d' ' -f2
    fi
}

# Function to get service VNC port
get_service_vnc_port() {
    local service_name="$1"
    if systemctl list-unit-files 2>/dev/null | grep -q "$service_name.service"; then
        sudo systemctl show "$service_name.service" -p ExecStart 2>/dev/null | grep -o 'localhost:[0-9]*' | cut -d':' -f2
    fi
}

# Function to repair a service
repair_service() {
    local username="$1"
    local current_vnc_port="$2"
    local service_name="novnc-$username"
    
    log_message "REPAIR: Starting repair for user $username (VNC port: $current_vnc_port)"
    
    # Get current noVNC port to preserve it
    local current_novnc_port
    current_novnc_port=$(sudo systemctl show "$service_name.service" -p ExecStart 2>/dev/null | grep -o 'listen [0-9]*' | cut -d' ' -f2)
    
    if [ -n "$current_novnc_port" ]; then
        log_message "REPAIR: Preserving noVNC port $current_novnc_port for $username"
        if "$SCRIPT_DIR/setup-novnc-user-enhanced.sh" "$username" "$current_novnc_port" --repair >/dev/null 2>&1; then
            log_message "REPAIR: Successfully repaired service for $username"
            return 0
        else
            log_message "ERROR: Failed to repair service for $username"
            return 1
        fi
    else
        log_message "ERROR: Could not determine current noVNC port for $username"
        return 1
    fi
}

# Main monitoring function
monitor_services() {
    log_message "DAEMON: Starting noVNC auto-repair daemon (PID: $$)"
    
    while true; do
        # Get all VNC users
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                USER=$(echo "$line" | awk '{print $1}')
                VNC_PORT=$(echo "$line" | grep -o 'rfbport [0-9]*' | cut -d' ' -f2)
                
                if echo "$line" | grep -q "/usr/bin/Xtigervnc" && [ -n "$VNC_PORT" ] && [ -n "$USER" ]; then
                    SERVICE_NAME="novnc-$USER"
                    
                    # Check if service exists
                    if systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE_NAME.service"; then
                        SERVICE_VNC_PORT=$(get_service_vnc_port "$SERVICE_NAME")
                        
                        # Check for port mismatch
                        if [ -n "$SERVICE_VNC_PORT" ] && [ "$SERVICE_VNC_PORT" != "$VNC_PORT" ]; then
                            log_message "MISMATCH: User $USER - Service: $SERVICE_VNC_PORT, Actual: $VNC_PORT"
                            repair_service "$USER" "$VNC_PORT"
                        fi
                        
                        # Check if service is running
                        if ! systemctl is-active --quiet "$SERVICE_NAME.service" 2>/dev/null; then
                            log_message "INACTIVE: Service $SERVICE_NAME is not running, attempting restart"
                            if sudo systemctl start "$SERVICE_NAME.service" 2>/dev/null; then
                                log_message "RESTART: Successfully restarted $SERVICE_NAME"
                            else
                                log_message "ERROR: Failed to restart $SERVICE_NAME"
                            fi
                        fi
                    fi
                fi
            fi
        done <<< "$(ps aux | grep Xtigervnc | grep -v grep)"
        
        sleep "$CHECK_INTERVAL"
    done
}

# Daemon control functions
start_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        print_warning "Daemon is already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    print_info "Starting noVNC auto-repair daemon..."
    
    # Create log file if it doesn't exist
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    
    # Start daemon in background
    nohup bash -c "
        echo \$\$ | sudo tee '$PID_FILE' >/dev/null
        $(declare -f monitor_services detect_vnc_server get_service_vnc_port repair_service log_message)
        SCRIPT_DIR='$SCRIPT_DIR'
        CHECK_INTERVAL='$CHECK_INTERVAL'
        LOG_FILE='$LOG_FILE'
        monitor_services
    " >/dev/null 2>&1 &
    
    sleep 2
    
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        print_success "Daemon started successfully (PID: $(cat "$PID_FILE"))"
        print_info "Logs: tail -f $LOG_FILE"
        return 0
    else
        print_error "Failed to start daemon"
        return 1
    fi
}

stop_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        print_warning "Daemon is not running (no PID file)"
        return 1
    fi
    
    local pid
    pid=$(cat "$PID_FILE")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        print_warning "Daemon is not running (stale PID file)"
        sudo rm -f "$PID_FILE"
        return 1
    fi
    
    print_info "Stopping noVNC auto-repair daemon (PID: $pid)..."
    
    if kill "$pid" 2>/dev/null; then
        # Wait for process to stop
        local count=0
        while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done
        
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "Daemon didn't stop gracefully, forcing..."
            kill -9 "$pid" 2>/dev/null
        fi
        
        sudo rm -f "$PID_FILE"
        log_message "DAEMON: Stopped noVNC auto-repair daemon"
        print_success "Daemon stopped successfully"
        return 0
    else
        print_error "Failed to stop daemon"
        return 1
    fi
}

status_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid
        pid=$(cat "$PID_FILE")
        print_success "Daemon is running (PID: $pid)"
        
        # Show recent activity
        if [ -f "$LOG_FILE" ]; then
            echo ""
            print_info "Recent activity (last 5 lines):"
            sudo tail -5 "$LOG_FILE" 2>/dev/null || echo "No recent activity"
        fi
        return 0
    else
        print_warning "Daemon is not running"
        if [ -f "$PID_FILE" ]; then
            sudo rm -f "$PID_FILE"
        fi
        return 1
    fi
}

show_logs() {
    if [ -f "$LOG_FILE" ]; then
        print_info "Recent logs from $LOG_FILE:"
        echo ""
        sudo tail -20 "$LOG_FILE"
    else
        print_warning "No log file found at $LOG_FILE"
    fi
}

install_service() {
    print_info "Installing noVNC auto-repair as systemd service..."
    
    sudo tee "/etc/systemd/system/$DAEMON_NAME.service" > /dev/null << EOF
[Unit]
Description=noVNC Auto-Repair Daemon
After=network.target
Wants=network.target

[Service]
Type=forking
User=root
ExecStart=$SCRIPT_DIR/novnc-auto-repair.sh start
ExecStop=$SCRIPT_DIR/novnc-auto-repair.sh stop
PIDFile=$PID_FILE
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$DAEMON_NAME.service"
    
    print_success "Service installed successfully!"
    print_info "Control with: sudo systemctl [start|stop|status] $DAEMON_NAME.service"
}

# Main script logic
case "${1:-}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    status)
        status_daemon
        ;;
    logs)
        show_logs
        ;;
    install)
        install_service
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
