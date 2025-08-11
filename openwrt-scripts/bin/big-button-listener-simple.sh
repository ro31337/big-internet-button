#!/bin/sh
# Big Internet Button - Simple Reliable Listener
# Uses a different approach that won't crash

# Configuration
CONFIG_FILE="/etc/big-button/config"
STATE_FILE="/etc/big-button/state"
LOG_FILE="/tmp/big-button.log"

# Load config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file $CONFIG_FILE not found!" >&2
    exit 1
fi
. "$CONFIG_FILE"

# Logging function
log_message() {
    if [ "$ENABLE_LOGGING" = "1" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - LISTENER: $1" >> "$LOG_FILE"
    fi
}

# Handle button press
handle_button_press() {
    STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo "active")
    
    if [ "$STATUS" = "blocked" ]; then
        log_message "Button pressed - restoring internet access"
        
        # Remove nftables blocking rules
        nft delete table inet big_button || true
        
        # Turn off LED
        echo "1" > "$DEVICE_SERIAL"
        
        # Two low beeps then one high beep
        echo "4" > "$DEVICE_SERIAL"
        echo "4" > "$DEVICE_SERIAL"
        echo "3" > "$DEVICE_SERIAL"
        
        # Reset timer
        echo "0" > "$STATE_FILE"
        echo "active" > "${STATE_FILE}.status"
        
        # Store button press time
        echo "$(date +%s)" > "${STATE_FILE}.last_press"
        
        # Remove warning and blocked files
        rm -f "${STATE_FILE}.warning"
        rm -f "${STATE_FILE}.warning_triggered"
        rm -f "${STATE_FILE}.blocked"
        
        # Stop LED blinker if running
        if [ -f "${STATE_FILE}.blinker_pid" ]; then
            BLINKER_PID=$(cat "${STATE_FILE}.blinker_pid" 2>/dev/null)
            if [ -n "$BLINKER_PID" ]; then
                kill "$BLINKER_PID" 2>/dev/null || true
            fi
            rm -f "${STATE_FILE}.blinker_pid"
        fi
        
        log_message "Internet restored - timer reset to 0"
        
    elif [ "$SNOOZE_MODE" = "1" ]; then
        CURRENT_TIMER=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
        
        # Stop any LED blinker
        if [ -f "${STATE_FILE}.blinker_pid" ]; then
            BLINKER_PID=$(cat "${STATE_FILE}.blinker_pid" 2>/dev/null)
            if [ -n "$BLINKER_PID" ]; then
                kill "$BLINKER_PID" 2>/dev/null || true
            fi
            rm -f "${STATE_FILE}.blinker_pid"
        fi
        
        # Turn off LED
        echo "1" > "$DEVICE_SERIAL"         
        # Two low beeps then one high beep
        echo "4" > "$DEVICE_SERIAL"         echo "4" > "$DEVICE_SERIAL"         echo "3" > "$DEVICE_SERIAL"         
        log_message "Button pressed - timer reset to 0 (was $CURRENT_TIMER minutes)"
    else
        log_message "Button pressed but internet not blocked - ignoring"
    fi
}

# Main loop - use cat instead of dd/hexdump
main() {
    log_message "Button listener started (TIMER=$TIMER_MINUTES min, SNOOZE=$SNOOZE_MODE)"
    log_message "Monitoring input device: $DEVICE_INPUT"
    
    # Store PID
    echo $$ > /var/run/big-button-listener.pid
    
    LAST_PRESS=0
    
    # Main loop - read input events continuously
    while true; do
        if [ ! -c "$DEVICE_INPUT" ]; then
            log_message "WARNING: Input device not found, waiting..."
            sleep 5
            continue
        fi
        
        # Read 24-byte events from input device
        # This approach reads one event at a time and won't crash
        while [ -c "$DEVICE_INPUT" ]; do
            # Read one event (24 bytes)
            EVENT=$(dd if="$DEVICE_INPUT" bs=24 count=1 2>/dev/null | hexdump -C | head -1)
            
            # Check if it's an Enter key event
            if echo "$EVENT" | grep -q "01 00 1c 00\|58 00 07"; then
                CURRENT_TIME=$(date +%s)
                TIME_DIFF=$((CURRENT_TIME - LAST_PRESS))
                
                # Debounce
                if [ "$TIME_DIFF" -ge "$DEBOUNCE_TIME" ]; then
                    log_message "Button press detected"
                    handle_button_press
                    LAST_PRESS=$CURRENT_TIME
                fi
            fi
        done
        
        # Device disappeared, wait and retry
        log_message "Input device disconnected, waiting..."
        sleep 2
    done
}

# Cleanup
cleanup() {
    log_message "Listener shutting down"
    rm -f /var/run/big-button-listener.pid
    exit 0
}

# Only trap INT and TERM, not HUP
trap cleanup INT TERM

# Start
main