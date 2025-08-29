# ntfy Windows Notifications - Initialization & Setup Script
# Downloads all required scripts from GitHub and sets up the system
# Run as Administrator for proper setup

param(
    [switch]$SkipDownload,
    [switch]$Cleanup,
    [switch]$Force,
    [string]$CustomBasePath = ""
)

# =============================================================================
# CONFIGURATION & CONSTANTS
# =============================================================================
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/kyrtopoulos/Windows/main/Scripts/ntfy-Notifications/src"
$CURRENT_SCRIPT_NAME = "ntfy-Windows-Notifications-Initialization.ps1"
$CONFIG_FILE_NAME = "ntfy-Windows-Notifications-Config.json"

# Script files to download from GitHub
$SCRIPT_FILES = @(
    "ntfy-Windows-Boot-Notification.ps1",
    "ntfy-Windows-Shutdown-Notification.ps1", 
    "ntfy-Queue-Processor-Service.ps1",
    "ntfy-Secure-Credentials-Setup.ps1",
    "ntfy-Windows-Notifications-Setup-Services.ps1",
    "ntfy-Queue-Processor-Service-Setup-Service.ps1"
)

Write-Host "ntfy Windows Notifications - System Initialization" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# ADMINISTRATOR CHECK
# =============================================================================
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = Read-Host
    exit 1
}

# =============================================================================
# CONFIGURATION LOADING
# =============================================================================
Write-Host "[1/8] Loading configuration..." -ForegroundColor Yellow

$configPath = Join-Path $PSScriptRoot $CONFIG_FILE_NAME
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Configuration file not found: $configPath" -ForegroundColor Red
    Write-Host "Please ensure $CONFIG_FILE_NAME is in the same directory as this script" -ForegroundColor Yellow
    exit 1
}

try {
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-Host "Configuration loaded successfully" -ForegroundColor Green
    Write-Host "  Base Path: $($config.BasePath)" -ForegroundColor Gray
    Write-Host "  Local Server: $($config.LocalServer)" -ForegroundColor Gray
    Write-Host "  Remote Server: $($config.RemoteServer)" -ForegroundColor Gray
}
catch {
    Write-Host "ERROR: Failed to parse configuration file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Override base path if custom provided
if ($CustomBasePath) {
    Write-Host "Using custom base path: $CustomBasePath" -ForegroundColor Cyan
    $config.BasePath = $CustomBasePath
}

Write-Host ""

# =============================================================================
# DIRECTORY CREATION
# =============================================================================
Write-Host "[2/8] Creating base directory..." -ForegroundColor Yellow

$basePath = $config.BasePath
if (-not (Test-Path $basePath)) {
    try {
        New-Item -ItemType Directory -Path $basePath -Force | Out-Null
        Write-Host "Created base directory: $basePath" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to create base directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
else {
    if ((Get-ChildItem $basePath | Measure-Object).Count -gt 0 -and -not $Force) {
        Write-Host "WARNING: Base directory already exists and contains files" -ForegroundColor Yellow
        $response = Read-Host "Continue anyway? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Setup cancelled by user" -ForegroundColor Gray
            exit 0
        }
    }
    Write-Host "Using existing directory: $basePath" -ForegroundColor Green
}

Write-Host ""

# =============================================================================
# SCRIPT DOWNLOAD
# =============================================================================
if (-not $SkipDownload) {
    Write-Host "[3/8] Downloading scripts from GitHub..." -ForegroundColor Yellow
    $downloadCount = 0
    $failedDownloads = @()

    foreach ($scriptFile in $SCRIPT_FILES) {
        $url = "$GITHUB_BASE_URL/$scriptFile"
        $destinationPath = Join-Path $basePath $scriptFile
        
        Write-Host "  Downloading: $scriptFile" -ForegroundColor Gray
        
        try {
            # Use TLS 1.2 for GitHub compatibility
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "ntfy-Windows-Notifications-Setup/1.0")
            $webClient.DownloadFile($url, $destinationPath)
            $webClient.Dispose()
            
            if (Test-Path $destinationPath) {
                $fileSize = (Get-Item $destinationPath).Length
                Write-Host "    Downloaded: $fileSize bytes" -ForegroundColor Green
                $downloadCount++
            }
            else {
                throw "File not created after download"
            }
        }
        catch {
            Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
            $failedDownloads += $scriptFile
        }
    }
    
    Write-Host ""
    Write-Host "Download Summary:" -ForegroundColor Cyan
    Write-Host "  Successfully downloaded: $downloadCount/$($SCRIPT_FILES.Count) files" -ForegroundColor Green
    
    if ($failedDownloads.Count -gt 0) {
        Write-Host "  Failed downloads: $($failedDownloads.Count)" -ForegroundColor Red
        foreach ($failed in $failedDownloads) {
            Write-Host "    - $failed" -ForegroundColor Red
        }
        
        $response = Read-Host "Continue with missing files? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Setup cancelled due to download failures" -ForegroundColor Gray
            exit 1
        }
    }
}
else {
    Write-Host "[3/8] Skipping download (using existing files)..." -ForegroundColor Yellow
}

Write-Host ""

# =============================================================================
# SCRIPT VERIFICATION
# =============================================================================
Write-Host "[4/8] Verifying script files..." -ForegroundColor Yellow

$missingFiles = @()
foreach ($scriptFile in $SCRIPT_FILES) {
    $scriptPath = Join-Path $basePath $scriptFile
    if (-not (Test-Path $scriptPath)) {
        $missingFiles += $scriptFile
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "ERROR: Missing required script files:" -ForegroundColor Red
    foreach ($missing in $missingFiles) {
        Write-Host "  - $missing" -ForegroundColor Red
    }
    exit 1
}

Write-Host "All required script files verified" -ForegroundColor Green
Write-Host ""

# =============================================================================
# CONFIGURATION FILE MIGRATION
# =============================================================================
Write-Host "[5/8] Moving configuration and setup files..." -ForegroundColor Yellow

try {
    # Move configuration file to base directory
    $configDestination = Join-Path $basePath $CONFIG_FILE_NAME
    if ($configPath -ne $configDestination) {
        Move-Item $configPath $configDestination -Force
        Write-Host "Configuration file moved to: $configDestination" -ForegroundColor Green
    }
    
    # Move initialization script to base directory
    $initDestination = Join-Path $basePath $CURRENT_SCRIPT_NAME
    $currentScriptPath = Join-Path $PSScriptRoot $CURRENT_SCRIPT_NAME
    if ($currentScriptPath -ne $initDestination -and (Test-Path $currentScriptPath)) {
        Move-Item $currentScriptPath $initDestination -Force
        Write-Host "Initialization script moved to: $initDestination" -ForegroundColor Green
    }
}
catch {
    Write-Host "ERROR: Failed to copy files: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# =============================================================================
# PERMISSION VERIFICATION
# =============================================================================
Write-Host "[6/8] Verifying PowerShell execution policy..." -ForegroundColor Yellow

$executionPolicy = Get-ExecutionPolicy
Write-Host "Current execution policy: $executionPolicy" -ForegroundColor Gray

if ($executionPolicy -eq "Restricted") {
    Write-Host "WARNING: PowerShell execution policy is Restricted" -ForegroundColor Yellow
    Write-Host "You may need to change it to RemoteSigned or Bypass to run the scripts" -ForegroundColor Yellow
    $response = Read-Host "Set execution policy to RemoteSigned? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        try {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "Execution policy set to RemoteSigned" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to set execution policy: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "Execution policy is compatible" -ForegroundColor Green
}

Write-Host ""

# =============================================================================
# SETUP OPTIONS DISPLAY
# =============================================================================
Write-Host "[7/8] Setup Options Available..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Your ntfy Windows Notifications system is now ready for configuration!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps - Choose ONE of these setup methods:" -ForegroundColor Cyan
Write-Host ""
Write-Host "OPTION 1: Task Scheduler (Recommended)" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
Write-Host "1. First, set up your credentials:" -ForegroundColor Gray
Write-Host "   cd `"$basePath`"" -ForegroundColor Yellow
Write-Host "   .\ntfy-Secure-Credentials-Setup.ps1 -Username `"your_username`" -Password `"your_password`"" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Then set up all services (boot, shutdown, and queue processor):" -ForegroundColor Gray
Write-Host "   .\ntfy-Windows-Notifications-Setup-Services.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "   OR set up only the queue processor:" -ForegroundColor Gray
Write-Host "   .\ntfy-Queue-Processor-Service-Setup-Service.ps1" -ForegroundColor Yellow
Write-Host ""

Write-Host "OPTION 2: Group Policy (Advanced Users)" -ForegroundColor White
Write-Host "=========================================" -ForegroundColor White
Write-Host "1. Set up credentials (same as Option 1)" -ForegroundColor Gray
Write-Host "2. Open Group Policy Editor: gpedit.msc" -ForegroundColor Gray
Write-Host "3. Navigate to: Computer Configuration -> Windows Settings -> Scripts" -ForegroundColor Gray
Write-Host "4. Under Startup -> PowerShell Scripts, add:" -ForegroundColor Gray
Write-Host "   Script Name: $basePath\ntfy-Windows-Boot-Notification.ps1" -ForegroundColor Yellow
Write-Host "5. Under Shutdown -> PowerShell Scripts, add:" -ForegroundColor Gray
Write-Host "   Script Name: $basePath\ntfy-Windows-Shutdown-Notification.ps1" -ForegroundColor Yellow
Write-Host "6. Set up queue processor with Task Scheduler:" -ForegroundColor Gray
Write-Host "   .\ntfy-Queue-Processor-Service-Setup-Service.ps1" -ForegroundColor Yellow
Write-Host "7. Apply changes: gpupdate /force" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
Write-Host "[8/8] Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Installation Summary:" -ForegroundColor Cyan
Write-Host "  Base Directory: $basePath" -ForegroundColor Gray
Write-Host "  Scripts Downloaded: $($SCRIPT_FILES.Count)" -ForegroundColor Gray
Write-Host "  Configuration: Ready" -ForegroundColor Gray
Write-Host ""

Write-Host "Files in base directory:" -ForegroundColor Cyan
$allFiles = Get-ChildItem $basePath -File | Sort-Object Name
foreach ($file in $allFiles) {
    Write-Host "  - $($file.Name) ($([math]::Round($file.Length / 1KB, 1)) KB)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Configuration Details:" -ForegroundColor Cyan
Write-Host "  Local Server: $($config.LocalServer)" -ForegroundColor Gray
Write-Host "  Remote Server: $($config.RemoteServer)" -ForegroundColor Gray
Write-Host "  Topic: $($config.Topic)" -ForegroundColor Gray
Write-Host "  Queue Processor Interval: $($config.QueueProcessorInterval) minutes" -ForegroundColor Gray
Write-Host ""

if (-not $Cleanup) {
    Write-Host "IMPORTANT: Remember to update your configuration file with correct server details before running setup!" -ForegroundColor Yellow
    Write-Host "Edit: $basePath\$CONFIG_FILE_NAME" -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# CLEANUP OPTION
# =============================================================================
if ($Cleanup) {
    Write-Host "Cleanup mode - removing original files from current directory..." -ForegroundColor Yellow
    $currentDir = $PSScriptRoot
    $baseDir = $config.BasePath
    
    if ($currentDir -ne $baseDir) {
        try {
            # Remove config file from current directory
            $originalConfig = Join-Path $currentDir $CONFIG_FILE_NAME
            if (Test-Path $originalConfig) {
                Remove-Item $originalConfig -Force
                Write-Host "Removed: $originalConfig" -ForegroundColor Green
            }
            
            # Remove initialization script from current directory
            $originalInit = Join-Path $currentDir $CURRENT_SCRIPT_NAME
            if (Test-Path $originalInit) {
                Remove-Item $originalInit -Force
                Write-Host "Removed: $originalInit" -ForegroundColor Green
            }
            
            Write-Host "Cleanup completed" -ForegroundColor Green
        }
        catch {
            Write-Host "Cleanup warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

Write-Host "Initialization completed successfully!" -ForegroundColor Green
Write-Host "Navigate to $basePath to continue with setup." -ForegroundColor Cyan
Write-Host ""
Write-Host "For help with any step, refer to the GitHub repository:" -ForegroundColor Gray
Write-Host "https://github.com/kyrtopoulos/Windows/tree/main/Scripts/ntfy-Notifications" -ForegroundColor Blue
