#!/bin/bash

# Purge abandoned manual publish videos and unpin their IPFS content
# Usage: ./purge-abandoned.sh [days] [batch_size]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

DAYS=${1:-7}
BATCH_SIZE=${2:-100}

echo "🔍 PURGE ABANDONED MANUAL PUBLISH VIDEOS - ANALYSIS"
echo "First, let's see what would be purged..."
echo "Target: Videos stuck in 'publish_manual' for $DAYS+ days"
echo "================================================="
echo ""

# Run dry-run first to show what would be affected
npm start -- purge-abandoned --dry-run --older-than-days="$DAYS" --batch-size="$BATCH_SIZE"

echo ""
echo "================================================="
echo "⚠️  EXECUTION CONFIRMATION"
echo "The above shows what will be purged."
echo "This will:"
echo "  - Mark abandoned videos as deleted in database"
echo "  - Unpin IPFS content (freeing storage)"
echo "  - Target videos stuck in publish_manual for $DAYS+ days"
echo "  - Cannot be undone!"
echo ""
read -p "Do you want to proceed with the purge? (type 'yes' to continue): " confirm

if [ "$confirm" = "yes" ]; then
    echo ""
    echo "🚀 EXECUTING ABANDONED VIDEOS PURGE..."
    echo "======================================"
    npm start -- purge-abandoned --no-dry-run --no-confirm --older-than-days="$DAYS" --batch-size="$BATCH_SIZE"
else
    echo "Operation cancelled. No changes were made."
    exit 1
fi