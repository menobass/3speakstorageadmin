#!/bin/bash

# Purge abandoned manual publish videos and unpin their IPFS content
# Usage: ./purge-abandoned.sh [dry-run|execute] [days] [batch_size]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

MODE=${1:-dry-run}
DAYS=${2:-7}
BATCH_SIZE=${3:-100}

if [ "$MODE" = "dry-run" ]; then
    echo "🔍 PURGE ABANDONED MANUAL PUBLISH VIDEOS - DRY RUN MODE"
    echo "Preview mode: No changes will be made"
    echo "Target: Videos stuck in 'publish_manual' for $DAYS+ days"
    echo "======================================================"
    npm start -- purge-abandoned --dry-run --older-than-days="$DAYS" --batch-size="$BATCH_SIZE"
elif [ "$MODE" = "execute" ]; then
    echo "⚠️  PURGE ABANDONED MANUAL PUBLISH VIDEOS - EXECUTION MODE"
    echo "This will mark abandoned videos as deleted and unpin IPFS content!"
    echo "Target: Videos stuck in 'publish_manual' for $DAYS+ days"
    echo "================================================================="
    read -p "Are you sure you want to proceed? (type 'yes' to continue): " confirm
    if [ "$confirm" = "yes" ]; then
        npm start -- purge-abandoned --no-dry-run --no-confirm --older-than-days="$DAYS" --batch-size="$BATCH_SIZE"
    else
        echo "Operation cancelled."
        exit 1
    fi
else
    echo "Usage: $0 [dry-run|execute] [days] [batch_size]"
    echo "Examples:"
    echo "  $0 dry-run         # Preview abandoned videos (7+ days old)"
    echo "  $0 execute         # Actually purge abandoned videos (7+ days old)"
    echo "  $0 dry-run 14      # Preview abandoned videos (14+ days old)"
    echo "  $0 execute 30 50   # Purge 30+ day old videos with batch size 50"
    exit 1
fi