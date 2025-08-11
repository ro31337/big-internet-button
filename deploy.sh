#!/bin/bash
# Big Internet Button - Deployment Script
# Deploys the button system to an OpenWrt router

# Configuration
ROUTER_HOST="${ROUTER_HOST:-root@openwrt.lan}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENWRT_SCRIPTS_DIR="$SCRIPT_DIR/openwrt-scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get timer minutes from config
TIMER_MINUTES=$(grep "^TIMER_MINUTES=" "$OPENWRT_SCRIPTS_DIR/etc/config" 2>/dev/null | cut -d= -f2 || echo "40")
WARNING_MINUTES=$((TIMER_MINUTES - 1))

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Big Internet Button Deployment Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  TIMER: ${TIMER_MINUTES} minutes (warning at ${WARNING_MINUTES} minutes)  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Print colored output
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if scripts directory exists
    if [ ! -d "$OPENWRT_SCRIPTS_DIR" ]; then
        print_error "Scripts directory not found: $OPENWRT_SCRIPTS_DIR"
        exit 1
    fi
    
    # Check SSH connectivity
    if ! ssh -o ConnectTimeout=5 "$ROUTER_HOST" "echo 'SSH connection OK'" >/dev/null 2>&1; then
        print_error "Cannot connect to router at $ROUTER_HOST"
        print_warning "Make sure:"
        print_warning "  - Router is powered on and accessible"
        print_warning "  - SSH is enabled on the router"
        print_warning "  - You can connect with: ssh $ROUTER_HOST"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Check and install required packages on router
install_packages() {
    print_status "Checking required packages on router..."
    
    # Check for SFTP server first
    if ! ssh "$ROUTER_HOST" "which /usr/libexec/sftp-server" >/dev/null 2>&1; then
        print_status "Installing SFTP server for file transfers..."
        ssh "$ROUTER_HOST" "opkg update --no-check-certificate && opkg install openssh-sftp-server" || {
            print_error "Failed to install SFTP server"
            print_warning "Please run: opkg install openssh-sftp-server"
            exit 1
        }
    fi
    
    # Check if packages are already installed
    PACKAGES_NEEDED=""
    
    if ! ssh "$ROUTER_HOST" "lsmod | grep -q cdc_acm" 2>/dev/null; then
        PACKAGES_NEEDED="$PACKAGES_NEEDED kmod-usb-acm"
    fi
    
    if ! ssh "$ROUTER_HOST" "lsmod | grep -q usbhid" 2>/dev/null; then
        PACKAGES_NEEDED="$PACKAGES_NEEDED kmod-usb-hid"
    fi
    
    if [ -n "$PACKAGES_NEEDED" ]; then
        print_status "Installing required packages: $PACKAGES_NEEDED"
        
        # Update package lists if not already done
        ssh "$ROUTER_HOST" "opkg list-installed | grep -q openssh-sftp-server || opkg update --no-check-certificate"
        
        # Install packages
        ssh "$ROUTER_HOST" "opkg install $PACKAGES_NEEDED" || {
            print_error "Package installation failed"
            exit 1
        }
    else
        print_status "All required packages already installed"
    fi
}

# Check and install required commands
check_commands() {
    print_status "Checking required commands on router..."
    
    # List of required commands
    REQUIRED_COMMANDS="grep sed awk cat echo sleep kill rm mv cp chmod mkdir date ps tail head hexdump dd nft"
    OPTIONAL_COMMANDS="evtest"
    
    # Check for nohup specifically (from coreutils-nohup package)
    if ! ssh "$ROUTER_HOST" "which nohup" >/dev/null 2>&1; then
        print_status "Installing nohup for background process management..."
        ssh "$ROUTER_HOST" "opkg install coreutils-nohup" || {
            print_warning "Failed to install nohup, will use alternative method"
        }
    fi
    
    # Check required commands
    MISSING_COMMANDS=""
    for cmd in $REQUIRED_COMMANDS; do
        if ! ssh "$ROUTER_HOST" "which $cmd" >/dev/null 2>&1; then
            MISSING_COMMANDS="$MISSING_COMMANDS $cmd"
        fi
    done
    
    if [ -n "$MISSING_COMMANDS" ]; then
        print_error "Missing required commands:$MISSING_COMMANDS"
        print_warning "Please install missing commands or packages"
        exit 1
    fi
    
    # Check optional commands
    for cmd in $OPTIONAL_COMMANDS; do
        if ! ssh "$ROUTER_HOST" "which $cmd" >/dev/null 2>&1; then
            print_warning "Optional command '$cmd' not found (not critical)"
        fi
    done
    
    print_status "All required commands available"
}

# Check USB device
check_usb_device() {
    print_status "Checking for Big Internet Button USB device..."
    
    if ssh "$ROUTER_HOST" "[ -c /dev/ttyACM0 ]" 2>/dev/null; then
        print_status "Serial device found: /dev/ttyACM0"
    else
        print_warning "Serial device /dev/ttyACM0 not found"
        print_warning "Make sure the Big Internet Button is connected to the router's USB port"
        
        # Try to detect the device
        print_status "Searching for USB device..."
        ssh "$ROUTER_HOST" "dmesg | grep -i 'raspberry pi' | tail -5"
        
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if ssh "$ROUTER_HOST" "[ -c /dev/input/event0 ]" 2>/dev/null; then
        print_status "Input device found: /dev/input/event0"
    else
        print_warning "Input device /dev/input/event0 not found"
        print_warning "Button press detection may not work"
    fi
}

# Stop existing service if running
stop_existing_service() {
    print_status "Stopping existing service if running..."
    
    ssh "$ROUTER_HOST" "/etc/init.d/big-button stop" 2>/dev/null || true
    
    # Kill processes using PID files or ps
    ssh "$ROUTER_HOST" "
        # Try to kill using PID files first
        [ -f /var/run/big-button-listener.pid ] && kill \$(cat /var/run/big-button-listener.pid) 2>/dev/null || true
        [ -f /var/run/big-button-daemon.pid ] && kill \$(cat /var/run/big-button-daemon.pid) 2>/dev/null || true
        
        # Fallback: find and kill by process name
        for pid in \$(ps | grep 'big-button-' | grep -v grep | awk '{print \$1}'); do
            kill \$pid 2>/dev/null || true
        done
    " 2>/dev/null || true
    
    # Clean up cron
    ssh "$ROUTER_HOST" "grep -v 'big-button-timer.sh' /etc/crontabs/root > /tmp/crontab.tmp 2>/dev/null && mv /tmp/crontab.tmp /etc/crontabs/root" 2>/dev/null || true
    
    # Ensure internet is unblocked
    ssh "$ROUTER_HOST" "nft delete table inet big_button" 2>/dev/null || true
    
    print_status "Cleanup complete"
}

# Deploy scripts to router
deploy_scripts() {
    print_status "Deploying scripts to router..."
    
    # Create directories on router
    ssh "$ROUTER_HOST" "mkdir -p /usr/local/bin /etc/big-button"
    
    # Copy main scripts
    print_status "Copying main scripts..."
    for script in big-button-daemon.sh big-button-timer.sh big-button-listener.sh big-button-control.sh monitor.sh; do
        if [ -f "$OPENWRT_SCRIPTS_DIR/bin/$script" ]; then
            scp "$OPENWRT_SCRIPTS_DIR/bin/$script" "$ROUTER_HOST:/usr/local/bin/"
            ssh "$ROUTER_HOST" "chmod +x /usr/local/bin/$script"
            print_status "  - $script deployed"
        else
            print_error "Script not found: $script"
        fi
    done
    
    # Copy init script
    print_status "Copying init script..."
    scp "$OPENWRT_SCRIPTS_DIR/init.d/big-button" "$ROUTER_HOST:/etc/init.d/"
    ssh "$ROUTER_HOST" "chmod +x /etc/init.d/big-button"
    
    # Copy configuration (but don't overwrite if exists)
    print_status "Deploying configuration..."
    if ssh "$ROUTER_HOST" "[ ! -f /etc/big-button/config ]" 2>/dev/null; then
        scp "$OPENWRT_SCRIPTS_DIR/etc/config" "$ROUTER_HOST:/etc/big-button/config"
        print_status "  - Configuration file deployed"
    else
        print_warning "Configuration file already exists - preserving existing config"
        print_warning "New config saved as /etc/big-button/config.new"
        scp "$OPENWRT_SCRIPTS_DIR/etc/config" "$ROUTER_HOST:/etc/big-button/config.new"
    fi
    
    print_status "All scripts deployed successfully"
}

# Test the installation
test_installation() {
    print_status "Testing installation..."
    
    # Test LED control
    print_status "Testing LED control..."
    ssh "$ROUTER_HOST" "/usr/local/bin/big-button-control.sh led on" || true
    sleep 1
    ssh "$ROUTER_HOST" "/usr/local/bin/big-button-control.sh led off" || true
    
    # Test beep
    print_status "Testing beep..."
    ssh "$ROUTER_HOST" "/usr/local/bin/big-button-control.sh beep high" || true
    
    # Run full test
    print_status "Running system test..."
    ssh "$ROUTER_HOST" "/usr/local/bin/big-button-control.sh test" || true
}

# Start the service
start_service() {
    print_status "Starting Big Internet Button service..."
    
    # Clean up any existing processes first
    ssh "$ROUTER_HOST" "
        # Kill using PID files
        [ -f /var/run/big-button-listener.pid ] && kill \$(cat /var/run/big-button-listener.pid) 2>/dev/null || true
        [ -f /var/run/big-button-daemon.pid ] && kill \$(cat /var/run/big-button-daemon.pid) 2>/dev/null || true
        
        # Clean up PID files
        rm -f /var/run/big-button*.pid
    " 2>/dev/null || true
    
    # Initialize system manually since init script has issues
    print_status "Initializing system components..."
    
    # Create a script on the router to properly start the listener
    ssh "$ROUTER_HOST" 'cat > /tmp/start_listener.sh << "EOF"
#!/bin/sh
# Initialize state
echo "0" > /etc/big-button/state
echo "active" > /etc/big-button/state.status

# Kill any existing listener
for pid in $(ps | grep big-button-list | grep -v grep | awk "{print \$1}"); do
    kill $pid 2>/dev/null || true
done

# Start listener in background
if which nohup >/dev/null 2>&1; then
    nohup /usr/local/bin/big-button-listener.sh > /tmp/listener.log 2>&1 &
    LISTENER_PID=$!
else
    /usr/local/bin/big-button-listener.sh > /tmp/listener.log 2>&1 &
    LISTENER_PID=$!
fi

# Verify we got a valid PID
if [ -n "$LISTENER_PID" ] && [ "$LISTENER_PID" != "$""!" ]; then
    echo "$LISTENER_PID" > /var/run/big-button-listener.pid
    echo "Listener started with PID: $LISTENER_PID"
else
    # Fallback to ps method
    sleep 1
    LISTENER_PID=$(ps | grep big-button-list | grep -v grep | head -1 | awk "{print \$1}")
    if [ -n "$LISTENER_PID" ]; then
        echo "$LISTENER_PID" > /var/run/big-button-listener.pid
        echo "Listener started with PID (from ps): $LISTENER_PID"
    else
        echo "Warning: Could not determine listener PID"
    fi
fi
EOF
chmod +x /tmp/start_listener.sh
/tmp/start_listener.sh'
    
    # Setup cron job
    ssh "$ROUTER_HOST" "
        grep -v 'big-button-timer' /etc/crontabs/root > /tmp/cron.tmp 2>/dev/null || true
        echo '* * * * * /usr/local/bin/big-button-timer.sh' >> /tmp/cron.tmp
        mv /tmp/cron.tmp /etc/crontabs/root
        /etc/init.d/cron restart >/dev/null 2>&1
        
        # Give feedback
        echo '2' > /dev/ttyACM0 2>/dev/null
        sleep 1
        echo '1' > /dev/ttyACM0 2>/dev/null
        echo '3' > /dev/ttyACM0 2>/dev/null
        
        echo 'Components started'
    " || {
        print_error "Failed to start service components"
        exit 1
    }
    
    print_status "Service components started"
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    local ERRORS=0
    
    # Check listener process (ps truncates names on OpenWrt)
    if ssh "$ROUTER_HOST" "ps | grep -q 'big-button-list'" 2>/dev/null || \
       ssh "$ROUTER_HOST" "[ -f /var/run/big-button-listener.pid ] && kill -0 \$(cat /var/run/big-button-listener.pid) 2>/dev/null" 2>/dev/null; then
        print_status "✓ Listener process running"
    else
        print_error "✗ Listener process not running"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check cron job
    if ssh "$ROUTER_HOST" "crontab -l | grep -q 'big-button-timer'" 2>/dev/null; then
        print_status "✓ Timer cron job installed"
    else
        print_error "✗ Timer cron job not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check state files
    if ssh "$ROUTER_HOST" "[ -f /etc/big-button/state ]" 2>/dev/null; then
        TIMER_VALUE=$(ssh "$ROUTER_HOST" "cat /etc/big-button/state" 2>/dev/null)
        print_status "✓ Timer state file exists (value: $TIMER_VALUE)"
    else
        print_error "✗ Timer state file missing"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check devices
    if ssh "$ROUTER_HOST" "[ -c /dev/ttyACM0 ]" 2>/dev/null; then
        print_status "✓ Serial device present (/dev/ttyACM0)"
    else
        print_warning "⚠ Serial device not found - make sure button is connected"
    fi
    
    if ssh "$ROUTER_HOST" "[ -c /dev/input/event0 ]" 2>/dev/null; then
        print_status "✓ Input device present (/dev/input/event0)"
    else
        print_warning "⚠ Input device not found - button press detection may fail"
    fi
    
    # Test LED control
    print_status "Testing LED control..."
    ssh "$ROUTER_HOST" "echo '2' > /dev/ttyACM0 2>/dev/null" || true
    sleep 1
    ssh "$ROUTER_HOST" "echo '1' > /dev/ttyACM0 2>/dev/null" || true
    
    if [ $ERRORS -eq 0 ]; then
        print_status "✓ All components verified successfully"
        return 0
    else
        print_error "Deployment verification failed with $ERRORS errors"
        return 1
    fi
}

# Show usage information
usage() {
    cat << EOF
Big Internet Button Deployment Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -r, --router HOST   Specify router host (default: root@openwrt.lan)
    -t, --test-only     Only run tests, don't start service
    -s, --skip-packages Skip package installation
    -f, --force         Force deployment even if checks fail
    -u, --uninstall     Remove Big Internet Button from router

Examples:
    $0                          # Deploy to default router
    $0 -r root@192.168.1.1     # Deploy to specific IP
    $0 -t                       # Test installation only
    $0 -u                       # Uninstall from router

Environment Variables:
    ROUTER_HOST    Router SSH connection string (default: root@openwrt.lan)
EOF
    exit 0
}

# Uninstall function
uninstall() {
    print_status "Uninstalling Big Internet Button from router..."
    
    # Stop service
    stop_existing_service
    
    # Disable auto-start
    ssh "$ROUTER_HOST" "/etc/init.d/big-button disable" 2>/dev/null || true
    
    # Remove files
    print_status "Removing files..."
    ssh "$ROUTER_HOST" "rm -f /usr/local/bin/big-button-*.sh"
    ssh "$ROUTER_HOST" "rm -f /etc/init.d/big-button"
    ssh "$ROUTER_HOST" "rm -rf /etc/big-button"
    ssh "$ROUTER_HOST" "rm -f /tmp/big-button.log"
    ssh "$ROUTER_HOST" "rm -f /var/run/big-button*"
    
    print_status "Uninstallation complete"
    exit 0
}

# Main deployment process
main() {
    print_status "Target router: $ROUTER_HOST"
    echo ""
    
    # Run deployment steps
    check_prerequisites
    
    if [ "$SKIP_PACKAGES" != "true" ]; then
        install_packages
        check_commands
    fi
    
    check_usb_device
    stop_existing_service
    deploy_scripts
    
    if [ "$TEST_ONLY" = "true" ]; then
        test_installation
        print_status "Test mode - service not started"
        print_warning "To start service manually, run:"
        print_warning "  ssh $ROUTER_HOST '/etc/init.d/big-button start'"
    else
        test_installation
        start_service
        
        # Verify deployment
        echo ""
        if verify_deployment; then
            echo ""
            echo -e "${GREEN}================================================${NC}"
            print_status "DEPLOYMENT SUCCESSFUL!"
            echo -e "${GREEN}================================================${NC}"
            echo ""
            echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║        CONFIGURATION SUMMARY               ║${NC}"
            echo -e "${YELLOW}╠════════════════════════════════════════════╣${NC}"
            echo -e "${YELLOW}║  Timer Duration: ${TIMER_MINUTES} minutes                  ║${NC}"
            echo -e "${YELLOW}║  Warning At: ${WARNING_MINUTES} minutes                     ║${NC}"
            echo -e "${YELLOW}║  Snooze Mode: ENABLED                      ║${NC}"
            echo -e "${YELLOW}║  Log File: /tmp/big-button.log            ║${NC}"
            echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
            echo ""
            print_status "The Big Internet Button is now active on your router"
            echo ""
            print_status "Testing Timeline:"
            if [ $WARNING_MINUTES -gt 1 ]; then
                echo "  • Minutes 0-$((WARNING_MINUTES - 1)): Normal operation"
            fi
            echo "  • Minute ${WARNING_MINUTES}: Warning (beep + LED blinks)"
            echo "  • Minute ${TIMER_MINUTES}: Internet blocks (LED solid red)"
            echo ""
            print_status "Useful commands:"
            echo "  Monitor:       ssh $ROUTER_HOST '/usr/local/bin/monitor.sh'"
            echo "  Check status:  ssh $ROUTER_HOST '/usr/local/bin/big-button-control.sh status'"
            echo "  View logs:     ssh $ROUTER_HOST '/usr/local/bin/big-button-control.sh log'"
            echo "  Manual reset:  ssh $ROUTER_HOST '/usr/local/bin/big-button-control.sh reset'"
            echo "  Force block:   ssh $ROUTER_HOST '/usr/local/bin/big-button-control.sh block'"
            echo ""
        else
            print_error "Deployment completed with errors"
            print_warning "Check logs: ssh $ROUTER_HOST 'cat /tmp/big-button.log'"
            print_warning "Check listener: ssh $ROUTER_HOST 'cat /tmp/listener.log'"
        fi
    fi
}

# Parse command line arguments
TEST_ONLY=false
SKIP_PACKAGES=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -r|--router)
            ROUTER_HOST="$2"
            shift 2
            ;;
        -t|--test-only)
            TEST_ONLY=true
            shift
            ;;
        -s|--skip-packages)
            SKIP_PACKAGES=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -u|--uninstall)
            uninstall
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Run main deployment
main