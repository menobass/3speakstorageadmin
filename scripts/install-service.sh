#!/bin/bash

# Install 3Speak IPFS Storage Management as a systemd service
# Usage: sudo ./install-service.sh

SERVICE_NAME="3speak-ipfs-storage-management"

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🎬 Installing 3Speak IPFS Storage Management Service"
echo "====================================================="

# Copy service file
echo "📋 Installing service file..."
cp "$PROJECT_ROOT/${SERVICE_NAME}.service" /etc/systemd/system/
chown root:root /etc/systemd/system/${SERVICE_NAME}.service
chmod 644 /etc/systemd/system/${SERVICE_NAME}.service

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