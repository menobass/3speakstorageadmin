#!/bin/bash
#
# Gentle IPFS Garbage Collection
# 
# Runs GC in short bursts during off-peak hours only.
# Designed to not kill your supernode while still reclaiming space.
#
# Usage: 
#   ./gentle-gc.sh              # Run once (respects time window)
#   ./gentle-gc.sh --force      # Ignore time window (careful!)
#   ./gentle-gc.sh --dry-run    # Just show what would happen
#
# Recommended: Run via cron at 2am:
#   0 2 * * * /path/to/gentle-gc.sh >> /var/log/ipfs-gc.log 2>&1
#

set -euo pipefail

# ============================================================
# CONFIGURATION - Adjust these for your needs
# ============================================================

# Time window (24h format) - only run GC during these hours
START_HOUR=2      # 2 AM
END_HOUR=4        # 4 AM

# GC burst settings
GC_DURATION=300       # Run GC for 5 minutes (300 seconds)
PAUSE_DURATION=600    # Pause for 10 minutes (600 seconds) between bursts
MAX_CYCLES=6          # Max number of GC cycles per run (6 cycles = ~90 min total window)

# Load protection - stop if system is overloaded
MAX_LOAD_AVERAGE=4.0  # Stop GC if 1-min load average exceeds this
MAX_IPFS_CONNECTIONS=500  # Stop if IPFS has too many active connections

# IPFS settings
IPFS_PATH="${IPFS_PATH:-/home/meno/.ipfs}"
IPFS_CMD="${IPFS_CMD:-ipfs}"

# Logging
LOG_PREFIX="[IPFS-GC]"

# ============================================================
# FUNCTIONS
# ============================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX ERROR: $1" >&2
}

is_within_time_window() {
    local current_hour=$(date +%H)
    current_hour=$((10#$current_hour))  # Remove leading zero
    
    if [ $current_hour -ge $START_HOUR ] && [ $current_hour -lt $END_HOUR ]; then
        return 0
    else
        return 1
    fi
}

get_load_average() {
    # Get 1-minute load average
    awk '{print $1}' /proc/loadavg
}

is_load_ok() {
    local load=$(get_load_average)
    local result=$(echo "$load < $MAX_LOAD_AVERAGE" | bc -l)
    [ "$result" -eq 1 ]
}

get_ipfs_connections() {
    # Count active IPFS swarm connections
    $IPFS_CMD swarm peers 2>/dev/null | wc -l || echo "0"
}

is_ipfs_ok() {
    local conns=$(get_ipfs_connections)
    [ "$conns" -lt "$MAX_IPFS_CONNECTIONS" ]
}

get_repo_size() {
    $IPFS_CMD repo stat --human 2>/dev/null | grep "RepoSize" | awk '{print $2, $3}' || echo "unknown"
}

run_gc_burst() {
    local duration=$1
    local end_time=$(($(date +%s) + duration))
    local gc_pid
    
    log "🗑️  Starting GC burst for ${duration}s..."
    log "📊 Repo size before: $(get_repo_size)"
    
    # Start GC in background with stream-errors for gentler operation
    $IPFS_CMD repo gc --stream-errors 2>&1 &
    gc_pid=$!
    
    # Monitor and kill after duration or if load spikes
    while [ $(date +%s) -lt $end_time ]; do
        # Check if GC is still running
        if ! kill -0 $gc_pid 2>/dev/null; then
            log "✅ GC completed naturally"
            return 0
        fi
        
        # Check system load
        if ! is_load_ok; then
            log "⚠️  Load too high ($(get_load_average)), stopping GC early"
            kill $gc_pid 2>/dev/null || true
            wait $gc_pid 2>/dev/null || true
            return 1
        fi
        
        # Check if still in time window
        if ! is_within_time_window && [ "${FORCE:-false}" != "true" ]; then
            log "⏰ Outside time window, stopping GC"
            kill $gc_pid 2>/dev/null || true
            wait $gc_pid 2>/dev/null || true
            return 2
        fi
        
        sleep 10
    done
    
    # Time's up, stop GC gracefully
    if kill -0 $gc_pid 2>/dev/null; then
        log "⏱️  Burst time complete, stopping GC..."
        kill $gc_pid 2>/dev/null || true
        wait $gc_pid 2>/dev/null || true
    fi
    
    log "📊 Repo size after: $(get_repo_size)"
    return 0
}

# ============================================================
# MAIN
# ============================================================

DRY_RUN=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --force)
            FORCE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--force]"
            echo ""
            echo "Gentle IPFS garbage collection with time windows and load protection."
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would happen without running GC"
            echo "  --force      Ignore time window restrictions"
            echo ""
            echo "Configuration (edit script to change):"
            echo "  Time window: ${START_HOUR}:00 - ${END_HOUR}:00"
            echo "  GC duration: ${GC_DURATION}s per burst"
            echo "  Pause: ${PAUSE_DURATION}s between bursts"
            echo "  Max cycles: ${MAX_CYCLES}"
            echo "  Max load: ${MAX_LOAD_AVERAGE}"
            exit 0
            ;;
    esac
done

log "=========================================="
log "🚀 Gentle IPFS Garbage Collection Starting"
log "=========================================="
log "⏰ Time window: ${START_HOUR}:00 - ${END_HOUR}:00"
log "🔄 GC burst: ${GC_DURATION}s on, ${PAUSE_DURATION}s off"
log "📊 Max cycles: ${MAX_CYCLES}"
log "⚡ Max load: ${MAX_LOAD_AVERAGE}"

# Check if we're in the time window
if ! is_within_time_window && [ "$FORCE" != "true" ]; then
    log "❌ Outside time window (current hour: $(date +%H)). Use --force to override."
    exit 0
fi

# Check IPFS is running
if ! $IPFS_CMD id &>/dev/null; then
    log_error "IPFS daemon not running!"
    exit 1
fi

log "📊 Current repo size: $(get_repo_size)"
log "🔗 Active connections: $(get_ipfs_connections)"
log "💻 System load: $(get_load_average)"

if [ "$DRY_RUN" = "true" ]; then
    log "🔍 DRY RUN - Would run $MAX_CYCLES GC cycles"
    log "🔍 Each cycle: ${GC_DURATION}s GC + ${PAUSE_DURATION}s pause"
    log "🔍 Total estimated time: $(( (GC_DURATION + PAUSE_DURATION) * MAX_CYCLES / 60 )) minutes"
    exit 0
fi

# Run GC cycles
for cycle in $(seq 1 $MAX_CYCLES); do
    log ""
    log "🔄 === Cycle $cycle of $MAX_CYCLES ==="
    
    # Check time window before each cycle
    if ! is_within_time_window && [ "$FORCE" != "true" ]; then
        log "⏰ Time window ended. Stopping."
        break
    fi
    
    # Check system health
    if ! is_load_ok; then
        log "⚠️  System load too high ($(get_load_average)). Waiting..."
        sleep 60
        continue
    fi
    
    # Run GC burst
    run_gc_burst $GC_DURATION
    gc_result=$?
    
    # If GC completed naturally (repo is clean), we're done
    if [ $gc_result -eq 0 ] && [ $cycle -lt $MAX_CYCLES ]; then
        # Check if there's likely more to collect
        log "✅ GC burst complete"
    fi
    
    # Pause between cycles (unless this is the last one)
    if [ $cycle -lt $MAX_CYCLES ]; then
        log "😴 Pausing for ${PAUSE_DURATION}s to let IPFS breathe..."
        sleep $PAUSE_DURATION
    fi
done

log ""
log "=========================================="
log "✅ Gentle GC Complete"
log "📊 Final repo size: $(get_repo_size)"
log "=========================================="
