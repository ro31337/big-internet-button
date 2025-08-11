#!/bin/sh
# Big Internet Button - Supervisor
# KEEPS THE LISTENER RUNNING NO MATTER WHAT

LOG_FILE="/tmp/big-button.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUPERVISOR: $1" >> "$LOG_FILE"
}

log_message "Supervisor started - will keep listener running forever"

# Save supervisor PID
echo $$ > /var/run/big-button-supervisor.pid

# Main loop - restart listener if it dies
while true; do
    # Check if listener is running
    if [ -f /var/run/big-button-listener.pid ]; then
        PID=$(cat /var/run/big-button-listener.pid)
        if kill -0 $PID 2>/dev/null; then
            # Listener is running, just wait
            sleep 10
            continue
        fi
    fi
    
    # Listener is not running, start it
    log_message "Listener not running, starting..."
    /usr/local/bin/big-button-listener.sh &
    
    # Wait a bit before checking again
    sleep 5
done