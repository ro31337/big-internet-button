# CLAUDE.md - Instructions for AI Assistants

This file contains specific instructions for Claude and other AI assistants working with the Big Internet Button project.

## Git Configuration

**Important**: Git is already configured for this project. When making commits:
- Use the existing git configuration (do not modify git config)
- Do NOT add Claude as co-author
- Use the configured git user identity
- The repository is set up and connected to GitHub

## Device Permissions

### Linux/WSL2 Serial Port Access

When working with the Big Internet Button on Linux or WSL2, you will encounter permission issues with `/dev/ttyACM0`. This is expected behavior.

**It is OK to:**
- Ask the user for the root password to set permissions
- Use `sudo chmod 666 /dev/ttyACM0` for immediate testing
- Suggest adding the user to the `dialout` group for permanent access
- Run commands that require sudo access for device permissions

**Default approach:**
```bash
# For immediate testing (temporary fix)
sudo chmod 666 /dev/ttyACM0

# For permanent fix (requires logout/login)
sudo usermod -a -G dialout $USER
```

## USB Device Attachment in WSL2

The Big Internet Button requires USBIPD to work in WSL2.

**Device Identification:**
- VID:PID: `2e8a:800a` (Raspberry Pi Pico)
- Shows as "USB Serial Device (COM5), USB Input Device" in Windows
- Appears as `/dev/ttyACM0` in Linux/WSL2

**Attachment Process:**
1. Use the provided `attach-button.ps1` script (requires Administrator)
2. The script automatically finds the device by VID:PID
3. Verify attachment with `attach-button.sh` in WSL2

## Testing the Device

**Always test in this order:**
1. Check device is attached (`ls /dev/ttyACM*`)
2. Fix permissions if needed (`sudo chmod 666 /dev/ttyACM0`)
3. Run demo script (`ruby demo-button.rb`)
4. Verify LED control and sound output
5. Test Enter key functionality separately

## Key Technical Details

- **Serial Communication**: 9600 baud, 8N1
- **Commands**: '1' (LED off), '2' (LED on), '3' (high beep), '4' (low beep)
- **HID Function**: Sends Enter key when pressed
- **Connection Delay**: Always wait 2 seconds after opening serial port

## Common Issues and Solutions

### Permission Denied
- **Always encountered on first use**
- Solution: Request sudo password and fix permissions
- This is normal Linux security behavior

### Device Not Found
- Check USBIPD attachment in Windows first
- Verify with `lsusb | grep 2e8a`
- May need to reinstall USBIPD or restart WSL2

### Serial Port Busy
- Another process may be using the port
- Close any other serial monitors
- Can use `lsof /dev/ttyACM0` to check

## Development Guidelines

1. **Always include permission fixes** in documentation and scripts
2. **Provide both temporary and permanent** permission solutions  
3. **Test scripts should handle** permission errors gracefully
4. **Include troubleshooting sections** in all user-facing docs
5. **Scripts should be idempotent** - safe to run multiple times

## Ruby-Specific Notes

- Use `serialport` gem for communication
- Always close serial connections properly
- Handle Ctrl+C gracefully in interactive scripts
- Bundler is preferred for dependency management

## Security Considerations

While changing device permissions with `chmod 666` makes the device accessible to all users, this is acceptable for:
- Development environments
- Personal computers
- Testing scenarios

For production or shared systems, prefer adding users to the `dialout` group.