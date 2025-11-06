#!/bin/bash

# 3Speak Storage Admin - Free Deleted IPFS Videos
# This script unpins IPFS videos that have been marked as deleted

echo "=================================================="
echo "  3Speak Storage Admin - Free Deleted IPFS Videos"
echo "=================================================="
echo ""
echo "This script will unpin IPFS videos that admins"
echo "have already marked as 'deleted'."
echo ""
echo "IPFS unpinning is different from S3 deletion:"
echo "- IPFS files are 'unpinned' (removed from our node)"
echo "- This frees up space on our IPFS storage"
echo "- Files may still exist on other IPFS nodes"
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

# Step 1: Check for IPFS deleted videos
echo "🔍 Checking for IPFS videos marked as deleted..."
PREVIEW=$(npm start -- list --status deleted --storage-type ipfs --limit 1 2>/dev/null)
if echo "$PREVIEW" | grep -q "No videos found"; then
    echo "✅ No deleted IPFS videos found - IPFS storage is clean!"
    exit 0
fi

echo "📋 Found deleted IPFS videos ready for unpinning"
echo ""

# Show sample
echo "📝 Sample of IPFS videos to be unpinned:"
npm start -- list --status deleted --storage-type ipfs --limit 3 2>/dev/null | grep -E "(Owner:|IPFS:|Created:)"
echo ""

# Step 2: Ask for batch size
echo "🎛️  IPFS Unpinning Configuration:"
echo ""
echo "Batch Size Options:"
echo "  1) Small (50 videos)    - Safest for IPFS operations"
echo "  2) Medium (100 videos)  - Balanced (Recommended)"
echo "  3) Large (200 videos)   - Faster, more aggressive"
echo "  4) Custom amount"
echo ""

while true; do
    read -p "Choose batch size [1-4]: " batch_choice
    case $batch_choice in
        1) BATCH_SIZE=50; break;;
        2) BATCH_SIZE=100; break;;
        3) BATCH_SIZE=200; break;;
        4) 
            while true; do
                read -p "Enter custom batch size (1-500): " custom_batch
                if [[ "$custom_batch" =~ ^[0-9]+$ ]] && [ "$custom_batch" -ge 1 ] && [ "$custom_batch" -le 500 ]; then
                    BATCH_SIZE=$custom_batch
                    break 2
                else
                    echo "❌ Please enter a number between 1 and 500"
                fi
            done
            ;;
        *) echo "❌ Please choose 1, 2, 3, or 4";;
    esac
done

echo ""
echo "📝 Configuration Summary:"
echo "   Target: IPFS videos marked as deleted"
echo "   Action: Unpin from IPFS node"
echo "   Batch Size: $BATCH_SIZE videos per batch"
echo "   Safety Level: Maximum (admin pre-approved)"
echo ""

# Step 3: Dry run
echo "🧪 Running safety check (dry run)..."
echo ""
npm start -- cleanup --status deleted --storage-type ipfs --batch-size $BATCH_SIZE --dry-run --no-confirm

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Safety check failed. Please review the errors above."
    exit 1
fi

echo ""
echo "✅ Safety check completed"
echo ""

# Step 4: Final confirmation
echo "🚨 FINAL CONFIRMATION"
echo ""
echo "This will unpin IPFS videos from our IPFS node."
echo "These videos have already been marked as deleted by admins."
echo "This action frees up IPFS storage space."
echo ""
read -p "Are you sure you want to proceed? [yes/no]: " final_confirm

if [ "$final_confirm" != "yes" ]; then
    echo "❌ IPFS cleanup cancelled by user"
    exit 0
fi

echo ""
echo "🚀 Starting IPFS unpinning process..."
echo "   Processing $BATCH_SIZE videos at a time"
echo "   You can press Ctrl+C to stop at any time"
echo ""

# Step 5: Execute cleanup
START_TIME=$(date)
npm start -- cleanup --status deleted --storage-type ipfs --batch-size $BATCH_SIZE --no-confirm

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ IPFS unpinning completed successfully!"
    echo ""
    echo "📊 IPFS storage freed up"
    echo ""
    echo "🕐 Started: $START_TIME"
    echo "🕐 Finished: $(date)"
else
    echo ""
    echo "❌ IPFS unpinning encountered issues. Check the output above."
    echo "   You can safely run this script again."
fi

echo ""
echo "📄 Full logs are available in: ./logs/app.log"
echo "=================================================="