#!/bin/bash
# Bash script to check if the button is available in WSL after attachment

echo "Checking for Big Internet Button in WSL..."

# Check USB devices
if command -v lsusb &> /dev/null; then
    echo "USB Devices:"
    lsusb | grep -i "2e8a:800a" || echo "Button not found in USB devices"
fi

# Check for serial devices
echo -e "\nSerial devices:"
ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null || echo "No serial devices found"

# Check dmesg for recent USB activity
echo -e "\nRecent USB kernel messages:"
dmesg | grep -i "usb\|tty" | tail -5

echo -e "\nIf the button is not visible, run the PowerShell script attach-button.ps1 as Administrator in Windows"