#!/bin/bash

# Install IPFS Gentle GC as a systemd timer
# Usage: sudo ./install-gc-timer.sh

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🗑️  Installing IPFS Gentle GC Timer"
echo "===================================="

# Copy service and timer files
echo "📋 Installing service files..."
cp "$PROJECT_ROOT/ipfs-gentle-gc.service" /etc/systemd/system/
cp "$PROJECT_ROOT/ipfs-gentle-gc.timer" /etc/systemd/system/
chown root:root /etc/systemd/system/ipfs-gentle-gc.*
chmod 644 /etc/systemd/system/ipfs-gentle-gc.*

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload

# Enable timer (not service - timer triggers the service)
echo "✅ Enabling timer..."
systemctl enable ipfs-gentle-gc.timer
systemctl start ipfs-gentle-gc.timer

echo ""
echo "🎯 Timer installed successfully!"
echo ""
echo "Usage:"
echo "  sudo systemctl status ipfs-gentle-gc.timer  # Check timer status"
echo "  sudo systemctl list-timers                  # List all timers"
echo "  sudo journalctl -u ipfs-gentle-gc -f        # View GC logs"
echo ""
echo "Manual run (for testing):"
echo "  sudo systemctl start ipfs-gentle-gc.service # Run GC now"
echo "  $PROJECT_ROOT/scripts/gentle-gc.sh --dry-run # Preview what would happen"
echo "  $PROJECT_ROOT/scripts/gentle-gc.sh --force   # Run now (ignore time window)"
echo ""
echo "⏰ Timer will trigger at 2:00 AM daily"
echo "🔄 GC runs in 5-min bursts with 10-min pauses"
echo "🛡️  Auto-stops if system load is too high"
