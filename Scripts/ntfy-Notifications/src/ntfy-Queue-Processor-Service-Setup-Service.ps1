# ntfy Queue Processor Service - Task Scheduler Service Setup
# Run this script as Administrator to create all three scheduled tasks
# Requires: ntfy-Windows-Notifications-Config.json in the same directory

param(
    [switch]$RemoveExisting,
    [switch]$ListTasks
)

# =============================================================================
# CONFIGURATION
# =============================================================================
$SCRIPT_DIR   = $PSScriptRoot
$CONFIG_FILE  = "ntfy-Windows-Notifications-Config.json"

# Task name
$QUEUE_TASK_NAME    = "ntfy Queue Processor Service"

# Script path (relative to this setup script)
$QUEUE_SCRIPT     = "ntfy-Queue-Processor-Service.ps1"

Write-Host "ntfy Queue Processor Service - Service Setup" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Verify configuration file exists
$configPath = Join-Path $SCRIPT_DIR $CONFIG_FILE
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Configuration file not found: $configPath" -ForegroundColor Red
    Write-Host "Please ensure $CONFIG_FILE is in the same directory as this script" -ForegroundColor Yellow
    exit 1
}

# Verify script file exist
$queueScriptPath    = Join-Path $SCRIPT_DIR $QUEUE_SCRIPT

if (-not (Test-Path $queueScriptPath)) {
     Write-Host "ERROR: Script file not found: $queueScriptPath" -ForegroundColor Red
     exit 1
}

Write-Host "Configuration verified successfully" -ForegroundColor Green
Write-Host "Script directory: $SCRIPT_DIR" -ForegroundColor Gray
Write-Host ""

# Functions
function Remove-ExistingTasks {
    Write-Host "Removing existing tasks..." -ForegroundColor Yellow
    $tasks = @($QUEUE_TASK_NAME)
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
    $tasks = @($QUEUE_TASK_NAME)
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
# [1/1] CREATE QUEUE PROCESSOR SERVICE TASK
# =============================================================================
Write-Host "[1/1] Creating ntfy Queue Processor Service task..." -ForegroundColor Cyan
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
Write-Host "- ntfy Queue processor Service: Runs every 10 minutes to process offline ntfy Windows Notifications" -ForegroundColor Gray
Write-Host "- Task run as SYSTEM account with highest privileges" -ForegroundColor Gray
Write-Host "- AC power requirement: Disabled" -ForegroundColor Gray
Write-Host "- Allowed to be run on demand" -ForegroundColor Gray
Write-Host "- Run as soon as possibe after a scheduled start is missed" -ForegroundColor Gray
Write-Host "- Restart on failure: 3 attempts, 1-minute intervals" -ForegroundColor Gray
Write-Host "- Execution time limit: 1 hour" -ForegroundColor Gray
Write-Host "- Can be forced to stop if the task does not end when requested" -ForegroundColor Gray
Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  Remove all tasks: .\ntfy-Queue-Processor-Service-Setup-Service.ps1 -RemoveExisting" -ForegroundColor Gray
Write-Host "  List task status: .\ntfy-Queue-Processor-Service-Setup-Service.ps1 -ListTasks" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step:" -ForegroundColor Yellow
Write-Host "Test ntfy Queue Processor Service: Run task manually or wait 10 minutes" -ForegroundColor Gray
