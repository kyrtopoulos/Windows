# ntfy Windows Notifications - Initialization & Setup Script
# Downloads all required scripts from GitHub and sets up the system with organized folder structure
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

# Script files to download from GitHub (main scripts go to base directory)
$MAIN_SCRIPT_FILES = @(
    "ntfy-Windows-Boot-Notification.ps1",
    "ntfy-Windows-Shutdown-Notification.ps1"
)

# Queue script files (go to queue directory)
$QUEUE_SCRIPT_FILES = @(
    "ntfy-Queue-Processor-Service.ps1"
)

# Setup script files to download (go to setup directory)
$SETUP_SCRIPT_FILES = @(
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
Write-Host "[1/9] Loading configuration..." -ForegroundColor Yellow

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
# DIRECTORY STRUCTURE CREATION
# =============================================================================
Write-Host "[2/9] Creating organized directory structure..." -ForegroundColor Yellow

$basePath = $config.BasePath
$logsPath = Join-Path $basePath "logs"
$configDir = Join-Path $basePath "config"
$setupPath = Join-Path $basePath "setup"
$credentialsPath = Join-Path $basePath "credentials"
$queuePath = Join-Path $basePath "queue"

$directoriesToCreate = @($basePath, $logsPath, $configDir, $setupPath, $credentialsPath, $queuePath)

foreach ($dir in $directoriesToCreate) {
    if (-not (Test-Path $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "Created directory: $dir" -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR: Failed to create directory $dir`: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "Directory exists: $dir" -ForegroundColor Gray
    }
}

# Check if base directory has existing files and warn user
if ((Get-ChildItem $basePath -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0 -and -not $Force) {
    Write-Host "WARNING: Base directory already contains files" -ForegroundColor Yellow
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Setup cancelled by user" -ForegroundColor Gray
        exit 0
    }
}

Write-Host ""

# =============================================================================
# MAIN SCRIPTS DOWNLOAD
# =============================================================================
if (-not $SkipDownload) {
    Write-Host "[3/9] Downloading main scripts from GitHub..." -ForegroundColor Yellow
    $downloadCount = 0
    $failedDownloads = @()

    foreach ($scriptFile in $MAIN_SCRIPT_FILES) {
        $url = "$GITHUB_BASE_URL/$scriptFile"
        $destinationPath = Join-Path $basePath $scriptFile
        
        Write-Host "  Downloading: $scriptFile (to base directory)" -ForegroundColor Gray
        
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
    
    Write-Host "Main scripts download summary: $downloadCount/$($MAIN_SCRIPT_FILES.Count) successful" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "[3/9] Skipping main scripts download (using existing files)..." -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# QUEUE SCRIPTS DOWNLOAD
# =============================================================================
if (-not $SkipDownload) {
    Write-Host "[4/9] Downloading queue scripts from GitHub..." -ForegroundColor Yellow
    $queueDownloadCount = 0
    $queueFailedDownloads = @()

    foreach ($scriptFile in $QUEUE_SCRIPT_FILES) {
        $url = "$GITHUB_BASE_URL/$scriptFile"
        $destinationPath = Join-Path $queuePath $scriptFile
        
        Write-Host "  Downloading: $scriptFile (to queue directory)" -ForegroundColor Gray
        
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
                $queueDownloadCount++
            }
            else {
                throw "File not created after download"
            }
        }
        catch {
            Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
            $queueFailedDownloads += $scriptFile
        }
    }
    
    Write-Host "Queue scripts download summary: $queueDownloadCount/$($QUEUE_SCRIPT_FILES.Count) successful" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "[4/9] Skipping queue scripts download (using existing files)..." -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# SETUP SCRIPTS DOWNLOAD
# =============================================================================
if (-not $SkipDownload) {
    Write-Host "[5/9] Downloading setup scripts from GitHub..." -ForegroundColor Yellow
    $setupDownloadCount = 0
    $setupFailedDownloads = @()

    foreach ($scriptFile in $SETUP_SCRIPT_FILES) {
        $url = "$GITHUB_BASE_URL/$scriptFile"
        $destinationPath = Join-Path $setupPath $scriptFile
        
        Write-Host "  Downloading: $scriptFile (to setup directory)" -ForegroundColor Gray
        
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
                $setupDownloadCount++
            }
            else {
                throw "File not created after download"
            }
        }
        catch {
            Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
            $setupFailedDownloads += $scriptFile
        }
    }
    
    Write-Host "Setup scripts download summary: $setupDownloadCount/$($SETUP_SCRIPT_FILES.Count) successful" -ForegroundColor Green
    
    # Combine all failed downloads
    $allFailedDownloads = @()
    if ($failedDownloads) { $allFailedDownloads += $failedDownloads }
    if ($queueFailedDownloads) { $allFailedDownloads += $queueFailedDownloads }
    if ($setupFailedDownloads) { $allFailedDownloads += $setupFailedDownloads }
    
    if ($allFailedDownloads.Count -gt 0) {
        Write-Host "  Total failed downloads: $($allFailedDownloads.Count)" -ForegroundColor Red
        foreach ($failed in $allFailedDownloads) {
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
    Write-Host "[5/9] Skipping setup scripts download (using existing files)..." -ForegroundColor Yellow
}

Write-Host ""

# =============================================================================
# SCRIPT VERIFICATION
# =============================================================================
Write-Host "[6/9] Verifying script files..." -ForegroundColor Yellow

$missingFiles = @()

# Check main scripts in base directory
foreach ($scriptFile in $MAIN_SCRIPT_FILES) {
    $scriptPath = Join-Path $basePath $scriptFile
    if (-not (Test-Path $scriptPath)) {
        $missingFiles += "$scriptFile (base directory)"
    }
}

# Check queue scripts in queue directory
foreach ($scriptFile in $QUEUE_SCRIPT_FILES) {
    $scriptPath = Join-Path $queuePath $scriptFile
    if (-not (Test-Path $scriptPath)) {
        $missingFiles += "$scriptFile (queue directory)"
    }
}

# Check setup scripts in setup directory
foreach ($scriptFile in $SETUP_SCRIPT_FILES) {
    $scriptPath = Join-Path $setupPath $scriptFile
    if (-not (Test-Path $scriptPath)) {
        $missingFiles += "$scriptFile (setup directory)"
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
Write-Host "[7/9] Moving configuration and setup files..." -ForegroundColor Yellow

try {
    # Move configuration file to config directory
    $configDestination = Join-Path $configDir $CONFIG_FILE_NAME
    if ($configPath -ne $configDestination) {
        Copy-Item $configPath $configDestination -Force
        Write-Host "Configuration file copied to: $configDestination" -ForegroundColor Green
    }
    
    # Move initialization script to setup directory
    $initDestination = Join-Path $setupPath $CURRENT_SCRIPT_NAME
    $currentScriptPath = Join-Path $PSScriptRoot $CURRENT_SCRIPT_NAME
    if ($currentScriptPath -ne $initDestination -and (Test-Path $currentScriptPath)) {
        Copy-Item $currentScriptPath $initDestination -Force
        Write-Host "Initialization script copied to: $initDestination" -ForegroundColor Green
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
Write-Host "[8/9] Verifying PowerShell execution policy..." -ForegroundColor Yellow

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
# FOLDER STRUCTURE SUMMARY
# =============================================================================
Write-Host "[9/10] Organized folder structure created:" -ForegroundColor Yellow
Write-Host "  $basePath\ (Base Directory)" -ForegroundColor Cyan
Write-Host "  │" -ForegroundColor Gray
Write-Host "  ├── ntfy-Windows-Boot-Notification.ps1" -ForegroundColor Gray
Write-Host "  ├── ntfy-Windows-Shutdown-Notification.ps1" -ForegroundColor Gray
Write-Host "  │" -ForegroundColor Gray
Write-Host "  ├── logs\" -ForegroundColor Cyan
Write-Host "  │   ├── ntfy-Windows-Boot-Notifications.log" -ForegroundColor Gray
Write-Host "  │   ├── ntfy-Windows-Shutdown-Notifications.log" -ForegroundColor Gray
Write-Host "  │   └── ntfy-Queue-Processor-Service.log" -ForegroundColor Gray
Write-Host "  │" -ForegroundColor Gray
Write-Host "  ├── config\" -ForegroundColor Cyan
Write-Host "  │   └── ntfy-Windows-Notifications-Config.json" -ForegroundColor Gray
Write-Host "  │" -ForegroundColor Gray
Write-Host "  ├── setup\" -ForegroundColor Cyan
Write-Host "  │   ├── ntfy-Queue-Processor-Service-Setup-Service.ps1" -ForegroundColor Gray
Write-Host "  │   ├── ntfy-Secure-Credentials-Setup.ps1" -ForegroundColor Gray
Write-Host "  │   ├── ntfy-Windows-Notifications-Initialization.ps1" -ForegroundColor Gray
Write-Host "  │   └── ntfy-Windows-Notifications-Setup-Services.ps1" -ForegroundColor Gray
Write-Host "  │" -ForegroundColor Gray
Write-Host "  ├── credentials\" -ForegroundColor Cyan
Write-Host "  │   ├── ntfy.key (created during credential setup)" -ForegroundColor Gray
Write-Host "  │   ├── ntfy-Password.enc (created during credential setup)" -ForegroundColor Gray
Write-Host "  │   └── ntfy-User.enc (created during credential setup)" -ForegroundColor Gray
Write-Host "  │" -ForegroundColor Gray
Write-Host "  └── queue\" -ForegroundColor Cyan
Write-Host "      ├── ntfy-Queue-Processor-Service.ps1" -ForegroundColor Gray
Write-Host "      └── ntfy-Windows-Notification-Queue.json (created when needed)" -ForegroundColor Gray

Write-Host ""

# =============================================================================
# SETUP OPTIONS DISPLAY
# =============================================================================
Write-Host "[10/10] Setup Options Available..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Your ntfy Windows Notifications system is now ready for configuration!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps - Choose ONE of these setup methods:" -ForegroundColor Cyan
Write-Host ""
Write-Host "OPTION 1: Task Scheduler (Recommended)" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
Write-Host "1. First, set up your credentials:" -ForegroundColor Gray
Write-Host "   cd `"$setupPath`"" -ForegroundColor Yellow
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
Write-Host "   cd `"$setupPath`"" -ForegroundColor Yellow
Write-Host "   .\ntfy-Queue-Processor-Service-Setup-Service.ps1" -ForegroundColor Yellow
Write-Host "7. Apply changes: gpupdate /force" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Installation Summary:" -ForegroundColor Cyan
Write-Host "  Base Directory: $basePath" -ForegroundColor Gray
Write-Host "  Main Scripts: $($MAIN_SCRIPT_FILES.Count)" -ForegroundColor Gray
Write-Host "  Setup Scripts: $($SETUP_SCRIPT_FILES.Count)" -ForegroundColor Gray
Write-Host "  Configuration: Ready" -ForegroundColor Gray
Write-Host "  Folder Structure: Organized" -ForegroundColor Gray
Write-Host ""

Write-Host "Files in organized structure:" -ForegroundColor Cyan

# Show files in each directory
$directories = @(
    @{ Path = $basePath; Name = "Base Directory"; Filter = "*.ps1" },
    @{ Path = $logsPath; Name = "Logs"; Filter = "*.*" },
    @{ Path = $configDir; Name = "Config"; Filter = "*.*" },
    @{ Path = $setupPath; Name = "Setup Scripts"; Filter = "*.ps1" },
    @{ Path = $credentialsPath; Name = "Credentials"; Filter = "*.*" },
    @{ Path = $queuePath; Name = "Queue"; Filter = "*.*" }
)

foreach ($dir in $directories) {
    $files = Get-ChildItem $dir.Path -File -Filter $dir.Filter -ErrorAction SilentlyContinue | Sort-Object Name
    if ($files) {
        Write-Host "  $($dir.Name):" -ForegroundColor White
        foreach ($file in $files) {
            Write-Host "    - $($file.Name) ($([math]::Round($file.Length / 1KB, 1)) KB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  $($dir.Name): (empty - files created as needed)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Configuration Details:" -ForegroundColor Cyan
Write-Host "  Local Server: $($config.LocalServer)" -ForegroundColor Gray
Write-Host "  Remote Server: $($config.RemoteServer)" -ForegroundColor Gray
Write-Host "  Topic: $($config.Topic)" -ForegroundColor Gray
Write-Host "  Queue Processor Interval: $($config.QueueProcessorInterval) minutes" -ForegroundColor Gray
Write-Host ""

if (-not $Cleanup) {
    Write-Host "IMPORTANT: Remember to update your configuration file with correct server details!" -ForegroundColor Yellow
    Write-Host "Edit: $configDir\$CONFIG_FILE_NAME" -ForegroundColor Yellow
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
Write-Host "Navigate to the appropriate directories to continue with setup:" -ForegroundColor Cyan
Write-Host "  - Credentials setup: cd `"$setupPath`"" -ForegroundColor Gray
Write-Host "  - Task setup: cd `"$setupPath`"" -ForegroundColor Gray
Write-Host "  - Configuration: cd `"$configDir`"" -ForegroundColor Gray
Write-Host ""
Write-Host "For help with any step, refer to the GitHub repository:" -ForegroundColor Gray
Write-Host "https://github.com/kyrtopoulos/Windows/tree/main/Scripts/ntfy-Notifications" -ForegroundColor Blue
