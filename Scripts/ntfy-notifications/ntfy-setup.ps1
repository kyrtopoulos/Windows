# ntfy Windows Notifications - Interactive Setup Script
# Enhanced setup with user prompts and deployment options

param(
    [string]$InstallPath = "C:\ntfy-notifications",
    [switch]$Silent
)

Write-Host "ntfy Windows Notifications - Interactive Setup" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

function Remove-ExistingInstallation {
    param([string]$Path)
    
    Write-Host "[CLEANUP] Checking for existing installation..." -ForegroundColor Yellow
    
    $found = $false
    
    # Check if installation directory exists
    if (Test-Path $Path) {
        Write-Host "Found existing installation at: $Path" -ForegroundColor Yellow
        $found = $true
    }
    
    # Check for existing Task Scheduler tasks
    $taskNames = @(
        "ntfy Startup Notification",
        "ntfy Shutdown Notification", 
        "ntfy Queue Processor",
        "ntfy Windows Startup Notification",
        "ntfy Windows Boot Notification"
    )
    
    $existingTasks = @()
    foreach ($taskName in $taskNames) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            $existingTasks += $taskName
            $found = $true
        }
    }
    
    if ($found) {
        if (-not $Silent) {
            Write-Host ""
            Write-Host "EXISTING INSTALLATION FOUND" -ForegroundColor Red
            if (Test-Path $Path) {
                Write-Host "  Directory: $Path" -ForegroundColor Gray
            }
            if ($existingTasks.Count -gt 0) {
                Write-Host "  Tasks: $($existingTasks -join ', ')" -ForegroundColor Gray
            }
            Write-Host ""
            $remove = Read-Host "Remove existing installation? (Y/n)"
            if ($remove -eq 'n' -or $remove -eq 'N') {
                Write-Host "Installation cancelled by user" -ForegroundColor Yellow
                exit 0
            }
        }
        
        Write-Host "Removing existing installation..." -ForegroundColor Yellow
        
        # Remove existing tasks
        foreach ($taskName in $existingTasks) {
            try {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                Write-Host "  Removed task: $taskName" -ForegroundColor Green
            }
            catch {
                Write-Host "  Warning: Could not remove task $taskName : $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Remove directory if it exists
        if (Test-Path $Path) {
            try {
                Remove-Item $Path -Recurse -Force -ErrorAction Stop
                Write-Host "  Removed directory: $Path" -ForegroundColor Green
            }
            catch {
                Write-Host "  Warning: Could not remove directory: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        Write-Host "Cleanup completed successfully" -ForegroundColor Green
    } else {
        Write-Host "No existing installation found" -ForegroundColor Green
    }
    Write-Host ""
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

function Get-UserConfiguration {
    if ($Silent) {
        return @{
            LocalServer = "http://192.168.1.100:8080"
            RemoteServer = "https://ntfy.sh"
            Topic = "MyWindowsNotifications"
            Username = ""
            Password = ""
            DeploymentType = "TaskScheduler"
        }
    }
    
    Write-Host "CONFIGURATION SETUP" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    
    # Local Server
    Write-Host "Local ntfy Server Configuration:" -ForegroundColor Yellow
    $localServer = Read-Host "Enter local server URL (default: http://192.168.1.100:8080)"
    if ([string]::IsNullOrEmpty($localServer)) {
        $localServer = "http://192.168.1.100:8080"
    }
    
    # Remote Server
    Write-Host ""
    Write-Host "Remote ntfy Server Configuration:" -ForegroundColor Yellow
    $remoteServer = Read-Host "Enter remote server URL (default: https://ntfy.sh)"
    if ([string]::IsNullOrEmpty($remoteServer)) {
        $remoteServer = "https://ntfy.sh"
    }
    
    # Topic
    Write-Host ""
    Write-Host "Notification Topic:" -ForegroundColor Yellow
    $topic = Read-Host "Enter notification topic (default: MyWindowsNotifications)"
    if ([string]::IsNullOrEmpty($topic)) {
        $topic = "MyWindowsNotifications"
    }
    
    # Authentication (optional)
    Write-Host ""
    Write-Host "Authentication (Optional - leave blank if not needed):" -ForegroundColor Yellow
    $username = Read-Host "Username"
    $password = ""
    if (-not [string]::IsNullOrEmpty($username)) {
        $password = Read-Host "Password" -AsSecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    }
    
    # Deployment Type
    Write-Host ""
    Write-Host "DEPLOYMENT CONFIGURATION" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose deployment method:" -ForegroundColor Yellow
    Write-Host "  1. Group Policy (Recommended for domain environments)" -ForegroundColor Gray
    Write-Host "  2. Task Scheduler (Recommended for standalone computers)" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $choice = Read-Host "Select option (1 or 2)"
        switch ($choice) {
            "1" { 
                $deploymentType = "GroupPolicy"
                break
            }
            "2" { 
                $deploymentType = "TaskScheduler"
                break
            }
            default {
                Write-Host "Invalid choice. Please select 1 or 2." -ForegroundColor Red
            }
        }
    } while ($choice -ne "1" -and $choice -ne "2")
    
    return @{
        LocalServer = $localServer
        RemoteServer = $remoteServer
        Topic = $topic
        Username = $username
        Password = $password
        DeploymentType = $deploymentType
    }
}

# =============================================================================
# FILE DOWNLOAD FUNCTIONS
# =============================================================================

function Download-RequiredFiles {
    param(
        [string]$InstallPath,
        [string]$SetupScriptPath
    )
    
    Write-Host "[FILES] Downloading required files from GitHub..." -ForegroundColor Yellow
    
    $baseUrl = "https://raw.githubusercontent.com/kyrtopoulos/Windows/main/Scripts/ntfy-notifications"
    $systemFiles = @(
        "files/ntfy-core-functions.ps1",
        "files/ntfy-startup-wrapper.cmd",
        "files/ntfy-shutdown-wrapper.cmd", 
        "files/ntfy-queue-processor.cmd",
        "files/test-ntfy-system.ps1",
        "files/test-startup-types.ps1"
    )
    $documentationFiles = @(
        "ntfy-Windows-Notifications-Project.md"
    )
    
    $downloadedFiles = 0
    $failedFiles = @()
    
    # Download system files from /files subdirectory
    foreach ($file in $systemFiles) {
        try {
            $url = "$baseUrl/$file"
            $fileName = Split-Path $file -Leaf
            $destination = Join-Path $InstallPath $fileName
            
            Write-Host "  Downloading $fileName..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing -ErrorAction Stop
            Write-Host "  ✓ $fileName" -ForegroundColor Green
            $downloadedFiles++
        }
        catch {
            Write-Host "  ✗ Failed to download $fileName : $($_.Exception.Message)" -ForegroundColor Red
            $failedFiles += $fileName
        }
    }
    
    # Download documentation from root directory
    foreach ($file in $documentationFiles) {
        try {
            $url = "$baseUrl/$file"
            $destination = Join-Path $InstallPath $file
            
            Write-Host "  Downloading $file..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing -ErrorAction Stop
            Write-Host "  ✓ $file" -ForegroundColor Green
            $downloadedFiles++
        }
        catch {
            Write-Host "  ✗ Failed to download $file : $($_.Exception.Message)" -ForegroundColor Red
            $failedFiles += $file
        }
    }
    
    Write-Host ""
    Write-Host "Download Summary:" -ForegroundColor Cyan
    $totalFiles = $systemFiles.Count + $documentationFiles.Count
    Write-Host "  Downloaded: $downloadedFiles/$totalFiles files" -ForegroundColor Gray
    
    if ($failedFiles.Count -gt 0) {
        Write-Host "  Failed files: $($failedFiles -join ', ')" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual download URLs:" -ForegroundColor Yellow
        foreach ($file in $systemFiles) {
            if ((Split-Path $file -Leaf) -in $failedFiles) {
                Write-Host "  $baseUrl/$file" -ForegroundColor Gray
            }
        }
        foreach ($file in $documentationFiles) {
            if ($file -in $failedFiles) {
                Write-Host "  $baseUrl/$file" -ForegroundColor Gray
            }
        }
    }
    
    return @{
        Downloaded = $downloadedFiles
        Failed = $failedFiles.Count
        Total = $totalFiles
        SetupScriptPath = $SetupScriptPath
    }
}

function Create-TaskSchedulerTasks {
    param(
        [string]$InstallPath,
        [string]$DeploymentType
    )
    
    Write-Host "[TASKS] Creating Task Scheduler tasks..." -ForegroundColor Yellow
    
    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    
    $tasksCreated = 0
    
    try {
        # Always create Queue Processor Task
        $queueAction = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$InstallPath\ntfy-queue-processor.cmd`""
        $queueTrigger = New-ScheduledTaskTrigger -Daily -At 12:00AM
        $queueTrigger.Repetition = (New-ScheduledTaskTrigger -Once -At 12:00AM -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 1)).Repetition
        
        Register-ScheduledTask -TaskName "ntfy Queue Processor" -Action $queueAction -Trigger $queueTrigger -Principal $principal -Settings $settings -Description "Processes queued ntfy windows notifications when network connectivity is restored, runs every 10 minutes with offline queue support and centralized configuration" | Out-Null
        Write-Host "  ✓ ntfy Queue Processor" -ForegroundColor Green
        $tasksCreated++
        
        if ($DeploymentType -eq "TaskScheduler") {
            # Create Startup Task
            $startupAction = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$InstallPath\ntfy-startup-wrapper.cmd`""
            $startupTrigger = New-ScheduledTaskTrigger -AtStartup
            
            Register-ScheduledTask -TaskName "ntfy Startup Notification" -Action $startupAction -Trigger $startupTrigger -Principal $principal -Settings $settings -Description "Sends ntfy windows startup notification with offline queue support and centralized configuration" | Out-Null
            Write-Host "  ✓ ntfy Startup Notification" -ForegroundColor Green
            $tasksCreated++
            
            # Create Shutdown Task (using Event Trigger for better reliability)
            $shutdownAction = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$InstallPath\ntfy-shutdown-wrapper.cmd`""
            
            # Create XML for event-based shutdown trigger
            $shutdownTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Sends ntfy windows shutdown notification with offline queue support and centralized configuration</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='User32'] and EventID=1074]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>NT AUTHORITY\SYSTEM</UserId>
      <LogonType>ServiceAccount</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c "$InstallPath\ntfy-shutdown-wrapper.cmd"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
            
            # Create Shutdown Task (using Event Trigger for shutdown detection)
            try {
                # Method 1: Try to create event-based shutdown trigger using CIM
                $shutdownTrigger = New-ScheduledTaskTrigger -AtStartup  # Placeholder, will be replaced
                
                # Create the task first
                $shutdownTask = New-ScheduledTask -Action $shutdownAction -Principal $principal -Settings $settings -Trigger $shutdownTrigger -Description "Sends ntfy windows shutdown notification with offline queue support and centralized configuration"
                $registeredTask = Register-ScheduledTask -TaskName "ntfy Shutdown Notification" -InputObject $shutdownTask
                
                # Now modify the task to use event trigger via COM object
                try {
                    $service = New-Object -ComObject Schedule.Service
                    $service.Connect()
                    $folder = $service.GetFolder("\")
                    $task = $folder.GetTask("ntfy Shutdown Notification")
                    $definition = $task.Definition
                    
                    # Clear existing triggers
                    $definition.Triggers.Clear()
                    
                    # Add event trigger for shutdown (Event ID 1074 from System log)
                    $trigger = $definition.Triggers.Create(0) # Event trigger
                    $trigger.Subscription = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[Provider[@Name='User32'] and EventID=1074]]</Select></Query></QueryList>"
                    $trigger.Enabled = $true
                    
                    # Register the modified task
                    $folder.RegisterTaskDefinition("ntfy Shutdown Notification", $definition, 6, "SYSTEM", $null, 5) | Out-Null
                    
                    Write-Host "  ✓ ntfy Shutdown Notification (Event ID 1074 trigger)" -ForegroundColor Green
                    $tasksCreated++
                }
                catch {
                    # If event trigger fails, create a basic task and warn user
                    Write-Host "  ! ntfy Shutdown Notification (Basic task - manual GPO recommended for shutdown)" -ForegroundColor Yellow
                    Write-Host "    Note: For reliable shutdown notifications, use Group Policy scripts" -ForegroundColor Gray
                    $tasksCreated++
                }
            }
            catch {
                Write-Host "  ! Error creating shutdown task: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "Successfully created $tasksCreated task(s)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error creating tasks: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# =============================================================================
# MAIN SETUP FUNCTIONS
# =============================================================================

function Create-ConfigurationFile {
    param(
        [string]$InstallPath,
        [hashtable]$Config
    )
    
    Write-Host "[CONFIG] Creating configuration file..." -ForegroundColor Yellow
    
    $configContent = @"
[Server]
LocalServer=$($Config.LocalServer)
RemoteServer=$($Config.RemoteServer)
Topic=$($Config.Topic)
Username=$($Config.Username)
Password=$($Config.Password)

[Timeouts]
NetworkTest=5
Startup=15
Shutdown=8
QueueProcessor=15

[Settings]
LoggingEnabled=true
QueueProcessorInterval=10
MaxRetries=3
RetryIntervalMinutes=5

[Logging]
# Separate log files for different components
StartupLogFile=ntfy-startup-notifications.log
ShutdownLogFile=ntfy-shutdown-notifications.log
QueueLogFile=ntfy-queue-processor.log
WrapperLogFile=ntfy-wrapper.log
# Log rotation settings
MaxLogSizeMB=10
MaxLogFiles=5
EnableLogRotation=true

[Paths]
# These will be relative to the script directory
QueueFile=ntfy-notification-queue.json
"@

    $configPath = Join-Path $InstallPath "ntfy-notifications-config.ini"
    try {
        $configContent | Out-File -FilePath $configPath -Encoding UTF8
        Write-Host "Configuration created: $configPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error creating configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-DirectoryPermissions {
    param([string]$InstallPath)
    
    Write-Host "[SECURITY] Setting file permissions..." -ForegroundColor Yellow
    try {
        # Set secure permissions on the directory
        $acl = Get-Acl $InstallPath
        $acl.SetAccessRuleProtection($true, $false) # Disable inheritance
        
        # Remove all existing access rules
        $acl.Access | ForEach-Object { 
            try { $acl.RemoveAccessRule($_) | Out-Null } catch { }
        }
        
        # Add specific permissions
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow")
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow")
        
        $acl.SetAccessRule($systemRule)
        $acl.SetAccessRule($adminRule)
        Set-Acl -Path $InstallPath -AclObject $acl
        
        Write-Host "Permissions set successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Warning: Could not set directory permissions: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Show-CompletionInfo {
    param(
        [string]$InstallPath,
        [hashtable]$Config,
        [string]$DeploymentType,
        [hashtable]$DownloadResult
    )
    
    Write-Host ""
    Write-Host "SETUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "=============================" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "  Install Path: $InstallPath" -ForegroundColor Gray
    Write-Host "  Local Server: $($Config.LocalServer)" -ForegroundColor Gray
    Write-Host "  Remote Server: $($Config.RemoteServer)" -ForegroundColor Gray
    Write-Host "  Topic: $($Config.Topic)" -ForegroundColor Gray
    Write-Host "  Authentication: $(if ($Config.Username) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
    Write-Host "  Deployment Type: $DeploymentType" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Downloaded Files:" -ForegroundColor Cyan
    Write-Host "  Successfully downloaded: $($DownloadResult.Downloaded)/$($DownloadResult.Total) files" -ForegroundColor $(if ($DownloadResult.Failed -eq 0) { "Green" } else { "Yellow" })
    if ($DownloadResult.Failed -gt 0) {
        Write-Host "  Warning: $($DownloadResult.Failed) files failed to download" -ForegroundColor Red
    }
    Write-Host ""
    
    Write-Host "Log Files:" -ForegroundColor Cyan
    Write-Host "  Startup: $InstallPath\ntfy-startup-notifications.log" -ForegroundColor Gray
    Write-Host "  Shutdown: $InstallPath\ntfy-shutdown-notifications.log" -ForegroundColor Gray
    Write-Host "  Queue: $InstallPath\ntfy-queue-processor.log" -ForegroundColor Gray
    Write-Host "  Wrapper: $InstallPath\ntfy-wrapper.log" -ForegroundColor Gray
    Write-Host ""
    
    if ($DeploymentType -eq "GroupPolicy") {
        Write-Host "GROUP POLICY SETUP REQUIRED:" -ForegroundColor Yellow
        Write-Host "============================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Open Group Policy Editor (gpedit.msc)" -ForegroundColor White
        Write-Host "2. Navigate to: Computer Configuration → Windows Settings → Scripts (Startup/Shutdown)" -ForegroundColor White
        Write-Host ""
        Write-Host "3. Configure Startup Script:" -ForegroundColor Yellow
        Write-Host "   - Double-click 'Startup'" -ForegroundColor Gray
        Write-Host "   - Click 'Add...'" -ForegroundColor Gray
        Write-Host "   - Script Name: $InstallPath\ntfy-startup-wrapper.cmd" -ForegroundColor Green
        Write-Host ""
        Write-Host "4. Configure Shutdown Script:" -ForegroundColor Yellow
        Write-Host "   - Double-click 'Shutdown'" -ForegroundColor Gray
        Write-Host "   - Click 'Add...'" -ForegroundColor Gray  
        Write-Host "   - Script Name: $InstallPath\ntfy-shutdown-wrapper.cmd" -ForegroundColor Green
        Write-Host ""
        Write-Host "Task Scheduler Information:" -ForegroundColor Cyan
        Write-Host "  ✓ Queue processing runs automatically every 10 minutes" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "Task Scheduler Information:" -ForegroundColor Cyan
        Write-Host "  ✓ ntfy Startup Notification - Runs at system startup" -ForegroundColor Gray
        Write-Host "  ✓ ntfy Shutdown Notification - Runs on shutdown events" -ForegroundColor Gray
        Write-Host "  ✓ ntfy Queue Processor - Runs every 10 minutes" -ForegroundColor Gray
        Write-Host ""
        Write-Host "All notifications are fully automated!" -ForegroundColor Green
    }
    
    Write-Host "Ready to Use:" -ForegroundColor Yellow
    Write-Host "1. Test the system:" -ForegroundColor Gray
    Write-Host "   cd $InstallPath" -ForegroundColor Gray
    Write-Host "   .\test-ntfy-system.ps1 -TestAll" -ForegroundColor Gray
    Write-Host "2. Read documentation: Open ntfy-Windows-Notifications-Project.md with your preferred editor" -ForegroundColor Gray
    Write-Host "3. Restart the computer to activate startup notifications" -ForegroundColor Gray
    Write-Host "4. All files are now located in: $InstallPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Documentation:" -ForegroundColor Cyan
    Write-Host "  Complete guide: $InstallPath\ntfy-Windows-Notifications-Project.md" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Setup completed successfully! No further action required." -ForegroundColor Green
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

function Main {
    # Get script path using multiple methods for reliability
    $setupScriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($setupScriptPath)) {
        $setupScriptPath = $PSCommandPath
    }
    if ([string]::IsNullOrEmpty($setupScriptPath)) {
        $setupScriptPath = $script:MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrEmpty($setupScriptPath)) {
        $setupScriptPath = (Get-Location).Path + "\ntfy-setup.ps1"
    }
    
    # Cleanup existing installations
    Remove-ExistingInstallation -Path $InstallPath
    
    # Get user configuration
    $config = Get-UserConfiguration
    
    # Create directory structure
    Write-Host "[SETUP] Creating directory structure..." -ForegroundColor Yellow
    if (-not (Test-Path $InstallPath)) {
        try {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
            Write-Host "Created directory: $InstallPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Error creating directory: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    # Create configuration file
    if (-not (Create-ConfigurationFile -InstallPath $InstallPath -Config $config)) {
        Write-Host "Setup failed during configuration creation" -ForegroundColor Red
        exit 1
    }
    
    # Set directory permissions
    Set-DirectoryPermissions -InstallPath $InstallPath | Out-Null
    
    # Download required files from GitHub
    $downloadResult = Download-RequiredFiles -InstallPath $InstallPath -SetupScriptPath $setupScriptPath
    
    # Create Task Scheduler tasks
    if (-not (Create-TaskSchedulerTasks -InstallPath $InstallPath -DeploymentType $config.DeploymentType)) {
        Write-Host "Warning: Some tasks may not have been created properly" -ForegroundColor Yellow
    }
    
    # Show completion information
    Show-CompletionInfo -InstallPath $InstallPath -Config $config -DeploymentType $config.DeploymentType -DownloadResult $downloadResult
    
    # Move setup script to installation directory (very last step)
    if (-not [string]::IsNullOrEmpty($downloadResult.SetupScriptPath) -and (Test-Path $downloadResult.SetupScriptPath)) {
        try {
            $setupDestination = Join-Path $InstallPath "ntfy-setup.ps1"
            Move-Item $downloadResult.SetupScriptPath $setupDestination -Force -ErrorAction Stop
            Write-Host "Setup script moved to: $setupDestination" -ForegroundColor Green
        }
        catch {
            Write-Host "Warning: Could not move setup script to installation directory: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Note: Setup script path could not be determined, manually copy ntfy-setup.ps1 to $InstallPath if needed" -ForegroundColor Gray
    }
}

# Run main function
Main