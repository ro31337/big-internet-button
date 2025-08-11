#!/bin/sh
# Big Internet Button - Button Press Listener
# Monitors the input device for button presses (Enter key)

# Configuration
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

# Logging function
log_message() {
    if [ "$ENABLE_LOGGING" = "1" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - LISTENER: $1" >> "$LOG_FILE"
    fi
}

# Add time to timer (snooze function)
add_timer_minutes() {
    # Get current timer value
    CURRENT_TIMER=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    
    # Reset timer to 0 (we'll add time from button press moment)
    echo "0" > "$STATE_FILE"
    
    # Store the last button press time
    echo "$(date +%s)" > "${STATE_FILE}.last_press"
    
    # Clean up warning state and blinker if active
    rm -f "${STATE_FILE}.warning_triggered"
    rm -f "${STATE_FILE}.blocked"
    
    # Stop LED blinker if running
    if [ -f "${STATE_FILE}.blinker_pid" ]; then
        BLINKER_PID=$(cat "${STATE_FILE}.blinker_pid" 2>/dev/null)
        if [ -n "$BLINKER_PID" ] && kill -0 "$BLINKER_PID" 2>/dev/null; then
            kill "$BLINKER_PID" 2>/dev/null || true
            
            # Also kill any orphaned sleep processes from the blinker
            sleep 1
            for pid in $(ps | grep "sleep 1" | grep -v grep | awk '{print $1}'); do
                kill $pid 2>/dev/null || true
            done
        fi
        rm -f "${STATE_FILE}.blinker_pid"
        rm -f /tmp/blinker.sh
    fi
    
    # Turn off LED first
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Two low beeps then one high beep (no sleep)
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null
    echo "3" > "$DEVICE_SERIAL" 2>/dev/null
    
    log_message "Button pressed - timer reset to 0 (was $CURRENT_TIMER minutes)"
    log_message "Timer will count up to $TIMER_MINUTES minutes from now"
}

# Restore internet access (when blocked)
restore_internet() {
    log_message "Button pressed - restoring internet access"
    
    # Remove nftables blocking rules
    nft delete table inet big_button 2>/dev/null
    
    # Turn off LED
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Two low beeps then one high beep (no sleep)
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null
    echo "3" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Reset timer
    echo "0" > "$STATE_FILE"
    echo "active" > "${STATE_FILE}.status"
    
    # Store button press time
    echo "$(date +%s)" > "${STATE_FILE}.last_press"
    
    # Remove warning and blocked files
    rm -f "${STATE_FILE}.warning"
    rm -f "${STATE_FILE}.warning_triggered"
    rm -f "${STATE_FILE}.blocked"
    
    # Stop LED blinker if running (shouldn't be, but just in case)
    if [ -f "${STATE_FILE}.blinker_pid" ]; then
        BLINKER_PID=$(cat "${STATE_FILE}.blinker_pid" 2>/dev/null)
        if [ -n "$BLINKER_PID" ] && kill -0 "$BLINKER_PID" 2>/dev/null; then
            kill "$BLINKER_PID" 2>/dev/null || true
        fi
        rm -f "${STATE_FILE}.blinker_pid"
    fi
    
    log_message "Internet restored - timer reset"
}

# Check if button event is Enter key
is_enter_key() {
    # Read 24 bytes from input device
    # Event structure: timestamp (8 bytes) + type (2) + code (2) + value (4) + padding (8)
    # Looking for EV_KEY (type 1) with KEY_ENTER (code 28) and value 1 (press)
    
    local event_data="$1"
    
    # Check if this looks like a key event
    # This is simplified - in production you'd parse the binary properly
    echo "$event_data" | grep -q "0001 001c 0001" && return 0
    
    # Alternative check for different format
    echo "$event_data" | grep -q "58 00 07" && return 0  # Observed pattern
    
    return 1
}

# Main listener loop
main() {
    log_message "Button listener started (TIMER=$TIMER_MINUTES min, SNOOZE=$SNOOZE_MODE)"
    log_message "Monitoring input device: $DEVICE_INPUT"
    
    # Check if input device exists
    if [ ! -c "$DEVICE_INPUT" ]; then
        log_message "ERROR: Input device $DEVICE_INPUT not found"
        exit 1
    fi
    
    LAST_PRESS=0
    
    # Monitor input device
    while true; do
        # Read events from input device
        # Using dd to read fixed-size chunks
        if dd if="$DEVICE_INPUT" bs=24 count=1 2>/dev/null | hexdump -C | head -1 > /tmp/button_event.tmp; then
            EVENT_DATA=$(cat /tmp/button_event.tmp)
            
            # Check if it's an Enter key press
            if [ -n "$EVENT_DATA" ] && is_enter_key "$EVENT_DATA"; then
                CURRENT_TIME=$(date +%s)
                TIME_DIFF=$((CURRENT_TIME - LAST_PRESS))
                
                # Debounce - ignore if pressed too quickly
                if [ "$TIME_DIFF" -ge "$DEBOUNCE_TIME" ]; then
                    log_message "Button press detected"
                    
                    # Check current status
                    STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo "active")
                    
                    if [ "$STATUS" = "blocked" ]; then
                        # Internet is blocked, restore it
                        restore_internet
                    elif [ "$SNOOZE_MODE" = "1" ]; then
                        # Snooze mode enabled - add time when button pressed
                        add_timer_minutes
                    else
                        log_message "Button pressed but internet not blocked - ignoring"
                    fi
                    
                    LAST_PRESS=$CURRENT_TIME
                fi
            fi
        fi
        
        # Small delay to prevent CPU spinning
        sleep 1
    done
}

# Alternative implementation using evtest if available
main_with_evtest() {
    log_message "Button listener started (evtest mode)"
    
    if ! which evtest >/dev/null 2>&1; then
        log_message "evtest not found, falling back to dd method"
        main
        return
    fi
    
    LAST_PRESS=0
    
    # Monitor with evtest
    evtest "$DEVICE_INPUT" 2>/dev/null | while read line; do
        # Look for Enter key press
        if echo "$line" | grep -q "KEY_ENTER.*value 1"; then
            CURRENT_TIME=$(date +%s)
            TIME_DIFF=$((CURRENT_TIME - LAST_PRESS))
            
            # Debounce
            if [ "$TIME_DIFF" -ge "$DEBOUNCE_TIME" ]; then
                log_message "Button press detected (evtest)"
                
                STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo "active")
                
                if [ "$STATUS" = "blocked" ]; then
                    # Internet is blocked, restore it
                    restore_internet
                elif [ "$SNOOZE_MODE" = "1" ]; then
                    # Snooze mode enabled - add time when button pressed
                    add_timer_minutes
                fi
                
                LAST_PRESS=$CURRENT_TIME
            fi
        fi
    done
}

# Trap signals for clean shutdown
trap 'log_message "Listener shutting down"; exit 0' INT TERM HUP

# Check if evtest is available and use it, otherwise fall back to dd method
if which evtest >/dev/null 2>&1; then
    main_with_evtest
else
    main
fi