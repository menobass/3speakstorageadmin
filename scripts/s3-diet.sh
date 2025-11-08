#!/bin/bash

# 3Speak Storage Admin - S3 Diet (Keep Only 480p for S3 Videos)
# This script optimizes S3 storage by keeping only 480p resolution for low-engagement S3 videos

echo "=============================================="
echo "  3Speak Storage Admin - S3 Diet 🪣"
echo "=============================================="
echo ""
echo "This script optimizes S3 storage by keeping only 480p"
echo "resolution for old, low-engagement S3 videos."
echo ""
echo "⚡ STORAGE IMPACT: Can save 60-80% S3 storage per video!"
echo "📺 USER IMPACT: Videos remain watchable in 480p quality"
echo ""
echo "🎯 Target: S3 videos only (newer uploads)"
echo "💡 Note: Platform stopped using S3 4 years ago - most old videos are IPFS"
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

# Step 1: Show current stats
echo "📊 Getting current statistics..."
echo ""
npm start -- stats 2>/dev/null | grep -E "(Total Videos:|Total Size:|Videos Cleaned Up:)"
echo ""

# Step 2: Configure optimization parameters
echo "🎛️  Optimization Configuration:"
echo ""
echo "Age Threshold Options:"
echo "  1) 3 months old    - More aggressive"
echo "  2) 6 months old    - Balanced (Recommended)"
echo "  3) 12 months old   - Conservative"
echo "  4) Custom months"
echo ""

while true; do
    read -p "Choose age threshold [1-4]: " age_choice
    case $age_choice in
        1) AGE_MONTHS=3; break;;
        2) AGE_MONTHS=6; break;;
        3) AGE_MONTHS=12; break;;
        4) 
            while true; do
                read -p "Enter custom age in months (1-36): " custom_age
                if [[ "$custom_age" =~ ^[0-9]+$ ]] && [ "$custom_age" -ge 1 ] && [ "$custom_age" -le 36 ]; then
                    AGE_MONTHS=$custom_age
                    break 2
                else
                    echo "❌ Please enter a number between 1 and 36"
                fi
            done
            ;;
        *) echo "❌ Please choose 1, 2, 3, or 4";;
    esac
done

echo ""
echo "View Count Threshold Options:"
echo "  1) Under 100 views  - Most aggressive"
echo "  2) Under 500 views  - Balanced (Recommended)"  
echo "  3) Under 1000 views - Conservative"
echo "  4) Custom threshold"
echo ""

while true; do
    read -p "Choose view threshold [1-4]: " view_choice
    case $view_choice in
        1) VIEW_THRESHOLD=100; break;;
        2) VIEW_THRESHOLD=500; break;;
        3) VIEW_THRESHOLD=1000; break;;
        4) 
            while true; do
                read -p "Enter custom view threshold (1-5000): " custom_views
                if [[ "$custom_views" =~ ^[0-9]+$ ]] && [ "$custom_views" -ge 1 ] && [ "$custom_views" -le 5000 ]; then
                    VIEW_THRESHOLD=$custom_views
                    break 2
                else
                    echo "❌ Please enter a number between 1 and 5000"
                fi
            done
            ;;
        *) echo "❌ Please choose 1, 2, 3, or 4";;
    esac
done

echo ""
echo "Batch Size Options:"
echo "  1) Small (10 videos)   - Safest, slowest"
echo "  2) Medium (25 videos)  - Balanced (Recommended)"
echo "  3) Large (50 videos)   - Faster, more aggressive"
echo "  4) Custom amount"
echo ""

while true; do
    read -p "Choose batch size [1-4]: " batch_choice
    case $batch_choice in
        1) BATCH_SIZE=10; break;;
        2) BATCH_SIZE=25; break;;
        3) BATCH_SIZE=50; break;;
        4) 
            while true; do
                read -p "Enter custom batch size (1-100): " custom_batch
                if [[ "$custom_batch" =~ ^[0-9]+$ ]] && [ "$custom_batch" -ge 1 ] && [ "$custom_batch" -le 100 ]; then
                    BATCH_SIZE=$custom_batch
                    break 2
                else
                    echo "❌ Please enter a number between 1 and 100"
                fi
            done
            ;;
        *) echo "❌ Please choose 1, 2, 3, or 4";;
    esac
done

echo ""
echo "📝 S3 Optimization Summary:"
echo "   Target: S3 videos older than $AGE_MONTHS months with <$VIEW_THRESHOLD views"
echo "   Action: Keep only 480p resolution (delete 1080p, 720p, 360p, source files)"
echo "   Batch Size: $BATCH_SIZE videos per batch"
echo "   Safety Level: HIGH (S3 videos remain playable in 480p)"
echo "   Storage Type: S3 only (not IPFS)"
echo ""

# Step 3: Preview what will be optimized
echo "🔍 Checking how many S3 videos qualify for S3 diet..."
PREVIEW=$(npm start -- list --older-than-days $((AGE_MONTHS * 30)) --view-threshold $VIEW_THRESHOLD --limit 1 --storage-type s3 2>/dev/null)
if echo "$PREVIEW" | grep -q "No videos found"; then
    echo "✅ No S3 videos found matching criteria - S3 storage is already optimized!"
    echo "💡 Remember: Platform stopped using S3 4 years ago - old videos are IPFS-only"
    exit 0
fi

echo "📋 Found S3 videos that qualify for S3 diet optimization"
echo ""

# Step 4: Dry run to show impact
echo "🧪 Running S3 optimization preview (dry run)..."
echo ""
npm start -- s3-diet --older-than-months $AGE_MONTHS --view-threshold $VIEW_THRESHOLD --batch-size $BATCH_SIZE --dry-run --no-confirm

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Preview failed. Please review the errors above."
    exit 1
fi

echo ""
echo "✅ Preview completed - showing potential storage savings"
echo ""

# Step 5: Final confirmation
echo "🚨 FINAL CONFIRMATION - S3 DIET"
echo ""
echo "⚠️  This will permanently delete high-resolution S3 files:"
echo "   • 1080p playlists and video segments"
echo "   • 720p playlists and video segments"  
echo "   • 360p playlists and video segments"
echo "   • Original source video files"
echo ""
echo "✅ This will keep:"
echo "   • 480p playlist and video segments (videos remain watchable)"
echo "   • Thumbnails and metadata"
echo ""
echo "💡 S3 videos will still be accessible but only in 480p quality"
echo "🪣 This only affects S3 storage (not IPFS)"
echo ""
read -p "Are you absolutely sure you want to proceed? [yes/no]: " final_confirm

if [ "$final_confirm" != "yes" ]; then
    echo "❌ S3 diet cancelled by user"
    exit 0
fi

echo ""
echo "🪣 Starting S3 diet process..."
echo "   Optimizing $BATCH_SIZE S3 videos at a time"
echo "   Keeping only 480p resolution per video"
echo "   You can press Ctrl+C to stop at any time"
echo ""

# Step 6: Execute S3 diet
START_TIME=$(date)
echo "🧹 Executing S3 diet optimization..."
echo ""

# Run S3 diet in background and monitor progress
npm start -- s3-diet --older-than-months $AGE_MONTHS --view-threshold $VIEW_THRESHOLD --batch-size $BATCH_SIZE --no-confirm > /tmp/3speak_s3diet_$$.log 2>&1 &
DIET_PID=$!

# Show progress indicator while optimization runs
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPIN_INDEX=0
SECONDS_ELAPSED=0

echo -n "Optimizing S3 videos "
while kill -0 $DIET_PID 2>/dev/null; do
    printf "\r${SPINNER[$SPIN_INDEX]} Optimizing S3 videos (keeping only 480p)... %02d:%02d elapsed" $((SECONDS_ELAPSED/60)) $((SECONDS_ELAPSED%60))
    SPIN_INDEX=$(( (SPIN_INDEX + 1) % 10 ))
    sleep 1
    SECONDS_ELAPSED=$((SECONDS_ELAPSED + 1))
done

# Wait for process to complete and get exit code
wait $DIET_PID
DIET_EXIT_CODE=$?

# Clear the spinner line
printf "\r\033[K"

# Display the output
DIET_OUTPUT=$(cat /tmp/3speak_s3diet_$$.log)
echo "$DIET_OUTPUT"

# Clean up temp file
rm -f /tmp/3speak_s3diet_$$.log

if [ $DIET_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ S3 diet completed successfully!"
    
    # Extract and highlight storage freed information
    STORAGE_SAVED=$(echo "$DIET_OUTPUT" | grep "💾 S3 STORAGE SAVED:" || echo "Storage information not available")
    if [ "$STORAGE_SAVED" != "Storage information not available" ]; then
        echo ""
        echo "🎉 RESULT: $STORAGE_SAVED"
        echo "🪣 S3 videos remain accessible in 480p quality!"
    fi
    
    echo ""
    echo "📊 Updated statistics:"
    npm start -- stats 2>/dev/null | grep -E "(Total Videos:|Total Size:|Videos Cleaned Up:)"
    echo ""
    echo "🕐 Started: $START_TIME"
    echo "🕐 Finished: $(date)"
else
    echo ""
    echo "❌ S3 diet encountered some issues. Check the output above."
    echo "   The process may have been interrupted or encountered errors."
    echo "   You can safely run this script again."
fi

echo ""
echo "📄 Full logs are available in: ./logs/app.log"
echo "=============================================="