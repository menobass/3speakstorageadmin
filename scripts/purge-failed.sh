#!/bin/bash

# Purge failed videos and unpin their IPFS content
# Usage: ./purge-failed.sh [batch_size]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

BATCH_SIZE=${1:-100}

echo "🔍 PURGE FAILED VIDEOS - ANALYSIS"
echo "First, let's see what would be purged..."
echo "=================================="
echo ""

# Run dry-run first to show what would be affected
npm start -- purge-failed --dry-run --batch-size="$BATCH_SIZE"

echo ""
echo "=================================="
echo "⚠️  EXECUTION CONFIRMATION"
echo "The above shows what will be purged."
echo "This will:"
echo "  - Mark failed videos as deleted in database"
echo "  - Unpin IPFS content (freeing storage)"
echo "  - Cannot be undone!"
echo ""
read -p "Do you want to proceed with the purge? (type 'yes' to continue): " confirm

if [ "$confirm" = "yes" ]; then
    echo ""
    echo "🚀 EXECUTING FAILED VIDEOS PURGE..."
    echo "===================================="
    npm start -- purge-failed --no-dry-run --no-confirm --batch-size="$BATCH_SIZE"
else
    echo "Operation cancelled. No changes were made."
    exit 1
fi