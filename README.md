# Big Internet Button 🔴

A large, programmable USB button that lights up, beeps, and sends keystrokes to your computer!

## What is this?

The Big Internet Button is a physical, arcade-style button that connects to your computer via USB. When you press it, it acts like pressing the Enter key on your keyboard. But that's not all - you can also control it from your computer to:
- 💡 Turn the LED inside on/off
- 🔊 Play beep sounds for notifications
- ⌨️ Send Enter keystrokes to any application

Perfect for:
- Stream deck / OBS scene switching
- Build status indicators (green = pass, red = fail)
- Notification alerts with sound
- Fun interactive projects
- Accessibility tools

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

## Files in This Project

- `README.md` - This file
- `CLAUDE.md` - Instructions for AI assistants
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