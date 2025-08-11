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
6. **Any fixes made on router must be applied to local scripts** - keep source in sync

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

## Critical Lessons Learned - SSH and Background Processes

### ALWAYS TEST SSH VARIABLE EXPANSION FIRST

**The Problem**: SSH heredocs and command execution DO NOT evaluate special shell variables like `$!` (last background PID) correctly. They will be written as literal strings.

**What Failed**:
```bash
# THIS DOES NOT WORK - $! becomes literal string "$!"
ssh root@router "
    some_process &
    PID=\$!  # This captures the string '$!' not the actual PID
"
```

**The Fix**:
```bash
# Method 1: Create a script file on the remote that can properly evaluate variables
ssh root@router 'cat > /tmp/script.sh << "EOF"
#!/bin/sh
some_process &
PID=$!  # Now this works because it's executed locally
echo $PID > /tmp/pid
EOF
chmod +x /tmp/script.sh
/tmp/script.sh'

# Method 2: Have the background process write its own PID
cat > /tmp/blinker.sh << 'SCRIPT'
#!/bin/sh
echo $$ > /tmp/pid  # Write our own PID
# ... rest of script
SCRIPT
```

### ALWAYS VERIFY PID CAPTURE METHODS

**What Failed**: Using `echo $$` inside a subshell returns the PARENT script PID, not the subshell PID:
```bash
# WRONG - captures parent PID
(
    echo $$ > pidfile  # This is WRONG - gets parent PID
    while true; do something; done
) &
```

**The Fix**: Create a separate script that runs as the actual process:
```bash
# RIGHT - script writes its own PID
cat > /tmp/worker.sh << 'EOF'
#!/bin/sh
echo $$ > /tmp/pid  # Correct - this is the script's PID
# ... do work
EOF
/tmp/worker.sh &
```

### ALWAYS CLEAN UP CHILD PROCESSES

**What Failed**: Killing a parent process doesn't kill its children. `sleep` commands become orphaned and continue running.

**The Fix**: When killing a background process, also clean up potential orphans:
```bash
# Kill the main process
kill $PID 2>/dev/null

# Also kill any orphaned children
for pid in $(ps | grep "sleep 1" | grep -v grep | awk '{print $1}'); do
    kill $pid 2>/dev/null
done
```

### MANDATORY TESTING PROTOCOL FOR SHELL SCRIPTS

Before deploying ANY shell script that uses background processes via SSH:

1. **Test variable expansion**:
```bash
ssh root@target 'test_var="test"; echo $test_var'  # Should work
ssh root@target 'sleep 1 & echo $!'  # Will likely fail
```

2. **Test PID capture method**:
```bash
# Create minimal test script
ssh root@target 'your_pid_capture_method'
# Verify it captures actual PID, not string or wrong PID
```

3. **Test process cleanup**:
```bash
# Start your background process
# Kill it
# Verify ALL related processes are gone with ps
```

4. **Test the exact deployment method**:
```bash
# Don't test locally then deploy via SSH
# Test THE EXACT SSH commands you'll use in deployment
```

### NEVER ASSUME - ALWAYS VERIFY

- **NEVER** assume SSH will handle variables the same as local shell
- **NEVER** deploy without testing the exact commands via SSH first
- **NEVER** trust that killing a parent kills all children
- **ALWAYS** create small test scripts to verify behavior
- **ALWAYS** check with `ps` that processes are actually running/killed

### The Golden Rule

**If you're working with background processes over SSH, create a test script FIRST that verifies your approach works. Only then implement it in the actual code.**