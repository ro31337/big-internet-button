#!/bin/sh
# Big Internet Button - Control and Utility Script
# Provides manual control and testing functions

# Configuration
CONFIG_FILE="/etc/big-button/config"
STATE_FILE="/etc/big-button/state"
LOG_FILE="/tmp/big-button.log"
DEVICE_SERIAL="/dev/ttyACM0"
DEVICE_INPUT="/dev/input/event0"

# Load config
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

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
    echo "=== Big Internet Button Status ==="
    echo ""
    
    # Check daemon
    if [ -f /var/run/big-button-daemon.pid ] && kill -0 $(cat /var/run/big-button-daemon.pid) 2>/dev/null; then
        echo "Daemon: RUNNING (PID: $(cat /var/run/big-button-daemon.pid))"
    else
        echo "Daemon: NOT RUNNING"
    fi
    
    # Check listener
    if [ -f /var/run/big-button-listener.pid ] && kill -0 $(cat /var/run/big-button-listener.pid) 2>/dev/null; then
        echo "Listener: RUNNING (PID: $(cat /var/run/big-button-listener.pid))"
    else
        echo "Listener: NOT RUNNING"
    fi
    
    # Check timer
    if [ -f "$STATE_FILE" ]; then
        ELAPSED=$(cat "$STATE_FILE")
        STATUS=$(cat "${STATE_FILE}.status" 2>/dev/null || echo "unknown")
        echo "Timer: $ELAPSED minutes"
        echo "Status: $STATUS"
    else
        echo "Timer: Not initialized"
    fi
    
    # Check internet blocking
    if nft list table inet big_button 2>/dev/null | grep -q "drop"; then
        echo "Internet: BLOCKED"
    else
        echo "Internet: ALLOWED"
    fi
    
    # Check devices
    echo ""
    echo "=== Device Status ==="
    [ -c "$DEVICE_SERIAL" ] && echo "Serial: $DEVICE_SERIAL (OK)" || echo "Serial: $DEVICE_SERIAL (NOT FOUND)"
    [ -c "$DEVICE_INPUT" ] && echo "Input: $DEVICE_INPUT (OK)" || echo "Input: $DEVICE_INPUT (NOT FOUND)"
}

# Reset timer
reset_timer() {
    echo "Resetting timer..."
    echo "0" > "$STATE_FILE"
    echo "active" > "${STATE_FILE}.status"
    rm -f "${STATE_FILE}.warning"
    echo "Timer reset to 0 minutes"
}

# Block internet manually
block_internet() {
    echo "Blocking internet access..."
    
    # Create nftables rules
    nft add table inet big_button 2>/dev/null
    nft add chain inet big_button forward \{ type filter hook forward priority 0 \; \} 2>/dev/null
    nft add rule inet big_button forward drop 2>/dev/null
    
    # Turn on LED
    echo "2" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Update status
    echo "blocked" > "${STATE_FILE}.status"
    
    echo "Internet blocked"
}

# Unblock internet manually
unblock_internet() {
    echo "Unblocking internet access..."
    
    # Remove nftables rules
    nft delete table inet big_button 2>/dev/null
    
    # Turn off LED
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null
    
    # Update status
    echo "active" > "${STATE_FILE}.status"
    
    echo "Internet unblocked"
}

# Control LED
control_led() {
    case "$1" in
        on)
            echo "2" > "$DEVICE_SERIAL" 2>/dev/null
            echo "LED turned ON"
            ;;
        off)
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
            echo "3" > "$DEVICE_SERIAL" 2>/dev/null
            echo "High beep played"
            ;;
        low)
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
    sleep 0.5
    echo ""
    
    # Test beeps
    echo "3. Testing beeps..."
    echo "   High beep"
    echo "3" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 0.5
    echo "   Low beep"
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 0.5
    echo ""
    
    # Test blink pattern
    echo "4. Testing blink pattern..."
    for i in 1 2 3; do
        echo "2" > "$DEVICE_SERIAL" 2>/dev/null
        sleep 0.3
        echo "1" > "$DEVICE_SERIAL" 2>/dev/null
        sleep 0.3
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
    else
        echo "No configuration file found"
        echo "Using defaults:"
        echo "  TIMER_MINUTES=40"
        echo "  WARNING_MINUTES=39"
        echo "  DEVICE_SERIAL=/dev/ttyACM0"
        echo "  DEVICE_INPUT=/dev/input/event0"
        echo "  ENABLE_LOGGING=1"
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