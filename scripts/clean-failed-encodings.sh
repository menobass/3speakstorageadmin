#!/bin/bash

# 3Speak Storage Admin - Clean Failed Encodings
# This script removes videos that failed during the encoding process

echo "================================================"
echo "  3Speak Storage Admin - Clean Failed Encodings"
echo "================================================"
echo ""
echo "This script removes videos with failed encoding statuses:"
echo "- 'encoding_failed' (system-generated failures)"
echo "- 'failed' (manually marked by admins)"
echo ""
echo "These videos are wasting storage space and will"
echo "never be successfully published."
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
    echo "❌ ERROR: Please run this script from the 3speakstorageadmin directory"
    exit 1
fi

# Build the project first
echo "📦 Building project..."
npm run build > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please check for errors."
    exit 1
fi

echo "✅ Project built successfully"
echo ""

# Step 1: Show failed encoding statistics
echo "📊 Checking failed encoding statistics..."
STATS=$(npm start -- stats 2>/dev/null)
echo "$STATS" | grep -E "(encoding_failed|failed):"
echo ""

# Step 2: Ask which type of failed videos to clean
echo "🎯 Failed Video Categories:"
echo ""
echo "Choose what to clean:"
echo "  1) encoding_failed only  - System-detected encoding failures"
echo "  2) failed only           - Admin-marked failed videos"
echo "  3) Both types            - All failed videos (Recommended)"
echo ""

while true; do
    read -p "Choose category [1-3]: " category_choice
    case $category_choice in
        1) STATUS_FILTER="encoding_failed"; DESCRIPTION="system encoding failures";;
        2) STATUS_FILTER="failed"; DESCRIPTION="admin-marked failed videos";;
        3) STATUS_FILTER="encoding_failed,failed"; DESCRIPTION="all failed videos";;
        *) echo "❌ Please choose 1, 2, or 3"; continue;;
    esac
    break
done

echo ""

# Step 3: Preview what will be cleaned
echo "🔍 Checking for $DESCRIPTION..."
PREVIEW=$(npm start -- list --status "$STATUS_FILTER" --limit 1 2>/dev/null)
if echo "$PREVIEW" | grep -q "No videos found"; then
    echo "✅ No $DESCRIPTION found - storage is clean!"
    exit 0
fi

echo "📋 Found $DESCRIPTION that can be removed"
echo ""

# Show sample
echo "📝 Sample of failed videos to be removed:"
npm start -- list --status "$STATUS_FILTER" --limit 3 2>/dev/null | grep -E "(Owner:|Status:|Size:|Created:)"
echo ""

# Step 4: Ask for batch size
echo "🎛️  Configuration Options:"
echo ""
echo "Batch Size Options:"
echo "  1) Small (25 videos)    - Conservative, slower"
echo "  2) Medium (50 videos)   - Balanced (Recommended)"
echo "  3) Large (100 videos)   - Faster, more aggressive"
echo "  4) Custom amount"
echo ""

while true; do
    read -p "Choose batch size [1-4]: " batch_choice
    case $batch_choice in
        1) BATCH_SIZE=25; break;;
        2) BATCH_SIZE=50; break;;
        3) BATCH_SIZE=100; break;;
        4) 
            while true; do
                read -p "Enter custom batch size (1-200): " custom_batch
                if [[ "$custom_batch" =~ ^[0-9]+$ ]] && [ "$custom_batch" -ge 1 ] && [ "$custom_batch" -le 200 ]; then
                    BATCH_SIZE=$custom_batch
                    break 2
                else
                    echo "❌ Please enter a number between 1 and 200"
                fi
            done
            ;;
        *) echo "❌ Please choose 1, 2, 3, or 4";;
    esac
done

echo ""
echo "📝 Configuration Summary:"
echo "   Target: $DESCRIPTION"
echo "   Statuses: $STATUS_FILTER"
echo "   Batch Size: $BATCH_SIZE videos per batch"
echo "   Safety Level: High (failed videos only)"
echo ""

# Step 5: Dry run
echo "🧪 Running safety check (dry run)..."
echo ""
npm start -- cleanup --status "$STATUS_FILTER" --batch-size $BATCH_SIZE --dry-run --no-confirm

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Safety check failed. Please review the errors above."
    exit 1
fi

echo ""
echo "✅ Safety check completed"
echo ""

# Step 6: Final confirmation
echo "🚨 FINAL CONFIRMATION"
echo ""
echo "This will permanently remove $DESCRIPTION."
echo "These videos failed encoding and cannot be published."
echo "This will free up significant storage space."
echo ""
read -p "Are you sure you want to proceed? [yes/no]: " final_confirm

if [ "$final_confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled by user"
    exit 0
fi

echo ""
echo "🚀 Starting failed encoding cleanup..."
echo "   Processing $BATCH_SIZE videos at a time"
echo "   Targeting: $DESCRIPTION"
echo "   You can press Ctrl+C to stop at any time"
echo ""

# Step 7: Execute cleanup
START_TIME=$(date)
npm start -- cleanup --status "$STATUS_FILTER" --batch-size $BATCH_SIZE --no-confirm

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Failed encoding cleanup completed!"
    echo ""
    echo "📊 Storage space recovered from failed encodings"
    echo ""
    echo "🕐 Started: $START_TIME"
    echo "🕐 Finished: $(date)"
else
    echo ""
    echo "❌ Cleanup encountered issues. Check the output above."
    echo "   You can safely run this script again."
fi

echo ""
echo "📄 Full logs are available in: ./logs/app.log"
echo "================================================"