#!/bin/sh
# Big Internet Button - Control and Utility Script
# Provides manual control and testing functions

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
        echo "$(date '+%Y-%m-%d %H:%M:%S') - CONTROL: $1" >> "$LOG_FILE"
    fi
}

# Usage information
usage() {
    cat << EOF
Big Internet Button Control Utility

Usage: $0 [command] [options]

Commands:
    status          Show current system status
    reset           Reset timer to 0
    block           Manually block internet
    unblock         Manually unblock internet
    led on|off      Control LED state
    beep high|low   Play beep sound
    test            Run system test
    config          Show current configuration
    log [n]         Show last n log entries (default: 20)
    monitor         Monitor button events in real-time
    
Examples:
    $0 status
    $0 led on
    $0 beep high
    $0 log 50
EOF
    exit 1
}

# Show system status
show_status() {
    echo "╔════════════════════════════════════════════╗"
    echo "║      Big Internet Button Status           ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    
    # Get timer values
    if [ -f "$STATE_FILE" ]; then
        ELAPSED=$(cat "$STATE_FILE")
        STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo "unknown")
    else
        ELAPSED=0
        STATUS="unknown"
    fi
    
    # Calculate remaining time
    REMAINING=$((TIMER_MINUTES - ELAPSED))
    WARNING_IN=$((WARNING_MINUTES - ELAPSED))
    
    echo "Configuration:"
    echo "  • Timer Duration: $TIMER_MINUTES minutes"
    echo "  • Warning At: $WARNING_MINUTES minutes"
    echo "  • Snooze Mode: $([ "$SNOOZE_MODE" = "1" ] && echo "ENABLED (button adds time)" || echo "DISABLED")"
    echo ""
    
    echo "Current State:"
    echo "  • Timer: $ELAPSED / $TIMER_MINUTES minutes elapsed"
    echo "  • Status: $STATUS"
    
    # Check internet status
    if nft list table inet big_button 2>/dev/null | grep -q "drop"; then
        echo "  • Internet: 🔴 BLOCKED (press button to restore)"
    else
        echo "  • Internet: 🟢 ALLOWED"
    fi
    echo ""
    
    echo "Timeline:"
    if [ "$STATUS" = "blocked" ]; then
        echo "  ⚠️  INTERNET IS BLOCKED - Press button to restore!"
    elif [ "$ELAPSED" -ge "$WARNING_MINUTES" ]; then
        echo "  ⚠️  WARNING ACTIVE - Internet blocks in $REMAINING minute(s)!"
    elif [ "$WARNING_IN" -gt 0 ]; then
        echo "  • Warning in: $WARNING_IN minute(s)"
        echo "  • Internet blocks in: $REMAINING minute(s)"
    else
        echo "  • Internet blocks in: $REMAINING minute(s)"
    fi
    echo ""
    
    echo "System Components:"
    # Check listener
    if [ -f /var/run/big-button-listener.pid ] && kill -0 $(cat /var/run/big-button-listener.pid) 2>/dev/null; then
        echo "  • Listener: ✓ Running (PID: $(cat /var/run/big-button-listener.pid))"
    else
        echo "  • Listener: ✗ NOT RUNNING"
    fi
    
    # Check cron
    if crontab -l 2>/dev/null | grep -q "big-button-timer"; then
        echo "  • Timer Cron: ✓ Installed"
    else
        echo "  • Timer Cron: ✗ Not installed"
    fi
    
    # Check devices
    if [ -c "$DEVICE_SERIAL" ]; then
        echo "  • Button Serial: ✓ Connected ($DEVICE_SERIAL)"
    else
        echo "  • Button Serial: ✗ Not found"
    fi
    
    if [ -c "$DEVICE_INPUT" ]; then
        echo "  • Button Input: ✓ Connected ($DEVICE_INPUT)"
    else
        echo "  • Button Input: ✗ Not found"
    fi
    
    echo ""
    echo "Last Log Entries:"
    if [ -f "$LOG_FILE" ]; then
        tail -3 "$LOG_FILE" | sed 's/^/  /'
    else
        echo "  No logs available"
    fi
}

# Reset timer
reset_timer() {
    echo "Resetting timer..."
    log_message "Manual timer reset requested"
    echo "0" > "$STATE_FILE"
    echo "active" > "${STATE_FILE}.status"
    rm -f "${STATE_FILE}.warning"
    log_message "Timer reset to 0 minutes"
    echo "Timer reset to 0 minutes"
}

# Block internet manually
block_internet() {
    echo "Blocking internet access..."
    log_message "Manual internet block requested"
    
    # Create nftables rules
    nft add table inet big_button 2>/dev/null
    nft add chain inet big_button forward \{ type filter hook forward priority 0 \; \} 2>/dev/null
    nft add rule inet big_button forward drop 2>/dev/null
    
    # Turn on LED
    echo "2" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Update status
    echo "blocked" > "${STATE_FILE}.status"
    
    log_message "Internet blocked manually"
    echo "Internet blocked"
}

# Unblock internet manually
unblock_internet() {
    echo "Unblocking internet access..."
    log_message "Manual internet unblock requested"
    
    # Remove nftables rules
    nft delete table inet big_button 2>/dev/null
    
    # Turn off LED
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Update status
    echo "active" > "${STATE_FILE}.status"
    
    log_message "Internet unblocked manually"
    echo "Internet unblocked"
}

# Control LED
control_led() {
    case "$1" in
        on)
            log_message "Manual LED ON"
            echo "2" > "$DEVICE_SERIAL" 2>/dev/null
            echo "LED turned ON"
            ;;
        off)
            log_message "Manual LED OFF"
            echo "1" > "$DEVICE_SERIAL" 2>/dev/null
            echo "LED turned OFF"
            ;;
        *)
            echo "Usage: $0 led {on|off}"
            ;;
    esac
}

# Play beep
play_beep() {
    case "$1" in
        high)
            log_message "Manual high beep"
            echo "3" > "$DEVICE_SERIAL" 2>/dev/null
            echo "High beep played"
            ;;
        low)
            log_message "Manual low beep"
            echo "4" > "$DEVICE_SERIAL" 2>/dev/null
            echo "Low beep played"
            ;;
        *)
            echo "Usage: $0 beep {high|low}"
            ;;
    esac
}

# Run system test
run_test() {
    echo "=== Running System Test ==="
    echo ""
    
    # Test devices
    echo "1. Checking devices..."
    if [ ! -c "$DEVICE_SERIAL" ]; then
        echo "   ERROR: Serial device not found"
        return 1
    fi
    if [ ! -c "$DEVICE_INPUT" ]; then
        echo "   ERROR: Input device not found"
        return 1
    fi
    echo "   Devices OK"
    echo ""
    
    # Test LED
    echo "2. Testing LED..."
    echo "   LED ON"
    echo "2" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 1
    echo "   LED OFF"
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 1
    echo ""
    
    # Test beeps
    echo "3. Testing beeps..."
    echo "   High beep"
    echo "3" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 1
    echo "   Low beep"
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 1
    echo ""
    
    # Test blink pattern
    echo "4. Testing blink pattern..."
    for i in 1 2 3; do
        echo "2" > "$DEVICE_SERIAL" 2>/dev/null
        sleep 1
        echo "1" > "$DEVICE_SERIAL" 2>/dev/null
        sleep 1
    done
    echo "   Blink pattern complete"
    echo ""
    
    # Test internet control
    echo "5. Testing internet control..."
    echo "   Blocking..."
    nft add table inet big_button_test 2>/dev/null
    nft add chain inet big_button_test forward \{ type filter hook forward priority 0 \; \} 2>/dev/null
    nft add rule inet big_button_test forward drop 2>/dev/null
    sleep 1
    echo "   Unblocking..."
    nft delete table inet big_button_test 2>/dev/null
    echo "   Internet control OK"
    echo ""
    
    echo "=== Test Complete ==="
}

# Show configuration
show_config() {
    echo "=== Current Configuration ==="
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
        echo ""
        echo "Calculated values:"
        echo "  WARNING_MINUTES=$WARNING_MINUTES (TIMER_MINUTES - 1)"
    else
        echo "ERROR: Configuration file not found at $CONFIG_FILE"
        echo "Cannot run without configuration!"
        exit 1
    fi
}

# Show log entries
show_log() {
    local lines=${1:-20}
    if [ -f "$LOG_FILE" ]; then
        echo "=== Last $lines log entries ==="
        tail -n "$lines" "$LOG_FILE"
    else
        echo "No log file found"
    fi
}

# Monitor button events
monitor_events() {
    echo "=== Monitoring Button Events ==="
    echo "Press Ctrl+C to stop"
    echo ""
    
    if [ -c "$DEVICE_INPUT" ]; then
        echo "Listening on $DEVICE_INPUT..."
        hexdump -C "$DEVICE_INPUT"
    else
        echo "ERROR: Input device $DEVICE_INPUT not found"
        exit 1
    fi
}

# Main command dispatcher
case "$1" in
    status)
        show_status
        ;;
    reset)
        reset_timer
        ;;
    block)
        block_internet
        ;;
    unblock)
        unblock_internet
        ;;
    led)
        control_led "$2"
        ;;
    beep)
        play_beep "$2"
        ;;
    test)
        run_test
        ;;
    config)
        show_config
        ;;
    log)
        show_log "$2"
        ;;
    monitor)
        monitor_events
        ;;
    *)
        usage
        ;;
esac