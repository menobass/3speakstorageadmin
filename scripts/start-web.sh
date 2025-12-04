#!/bin/bash

# 3Speak Storage Admin Web Interface Startup Script
# Usage: ./start-web.sh [password] [port]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Check if password and port are provided
PASSWORD=${1:-$(grep WEB_PASSWORD .env 2>/dev/null | cut -d'=' -f2 || echo "admin123")}
PORT=${2:-$(grep WEB_PORT .env 2>/dev/null | cut -d'=' -f2 || echo "3000")}

echo "🎬 Starting 3Speak Storage Admin Web Interface"
echo "=============================================="
echo ""
echo "📦 Building project..."
npm run build > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please check for errors:"
    npm run build
    exit 1
fi

echo "✅ Build successful"
echo ""
echo "🌐 Starting web server..."
echo "   URL: http://localhost:$PORT"
echo "   Password: $PASSWORD"
echo ""
echo "💡 Use Ctrl+C to stop the server"
echo "=============================================="

# Start the web server
export WEB_PASSWORD="$PASSWORD"
export WEB_PORT="$PORT"
npm run web