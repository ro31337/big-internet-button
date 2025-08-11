# Big Internet Button - OpenWrt Implementation Guide

## Overview

This implementation provides a complete "Internet Timeout" system for OpenWrt routers using the Big Internet Button. The system blocks internet access after a configurable timeout period (default: 40 minutes) and requires pressing the physical button to restore connectivity.

## System Architecture

```
┌─────────────────────────────────────────────────┐
│                OpenWrt Router                    │
│                                                  │
│  ┌──────────────┐     ┌──────────────┐         │
│  │   Daemon     │────▶│   Timer      │         │
│  │  (Main)      │     │  (Cron)      │         │
│  └──────────────┘     └──────────────┘         │
│         │                     │                 │
│         │                     ▼                 │
│         │              ┌──────────────┐         │
│         │              │  nftables    │         │
│         │              │  (Firewall)  │         │
│         │              └──────────────┘         │
│         │                                       │
│         ▼                                       │
│  ┌──────────────┐     ┌──────────────┐         │
│  │   Listener   │────▶│   Button     │         │
│  │  (Input)     │     │  (USB HID)   │         │
│  └──────────────┘     └──────────────┘         │
│                               │                 │
│                               ▼                 │
│                        ┌──────────────┐         │
│                        │    LED &     │         │
│                        │   Speaker    │         │
│                        │  (USB Serial)│         │
│                        └──────────────┘         │
└─────────────────────────────────────────────────┘
```

## Components

### 1. Main Daemon (`big-button-daemon.sh`)

**Purpose**: Central coordinator for the entire system

**Key Functions**:
- Initializes the button on startup (LED blink + beep sequence)
- Manages background processes (listener and timer)
- Provides health monitoring and auto-recovery
- Handles graceful shutdown

**Commands**:
```bash
/usr/local/bin/big-button-daemon.sh start    # Start daemon
/usr/local/bin/big-button-daemon.sh stop     # Stop daemon
/usr/local/bin/big-button-daemon.sh restart  # Restart daemon
/usr/local/bin/big-button-daemon.sh status   # Check status
```

### 2. Timer Management (`big-button-timer.sh`)

**Purpose**: Tracks internet usage time and triggers blocking

**Key Functions**:
- Runs every minute via cron
- Increments usage timer
- Provides warnings at 39 minutes (beep + 3 blinks)
- Blocks internet at 40 minutes (double beep + solid LED)
- Uses nftables to block forwarding traffic

**Timer States**:
- **0-38 minutes**: Normal operation
- **39 minutes**: Warning (high beep + 3 blinks)
- **39.5 minutes**: Repeat warning (LED flash only)
- **40 minutes**: Internet blocked (double beep + LED on)

### 3. Button Listener (`big-button-listener.sh`)

**Purpose**: Monitors button presses and manages timer/internet control

**Key Functions**:
- Continuously monitors `/dev/input/event0`
- Detects Enter key press events
- **Snooze Mode** (when enabled):
  - Button press at ANY time resets timer to 0
  - Adds up to TIMER_MINUTES (default: 40) from button press
  - Multiple presses don't stack - always max 40 minutes from last press
  - Quick double-blink LED feedback when time added
- **When Internet Blocked**:
  - Restores internet (removes firewall rules)
  - Resets timer to 0
  - LED turns off + low beep feedback
- Implements debouncing (2-second minimum between presses)

**Snooze Mode Behavior**:
- Press at 10 minutes → Timer resets to 0 (40 minutes until block)
- Press at 35 minutes → Timer resets to 0 (40 minutes until block)
- Press multiple times → Each press resets to 0 (no stacking)
- Maximum time is always TIMER_MINUTES from last button press

**Detection Methods**:
- Primary: Direct event reading with hexdump
- Fallback: evtest if available (optional package)

### 4. Control Utility (`big-button-control.sh`)

**Purpose**: Manual control and testing interface

**Available Commands**:
```bash
# System commands
big-button-control.sh status    # Show system status
big-button-control.sh reset      # Reset timer to 0
big-button-control.sh block      # Manually block internet
big-button-control.sh unblock    # Manually unblock internet

# Hardware control
big-button-control.sh led on     # Turn LED on
big-button-control.sh led off    # Turn LED off
big-button-control.sh beep high  # Play high beep
big-button-control.sh beep low   # Play low beep

# Diagnostics
big-button-control.sh test       # Run system test
big-button-control.sh config     # Show configuration
big-button-control.sh log [n]    # Show last n log entries
big-button-control.sh monitor    # Monitor button events
```

### 5. Init Script (`/etc/init.d/big-button`)

**Purpose**: OpenWrt service management

**Features**:
- Integrates with OpenWrt's init system
- Supports auto-start on boot
- Creates default configuration if missing
- Handles USB device detection
- Attempts module loading if devices missing

**Service Commands**:
```bash
/etc/init.d/big-button start    # Start service
/etc/init.d/big-button stop     # Stop service  
/etc/init.d/big-button restart  # Restart service
/etc/init.d/big-button status   # Check status
/etc/init.d/big-button enable   # Enable auto-start
/etc/init.d/big-button disable  # Disable auto-start
```

### 6. Configuration File (`/etc/big-button/config`)

**Purpose**: Centralized configuration

**Settings**:
```bash
TIMER_MINUTES=40              # Minutes until internet blocks
WARNING_MINUTES=39            # When to show warning
WARNING_REPEAT_SECONDS=30     # Warning repeat interval
SNOOZE_MODE=1                 # Enable snooze (button adds time)
DEVICE_SERIAL="/dev/ttyACM0"  # Serial device for LED/sound
DEVICE_INPUT="/dev/input/event0"  # Input device for button
ENABLE_LOGGING=1              # Enable/disable logging
LOG_FILE="/tmp/big-button.log"  # Log file location
DEBOUNCE_TIME=2               # Button debounce (seconds)
LED_BLINK_DELAY=0.5          # LED blink timing
```

## Deployment Script (`deploy.sh`)

**Purpose**: Automated deployment to OpenWrt router

**Features**:
- Checks prerequisites (SSH connectivity, scripts)
- Installs required packages (kmod-usb-acm, kmod-usb-hid)
- Verifies USB device presence
- Stops existing installations
- Deploys all scripts and configuration
- Tests hardware (LED, beep)
- Starts and enables service

**Usage**:
```bash
# Basic deployment
./deploy.sh

# Deploy to specific router
./deploy.sh -r root@192.168.1.1

# Test only (don't start service)
./deploy.sh -t

# Skip package installation
./deploy.sh -s

# Uninstall from router
./deploy.sh -u

# Show help
./deploy.sh -h
```

**Deployment Process**:
1. Checks SSH connectivity to router
2. Installs USB kernel modules if needed
3. Verifies button is connected
4. Stops any existing service
5. Copies scripts to `/usr/local/bin/`
6. Installs init script to `/etc/init.d/`
7. Creates configuration in `/etc/big-button/`
8. Tests LED and beep functionality
9. Starts service and enables auto-start

## File Locations on Router

```
/usr/local/bin/
├── big-button-daemon.sh      # Main daemon
├── big-button-timer.sh       # Timer script (cron)
├── big-button-listener.sh    # Button monitor
└── big-button-control.sh     # Control utility

/etc/
├── init.d/
│   └── big-button            # Service script
├── big-button/
│   ├── config                # Configuration
│   ├── state                 # Current timer value
│   └── state.status          # Current status (active/blocked)
└── crontabs/
    └── root                  # Cron job for timer

/var/run/
├── big-button-daemon.pid     # Daemon PID
└── big-button-listener.pid   # Listener PID

/tmp/
└── big-button.log           # System log
```

## Technical Details

### Internet Blocking Method

Uses nftables to block all forwarding traffic:
```bash
# Block internet
nft add table inet big_button
nft add chain inet big_button forward { type filter hook forward priority 0 \; }
nft add rule inet big_button forward drop

# Restore internet
nft delete table inet big_button
```

### Button Detection

Reads raw input events from `/dev/input/event0`:
- Event type: EV_KEY (0x01)
- Event code: KEY_ENTER (28 / 0x1C)
- Event value: 1 (press) / 0 (release)

### LED/Sound Control

Simple serial commands to `/dev/ttyACM0`:
- `echo '1' > /dev/ttyACM0` - LED OFF
- `echo '2' > /dev/ttyACM0` - LED ON
- `echo '3' > /dev/ttyACM0` - High beep
- `echo '4' > /dev/ttyACM0` - Low beep

### Process Management

- Daemon runs continuously with health monitoring
- Listener runs as background process
- Timer runs via cron (every minute)
- All processes tracked via PID files
- Automatic restart on failure

## Troubleshooting

### Button Not Detected

```bash
# Check USB device
ssh root@openwrt.lan "dmesg | grep -i usb | tail -20"

# Check devices exist
ssh root@openwrt.lan "ls -la /dev/ttyACM* /dev/input/event*"

# Load modules manually
ssh root@openwrt.lan "modprobe cdc_acm && modprobe usbhid"
```

### Service Won't Start

```bash
# Check logs
ssh root@openwrt.lan "cat /tmp/big-button.log"

# Run manual test
ssh root@openwrt.lan "/usr/local/bin/big-button-control.sh test"

# Check device permissions
ssh root@openwrt.lan "ls -la /dev/ttyACM0 /dev/input/event0"
```

### Internet Not Blocking/Unblocking

```bash
# Check firewall rules
ssh root@openwrt.lan "nft list tables"
ssh root@openwrt.lan "nft list table inet big_button"

# Manual control
ssh root@openwrt.lan "/usr/local/bin/big-button-control.sh block"
ssh root@openwrt.lan "/usr/local/bin/big-button-control.sh unblock"
```

### Timer Not Working

```bash
# Check cron job
ssh root@openwrt.lan "crontab -l | grep big-button"

# Check state file
ssh root@openwrt.lan "cat /etc/big-button/state"
ssh root@openwrt.lan "cat /etc/big-button/state.status"

# Manual timer test
ssh root@openwrt.lan "/usr/local/bin/big-button-timer.sh"
```

## Customization

### Change Timeout Duration

Edit `/etc/big-button/config` on router:
```bash
TIMER_MINUTES=30  # Change from 40 to 30 minutes
WARNING_MINUTES=29  # Update warning time
```

Then restart service:
```bash
/etc/init.d/big-button restart
```

### Configure Snooze Mode

The button can work in two modes:

**Snooze Mode Enabled (default)**:
```bash
SNOOZE_MODE=1  # Button adds time at any moment
```
- Press button anytime to reset timer to 0
- Gives you maximum TIMER_MINUTES from button press
- Multiple presses don't stack (always max 40 minutes from last press)
- Example: Press at 10min → reset to 0 (40min total)
- Example: Press at 35min → reset to 0 (40min total)

**Snooze Mode Disabled**:
```bash
SNOOZE_MODE=0  # Button only works when blocked
```
- Button only responds when internet is blocked
- Press button to restore internet and reset timer
- Button presses while internet is active are ignored

### Disable Logging

Edit `/etc/big-button/config`:
```bash
ENABLE_LOGGING=0
```

### Custom LED Patterns

Modify blink patterns in scripts:
```bash
# In big-button-timer.sh
blink_led 5 0.2  # 5 blinks, 0.2 second interval
```

## Security Considerations

1. **Physical Access**: Button provides physical control over internet
2. **No Authentication**: Anyone with physical access can press button
3. **Firewall Rules**: Only affects forwarding, not router access
4. **Fail-Safe**: Internet automatically restored on router reboot
5. **Logging**: Activity logged to `/tmp/` (cleared on reboot)

## Performance Impact

- **CPU Usage**: <1% average
- **Memory Usage**: <1MB total
- **Storage**: <100KB for all scripts
- **Network Impact**: None when internet enabled
- **Response Time**: <100ms button press to action

## Known Limitations

1. Single button device support (first `/dev/input/event0`)
2. Timer precision limited to 1-minute increments
3. No web UI (command-line only)
4. English-only log messages
5. No user differentiation (affects all users equally)

## Future Enhancements

Possible improvements:
- Web UI integration via LuCI
- Multiple schedule support
- Per-device blocking
- Statistics and usage tracking
- Mobile app for remote control
- Multiple button support
- Configurable blocking rules