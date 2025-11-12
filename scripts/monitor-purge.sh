#!/bin/bash

# Monitor S3 purge progress in real-time

echo "=================================================="
echo "  S3 Purge Progress Monitor"
echo "=================================================="
echo ""

while true; do
    echo "🔄 $(date): Checking current status..."
    
    # Get current deleted video count
    DELETED_COUNT=$(npm start -- stats 2>/dev/null | grep -E '^\s*info:\s+deleted:' | grep -oE '[0-9]+' | head -1)
    
    # Get remaining S3 videos to purge
    REMAINING=$(npm start -- purge-s3 --dry-run --limit 1000 2>/dev/null | grep "WILL BE MARKED AS DELETED:" | grep -oE '[0-9]+')
    
    if [ -z "$DELETED_COUNT" ]; then
        echo "❌ Could not get stats - purge might be running"
    else
        echo "📊 Current deleted videos: $DELETED_COUNT"
        if [ -n "$REMAINING" ] && [ "$REMAINING" -gt 0 ]; then
            echo "⏳ Remaining S3 videos to purge: ~$REMAINING (in next 1000 batch)"
            echo "✅ Purge is working - videos are being marked as deleted!"
        else
            echo "🎉 No more S3 videos to purge in current batch!"
            echo "💡 Run with higher --limit to check for more videos"
        fi
    fi
    
    echo "---"
    sleep 10
done