#!/bin/bash

# Purge failed videos and unpin their IPFS content
# Usage: ./purge-failed.sh [dry-run|execute]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

MODE=${1:-dry-run}
BATCH_SIZE=${2:-100}

if [ "$MODE" = "dry-run" ]; then
    echo "🔍 PURGE FAILED VIDEOS - DRY RUN MODE"
    echo "Preview mode: No changes will be made"
    echo "====================================="
    npm start -- purge-failed --dry-run --batch-size="$BATCH_SIZE"
elif [ "$MODE" = "execute" ]; then
    echo "⚠️  PURGE FAILED VIDEOS - EXECUTION MODE"
    echo "This will mark failed videos as deleted and unpin IPFS content!"
    echo "======================================================"
    read -p "Are you sure you want to proceed? (type 'yes' to continue): " confirm
    if [ "$confirm" = "yes" ]; then
        npm start -- purge-failed --no-dry-run --no-confirm --batch-size="$BATCH_SIZE"
    else
        echo "Operation cancelled."
        exit 1
    fi
else
    echo "Usage: $0 [dry-run|execute] [batch_size]"
    echo "Examples:"
    echo "  $0 dry-run     # Preview what would be purged"
    echo "  $0 execute     # Actually purge failed videos"
    echo "  $0 dry-run 50  # Preview with custom batch size"
    exit 1
fi