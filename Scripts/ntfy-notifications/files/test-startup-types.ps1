# Test script to verify startup type detection and force different startup scenarios
# Run as Administrator

param(
    [switch]$ShowCurrentStatus,
    [switch]$DisableFastStartup,
    [switch]$EnableFastStartup,
    [switch]$TestStartupDetection,
    [switch]$ForceShutdown,
    [switch]$ForceRestart,
    [string]$InstallPath = "C:\ntfy-notifications"
)

Write-Host "ntfy Startup Type Test Script" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Check admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

if ($ShowCurrentStatus) {
    Write-Host "Current Fast Startup Status:" -ForegroundColor Yellow
    Write-Host "============================" -ForegroundColor Yellow
    
    # Check hibernation availability
    $hibernateCheck = powercfg /a
    $hibernateAvailable = $hibernateCheck -match "Hibernate"
    Write-Host "Hibernation Available: $hibernateAvailable" -ForegroundColor $(if($hibernateAvailable) {"Green"} else {"Red"})
    
    # Check Fast Startup registry setting
    try {
        $fastStartupReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
        if ($fastStartupReg) {
            $fastStartupEnabled = $fastStartupReg.HiberbootEnabled -eq 1
            Write-Host "Fast Startup Registry Setting: $fastStartupEnabled (Value: $($fastStartupReg.HiberbootEnabled))" -ForegroundColor $(if($fastStartupEnabled) {"Green"} else {"Red"})
        } else {
            Write-Host "Fast Startup Registry Setting: Not found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Fast Startup Registry Setting: Error reading - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Check hibernation file
    $hiberfil = "C:\hiberfil.sys"
    if (Test-Path $hiberfil) {
        $hiberfilInfo = Get-Item $hiberfil -Force
        Write-Host "Hibernation File: Found (Size: $([math]::Round($hiberfilInfo.Length / 1GB, 2)) GB)" -ForegroundColor Green
        Write-Host "  Last Modified: $($hiberfilInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    } else {
        Write-Host "Hibernation File: Not found" -ForegroundColor Red
    }
    
    # Show startup information
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $systemUptime = (Get-Date) - $osInfo.LastBootUpTime
        Write-Host "Last Startup Time: $($osInfo.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
        Write-Host "System Uptime: $($systemUptime.ToString('d\.hh\:mm\:ss'))" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Startup Information: Error reading - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

if ($DisableFastStartup) {
    Write-Host "Disabling Fast Startup..." -ForegroundColor Yellow
    try {
        # Set registry value to disable Fast Startup
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
        Write-Host "Fast Startup disabled via registry" -ForegroundColor Green
        Write-Host "Note: Change takes effect after next reboot" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Failed to disable Fast Startup: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($EnableFastStartup) {
    Write-Host "Enabling Fast Startup..." -ForegroundColor Yellow
    try {
        # First ensure hibernation is enabled
        powercfg /hibernate on
        Write-Host "Hibernation enabled" -ForegroundColor Green
        
        # Set registry value to enable Fast Startup
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 1 -Type DWord -Force
        Write-Host "Fast Startup enabled via registry" -ForegroundColor Green
        Write-Host "Note: Change takes effect immediately" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Failed to enable Fast Startup: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($TestStartupDetection) {
    Write-Host "Testing Startup Type Detection..." -ForegroundColor Yellow
    
    if (Test-Path $InstallPath) {
        Set-Location $InstallPath
        if (Test-Path "ntfy-core-functions.ps1") {
            Write-Host "Running startup detection test..." -ForegroundColor Gray
            & .\ntfy-core-functions.ps1 -Action "Startup"
        } else {
            Write-Host "Error: ntfy-core-functions.ps1 not found in $InstallPath" -ForegroundColor Red
        }
    } else {
        Write-Host "Error: Install path not found: $InstallPath" -ForegroundColor Red
    }
}

if ($ForceShutdown) {
    Write-Host "Forcing True Shutdown (no Fast Startup)..." -ForegroundColor Yellow
    Write-Host "This will shutdown the computer completely" -ForegroundColor Red
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Write-Host "Initiating true shutdown in 10 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        shutdown /s /f /t 0
    }
}

if ($ForceRestart) {
    Write-Host "Forcing Restart (True Startup Cycle)..." -ForegroundColor Yellow
    Write-Host "This will restart the computer (true shutdown + startup)" -ForegroundColor Red
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Write-Host "Initiating restart in 10 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        shutdown /r /f /t 0
    }
}

if (-not ($ShowCurrentStatus -or $DisableFastStartup -or $EnableFastStartup -or $TestStartupDetection -or $ForceShutdown -or $ForceRestart)) {
    Write-Host "Usage Examples:" -ForegroundColor Yellow
    Write-Host "  Show current status: .\test-startup-types.ps1 -ShowCurrentStatus" -ForegroundColor Gray
    Write-Host "  Test startup detection: .\test-startup-types.ps1 -TestStartupDetection" -ForegroundColor Gray
    Write-Host "  Disable Fast Startup: .\test-startup-types.ps1 -DisableFastStartup" -ForegroundColor Gray
    Write-Host "  Enable Fast Startup: .\test-startup-types.ps1 -EnableFastStartup" -ForegroundColor Gray
    Write-Host "  Force true shutdown: .\test-startup-types.ps1 -ForceShutdown" -ForegroundColor Gray
    Write-Host "  Force restart: .\test-startup-types.ps1 -ForceRestart" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Test Scenarios:" -ForegroundColor Cyan
    Write-Host "1. Normal shutdown/startup (Fast Startup enabled - default)" -ForegroundColor Gray
    Write-Host "2. Restart (Forces true shutdown/startup cycle)" -ForegroundColor Gray  
    Write-Host "3. True shutdown (Disable Fast Startup, then shutdown)" -ForegroundColor Gray
}
