# Test script for ntfy Windows Notifications System
# Tests all components individually to verify functionality

param(
    [string]$InstallPath = "C:\ntfy-notifications",
    [switch]$TestStartup,
    [switch]$TestShutdown, 
    [switch]$TestQueue,
    [switch]$TestConfiguration,
    [switch]$TestAll
)

Write-Host "ntfy Windows Notifications - Test Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Set location to install path
if (Test-Path $InstallPath) {
    Set-Location $InstallPath
    Write-Host "Working directory: $InstallPath" -ForegroundColor Green
} else {
    Write-Host "ERROR: Install path not found: $InstallPath" -ForegroundColor Red
    Write-Host "Please run the setup script first" -ForegroundColor Yellow
    exit 1
}

# Check if files exist
$requiredFiles = @(
    "ntfy-core-functions.ps1",
    "ntfy-notifications-config.ini",
    "ntfy-startup-wrapper.cmd",
    "ntfy-shutdown-wrapper.cmd", 
    "ntfy-queue-processor.cmd"
)

Write-Host "Checking required files..." -ForegroundColor Yellow
$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: Missing required files. Please copy all files to the installation directory." -ForegroundColor Red
    Write-Host "Missing files:" -ForegroundColor Yellow
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host ""

# Test configuration loading
if ($TestConfiguration -or $TestAll) {
    Write-Host "TEST: Configuration Loading..." -ForegroundColor Yellow
    try {
        $result = & .\ntfy-core-functions.ps1 -Action "ProcessQueue"
        Write-Host "Configuration test completed" -ForegroundColor Green
    }
    catch {
        Write-Host "Configuration test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test startup notification
if ($TestStartup -or $TestAll) {
    Write-Host "TEST: Startup Notification..." -ForegroundColor Yellow
    Write-Host "This will send a test startup notification" -ForegroundColor Gray
    
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        try {
            & .\ntfy-core-functions.ps1 -Action "Startup"
            Write-Host "Startup notification test completed" -ForegroundColor Green
        }
        catch {
            Write-Host "Startup notification test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Test shutdown notification  
if ($TestShutdown -or $TestAll) {
    Write-Host "TEST: Shutdown Notification..." -ForegroundColor Yellow
    Write-Host "This will send a test shutdown notification" -ForegroundColor Gray
    
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        try {
            & .\ntfy-core-functions.ps1 -Action "Shutdown"
            Write-Host "Shutdown notification test completed" -ForegroundColor Green
        }
        catch {
            Write-Host "Shutdown notification test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Test queue processing
if ($TestQueue -or $TestAll) {
    Write-Host "TEST: Queue Processing..." -ForegroundColor Yellow
    Write-Host "This will process any queued notifications" -ForegroundColor Gray
    
    if (Test-Path "ntfy-notification-queue.json") {
        $queueContent = Get-Content "ntfy-notification-queue.json" -Raw
        $queue = $queueContent | ConvertFrom-Json
        Write-Host "Found $($queue.Count) queued notification(s)" -ForegroundColor Cyan
    } else {
        Write-Host "No queue file found - will test queue processor anyway" -ForegroundColor Gray
    }
    
    try {
        & .\ntfy-core-functions.ps1 -Action "ProcessQueue"
        Write-Host "Queue processing test completed" -ForegroundColor Green
    }
    catch {
        Write-Host "Queue processing test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test batch wrappers
Write-Host "TEST: Batch Wrappers..." -ForegroundColor Yellow
Write-Host "Testing batch wrapper execution..." -ForegroundColor Gray

Write-Host "  Testing startup wrapper..." -ForegroundColor Gray
try {
    $output = & .\ntfy-startup-wrapper.cmd
    Write-Host "  Startup wrapper test completed" -ForegroundColor Green
}
catch {
    Write-Host "  Startup wrapper test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Show log contents if available
$logFiles = @(
    "ntfy-startup-notifications.log",
    "ntfy-shutdown-notifications.log", 
    "ntfy-queue-processor.log",
    "ntfy-wrapper.log"
)

foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        Write-Host "Recent Log Entries ($logFile):" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        Get-Content $logFile -Tail 10 | ForEach-Object {
            Write-Host $_ -ForegroundColor Gray
        }
        Write-Host ""
    }
}

Write-Host "Test completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  Test all components: .\test-ntfy-system.ps1 -TestAll" -ForegroundColor Gray
Write-Host "  Test configuration: .\test-ntfy-system.ps1 -TestConfiguration" -ForegroundColor Gray  
Write-Host "  Test startup notification: .\test-ntfy-system.ps1 -TestStartup" -ForegroundColor Gray
Write-Host "  Test queue processing: .\test-ntfy-system.ps1 -TestQueue" -ForegroundColor Gray
