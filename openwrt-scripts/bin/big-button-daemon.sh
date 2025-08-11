#!/bin/sh
# Big Internet Button - Main Daemon Script
# Manages the overall button system coordination

# Configuration paths
CONFIG_FILE="/etc/big-button/config"
STATE_FILE="/etc/big-button/state"
LOCK_FILE="/var/run/big-button.lock"
LOG_FILE="/tmp/big-button.log"
PID_FILE="/var/run/big-button-daemon.pid"

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
        echo "$(date '+%Y-%m-%d %H:%M:%S') - DAEMON: $1" >> "$LOG_FILE"
    fi
}

# Reload config function
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
        WARNING_MINUTES=$((TIMER_MINUTES - 1))
    fi
}

# Initialize button on startup
initialize_button() {
    log_message "Initializing Big Internet Button (TIMER=$TIMER_MINUTES min, WARNING=$WARNING_MINUTES min)"
    
    # Check if devices exist
    if [ ! -c "$DEVICE_SERIAL" ]; then
        log_message "ERROR: Serial device $DEVICE_SERIAL not found"
        return 1
    fi
    
    if [ ! -c "$DEVICE_INPUT" ]; then
        log_message "ERROR: Input device $DEVICE_INPUT not found"
        return 1
    fi
    
    # Blink LED and beep to indicate ready
    echo "2" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 1
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null
    sleep 1
    echo "3" > "$DEVICE_SERIAL" 2>/dev/null  # High beep
    sleep 1
    echo "4" > "$DEVICE_SERIAL" 2>/dev/null  # Low beep
    
    log_message "Button initialized successfully"
    return 0
}

# Reset timer and state
reset_state() {
    echo "0" > "$STATE_FILE"
    echo "active" > "${STATE_FILE}.status"
    log_message "State reset - timer started"
}

# Start background processes
start_processes() {
    log_message "Starting background processes"
    
    # Start button listener
    /usr/local/bin/big-button-listener.sh &
    echo $! > /var/run/big-button-listener.pid
    
    # Enable timer in cron
    if ! grep -q "big-button-timer.sh" /etc/crontabs/root 2>/dev/null; then
        echo "* * * * * /usr/local/bin/big-button-timer.sh" >> /etc/crontabs/root
        /etc/init.d/cron restart
    fi
    
    log_message "Background processes started"
}

# Stop background processes
stop_processes() {
    log_message "Stopping background processes"
    
    # Stop listener
    if [ -f /var/run/big-button-listener.pid ]; then
        kill $(cat /var/run/big-button-listener.pid) 2>/dev/null
        rm -f /var/run/big-button-listener.pid
    fi
    
    # Remove cron job
    grep -v "big-button-timer.sh" /etc/crontabs/root > /tmp/crontab.tmp 2>/dev/null
    mv /tmp/crontab.tmp /etc/crontabs/root 2>/dev/null
    /etc/init.d/cron restart
    
    # Turn off LED
    echo "1" > "$DEVICE_SERIAL" 2>/dev/null
    
    log_message "Background processes stopped"
}

# Signal handlers
trap_handler() {
    log_message "Received signal - shutting down"
    stop_processes
    rm -f "$PID_FILE" "$LOCK_FILE"
    exit 0
}

# Main daemon function
main() {
    # Clear old log on startup
    echo "=== Big Internet Button Starting ===" > "$LOG_FILE"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "Configuration: TIMER=$TIMER_MINUTES min, WARNING=$WARNING_MINUTES min" >> "$LOG_FILE"
    echo "===================================" >> "$LOG_FILE"
    
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Daemon already running with PID $OLD_PID"
            log_message "Daemon already running with PID $OLD_PID"
            exit 1
        fi
    fi
    
    # Create PID file
    echo $$ > "$PID_FILE"
    
    # Set up signal handlers
    trap trap_handler INT TERM HUP
    
    # Load configuration
    load_config
    log_message "Configuration loaded: TIMER=$TIMER_MINUTES, WARNING=$WARNING_MINUTES"
    
    # Initialize
    if ! initialize_button; then
        log_message "Failed to initialize button"
        rm -f "$PID_FILE"
        exit 1
    fi
    
    # Reset state
    reset_state
    
    # Start processes
    start_processes
    
    log_message "Big Button Daemon started successfully (PID: $$)"
    
    # Keep daemon running
    while true; do
        sleep 60
        
        # Health check - verify processes are running
        if [ ! -f /var/run/big-button-listener.pid ] || \
           ! kill -0 $(cat /var/run/big-button-listener.pid) 2>/dev/null; then
            log_message "Listener process died - restarting"
            /usr/local/bin/big-button-listener.sh &
            echo $! > /var/run/big-button-listener.pid
        fi
    done
}

# Handle command line arguments
case "$1" in
    start)
        echo "Starting Big Button Daemon..."
        main
        ;;
    stop)
        echo "Stopping Big Button Daemon..."
        if [ -f "$PID_FILE" ]; then
            kill $(cat "$PID_FILE") 2>/dev/null
            rm -f "$PID_FILE"
        fi
        stop_processes
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            echo "Big Button Daemon is running (PID: $(cat $PID_FILE))"
            if [ -f "$STATE_FILE" ]; then
                echo "Timer: $(cat $STATE_FILE) minutes"
                echo "Status: $(cat ${STATE_FILE}.status 2>/dev/null || echo 'unknown')"
            fi
        else
            echo "Big Button Daemon is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac