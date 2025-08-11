# PowerShell script to attach the Big Internet Button to WSL
# Run as Administrator

$VID_PID = "2e8a:800a"

# Get the BUSID for the device
$device = usbipd list | Select-String $VID_PID
if ($device) {
    $busid = ($device -split '\s+')[0]
    Write-Host "Found Big Internet Button at BUSID: $busid"
    
    # Check if already attached
    if ($device -match "Attached") {
        Write-Host "Device is already attached to WSL"
    } else {
        # Bind if not shared
        if ($device -match "Not shared") {
            Write-Host "Binding device..."
            usbipd bind --busid $busid
        }
        
        # Attach to WSL
        Write-Host "Attaching device to WSL..."
        usbipd attach --wsl --busid $busid
        Write-Host "Device attached successfully!"
    }
} else {
    Write-Host "Big Internet Button (VID:PID $VID_PID) not found!"
    Write-Host "Make sure the button is connected via USB."
}