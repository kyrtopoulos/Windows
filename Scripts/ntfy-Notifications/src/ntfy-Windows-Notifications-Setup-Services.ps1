# ntfy Windows Notifications - Task Scheduler Services Setup
# Run this script as Administrator to create all three scheduled tasks
# Requires: ntfy-Windows-Notifications-Config.json in the config directory

param(
    [switch]$RemoveExisting,
    [switch]$ListTasks
)

# =============================================================================
# CONFIGURATION
# =============================================================================
$SCRIPT_DIR   = $PSScriptRoot
$CONFIG_FILE  = "ntfy-Windows-Notifications-Config.json"

# Task names
$BOOT_TASK_NAME     = "ntfy Windows Boot Notification"
$SHUTDOWN_TASK_NAME = "ntfy Windows Shutdown Notification"
$QUEUE_TASK_NAME    = "ntfy Queue Processor Service"

# Script paths (located in base directory, not setup directory)
$BOOT_SCRIPT      = "ntfy-Windows-Boot-Notification.ps1"
$SHUTDOWN_SCRIPT  = "ntfy-Windows-Shutdown-Notification.ps1"
$QUEUE_SCRIPT     = "ntfy-Queue-Processor-Service.ps1"

Write-Host "ntfy Windows Notifications - Services Setup" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Load configuration to determine base path
$configPath = Join-Path $SCRIPT_DIR "..\config\$CONFIG_FILE"
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Configuration file not found: $configPath" -ForegroundColor Red
    Write-Host "Please ensure $CONFIG_FILE is in the config directory" -ForegroundColor Yellow
    exit 1
}

try {
    $config = Get-Content $configPath | ConvertFrom-Json
    $SCRIPT_BASE_PATH = $config.BasePath
} catch {
    Write-Host "ERROR: Failed to parse configuration file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify script files exist in base directory
$bootScriptPath     = Join-Path $SCRIPT_BASE_PATH $BOOT_SCRIPT
$shutdownScriptPath = Join-Path $SCRIPT_BASE_PATH $SHUTDOWN_SCRIPT
$queueScriptPath = Join-Path $SCRIPT_BASE_PATH "queue\$QUEUE_SCRIPT"

foreach ($scriptPath in @($bootScriptPath, $shutdownScriptPath, $queueScriptPath)) {
    if (-not (Test-Path $scriptPath)) {
        Write-Host "ERROR: Script file not found: $scriptPath" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Configuration verified successfully" -ForegroundColor Green
Write-Host "Configuration path: $configPath" -ForegroundColor Gray
Write-Host "Script base path: $SCRIPT_BASE_PATH" -ForegroundColor Gray
Write-Host ""

# Functions
function Remove-ExistingTasks {
    Write-Host "Removing existing tasks..." -ForegroundColor Yellow
    $tasks = @($BOOT_TASK_NAME, $SHUTDOWN_TASK_NAME, $QUEUE_TASK_NAME)
    foreach ($taskName in $tasks) {
        try {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Host "  - Removed: $taskName" -ForegroundColor Green
            }
        } catch {
            Write-Host "  - Task not found: $taskName" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

function List-ExistingTasks {
    Write-Host "Current ntfy tasks:" -ForegroundColor Yellow
    $tasks = @($BOOT_TASK_NAME, $SHUTDOWN_TASK_NAME, $QUEUE_TASK_NAME)
    foreach ($taskName in $tasks) {
        try {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                $info = Get-ScheduledTaskInfo -TaskName $taskName
                Write-Host "  - $taskName : $($task.State) (Last: $($info.LastRunTime))" -ForegroundColor Green
            } else {
                Write-Host "  - $taskName : Not found" -ForegroundColor Red
            }
        } catch {
            Write-Host "  - $taskName : Error checking status" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Handle flags
if ($ListTasks) { List-ExistingTasks; exit 0 }
if ($RemoveExisting) { Remove-ExistingTasks; Write-Host "Task removal completed" -ForegroundColor Green; exit 0 }

# Remove existing tasks before creating new ones
Remove-ExistingTasks

Write-Host "Creating scheduled tasks..." -ForegroundColor Yellow
Write-Host ""

# =============================================================================
# [1/3] CREATE NTFY WINDOWS BOOT NOTIFICATION TASK
# =============================================================================
Write-Host "[1/3] Creating ntfy Windows Boot Notification task..." -ForegroundColor Cyan
try {
    $bootAction  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$bootScriptPath`""
    $bootTrigger = New-ScheduledTaskTrigger -AtStartup
    $principal   = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings    = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask -TaskName $BOOT_TASK_NAME -Action $bootAction -Trigger $bootTrigger -Principal $principal -Settings $settings `
        -Description "Sends ntfy Windows Boot Notification with offline queue support and centralized configuration" | Out-Null
    Write-Host "  ntfy Windows Boot Notification task created successfully" -ForegroundColor Green
} catch {
    Write-Host "  ERROR creating ntfy Windows Boot Notification task: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# [2/3] CREATE NTFY WINDOWS SHUTDOWN NOTIFICATION TASK - FIXED VERSION
# =============================================================================
Write-Host "[2/3] Creating ntfy Windows Shutdown Notification task..." -ForegroundColor Cyan
try {
    try { Unregister-ScheduledTask -TaskName $SHUTDOWN_TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue } catch {}

    $tnQuoted = '"' + $SHUTDOWN_TASK_NAME + '"'
    $escapedScriptPath = $shutdownScriptPath -replace '"', '\"'
    $trQuoted = "`"powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \`"$escapedScriptPath\`"`""
    $moQuoted = '"*[System[Provider[@Name=''User32''] and EventID=1074]]"'

    # Step 1: Create task without description first
    $argLine = @(
        '/create',
        '/tn', $tnQuoted,
        '/tr', $trQuoted,
        '/sc', 'onevent',
        '/ec', 'System',
        '/mo', $moQuoted,
        '/ru', 'SYSTEM',
        '/rl', 'HIGHEST',
        '/f'
    ) -join ' '

    $stderrPath = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath 'schtasks.exe' -ArgumentList $argLine -NoNewWindow -Wait -PassThru -RedirectStandardError $stderrPath

    if ($p.ExitCode -ne 0) {
        $stderr = Get-Content -Raw $stderrPath
        Write-Host "  ERROR creating ntfy Windows Shutdown Notification task: $stderr" -ForegroundColor Red
        throw "schtasks failed"
    }

    Remove-Item $stderrPath -ErrorAction SilentlyContinue

    # Step 2: Export task to XML
    $tempXmlPath = [IO.Path]::GetTempFileName() -replace '\.tmp$', '.xml'
    $exportCmd = "schtasks /query /tn `"$SHUTDOWN_TASK_NAME`" /xml"
    $xmlContent = & cmd /c $exportCmd

    # Step 3: Add description to XML
    [xml]$xmlDoc = $xmlContent
    
    # Create Description element if it doesn't exist
    $registrationInfo = $xmlDoc.Task.RegistrationInfo
    if (!$registrationInfo) {
        $registrationInfo = $xmlDoc.CreateElement("RegistrationInfo", $xmlDoc.DocumentElement.NamespaceURI)
        $xmlDoc.Task.PrependChild($registrationInfo) | Out-Null
    }
    
    # Remove existing description if present
    $existingDesc = $registrationInfo.SelectSingleNode("*[local-name()='Description']")
    if ($existingDesc) { $registrationInfo.RemoveChild($existingDesc) | Out-Null }
    
    # Add new description
    $descElement = $xmlDoc.CreateElement("Description", $xmlDoc.DocumentElement.NamespaceURI)
    $descElement.InnerText = "Sends ntfy Windows Shutdown Notification with offline queue support and centralized configuration"
    $registrationInfo.AppendChild($descElement) | Out-Null

    # Step 4: Save modified XML
    $xmlDoc.Save($tempXmlPath)

    # Step 5: Delete existing task and recreate from XML
    Unregister-ScheduledTask -TaskName $SHUTDOWN_TASK_NAME -Confirm:$false
    
    $importCmd = "schtasks /create /xml `"$tempXmlPath`" /tn `"$SHUTDOWN_TASK_NAME`" /ru SYSTEM"
    $importResult = & cmd /c $importCmd 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR importing task with description: $importResult" -ForegroundColor Red
        throw "XML import failed"
    }

    # Step 6: Apply additional settings
    $settingsShutdown = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    Set-ScheduledTask -TaskName $SHUTDOWN_TASK_NAME -Settings $settingsShutdown | Out-Null

    # Cleanup
    Remove-Item $tempXmlPath -ErrorAction SilentlyContinue
        
    Write-Host "  ntfy Windows Shutdown Notification task created successfully with description" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR creating ntfy Windows Shutdown Notification task: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# [3/3] CREATE QUEUE PROCESSOR SERVICE TASK
# =============================================================================
Write-Host "[3/3] Creating ntfy Queue Processor Service task..." -ForegroundColor Cyan
try {
    $queueAction  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$queueScriptPath`""
    $queueTrigger = New-ScheduledTaskTrigger -Daily -At 12:00AM
    $queueTrigger.Repetition = (New-ScheduledTaskTrigger -Once -At 12:00AM -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 1)).Repetition

    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask -TaskName $QUEUE_TASK_NAME -Action $queueAction -Trigger $queueTrigger -Principal $principal -Settings $settings `
        -Description "Processes queued ntfy Windows Notifications when network connectivity is restored, runs every 10 minutes with offline queue support and centralized configuration" | Out-Null
    Write-Host "  ntfy Queue Processor Service task created successfully" -ForegroundColor Green
} catch {
    Write-Host "  ERROR creating ntfy queue processor service task: $($_.Exception.Message)" -ForegroundColor Red
}

# Wrap-up
Write-Host ""
Write-Host "Task creation completed!" -ForegroundColor Green
Write-Host ""

List-ExistingTasks

Write-Host "Setup Summary:" -ForegroundColor Cyan
Write-Host "- ntfy Windows Boot Notifications: Trigger on system startup" -ForegroundColor Gray
Write-Host "- ntfy Windows Shutdown Notifications: Trigger on Event ID 1074 (User32)" -ForegroundColor Gray
Write-Host "- ntfy Queue processor Service: Runs every 10 minutes to process offline ntfy Windows Notifications" -ForegroundColor Gray
Write-Host "- All tasks run as SYSTEM account with highest privileges" -ForegroundColor Gray
Write-Host "- AC power requirement: Disabled" -ForegroundColor Gray
Write-Host "- Allowed to be run on demand" -ForegroundColor Gray
Write-Host "- Run as soon as possible after a scheduled start is missed" -ForegroundColor Gray
Write-Host "- Restart on failure: 3 attempts, 1-minute intervals" -ForegroundColor Gray
Write-Host "- Execution time limit: 1 hour" -ForegroundColor Gray
Write-Host "- Can be forced to stop if the task does not end when requested" -ForegroundColor Gray
Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  Remove all tasks: .\ntfy-Windows-Notifications-Setup-Services.ps1 -RemoveExisting" -ForegroundColor Gray
Write-Host "  List task status: .\ntfy-Windows-Notifications-Setup-Services.ps1 -ListTasks" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test ntfy Windows Boot Notification: Restart your computer" -ForegroundColor Gray
Write-Host "2. Test ntfy Windows Shutdown Notification: Shutdown your computer" -ForegroundColor Gray
Write-Host "3. Test ntfy Queue Processor Service: Run task manually or wait 10 minutes" -ForegroundColor Gray
