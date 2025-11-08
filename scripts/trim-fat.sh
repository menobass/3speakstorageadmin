#!/bin/bash

# 3Speak Storage Admin - Trim Fat (Account-Specific Cleanup)
# This script removes unwanted content from a specific account

echo "=============================================="
echo "  3Speak Storage Admin - Trim Fat ✂️"
echo "=============================================="
echo ""
echo "This script trims fat from a specific account."
echo "Target: Old or low-engagement content from chosen user"
echo ""
echo "⚡ STORAGE IMPACT: Frees up account-specific storage!"
echo "📺 USER IMPACT: ⚠️  Content becomes INACCESSIBLE (IPFS) or DELETED (S3)"
echo ""
echo "🎯 Target: Both S3 and IPFS videos from specific account"
echo "💡 Note: Intelligently handles different storage types!"
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

# Step 1: Get account name
echo "👤 Account Selection:"
echo ""
while true; do
    read -p "Enter account/username to trim fat from: " ACCOUNT_NAME
    if [[ "$ACCOUNT_NAME" =~ ^[a-zA-Z0-9._-]+$ ]] && [ ${#ACCOUNT_NAME} -ge 3 ] && [ ${#ACCOUNT_NAME} -le 50 ]; then
        break
    else
        echo "❌ Please enter a valid account name (3-50 characters, alphanumeric, dots, dashes, underscores only)"
    fi
done

echo ""
echo "📊 Getting account statistics for: $ACCOUNT_NAME"
echo ""
ACCOUNT_STATS=$(npm start -- stats --username $ACCOUNT_NAME 2>/dev/null)
if echo "$ACCOUNT_STATS" | grep -q "No videos found"; then
    echo "❌ No videos found for account: $ACCOUNT_NAME"
    echo "💡 Please check the username spelling and try again"
    exit 1
fi

echo "$ACCOUNT_STATS" | grep -E "(Total Videos:|S3 Videos:|IPFS Videos:|Total Size:)"
echo ""

# Step 2: Choose trimming method
echo "✂️  Fat Trimming Method:"
echo ""
echo "  1) Age-based trimming    - Remove content older than X years"
echo "  2) Engagement-based      - Remove low-engagement content (any age)"
echo "  3) Combined criteria     - Age AND low engagement"
echo "  4) Custom configuration  - Full control over all parameters"
echo ""

while true; do
    read -p "Choose trimming method [1-4]: " TRIM_METHOD
    case $TRIM_METHOD in
        1|2|3|4) break;;
        *) echo "❌ Please choose 1, 2, 3, or 4";;
    esac
done

# Step 3: Configure based on method
case $TRIM_METHOD in
    1) # Age-based
        echo ""
        echo "📅 Age-Based Trimming Configuration:"
        echo ""
        echo "  1) 2+ years old     - Conservative"
        echo "  2) 3+ years old     - Moderate"  
        echo "  3) 4+ years old     - Aggressive"
        echo "  4) 5+ years old     - Most aggressive"
        echo "  5) Custom years"
        echo ""
        
        while true; do
            read -p "Choose age threshold [1-5]: " age_choice
            case $age_choice in
                1) AGE_MONTHS=24; VIEW_THRESHOLD=999999; break;;
                2) AGE_MONTHS=36; VIEW_THRESHOLD=999999; break;;
                3) AGE_MONTHS=48; VIEW_THRESHOLD=999999; break;;
                4) AGE_MONTHS=60; VIEW_THRESHOLD=999999; break;;
                5) 
                    while true; do
                        read -p "Enter minimum age in years (1-10): " custom_years
                        if [[ "$custom_years" =~ ^[0-9]+$ ]] && [ "$custom_years" -ge 1 ] && [ "$custom_years" -le 10 ]; then
                            AGE_MONTHS=$((custom_years * 12))
                            VIEW_THRESHOLD=999999
                            break 2
                        else
                            echo "❌ Please enter a number between 1 and 10"
                        fi
                    done
                    ;;
                *) echo "❌ Please choose 1, 2, 3, 4, or 5";;
            esac
        done
        ;;
        
    2) # Engagement-based
        echo ""
        echo "📈 Engagement-Based Trimming Configuration:"
        echo ""
        echo "  1) Under 50 views   - Most aggressive"
        echo "  2) Under 100 views  - Aggressive"
        echo "  3) Under 250 views  - Moderate"
        echo "  4) Under 500 views  - Conservative"
        echo "  5) Custom threshold"
        echo ""
        
        while true; do
            read -p "Choose engagement threshold [1-5]: " engage_choice
            case $engage_choice in
                1) AGE_MONTHS=0; VIEW_THRESHOLD=50; break;;
                2) AGE_MONTHS=0; VIEW_THRESHOLD=100; break;;
                3) AGE_MONTHS=0; VIEW_THRESHOLD=250; break;;
                4) AGE_MONTHS=0; VIEW_THRESHOLD=500; break;;
                5) 
                    while true; do
                        read -p "Enter maximum view count (1-5000): " custom_views
                        if [[ "$custom_views" =~ ^[0-9]+$ ]] && [ "$custom_views" -ge 1 ] && [ "$custom_views" -le 5000 ]; then
                            AGE_MONTHS=0
                            VIEW_THRESHOLD=$custom_views
                            break 2
                        else
                            echo "❌ Please enter a number between 1 and 5000"
                        fi
                    done
                    ;;
                *) echo "❌ Please choose 1, 2, 3, 4, or 5";;
            esac
        done
        ;;
        
    3) # Combined criteria
        echo ""
        echo "🎯 Combined Criteria Configuration:"
        echo ""
        echo "Age threshold:"
        echo "  1) 1+ years old     2) 2+ years old     3) 3+ years old"
        echo ""
        
        while true; do
            read -p "Choose minimum age [1-3]: " age_choice
            case $age_choice in
                1) AGE_MONTHS=12; break;;
                2) AGE_MONTHS=24; break;;
                3) AGE_MONTHS=36; break;;
                *) echo "❌ Please choose 1, 2, or 3";;
            esac
        done
        
        echo ""
        echo "Engagement threshold:"
        echo "  1) Under 100 views  2) Under 250 views  3) Under 500 views"
        echo ""
        
        while true; do
            read -p "Choose max engagement [1-3]: " engage_choice
            case $engage_choice in
                1) VIEW_THRESHOLD=100; break;;
                2) VIEW_THRESHOLD=250; break;;
                3) VIEW_THRESHOLD=500; break;;
                *) echo "❌ Please choose 1, 2, or 3";;
            esac
        done
        ;;
        
    4) # Custom configuration
        echo ""
        echo "🔧 Custom Configuration:"
        echo ""
        
        while true; do
            read -p "Minimum age in months (0=any age, 1-120): " AGE_MONTHS
            if [[ "$AGE_MONTHS" =~ ^[0-9]+$ ]] && [ "$AGE_MONTHS" -ge 0 ] && [ "$AGE_MONTHS" -le 120 ]; then
                break
            else
                echo "❌ Please enter a number between 0 and 120"
            fi
        done
        
        while true; do
            read -p "Maximum view count (1-10000, or 999999 for no limit): " VIEW_THRESHOLD
            if [[ "$VIEW_THRESHOLD" =~ ^[0-9]+$ ]] && [ "$VIEW_THRESHOLD" -ge 1 ]; then
                break
            else
                echo "❌ Please enter a valid number"
            fi
        done
        ;;
esac

# Step 4: Batch size
echo ""
echo "📦 Processing Batch Size:"
echo "  1) Small (10 videos)   - Safest"
echo "  2) Medium (25 videos)  - Balanced (Recommended)"
echo "  3) Large (50 videos)   - Faster"
echo ""

while true; do
    read -p "Choose batch size [1-3]: " batch_choice
    case $batch_choice in
        1) BATCH_SIZE=10; break;;
        2) BATCH_SIZE=25; break;;
        3) BATCH_SIZE=50; break;;
        *) echo "❌ Please choose 1, 2, or 3";;
    esac
done

# Step 5: Summary
echo ""
echo "✂️  Trim Fat Configuration Summary:"
echo "   Account: $ACCOUNT_NAME"
if [ $AGE_MONTHS -eq 0 ]; then
    echo "   Age filter: Any age"
else
    echo "   Age filter: Older than $AGE_MONTHS months ($((AGE_MONTHS / 12)) years)"
fi

if [ $VIEW_THRESHOLD -eq 999999 ]; then
    echo "   Engagement filter: Any view count"
else
    echo "   Engagement filter: Under $VIEW_THRESHOLD views"
fi

echo "   Batch size: $BATCH_SIZE videos"
echo "   Action: S3 files deleted, IPFS hashes unpinned"
echo ""

# Step 6: Preview
echo "🔍 Analyzing account content..."
PREVIEW=$(npm start -- list --username $ACCOUNT_NAME --older-than-days $((AGE_MONTHS * 30)) --view-threshold $VIEW_THRESHOLD --limit 5 2>/dev/null)

if echo "$PREVIEW" | grep -q "No videos found"; then
    echo "✅ No videos match the trimming criteria - account is already lean!"
    echo "💡 Try adjusting the age or engagement thresholds"
    exit 0
fi

echo "📋 Found videos that match trimming criteria"
echo ""

# Step 7: Dry run
echo "🧪 Running trim fat preview (dry run)..."
echo ""
npm start -- trim-fat --username $ACCOUNT_NAME --older-than-months $AGE_MONTHS --view-threshold $VIEW_THRESHOLD --batch-size $BATCH_SIZE --dry-run --no-confirm

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Preview failed. Please review the errors above."
    exit 1
fi

echo ""
echo "✅ Preview completed - showing potential fat trimming results"
echo ""

# Step 8: Final confirmation
echo "🚨 FINAL CONFIRMATION - TRIM FAT"
echo ""
echo "⚠️  ⚠️  ⚠️  DESTRUCTIVE ACTION ⚠️  ⚠️  ⚠️"
echo ""
echo "This will PERMANENTLY remove content from account: $ACCOUNT_NAME"
echo ""
echo "📹 What will happen:"
echo "   • S3 videos: Files deleted from Wasabi storage"
echo "   • IPFS videos: Hashes unpinned (videos become inaccessible)"
echo "   • Database: Videos marked as cleaned up"
echo "   • Result: Content matching criteria will be gone forever"
echo ""
echo "✅ This will achieve:"
echo "   • Reduced storage costs for this account"
echo "   • Cleaner content library"
echo "   • Freed up storage space"
echo ""
echo "💡 Only proceed if you're sure this content is unwanted!"
echo ""
read -p "Trim fat from account '$ACCOUNT_NAME'? Type 'TRIM' to confirm: " final_confirm

if [ "$final_confirm" != "TRIM" ]; then
    echo "❌ Fat trimming cancelled by user"
    exit 0
fi

echo ""
echo "✂️  Starting fat trimming process for: $ACCOUNT_NAME"
echo "   Processing $BATCH_SIZE videos at a time"
echo "   Handling both S3 and IPFS content appropriately"
echo "   You can press Ctrl+C to stop at any time"
echo ""

# Step 9: Execute trim fat
START_TIME=$(date)
echo "🧹 Executing account fat trimming..."
echo ""

# Run trim fat in background and monitor progress
npm start -- trim-fat --username $ACCOUNT_NAME --older-than-months $AGE_MONTHS --view-threshold $VIEW_THRESHOLD --batch-size $BATCH_SIZE --no-confirm > /tmp/3speak_trimfat_$$.log 2>&1 &
TRIM_PID=$!

# Show progress indicator
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPIN_INDEX=0
SECONDS_ELAPSED=0

echo -n "Trimming account fat "
while kill -0 $TRIM_PID 2>/dev/null; do
    printf "\r${SPINNER[$SPIN_INDEX]} Trimming fat from $ACCOUNT_NAME... %02d:%02d elapsed" $((SECONDS_ELAPSED/60)) $((SECONDS_ELAPSED%60))
    SPIN_INDEX=$(( (SPIN_INDEX + 1) % 10 ))
    sleep 1
    SECONDS_ELAPSED=$((SECONDS_ELAPSED + 1))
done

# Wait for process to complete and get exit code
wait $TRIM_PID
TRIM_EXIT_CODE=$?

# Clear the spinner line
printf "\r\033[K"

# Display the output
TRIM_OUTPUT=$(cat /tmp/3speak_trimfat_$$.log)
echo "$TRIM_OUTPUT"

# Clean up temp file
rm -f /tmp/3speak_trimfat_$$.log

if [ $TRIM_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Account fat trimming completed successfully!"
    
    # Extract and highlight results
    STORAGE_FREED=$(echo "$TRIM_OUTPUT" | grep "STORAGE FREED:" || echo "Storage information not available")
    if [ "$STORAGE_FREED" != "Storage information not available" ]; then
        echo ""
        echo "🎉 RESULT: $STORAGE_FREED"
        echo "✂️  Fat successfully trimmed from account: $ACCOUNT_NAME"
        echo ""
    fi
    
    echo "📊 Updated account statistics:"
    npm start -- stats --username $ACCOUNT_NAME 2>/dev/null | grep -E "(Total Videos:|S3 Videos:|IPFS Videos:|Total Size:)"
    echo ""
    echo "🕐 Started: $START_TIME"
    echo "🕐 Finished: $(date)"
else
    echo ""
    echo "❌ Fat trimming encountered some issues. Check the output above."
    echo "   The process may have been interrupted or encountered errors."
    echo "   You can safely run this script again."
fi

echo ""
echo "📄 Full logs are available in: ./logs/app.log"
echo "=============================================="