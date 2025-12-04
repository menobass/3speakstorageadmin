#!/bin/bash

# Install 3Speak IPFS Storage Management as a systemd service
# Usage: sudo ./install-service.sh [user]
#
# Examples:
#   sudo ./install-service.sh           # Uses current user
#   sudo ./install-service.sh www-data  # Uses www-data user

SERVICE_NAME="3speak-ipfs-storage-management"

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Determine user - use argument, SUDO_USER, or default to 'meno'
SERVICE_USER="${1:-${SUDO_USER:-meno}}"
SERVICE_GROUP="$SERVICE_USER"

# Verify user exists
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "❌ User '$SERVICE_USER' does not exist"
    echo "💡 Usage: sudo ./install-service.sh [username]"
    exit 1
fi

echo "🎬 Installing 3Speak IPFS Storage Management Service"
echo "====================================================="
echo "📁 Project path: $PROJECT_ROOT"
echo "👤 Service user: $SERVICE_USER"
echo ""

# Check prerequisites
if [ ! -f "$PROJECT_ROOT/dist/web-server.js" ]; then
    echo "❌ dist/web-server.js not found. Run 'npm run build' first!"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ .env file not found. Copy .env.example and configure it!"
    exit 1
fi

if ! command -v node &>/dev/null; then
    echo "❌ Node.js not found. Please install Node.js first."
    exit 1
fi

NODE_PATH=$(which node)
echo "📦 Node.js: $NODE_PATH"

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"
chown "$SERVICE_USER:$SERVICE_GROUP" "$PROJECT_ROOT/logs"

# Generate service file with correct paths
echo "📋 Generating service file..."
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=3Speak IPFS Storage Management Web Interface
Documentation=https://github.com/menobass/3speakstorageadmin
After=network.target mongodb.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$PROJECT_ROOT
Environment=NODE_ENV=production
EnvironmentFile=$PROJECT_ROOT/.env
ExecStart=$NODE_PATH $PROJECT_ROOT/dist/web-server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=3speak-ipfs-storage-management

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=$PROJECT_ROOT/logs
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload

# Enable service
echo "✅ Enabling service..."
systemctl enable ${SERVICE_NAME}.service

echo ""
echo "🎯 Service installed successfully!"
echo ""
echo "Usage:"
echo "  sudo systemctl start $SERVICE_NAME    # Start the service"
echo "  sudo systemctl stop $SERVICE_NAME     # Stop the service"
echo "  sudo systemctl restart $SERVICE_NAME  # Restart the service"
echo "  sudo systemctl status $SERVICE_NAME   # Check status"
echo "  sudo journalctl -u $SERVICE_NAME -f   # View logs"
echo ""
echo "💡 The service will start automatically on boot"
echo "💡 Configure settings in: $PROJECT_ROOT/.env"