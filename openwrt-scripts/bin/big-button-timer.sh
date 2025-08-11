#!/bin/sh
# Big Internet Button - Timer Management Script
# Runs every minute via cron to check timer status

# Configuration
CONFIG_FILE="/etc/big-button/config"
STATE_FILE="/etc/big-button/state"
LOG_FILE="/tmp/big-button.log"
DEVICE_SERIAL="/dev/ttyACM0"

# Default values
TIMER_MINUTES=40
WARNING_MINUTES=39
WARNING_REPEAT_SECONDS=30
ENABLE_LOGGING=1

# Load config
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# Logging function
log_message() {
    if [ "$ENABLE_LOGGING" = "1" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - TIMER: $1" >> "$LOG_FILE"
    fi
}

# Blink LED pattern
blink_led() {
    local count=$1
    local delay=${2:-0.5}
    
    for i in $(seq 1 $count); do
        echo "2" > "$DEVICE_SERIAL" 2>/dev/null
        sleep "$delay"
        echo "1" > "$DEVICE_SERIAL" 2>/dev/null
        sleep "$delay"
    done
}

# Block internet access
block_internet() {
    log_message "Blocking internet access"
    
    # Create nftables rules to block forwarding
    nft add table inet big_button 2>/dev/null
    nft add chain inet big_button forward \{ type filter hook forward priority 0 \; \} 2>/dev/null
    nft add rule inet big_button forward drop 2>/dev/null
    
    # Turn on red LED
    echo "2" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Update status
    echo "blocked" > "${STATE_FILE}.status"
    
    log_message "Internet blocked - waiting for button press"
}

# Check if internet is already blocked
is_internet_blocked() {
    nft list table inet big_button 2>/dev/null | grep -q "drop" && return 0
    return 1
}

# Main timer logic
main() {
    # Check if daemon is running
    if [ ! -f /var/run/big-button-daemon.pid ]; then
        exit 0
    fi
    
    # Check if devices exist
    if [ ! -c "$DEVICE_SERIAL" ]; then
        log_message "ERROR: Serial device not found"
        exit 1
    fi
    
    # Get current timer value
    ELAPSED=0
    if [ -f "$STATE_FILE" ]; then
        ELAPSED=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    fi
    
    # Get current status
    STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo "active")
    
    # If internet is blocked, don't increment timer
    if [ "$STATUS" = "blocked" ] || is_internet_blocked; then
        exit 0
    fi
    
    # Increment timer
    ELAPSED=$((ELAPSED + 1))
    echo "$ELAPSED" > "$STATE_FILE"
    
    # Check for warning time (1 minute before timeout)
    if [ "$ELAPSED" -eq "$WARNING_MINUTES" ]; then
        log_message "Warning: 1 minute until internet timeout"
        
        # High beep
        echo "3" > "$DEVICE_SERIAL" 2>/dev/null
        
        # Three blinks
        blink_led 3 0.5
        
        # Store warning time for repeat warnings
        echo "$(date +%s)" > "${STATE_FILE}.warning"
        
    # Check for 30-second warning
    elif [ "$ELAPSED" -eq "$WARNING_MINUTES" ] && [ -f "${STATE_FILE}.warning" ]; then
        LAST_WARNING=$(cat "${STATE_FILE}.warning" 2>/dev/null || echo 0)
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - LAST_WARNING))
        
        # If 30 seconds have passed since last warning
        if [ "$TIME_DIFF" -ge "$WARNING_REPEAT_SECONDS" ]; then
            log_message "Warning: 30 seconds until internet timeout"
            
            # Flash LED without beep
            blink_led 3 0.3
            
            echo "$CURRENT_TIME" > "${STATE_FILE}.warning"
        fi
        
    # Check for timeout
    elif [ "$ELAPSED" -ge "$TIMER_MINUTES" ]; then
        log_message "Timer expired after $TIMER_MINUTES minutes"
        
        # Double high beep
        echo "3" > "$DEVICE_SERIAL" 2>/dev/null
        sleep 0.2
        echo "3" > "$DEVICE_SERIAL" 2>/dev/null
        
        # Block internet
        block_internet
        
        # Remove warning file
        rm -f "${STATE_FILE}.warning"
    fi
}

# Run main function
main