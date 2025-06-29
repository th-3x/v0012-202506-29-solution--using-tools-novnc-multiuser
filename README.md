# 🌐 noVNC Multi-User Tools

A comprehensive toolkit for easily managing noVNC web interfaces for multiple VNC users.

## 🚀 Quick Start

```bash
# List all VNC users and their noVNC status
./list-vnc-users.sh

# Set up noVNC for a user (auto-assigns port)
./setup-novnc-user.sh x3

# Set up noVNC with specific port
./setup-novnc-user.sh x4 6082

# Manage all noVNC services
./manage-novnc-services.sh status
```

## 📋 Tools Overview

### 🔧 setup-novnc-user.sh
**Purpose**: Automatically set up noVNC web interface for any VNC user

**Usage**:
```bash
./setup-novnc-user.sh <username> [novnc_port]
```

**Features**:
- ✅ Auto-detects VNC server port for the user
- ✅ Auto-assigns noVNC port (or use custom port)
- ✅ Creates dedicated systemd service
- ✅ Enables auto-start on boot
- ✅ Validates setup and shows connection info
- ✅ Handles port conflicts gracefully

**Examples**:
```bash
./setup-novnc-user.sh x3              # Auto-assign port
./setup-novnc-user.sh x4 6082         # Use specific port
```

### 📊 list-vnc-users.sh
**Purpose**: Display all VNC users and their noVNC setup status

**Features**:
- ✅ Shows all active VNC sessions
- ✅ Displays VNC and noVNC ports
- ✅ Shows service status (Active/Inactive/No Service)
- ✅ Provides web URLs for easy access
- ✅ Color-coded status indicators

**Sample Output**:
```
USER       DISPLAY  VNC_PORT NOVNC_PORT  STATUS   WEB_URL
==========================================================
x2         :1       5901     6080        ACTIVE   http://localhost:6080/vnc.html
x3         :2       5902     6081        ACTIVE   http://localhost:6081/vnc.html
x4         :3       5903     N/A         NO_SERVICE N/A
```

### 🔧 manage-novnc-services.sh
**Purpose**: Bulk management of all noVNC services

**Usage**:
```bash
./manage-novnc-services.sh <action>
```

**Actions**:
- `status` - Show status of all services
- `start` - Start all services
- `stop` - Stop all services  
- `restart` - Restart all services
- `logs` - Show logs for all services
- `enable` - Enable auto-start for all services
- `disable` - Disable auto-start for all services

### 🗑️ remove-novnc-user.sh
**Purpose**: Safely remove noVNC setup for a specific user

**Usage**:
```bash
./remove-novnc-user.sh <username>
```

**Features**:
- ✅ Stops and disables service
- ✅ Removes service file
- ✅ Preserves VNC server (only removes web interface)
- ✅ Confirmation prompt for safety
- ✅ Clear status reporting

## 🎯 Common Workflows

### Setting Up New User
```bash
# 1. Check current VNC users
./list-vnc-users.sh

# 2. Set up noVNC for new user
./setup-novnc-user.sh x5

# 3. Verify setup
./list-vnc-users.sh
```

### Managing All Services
```bash
# Check status of all services
./manage-novnc-services.sh status

# Restart all services
./manage-novnc-services.sh restart

# View logs
./manage-novnc-services.sh logs
```

### Troubleshooting
```bash
# Check what's running
./list-vnc-users.sh

# Check service logs
./manage-novnc-services.sh logs

# Restart problematic service
sudo systemctl restart novnc-x3.service
```

## 🔌 Port Management

### Default Port Assignment
The tools automatically assign ports based on VNC ports:
- VNC 5901 → noVNC 6080
- VNC 5902 → noVNC 6081  
- VNC 5903 → noVNC 6082
- etc.

### Custom Port Assignment
```bash
# Use specific port
./setup-novnc-user.sh x3 6085

# Check for port conflicts
netstat -tlnp | grep :6085
```

## 🌐 Access Methods

### Local Access
```bash
# Web browser (recommended)
http://localhost:6080/vnc.html  # x2 user
http://localhost:6081/vnc.html  # x3 user

# VNC client
localhost:5901  # x2 user
localhost:5902  # x3 user
```

### Remote Access (SSH Tunnel)
```bash
# Single user
ssh -L 6081:localhost:6081 user@server

# Multiple users
ssh -L 6080:localhost:6080 -L 6081:localhost:6081 -L 6082:localhost:6082 user@server
```

## 🔒 Security Considerations

### Network Security
- noVNC services bind to all interfaces (0.0.0.0)
- Use SSH tunneling for remote access
- Consider firewall rules for production

### Service Security
- Services run as 'nobody' user
- Automatic restart on failure
- Isolated per-user services

## 🛠️ Advanced Usage

### Custom Service Configuration
```bash
# Edit service file directly
sudo systemctl edit novnc-x3.service

# View service configuration
sudo systemctl show novnc-x3.service
```

### Monitoring
```bash
# Watch service status
watch -n 2 './list-vnc-users.sh'

# Monitor logs in real-time
journalctl -u novnc-x3.service -f
```

### Backup/Restore Services
```bash
# Backup service files
sudo cp /etc/systemd/system/novnc-*.service /backup/

# Restore services
sudo cp /backup/novnc-*.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## 🐛 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
sudo systemctl status novnc-x3.service

# Check logs
journalctl -u novnc-x3.service -n 20

# Verify VNC server is running
ps aux | grep x3 | grep vnc
```

#### Port Already in Use
```bash
# Find what's using the port
sudo netstat -tlnp | grep :6081

# Kill process if needed
sudo kill <pid>
```

#### Web Interface Not Loading
```bash
# Verify service is listening
netstat -tlnp | grep :6081

# Check firewall
sudo ufw status

# Test locally
curl -I http://localhost:6081
```

### Log Locations
- Service logs: `journalctl -u novnc-<username>.service`
- VNC logs: `/home/<username>/.vnc/*.log`
- System logs: `/var/log/syslog`

## 📝 Requirements

- Ubuntu/Debian-based system
- Existing VNC users with running VNC servers
- sudo privileges
- noVNC and websockify packages (auto-installed)

## 🤝 Integration

These tools work seamlessly with:
- Existing KDE VNC installer setup
- Manual VNC server configurations
- Any TigerVNC or similar VNC server setup

## 📄 License

Open source - feel free to modify and distribute.

---

**Generated by Amazon Q Assistant**
**Part of the KDE VNC Multi-User Toolkit**
