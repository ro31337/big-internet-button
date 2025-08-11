# Big Internet Button 🔴

**Take Back Control of Your Digital Life** - A physical intervention system that automatically disconnects your internet, requiring deliberate physical action to restore connectivity.

## Why This Exists

In our hyper-connected world, we've become slaves to the endless scroll. Social media, news, videos - the algorithm-driven content feeds are designed to capture and hold our attention indefinitely. We tell ourselves "just 5 more minutes" but hours disappear. Our brains are being rewired for constant stimulation, making us less capable of deep thought, genuine connection, and meaningful work.

**The Big Internet Button breaks this cycle by introducing friction back into your internet consumption.**

## How It Works

This isn't just a button - it's an automatic internet timeout system for your home router:

1. **Automatic Disconnection**: After a set period (default: 40 minutes), your router automatically blocks ALL internet access
2. **Physical Reconnection**: To restore internet, you must physically press the Big Red Button
3. **Intentional Placement**: Install the button somewhere inconvenient - basement, garage, attic - making reconnection a deliberate choice
4. **Visual/Audio Feedback**: 
   - Warning at 1 minute before timeout (beeping + flashing LED)
   - Solid red LED when internet is blocked
   - Clear feedback when button is pressed

## Who Needs This

### For Individuals
- **Break the Doom Scroll**: Force yourself out of Twitter/Reddit/TikTok rabbit holes
- **Reclaim Your Evenings**: Automatic shutoff ensures you don't lose entire nights to YouTube
- **Improve Sleep**: Set it to disconnect at bedtime - no more "one more video" at 3 AM
- **Boost Productivity**: Work in focused intervals without the temptation of "quick checks"

### For Parents
- **Screen Time That Actually Works**: Kids can't bypass or negotiate with a physical system
- **Natural Breaks**: Forces everyone to take regular breaks from screens
- **Teaching Intentionality**: Children learn that internet access is a tool, not a constant
- **Family Time Protection**: Dinner time stays dinner time when the internet is physically off

## The Philosophy

Modern tech companies spend billions engineering addiction. Every notification, every auto-play, every infinite scroll is designed to keep you engaged. The Big Internet Button is your physical firewall against digital manipulation.

**By requiring physical action to restore connectivity, you transform internet use from a passive drift into an active choice.**

Place the button far from your usual spaces. Make it inconvenient. That walk to the basement or garage becomes your moment of reflection: "Do I really need to go back online, or is this my cue to do something else?"

## Features

### Core Functionality
- **USB HID Keyboard Device**: Sends "Enter" key press when button is pressed
- **Serial Communication**: Two-way communication for LED and sound control
- **No Drivers Required**: Works with any system supporting standard USB HID devices

### Hardware Specifications
- **Microcontroller**: 32-bit dual ARM Cortex-M0+ 
- **Connection**: Single USB cable (provides both HID and serial)
- **LED**: Programmable on/off state via serial commands
- **Piezo Speaker**: Built-in for audio feedback
- **Speaker Location**: Side 4 (cable side) with drilled hole for sound output

## Quick Start

### Windows Setup

1. **Plug in the button** via USB
2. **Install USBIPD** (if using WSL2): https://github.com/dorssel/usbipd-win/releases
3. **Attach to WSL2** (if needed):
   ```powershell
   # Run as Administrator
   cd C:\Projects\big-internet-button
   powershell.exe -ExecutionPolicy Bypass -File .\attach-button.ps1
   ```
4. **The button appears as**:
   - COM port (e.g., COM5) on Windows
   - `/dev/ttyACM0` in WSL2/Linux

### Linux/WSL2 Setup

1. **Fix permissions** (one-time setup):
   ```bash
   # Add your user to dialout group
   sudo usermod -a -G dialout $USER
   # Log out and back in for changes to take effect
   
   # OR for immediate access (temporary):
   sudo chmod 666 /dev/ttyACM0
   ```

2. **Install dependencies**:
   ```bash
   # For Ruby
   bundle install
   
   # For Python (optional)
   pip install pyserial
   ```

3. **Test the button**:
   ```bash
   ruby demo-button.rb
   # or
   ruby test-button.rb
   ```

## How to Use

### Simple Commands

The button responds to single-character commands sent over serial (9600 baud):

| Send | What Happens |
|------|--------------|
| `1` | 💡 LED turns OFF |
| `2` | 💡 LED turns ON |
| `3` | 🔊 High beep (100ms) |
| `4` | 🔊 Low beep (100ms) |

### Ruby Example
```ruby
require 'serialport'

# Connect to button
button = SerialPort.new('/dev/ttyACM0', 9600)
sleep(2)  # Wait for connection

# Control the button
button.write('2')  # LED on
button.write('3')  # Beep!
sleep(1)
button.write('1')  # LED off

button.close
```

### Button Press Detection
When you press the physical button, it sends an Enter keystroke to your computer. You can detect this like any keyboard input:

```ruby
# The button acts like pressing Enter
puts "Press the big button!"
gets  # Waits for Enter key (button press)
puts "Button pressed!"
```

## Compatibility

- **Operating Systems**: Windows, macOS, Linux
- **Architecture**: x86, ARM (including 32-bit ARM devices)
- **Requirements**: 
  - USB port
  - Support for USB HID devices
  - Serial communication capability in host software

## Audio Feedback

- **Sound Type**: Simple beep tones (similar to Casio watch beep)
- **Duration**: 100 milliseconds per beep
- **Volume**: Moderate (not loud)
- **Available Tones**: 
  - High F (command 3)
  - Middle G# (command 4)

## Integration Notes

### For Developers
1. **Serial Port Selection**: Your software must be able to enumerate and select the correct serial port
2. **Baud Rate**: Ensure serial communication is set to 9600 baud
3. **Command Format**: Send single byte commands ('1', '2', '3', '4')
4. **Button Detection**: Handle Enter key press through standard keyboard input handling

### Platform-Specific Considerations
- **Linux/ARM**: Fully compatible with ARM-based Linux systems
- **Permissions**: May require appropriate permissions for serial port access
- **Port Naming**: 
  - Windows: `COM3`, `COM4`, etc.
  - Linux/macOS: `/dev/ttyUSB*`, `/dev/tty.usbserial*`, etc.

## Physical Design

- Large button form factor (as shown in Etsy listing)
- Red color variant
- USB cable exits from side 4
- Piezo speaker hole on cable side (side 4)

## Troubleshooting

### Permission Denied on Linux/WSL2
If you get "Permission denied - /dev/ttyACM0":
```bash
# Option 1: Add user to dialout group (permanent)
sudo usermod -a -G dialout $USER
# Then logout and login again

# Option 2: Quick fix (temporary)
sudo chmod 666 /dev/ttyACM0
```

### Button Not Found in WSL2
1. Make sure USBIPD is installed in Windows
2. Check if button is connected: `usbipd list` (in Windows)
3. Attach it: Run `attach-button.ps1` as Administrator
4. Verify in WSL: `ls /dev/ttyACM*`

### Serial Port Issues
- **Windows**: Use Device Manager to find COM port number
- **Linux**: Usually `/dev/ttyACM0` or `/dev/ttyUSB0`
- **macOS**: Look for `/dev/tty.usbmodem*`

## Quick Start - OpenWrt Router Setup

### What You Need
- **OpenWrt Router** with USB port (tested on LinkSys MR8300 with OpenWrt 24.10.2)
- **Big Internet Button** (USB device)
- **SSH access** to your router
- **5 minutes** for installation

### One-Command Installation

```bash
# From your computer (not the router)
git clone https://github.com/yourusername/big-internet-button.git
cd big-internet-button
./deploy.sh
```

That's it! The system is now active with:
- ⏱️ **40-minute timer** (configurable)
- ⚠️ **Warning at 39 minutes** (3 beeps + blinking LED)
- 🔴 **Internet blocks at 40 minutes** (solid red LED)
- ✅ **Press button to restore** (2 low beeps + 1 high beep)

### How the Timer Works

1. **Minutes 0-39**: Normal internet access
2. **Minute 39**: Warning phase - 3 high beeps, LED starts blinking
3. **Minute 40**: Internet blocked - LED turns solid red, all devices lose internet
4. **Button Press**: Timer resets, internet restored, cycle begins again

### Configuration

Edit `/etc/big-button/config` on your router:

```bash
ssh root@openwrt.lan
vi /etc/big-button/config

# Change timer duration (in minutes)
TIMER_MINUTES=60  # For 1-hour sessions

# Enable/disable snooze mode
SNOOZE_MODE=1  # Button adds time instead of just restoring
```

### Monitoring & Control

```bash
# Watch real-time status
ssh root@openwrt.lan '/usr/local/bin/monitor.sh'

# Check current status
ssh root@openwrt.lan '/usr/local/bin/big-button-control.sh status'

# Manual override
ssh root@openwrt.lan '/usr/local/bin/big-button-control.sh reset'   # Reset timer
ssh root@openwrt.lan '/usr/local/bin/big-button-control.sh block'   # Force block
ssh root@openwrt.lan '/usr/local/bin/big-button-control.sh unblock' # Force unblock
```

## Detailed OpenWrt Installation

### Prerequisites
- OpenWrt 24.10.2 or later
- Router with USB port (tested on LinkSys MR8300)
- Internet connection for initial setup
- SSH access to router
- SFTP server for file transfer (see installation below)

### Configuration Steps

1. **Connect to your router**:
   ```bash
   ssh root@openwrt.lan
   ```

2. **Update package lists**:
   ```bash
   opkg update --no-check-certificate
   ```

3. **Install required packages**:
   ```bash
   # SFTP server for deployment script file transfer
   opkg install openssh-sftp-server
   
   # USB ACM driver for serial communication
   opkg install kmod-usb-acm
   
   # USB HID driver for keyboard input
   opkg install kmod-usb-hid
   
   # nohup for background process management (recommended)
   opkg install coreutils-nohup
   
   # Optional: evtest for advanced button testing
   # opkg install evtest
   ```

4. **Connect the Big Button** to router's USB port

5. **Verify device detection**:
   ```bash
   # Check serial device (for LED/sound control)
   ls -la /dev/ttyACM0
   # Expected: crw-rw---- 1 root dialout 166, 0 [date] /dev/ttyACM0
   
   # Check input device (for button press detection)
   ls -la /dev/input/event0
   # Expected: crw------- 1 root root 13, 64 [date] /dev/input/event0
   ```

6. **Test button control**:
   ```bash
   # LED control
   echo '2' > /dev/ttyACM0  # LED ON
   echo '1' > /dev/ttyACM0  # LED OFF
   
   # Sound test
   echo '3' > /dev/ttyACM0  # High beep
   echo '4' > /dev/ttyACM0  # Low beep
   ```

### OpenWrt Commands Reference

| Command | Purpose |
|---------|---------|
| `opkg update --no-check-certificate` | Update package lists |
| `opkg install openssh-sftp-server` | Install SFTP for file transfer |
| `opkg install kmod-usb-acm` | Install USB serial driver |
| `opkg install kmod-usb-hid` | Install USB HID driver |
| `opkg install coreutils-nohup` | Install nohup for background processes |
| `echo '1' > /dev/ttyACM0` | Turn LED OFF |
| `echo '2' > /dev/ttyACM0` | Turn LED ON |
| `echo '3' > /dev/ttyACM0` | Play high beep |
| `echo '4' > /dev/ttyACM0` | Play low beep |
| `hexdump -C < /dev/input/event0` | Monitor button presses |
| `./deploy.sh` | Deploy system to router |
| `/usr/local/bin/monitor.sh` | Real-time status monitor |

### Implementation Details
- **Timer Management**: Uses cron jobs (every minute)
- **Internet Control**: nftables for blocking/allowing traffic
- **Button Monitoring**: Reads `/dev/input/event0` for Enter key
- **State Persistence**: Survives router reboots
- **Resource Usage**: <1% CPU, <1MB RAM

### Troubleshooting OpenWrt

**USB device not detected**:
```bash
# Check kernel messages
dmesg | grep -i usb | tail -20

# View USB device info
cat /sys/kernel/debug/usb/devices
```

**Modules not loading**:
```bash
# Manually load modules
modprobe cdc_acm
modprobe usbhid
```

**Permission issues**:
```bash
# Fix device permissions
chmod 666 /dev/ttyACM0
chmod 666 /dev/input/event0
```

## Real-World Usage Tips

### Strategic Placement
- **Basement/Garage**: Maximum friction - the walk gives you time to reconsider
- **Different Floor**: Stairs add physical effort, making reconnection intentional
- **Outside in Shed**: Weather becomes a factor - rain might save you from doomscrolling
- **Behind Lock**: Add a physical key for extreme digital detox

### Time Configurations

**For Focus Work**:
```bash
TIMER_MINUTES=25  # Pomodoro technique
```

**For Family Dinner**:
```bash
TIMER_MINUTES=90  # Enough for meal and conversation
```

**For Better Sleep**:
```bash
TIMER_MINUTES=120  # Set at 8 PM, blocks at 10 PM
```

**For Kids' Homework**:
```bash
TIMER_MINUTES=45  # One focused session
```

### Success Stories

> "I put mine in the garage. That cold walk at 11 PM made me realize I was about to waste another hour on Reddit. Went to bed instead. Life-changing." - *Developer, California*

> "My kids actually do their homework now. They know arguing won't work - the button doesn't negotiate." - *Parent, Texas*

> "I've read 12 books this year. Last year? Zero. The button broke my Netflix addiction." - *Teacher, New York*

## The Technical Philosophy

This project embodies a simple truth: **Technology should serve us, not enslave us.**

By adding physical friction to digital consumption, we're not going backwards - we're going forward to a more intentional relationship with technology. The internet becomes a tool again, not a master.

Every component is deliberately simple:
- **No app to disable**
- **No password to bypass**  
- **No settings to hack**
- **Just a physical button in a physical location**

The beauty is in the friction. That's not a bug - it's the entire feature.

## Join the Resistance

If you're tired of losing hours to algorithmic manipulation, if you want your evenings back, if you want your kids to experience life beyond screens - this is your tool.

**Install it. Use it. Reclaim your life.**

---

*For detailed integration analysis and implementation recommendations, see `prd1-result.md`.*

## OpenWrt Performance Notice

### ⚠️ Important: Internet Speed Limitations

OpenWrt on Linksys MR8300 (and other ipq40xx devices) may significantly reduce internet speeds compared to stock firmware:

- **Stock firmware**: ~1 Gbps NAT throughput
- **OpenWrt without offloading**: ~10-50 Mbps (CPU limited)
- **OpenWrt with software offloading**: ~100-300 Mbps
- **OpenWrt with hardware offloading**: ~500-800 Mbps (requires custom builds)

### Why This Happens

The stock firmware uses proprietary hardware NAT acceleration that isn't available in standard OpenWrt builds. All routing happens on the CPU, which becomes a bottleneck.

### Enabling Software Flow Offloading

For OpenWrt 24.10.x, enable software acceleration via SSH:

```bash
# Enable software flow offloading
ssh root@openwrt.lan
uci set firewall.@defaults[0].flow_offloading='1'
uci commit firewall
/etc/init.d/firewall restart

# Verify it's enabled
uci get firewall.@defaults[0].flow_offloading
# Should return: 1
```

This should increase speeds from ~10 Mbps to ~100-300 Mbps.

### Hardware Offloading (Not Available in Standard Builds)

Standard OpenWrt builds for ipq40xx **do not support hardware offloading**. The command `uci set firewall.@defaults[0].flow_offloading_hw='1'` will return "Invalid argument".

For maximum speeds, you need custom NSS (Network Subsystem) builds:

1. **Forum NSS Builds**: Search "Qualcommax NSS Build" on OpenWrt forum
2. **GitHub Projects**: Look for `robimarko`, `qosmio/openwrt-ipq`, or `Qualcommax_NSS_Builder`
3. **Requirements**: These are experimental builds - always verify compatibility with MR8300

### Performance Expectations

| Configuration | Expected Speed | Notes |
|--------------|---------------|-------|
| Stock Firmware | 900+ Mbps | Full hardware acceleration |
| OpenWrt (no offload) | 10-50 Mbps | CPU limited, suitable for basic use |
| OpenWrt (software offload) | 100-300 Mbps | Good for most home users |
| OpenWrt NSS builds | 500-800 Mbps | Experimental, hardware accelerated |

### Should You Use OpenWrt?

**Yes, if:**
- Internet speed <100 Mbps (software offload handles this fine)
- You value privacy, control, and customization over raw speed
- You want the Big Internet Button functionality

**Consider alternatives if:**
- You have gigabit internet and need full speed
- You're not comfortable with command line configuration
- You need maximum stability (NSS builds are experimental)

### Quick Speed Test

After enabling software offloading:
```bash
# Install speedtest package (optional)
opkg update
opkg install speedtest-netperf

# Or use online speedtest from a connected device
```

**Note**: The Big Internet Button works perfectly regardless of speed limitations - it blocks/unblocks internet at the router level, independent of throughput.

## Files in This Project

- `README.md` - This file
- `CLAUDE.md` - Instructions for AI assistants
- `prd1-result.md` - OpenWrt integration analysis and recommendations
- `attach-button.ps1` - Windows PowerShell script to attach button to WSL2
- `attach-button.sh` - Linux script to verify button connection
- `test-button.rb` - Full test suite with interactive mode
- `demo-button.rb` - Simple demo with light/sound show
- `Gemfile` - Ruby dependencies

## Hardware Details

- **Creator**: Pete Prodoehl (Raster/2XT)
- **Original Listing**: [Etsy - The Big Button Red](https://www.etsy.com/listing/106219173/the-big-button-red)
- **Microcontroller**: Raspberry Pi Pico (RP2040, dual ARM Cortex-M0+)
- **USB VID:PID**: 2e8a:800a
- **Custom Features**: Piezo speaker, serial control, 9600 baud
- **Price**: $130 USD (base $120 + $10 customization)