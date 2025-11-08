#!/bin/bash

# 3Speak Storage Admin - Slim User Script
# Targeted storage diet for a specific user - keeps only 480p for old videos
# Shows cost savings calculation at the end

echo "=============================================="
echo "  🥗 3Speak Storage Admin - Slim User"
echo "=============================================="
echo ""
echo "This script optimizes storage for a specific user by:"
echo "• Keeping only 480p resolution for old videos"
echo "• Deleting 1080p, 720p, 360p + source files"  
echo "• Videos remain watchable in 480p quality"
echo "• Shows cost savings calculation"
echo ""
echo "💡 This is like 'storage diet' but user-focused!"
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

# Step 1: Get username
while true; do
    read -p "Enter username to optimize: " TARGET_USERNAME
    TARGET_USERNAME=$(echo "$TARGET_USERNAME" | xargs)
    if [ -n "$TARGET_USERNAME" ]; then
        break
    fi
    echo "❌ Username cannot be empty."
done

echo ""

# Step 2: Age threshold selection  
echo "📅 Age Threshold Options:"
echo ""
echo "How far back should we optimize videos?"
echo "  1) 3 months+  (Conservative - recent videos untouched)"
echo "  2) 6 months+  (Balanced - good middle ground) ⭐ Recommended"
echo "  3) 12 months+ (Aggressive - only very old videos)"
echo "  4) 18 months+ (Ultra conservative - ancient videos only)"
echo "  5) Custom months"
echo ""

AGE_MONTHS=6
while true; do
    read -p "Choose age threshold [1-5]: " age_choice
    case $age_choice in
        1) AGE_MONTHS=3; AGE_DESC="3+ months old"; break;;
        2) AGE_MONTHS=6; AGE_DESC="6+ months old"; break;;
        3) AGE_MONTHS=12; AGE_DESC="12+ months old"; break;;
        4) AGE_MONTHS=18; AGE_DESC="18+ months old"; break;;
        5) 
            while true; do
                read -p "Enter custom months (1-60): " custom_months
                if [[ "$custom_months" =~ ^[0-9]+$ ]] && [ "$custom_months" -ge 1 ] && [ "$custom_months" -le 60 ]; then
                    AGE_MONTHS=$custom_months
                    AGE_DESC="${custom_months}+ months old"
                    break 2
                else
                    echo "❌ Please enter a number between 1 and 60"
                fi
            done
            ;;
        *) echo "❌ Please choose 1, 2, 3, 4, or 5";;
    esac
done

echo ""

# Step 3: Batch size selection
echo "🎛️  Batch Size Options:"
echo ""
echo "  1) Small (10 videos)      - Safest, slower"
echo "  2) Medium (25 videos)     - Balanced ⭐ Recommended"
echo "  3) Large (50 videos)      - Faster processing"
echo "  4) Custom (1-200 videos)"
echo ""

BATCH_SIZE=25
while true; do
    read -p "Choose batch size [1-4]: " batch_choice
    case $batch_choice in
        1) BATCH_SIZE=10; break;;
        2) BATCH_SIZE=25; break;;
        3) BATCH_SIZE=50; break;;
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
echo "   Target User: $TARGET_USERNAME"
echo "   Age Threshold: Videos $AGE_DESC"
echo "   Batch Size: $BATCH_SIZE videos per batch"
echo "   Optimization: Keep only 480p + thumbnails"
echo ""

# Step 4: Preview analysis
echo "🔍 Analyzing $TARGET_USERNAME's content ($AGE_DESC)..."
echo ""
npm start -- slim-user --username "$TARGET_USERNAME" --older-than-months $AGE_MONTHS --dry-run --no-confirm

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Analysis failed. Please review the errors above."
    exit 1
fi

echo ""
echo "✅ Analysis completed"
echo ""

# Step 5: Final confirmation
echo "🚨 FINAL CONFIRMATION - SLIM USER"
echo ""
echo "This will optimize storage for: $TARGET_USERNAME"
echo "Target: Videos $AGE_DESC"
echo ""
echo "⚠️  WHAT WILL BE DELETED:"
echo "   • 1080p playlists and video segments"
echo "   • 720p playlists and video segments"  
echo "   • 360p playlists and video segments"
echo "   • Original source video files"
echo ""
echo "✅ WHAT WILL BE KEPT:"
echo "   • 480p playlist and video segments (videos remain watchable)"
echo "   • Thumbnails and metadata"
echo ""
read -p "Are you sure you want to proceed? [yes/no]: " final_confirm

if [ "$final_confirm" != "yes" ]; then
    echo "❌ Optimization cancelled by user"
    exit 0
fi

echo ""
echo "🥗 Starting user storage optimization..."
echo "   User: $TARGET_USERNAME"
echo "   Target: Videos $AGE_DESC"  
echo "   Batch size: $BATCH_SIZE"
echo "   You can press Ctrl+C to stop at any time"
echo ""

# Step 6: Execute optimization
START_TIME=$(date)
echo "🧹 Executing optimization..."
echo ""

# Run optimization in background and monitor progress
npm start -- slim-user --username "$TARGET_USERNAME" --older-than-months $AGE_MONTHS --batch-size $BATCH_SIZE --no-confirm > /tmp/3speak_slim_$$.log 2>&1 &
SLIM_PID=$!

# Show progress indicator while optimization runs
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPIN_INDEX=0
SECONDS_ELAPSED=0

echo -n "Optimizing "
while kill -0 $SLIM_PID 2>/dev/null; do
    printf "\r${SPINNER[$SPIN_INDEX]} Optimizing %s (%s)... %02d:%02d elapsed" "$TARGET_USERNAME" "$AGE_DESC" $((SECONDS_ELAPSED/60)) $((SECONDS_ELAPSED%60))
    SPIN_INDEX=$(( (SPIN_INDEX + 1) % 10 ))
    sleep 1
    SECONDS_ELAPSED=$((SECONDS_ELAPSED + 1))
done

# Wait for process to complete and get exit code
wait $SLIM_PID
SLIM_EXIT_CODE=$?

# Clear the spinner line
printf "\r\033[K"

# Display the output
SLIM_OUTPUT=$(cat /tmp/3speak_slim_$$.log)
echo "$SLIM_OUTPUT"

# Clean up temp file
rm -f /tmp/3speak_slim_$$.log

if [ $SLIM_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ User optimization completed successfully!"
    
    # Extract and highlight storage and cost savings
    STORAGE_FREED=$(echo "$SLIM_OUTPUT" | grep "💾 STORAGE FREED:" || echo "Storage information not available")
    COST_SAVINGS=$(echo "$SLIM_OUTPUT" | grep "💰 COST SAVINGS:" || echo "Cost savings information not available")
    
    if [ "$STORAGE_FREED" != "Storage information not available" ]; then
        echo ""
        echo "🎉 RESULTS:"
        echo "   $STORAGE_FREED"
        if [ "$COST_SAVINGS" != "Cost savings information not available" ]; then
            echo "   $COST_SAVINGS"
        fi
    fi
    
    echo ""
    echo "📊 Updated user stats for $TARGET_USERNAME:"
    node scripts/check-account-storage.js "$TARGET_USERNAME" 2>/dev/null | tail -15
    echo ""
    echo "🕐 Started: $START_TIME"
    echo "🕐 Finished: $(date)"
else
    echo ""
    echo "❌ Optimization encountered some issues. Check the output above."
    echo "   The process may have been interrupted or encountered errors."
    echo "   You can safely run this script again."
fi

echo ""
echo "📄 Full logs are available in: ./logs/app.log"
echo "=============================================="