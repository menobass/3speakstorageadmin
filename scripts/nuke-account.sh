#!/bin/bash

# 3Speak Storage Admin - Nuke Account Script
# This script permanently deletes ALL videos for a specific account.
# It will delete S3 objects, unpin IPFS hashes, and mark videos as deleted.

echo "=============================================="
echo "  ☢️  3Speak Storage Admin - Nuke Account"
echo "=============================================="
echo ""
echo "This script will permanently delete ALL content for a specific user."
echo "Use ONLY when you are absolutely certain the account must be removed."
echo ""
echo "⚠️  ACTIONS PERFORMED:" 
echo "   • Deletes every S3 object associated with the account"
echo "   • Unpins every IPFS hash associated with the account"
echo "   • Marks every video as deleted in the database"
echo ""
echo "There is no undo. Double-check the username before proceeding."
echo ""

# Ensure we are inside the project directory
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
    echo "❌ ERROR: Please run this script from the 3speakstorageadmin directory"
    exit 1
fi

# Build the project to ensure latest code
echo "📦 Building project..."
if ! npm run build > /dev/null 2>&1; then
    echo "❌ Build failed. Please run npm install and try again."
    exit 1
fi

echo "✅ Project built successfully"
echo ""

# Prompt for username
while true; do
    read -p "Enter the username to nuke: " TARGET_USERNAME
    TARGET_USERNAME=$(echo "$TARGET_USERNAME" | xargs)
    if [ -n "$TARGET_USERNAME" ]; then
        break
    fi
    echo "❌ Username cannot be empty."
done

TARGET_DISPLAY="$TARGET_USERNAME"

# Include already cleaned videos?
echo ""
read -p "Include videos already marked as cleaned? (y/N): " INCLUDE_CLEANED_INPUT
INCLUDE_CLEANED_INPUT=$(echo "$INCLUDE_CLEANED_INPUT" | tr '[:upper:]' '[:lower:]')
if [[ "$INCLUDE_CLEANED_INPUT" == "y" || "$INCLUDE_CLEANED_INPUT" == "yes" ]]; then
    INCLUDE_CLEANED_FLAG="--include-cleaned"
    INCLUDE_LABEL="Yes"
else
    INCLUDE_CLEANED_FLAG=""
    INCLUDE_LABEL="No"
fi

# Batch size selection
echo ""
echo "🎛️  Batch Size Options:"
echo "  1) Conservative (10 videos)"
echo "  2) Standard (25 videos)"
echo "  3) Aggressive (50 videos)"
echo "  4) Custom (1-500 videos)"
echo ""

BATCH_SIZE=25
while true; do
    read -p "Choose batch size [1-4]: " batch_choice
    case $batch_choice in
        1) BATCH_SIZE=10; break ;;
        2) BATCH_SIZE=25; break ;;
        3) BATCH_SIZE=50; break ;;
        4)
            while true; do
                read -p "Enter custom batch size (1-500): " custom_batch
                if [[ "$custom_batch" =~ ^[0-9]+$ ]] && [ "$custom_batch" -ge 1 ] && [ "$custom_batch" -le 500 ]; then
                    BATCH_SIZE=$custom_batch
                    break 2
                fi
                echo "❌ Please enter a number between 1 and 500."
            done
            ;;
        *)
            echo "❌ Please choose option 1, 2, 3, or 4."
            ;;
    esac
done

echo ""
echo "📝 Configuration Summary:"
echo "   Account: $TARGET_DISPLAY"
echo "   Include already cleaned videos: $INCLUDE_LABEL"
echo "   Batch size: $BATCH_SIZE"
echo ""

echo "🧪 Running destructive impact preview (dry run)..."
DRY_RUN_CMD=(npm start -- nuke-account --username "$TARGET_USERNAME" --dry-run)
if [ -n "$INCLUDE_CLEANED_FLAG" ]; then
    DRY_RUN_CMD+=("$INCLUDE_CLEANED_FLAG")
fi

if ! DRY_RUN_OUTPUT=$("${DRY_RUN_CMD[@]}" 2>&1); then
    echo ""
    echo "❌ Dry run failed. Review the output below:"
    echo "----------------------------------------------"
    echo "$DRY_RUN_OUTPUT"
    echo "----------------------------------------------"
    exit 1
fi

echo ""
echo "✅ Dry run completed. Impact summary:"
echo "----------------------------------------------"
echo "$DRY_RUN_OUTPUT"
echo "----------------------------------------------"
echo ""

echo "🚨 FINAL WARNING"
echo "This will permanently remove ALL content for account: $TARGET_DISPLAY"
echo "There is NO recovery after this point."
echo ""
read -p "Type 'NUKE $TARGET_DISPLAY' to confirm: " FINAL_CONFIRM
if [ "$FINAL_CONFIRM" != "NUKE $TARGET_DISPLAY" ]; then
    echo "❌ Confirmation phrase mismatch. Aborting."
    exit 0
fi

echo ""
echo "🔥 Initiating nuclear cleanup for account: $TARGET_DISPLAY"
echo "   Batch size: $BATCH_SIZE"
echo "   Include cleaned videos: $INCLUDE_LABEL"
echo ""

START_TIME=$(date)
TEMP_LOG=$(mktemp /tmp/3speak_nuke_account_XXXXXX.log)

NUKE_CMD=(npm start -- nuke-account --username "$TARGET_USERNAME" --batch-size "$BATCH_SIZE" --no-confirm)
if [ -n "$INCLUDE_CLEANED_FLAG" ]; then
    NUKE_CMD+=("$INCLUDE_CLEANED_FLAG")
fi

"${NUKE_CMD[@]}" > "$TEMP_LOG" 2>&1 &
NUKE_PID=$!

SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPIN_INDEX=0
SECONDS_ELAPSED=0

echo -n "Processing "
while kill -0 $NUKE_PID 2>/dev/null; do
    printf "\r${SPINNER[$SPIN_INDEX]} Nuking account %s... %02d:%02d elapsed" "$TARGET_DISPLAY" $((SECONDS_ELAPSED/60)) $((SECONDS_ELAPSED%60))
    SPIN_INDEX=$(( (SPIN_INDEX + 1) % 10 ))
    sleep 1
    SECONDS_ELAPSED=$((SECONDS_ELAPSED + 1))
done

wait $NUKE_PID
NUKE_EXIT_CODE=$?

printf "\r\033[K"

NUKE_OUTPUT=$(cat "$TEMP_LOG")
rm -f "$TEMP_LOG"

echo "----------------------------------------------"
echo "$NUKE_OUTPUT"
echo "----------------------------------------------"

FINISH_TIME=$(date)

echo ""
if [ $NUKE_EXIT_CODE -eq 0 ]; then
    echo "✅ Account nuke completed successfully!"
    echo ""
    echo "🕐 Started:  $START_TIME"
    echo "🕐 Finished: $FINISH_TIME"
    echo ""
    echo "📊 Updated statistics (snapshot):"
    npm start -- stats 2>/dev/null | grep -E "(deleted:|Total Videos:|Total Size:|Videos Cleaned Up:)"
else
    echo "❌ Account nuke encountered issues. Review the output above."
    echo "   You can re-run the script if needed."
fi

echo ""
echo "📄 Full logs are available in: ./logs/app.log"
echo "=============================================="
