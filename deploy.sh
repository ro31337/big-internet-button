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
NC='\033[0m' # No Color

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
        
        # Update package lists
        ssh "$ROUTER_HOST" "opkg update --no-check-certificate" || {
            print_warning "Package update failed - router may not have internet"
            print_warning "Please ensure router has internet access and try again"
            exit 1
        }
        
        # Install packages
        ssh "$ROUTER_HOST" "opkg install $PACKAGES_NEEDED" || {
            print_error "Package installation failed"
            exit 1
        }
    else
        print_status "All required packages already installed"
    fi
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
    ssh "$ROUTER_HOST" "killall big-button-daemon.sh big-button-listener.sh" 2>/dev/null || true
    
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
    for script in big-button-daemon.sh big-button-timer.sh big-button-listener.sh big-button-control.sh; do
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
    
    # Start service
    ssh "$ROUTER_HOST" "/etc/init.d/big-button start" || {
        print_error "Failed to start service"
        print_warning "Check logs with: ssh $ROUTER_HOST 'cat /tmp/big-button.log'"
        exit 1
    }
    
    # Enable auto-start on boot
    ssh "$ROUTER_HOST" "/etc/init.d/big-button enable"
    
    # Check status
    sleep 2
    ssh "$ROUTER_HOST" "/usr/local/bin/big-button-control.sh status"
    
    print_status "Service started and enabled"
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
    echo "================================================"
    echo "   Big Internet Button Deployment Script"
    echo "================================================"
    echo ""
    
    print_status "Target router: $ROUTER_HOST"
    echo ""
    
    # Run deployment steps
    check_prerequisites
    
    if [ "$SKIP_PACKAGES" != "true" ]; then
        install_packages
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
        
        echo ""
        echo "================================================"
        print_status "Deployment Complete!"
        echo "================================================"
        echo ""
        print_status "The Big Internet Button is now active on your router"
        print_status "Internet will be blocked after 40 minutes of use"
        print_status "Press the button to restore internet access"
        echo ""
        print_status "Useful commands:"
        echo "  Check status:  ssh $ROUTER_HOST '/usr/local/bin/big-button-control.sh status'"
        echo "  View logs:     ssh $ROUTER_HOST '/usr/local/bin/big-button-control.sh log'"
        echo "  Manual reset:  ssh $ROUTER_HOST '/usr/local/bin/big-button-control.sh reset'"
        echo "  Stop service:  ssh $ROUTER_HOST '/etc/init.d/big-button stop'"
        echo ""
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