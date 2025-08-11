#!/bin/sh
# Big Internet Button - Timer Management Script
# Runs every minute via cron to check timer status

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
        echo "$(date '+%Y-%m-%d %H:%M:%S') - TIMER: $1" >> "$LOG_FILE"
    fi
}

# Blink LED pattern
blink_led() {
    local count=$1
    local delay=${2:-1}  # Default to 1 second (router limitation)
    
    log_message "Blinking LED $count times"
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
    
    # Stop LED blinker if running
    if [ -f "${STATE_FILE}.blinker_pid" ]; then
        BLINKER_PID=$(cat "${STATE_FILE}.blinker_pid" 2>/dev/null)
        if [ -n "$BLINKER_PID" ] && kill -0 "$BLINKER_PID" 2>/dev/null; then
            log_message "Stopping LED blinker (PID: $BLINKER_PID)"
            kill "$BLINKER_PID" 2>/dev/null || true
            
            # Also kill any orphaned sleep processes from the blinker
            sleep 1
            for pid in $(ps | grep "sleep 1" | grep -v grep | awk '{print $1}'); do
                kill $pid 2>/dev/null || true
            done
        fi
        rm -f "${STATE_FILE}.blinker_pid"
    fi
    
    # Clean up blinker script
    rm -f /tmp/blinker.sh
    
    # Mark as blocked (stops blinker loop)
    touch "${STATE_FILE}.blocked"
    
    # Create nftables rules to block forwarding
    nft add table inet big_button 2>/dev/null
    nft add chain inet big_button forward \{ type filter hook forward priority 0 \; \} 2>/dev/null
    nft add rule inet big_button forward drop 2>/dev/null
    
    # Turn on solid red LED (no beep)
    echo "2" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Update status
    echo "blocked" > "${STATE_FILE}.status"
    
    # Clean up warning files
    rm -f "${STATE_FILE}.warning_triggered"
    
    log_message "Internet blocked - LED on solid, waiting for button press"
}

# Check if internet is already blocked
is_internet_blocked() {
    nft list table inet big_button 2>/dev/null | grep -q "drop" && return 0
    return 1
}

# Main timer logic
main() {
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
        log_message "Internet is blocked - timer paused at $ELAPSED minutes"
        exit 0
    fi
    
    # Increment timer
    ELAPSED=$((ELAPSED + 1))
    echo "$ELAPSED" > "$STATE_FILE"
    
    log_message "Timer incremented to $ELAPSED / $TIMER_MINUTES minutes (warning at $WARNING_MINUTES)"
    
    # Check for warning time (1 minute before timeout)
    if [ "$ELAPSED" -eq "$WARNING_MINUTES" ]; then
        # Only trigger warning once when we first hit warning time
        if [ ! -f "${STATE_FILE}.warning_triggered" ]; then
            log_message "Warning: 1 minute until internet timeout"
            
            # Three high beeps without sleep
            echo "3" > "$DEVICE_SERIAL" 2>/dev/null
            echo "3" > "$DEVICE_SERIAL" 2>/dev/null
            echo "3" > "$DEVICE_SERIAL" 2>/dev/null
            
            # Mark warning as triggered
            touch "${STATE_FILE}.warning_triggered"
            
            # Start LED blinker in background with proper PID tracking
            log_message "Starting LED blinker for warning"
            
            # Create blinker script
            cat > /tmp/blinker.sh << 'BLINKER'
#!/bin/sh
echo $$ > /etc/big-button/state.blinker_pid
trap 'exit 0' TERM INT HUP
while [ -f "/etc/big-button/state.warning_triggered" ] && [ ! -f "/etc/big-button/state.blocked" ]; do
    echo "2" > /dev/ttyACM0 2>/dev/null
    sleep 1
    echo "1" > /dev/ttyACM0 2>/dev/null
    sleep 1
done
BLINKER
            chmod +x /tmp/blinker.sh
            /tmp/blinker.sh > /dev/null 2>&1 &
            
            sleep 1
            if [ -f "${STATE_FILE}.blinker_pid" ]; then
                BLINKER_PID=$(cat "${STATE_FILE}.blinker_pid")
                log_message "Started LED blinker with PID: $BLINKER_PID"
            else
                log_message "Warning: Could not capture blinker PID"
            fi
            
            log_message "Warning beeps sent, LED blinker started"
        fi
        
    # Check for timeout
    elif [ "$ELAPSED" -ge "$TIMER_MINUTES" ]; then
        log_message "Timer expired after $TIMER_MINUTES minutes"
        
        # No beep, just solid red LED
        log_message "Blocking internet access - LED on, no beep"
        
        # Block internet
        block_internet
        
        # Remove warning file
        rm -f "${STATE_FILE}.warning"
    fi
}

# Run main function
main