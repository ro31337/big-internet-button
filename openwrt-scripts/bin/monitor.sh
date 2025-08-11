#!/bin/sh
# Big Internet Button - Real-time Monitor

CONFIG_FILE="/etc/big-button/config"
STATE_FILE="/etc/big-button/state"
LOG_FILE="/tmp/big-button.log"

# Load config - REQUIRED, no defaults!
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file $CONFIG_FILE not found!" >&2
    exit 1
fi
. "$CONFIG_FILE"

# Calculate WARNING_MINUTES after loading config
WARNING_MINUTES=$((TIMER_MINUTES - 1))

while true; do
    clear
    echo '╔══════════════════════════════════════════╗'
    echo '║   Big Internet Button Monitor           ║'
    echo '╚══════════════════════════════════════════╝'
    echo ''
    
    TIMER=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo 'unknown')
    
    # Show timer with visual progress bar
    echo "Timer: $TIMER / $TIMER_MINUTES minutes"
    
    # Progress bar
    printf "["
    for i in $(seq 1 $TIMER_MINUTES); do
        if [ $i -le $TIMER ]; then
            printf "█"
        else
            printf " "
        fi
    done
    printf "]\n\n"
    
    echo "Status: $STATUS"
    echo "Time: $(date '+%H:%M:%S')"
    echo "Warning at: $WARNING_MINUTES min | Block at: $TIMER_MINUTES min"
    
    # Check listener process
    if ps | grep -q '[b]ig-button-listener'; then
        echo "Listener: ✓ Running"
    else
        echo "Listener: ✗ Not running"
    fi
    
    # Show alerts
    if [ "$TIMER" -eq "$WARNING_MINUTES" ]; then
        echo ''
        echo '┌──────────────────────────────────────┐'
        echo '│ ⚠️  WARNING: 1 minute until block!   │'
        echo '└──────────────────────────────────────┘'
    elif [ "$TIMER" -ge "$TIMER_MINUTES" ]; then
        echo ''
        echo '┌──────────────────────────────────────┐'
        echo '│ 🔴 INTERNET BLOCKED                  │'
        echo '│    Press button to restore!          │'
        echo '└──────────────────────────────────────┘'
    fi
    
    echo ''
    echo 'Last 3 log entries:'
    tail -3 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
    
    echo ''
    echo 'Press Ctrl+C to exit monitor'
    sleep 5
done