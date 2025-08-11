#!/bin/sh
# Big Internet Button - RELIABLE Listener
# NO FANCY SHIT - JUST WORKS

CONFIG_FILE="/etc/big-button/config"
STATE_FILE="/etc/big-button/state"
LOG_FILE="/tmp/big-button.log"

# Load config
. "$CONFIG_FILE"

# Log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - LISTENER: $1" >> "$LOG_FILE"
}

# Start
log_message "Button listener started (TIMER=$TIMER_MINUTES min, SNOOZE=$SNOOZE_MODE)"
log_message "Monitoring input device: $DEVICE_INPUT"

# Save PID
echo $$ > /var/run/big-button-listener.pid

LAST_PRESS=0

# MAIN LOOP - NEVER EXITS
while true; do
    # Make sure device exists
    if [ ! -c "$DEVICE_INPUT" ]; then
        sleep 5
        continue
    fi
    
    # Read ONE event at a time - 24 bytes
    EVENT_HEX=$(dd if="$DEVICE_INPUT" bs=24 count=1 | hexdump -C | head -1)
    
    # Check if Enter key (multiple patterns because who knows)
    if echo "$EVENT_HEX" | grep -q "01 00 1c 00\|58 00 07\|1c 00 01 00"; then
        
        # Debounce
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - LAST_PRESS))
        
        if [ "$TIME_DIFF" -lt "$DEBOUNCE_TIME" ]; then
            continue
        fi
        
        log_message "Button press detected"
        LAST_PRESS=$CURRENT_TIME
        
        # Get status
        STATUS=$(cat "${STATE_FILE}.status" || echo "active")
        
        if [ "$STATUS" = "blocked" ]; then
            log_message "Button pressed - restoring internet"
            
            # Unblock internet
            nft delete table inet big_button || true
            
            # LED off
            echo "1" > "$DEVICE_SERIAL"
            
            # Beeps: low-low-high
            echo "4" > "$DEVICE_SERIAL"
            echo "4" > "$DEVICE_SERIAL"
            echo "3" > "$DEVICE_SERIAL"
            
            # Reset state
            echo "0" > "$STATE_FILE"
            echo "active" > "${STATE_FILE}.status"
            echo "$(date +%s)" > "${STATE_FILE}.last_press"
            
            # Clean up files
            rm -f "${STATE_FILE}.warning"
            rm -f "${STATE_FILE}.warning_triggered"
            rm -f "${STATE_FILE}.blocked"
            
            # Kill blinker if exists
            if [ -f "${STATE_FILE}.blinker_pid" ]; then
                kill $(cat "${STATE_FILE}.blinker_pid") || true
                rm -f "${STATE_FILE}.blinker_pid"
            fi
            
            log_message "Internet restored - timer at 0"
            
        elif [ "$SNOOZE_MODE" = "1" ]; then
            CURRENT_TIMER=$(cat "$STATE_FILE" || echo 0)
            
            # Kill blinker if exists
            if [ -f "${STATE_FILE}.blinker_pid" ]; then
                kill $(cat "${STATE_FILE}.blinker_pid") || true
                rm -f "${STATE_FILE}.blinker_pid"
            fi
            
            # LED off
            echo "1" > "$DEVICE_SERIAL"
            
            # Beeps: low-low-high
            echo "4" > "$DEVICE_SERIAL"
            echo "4" > "$DEVICE_SERIAL"
            echo "3" > "$DEVICE_SERIAL"
            
            # Reset timer
            echo "0" > "$STATE_FILE"
            echo "active" > "${STATE_FILE}.status"
            echo "$(date +%s)" > "${STATE_FILE}.last_press"
            
            # Clean up warning files
            rm -f "${STATE_FILE}.warning"
            rm -f "${STATE_FILE}.warning_triggered"
            
            log_message "Timer reset to 0 (was $CURRENT_TIMER)"
        else
            log_message "Button pressed - ignoring (not blocked)"
        fi
    fi
done