#!/bin/bash

# 3Speak Storage Admin - Quick Status Check
# This script shows a quick overview of the storage status

echo "========================================"
echo "  3Speak Storage Admin - Status Check"
echo "========================================"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
    echo "❌ ERROR: Please run this script from the 3speakstorageadmin directory"
    exit 1
fi

# Build the project if needed
if [ ! -d "dist" ]; then
    echo "📦 Building project (first run)..."
    npm run build > /dev/null 2>&1
    echo ""
fi

echo "📊 Current Storage Statistics:"
echo "========================================"
npm start -- stats --detailed 2>/dev/null

echo ""
echo "🎯 Cleanup Opportunities:"
echo "========================================"

# Check admin-deleted videos
DELETED_COUNT=$(npm start -- list --status deleted --limit 1 2>/dev/null | grep -o "Found [0-9]* videos" | grep -o "[0-9]*" || echo "0")
if [ "$DELETED_COUNT" != "0" ]; then
    echo "🔥 Admin-deleted videos ready for S3 cleanup"
    echo "   Run: ./scripts/free-deleted-videos.sh"
else
    echo "✅ No admin-deleted videos need cleanup"
fi

# Check banned user content  
BANNED_COUNT=$(npm start -- list --banned-users --limit 1 2>/dev/null | grep -o "Found [0-9]* videos" | grep -o "[0-9]*" || echo "0")
if [ "$BANNED_COUNT" != "0" ]; then
    echo "⚠️  Banned user content found"
    echo "   Run: ./scripts/remove-banned-content.sh"
else
    echo "✅ No banned user content found"
fi

# Check stuck uploads (90+ days)
STUCK_COUNT=$(npm start -- list --stuck-days 90 --limit 1 2>/dev/null | grep -o "Found [0-9]* videos" | grep -o "[0-9]*" || echo "0")
if [ "$STUCK_COUNT" != "0" ]; then
    echo "📦 Stuck uploads (90+ days) found"
    echo "   Run: ./scripts/clean-stuck-uploads.sh"
else
    echo "✅ No old stuck uploads found"
fi

echo ""
🛠️  Available Scripts:**
echo "========================================"
echo "./scripts/status-check.sh            - This status overview"
echo "./scripts/free-deleted-videos.sh     - Clean admin-deleted S3 videos (SAFEST)"
echo "./scripts/free-deleted-ipfs.sh       - Clean admin-deleted IPFS videos"
echo "./scripts/clean-failed-encodings.sh  - Remove failed encoding videos (BIG WINS)"
echo "./scripts/remove-banned-content.sh   - Remove banned user content"  
echo "./scripts/clean-stuck-uploads.sh     - Clean old stuck uploads"
echo "./scripts/clean-low-engagement.sh    - Remove low-engagement videos (CAUTION!)"
echo ""
echo "💡 Recommended order: free-deleted-videos.sh → clean-failed-encodings.sh"
echo "========================================"