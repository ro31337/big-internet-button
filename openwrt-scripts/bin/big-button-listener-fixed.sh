#!/bin/sh
# Big Internet Button - Fixed Listener Script
# More robust version that doesn't crash

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

# Function to handle button press when internet is blocked
handle_blocked_state() {
    log_message "Button pressed - restoring internet access"
    
    # Remove nftables blocking rules
    nft delete table inet big_button 2>/dev/null || true
    
    # Turn off LED
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null || true
    
    # Two low beeps then one high beep
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null || true
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null || true
    echo "3" > "$DEVICE_SERIAL" 2>/dev/null || true
    
    # Reset timer to 0
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
}

# Function to handle button press in snooze mode
handle_snooze_mode() {
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
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null || true
    
    # Two low beeps then one high beep
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null || true
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null || true
    echo "3" > "$DEVICE_SERIAL" 2>/dev/null || true
    
    log_message "Button pressed - timer reset to 0 (was $CURRENT_TIMER minutes)"
}

# Main loop - simplified and more robust
main_loop() {
    log_message "Button listener started (TIMER=$TIMER_MINUTES min, SNOOZE=$SNOOZE_MODE)"
    log_message "Monitoring input device: $DEVICE_INPUT"
    
    # Store PID for management
    echo $$ > /var/run/big-button-listener.pid
    
    LAST_PRESS=0
    
    # Main loop - will restart if hexdump fails
    while true; do
        # Check if device exists
        if [ ! -c "$DEVICE_INPUT" ]; then
            log_message "WARNING: Input device not found, waiting..."
            sleep 5
            continue
        fi
        
        # Read from device - this will block until data arrives
        # If it fails, the loop continues
        hexdump -C "$DEVICE_INPUT" 2>/dev/null | while IFS= read -r line; do
            # Check for Enter key pattern
            if echo "$line" | grep -q "01 00 1c 00\|58 00 07"; then
                CURRENT_TIME=$(date +%s)
                TIME_DIFF=$((CURRENT_TIME - LAST_PRESS))
                
                # Debounce - ignore if pressed too quickly
                if [ "$TIME_DIFF" -ge "$DEBOUNCE_TIME" ]; then
                    log_message "Button press detected"
                    
                    # Check current status
                    STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo "active")
                    
                    if [ "$STATUS" = "blocked" ]; then
                        handle_blocked_state
                    elif [ "$SNOOZE_MODE" = "1" ]; then
                        handle_snooze_mode
                    else
                        log_message "Button pressed but internet not blocked - ignoring"
                    fi
                    
                    LAST_PRESS=$CURRENT_TIME
                    
                    # Important: Update the outer loop's LAST_PRESS
                    echo "$CURRENT_TIME" > /tmp/last_button_press
                fi
            fi
        done
        
        # If hexdump exits (device disconnect, etc), log and retry
        log_message "Input stream interrupted, restarting monitoring..."
        sleep 1
        
        # Update LAST_PRESS from file if it was updated
        if [ -f /tmp/last_button_press ]; then
            LAST_PRESS=$(cat /tmp/last_button_press)
            rm -f /tmp/last_button_press
        fi
    done
}

# Cleanup function
cleanup() {
    log_message "Listener shutting down"
    rm -f /var/run/big-button-listener.pid
    rm -f /tmp/last_button_press
    exit 0
}

# Set up signal handlers
trap cleanup INT TERM HUP

# Start the main loop
main_loop