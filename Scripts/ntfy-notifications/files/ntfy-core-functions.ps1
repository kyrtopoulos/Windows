# ntfy Windows Notifications - Core Functions Script
# Handles both Startup and Shutdown notifications with offline queue support
# Usage: ntfy-core-functions.ps1 -Action "Startup|Shutdown|ProcessQueue"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Startup", "Shutdown", "ProcessQueue")]
    [string]$Action
)

# =============================================================================
# GLOBAL VARIABLES AND INITIALIZATION
# =============================================================================

# Get script directory (works in all execution contexts)
$SCRIPT_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent
if (-not $SCRIPT_DIR) { $SCRIPT_DIR = $PSScriptRoot }
if (-not $SCRIPT_DIR) { $SCRIPT_DIR = (Get-Location).Path }

# Configuration and file paths
$CONFIG_FILE = Join-Path $SCRIPT_DIR "ntfy-notifications-config.ini"
$computerName = $env:COMPUTERNAME

# Global configuration object
$config = $null

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

function Read-IniFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        throw "Configuration file not found: $FilePath"
    }
    
    $ini = @{}
    $section = $null
    
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -eq "" -or $line.StartsWith("#") -or $line.StartsWith(";")) {
            return
        }
        
        # Section header
        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1]
            $ini[$section] = @{}
            return
        }
        
        # Key-value pair
        if ($line -match '^([^=]+)=(.*)$' -and $section) {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $ini[$section][$key] = $value
        }
    }
    
    return $ini
}

function Initialize-Configuration {
    try {
        Write-Log "Loading configuration from: $CONFIG_FILE"
        $configData = Read-IniFile -FilePath $CONFIG_FILE
        
        # Create configuration object with computed paths
        $script:config = @{
            LocalServer = $configData.Server.LocalServer
            RemoteServer = $configData.Server.RemoteServer
            Topic = $configData.Server.Topic
            Username = $configData.Server.Username
            Password = $configData.Server.Password
            
            NetworkTestTimeout = [int]$configData.Timeouts.NetworkTest
            StartupTimeout = [int]$configData.Timeouts.Startup
            ShutdownTimeout = [int]$configData.Timeouts.Shutdown
            QueueProcessorTimeout = [int]$configData.Timeouts.QueueProcessor
            
            LoggingEnabled = [bool]($configData.Settings.LoggingEnabled -eq "true")
            QueueProcessorInterval = [int]$configData.Settings.QueueProcessorInterval
            MaxRetries = [int]$configData.Settings.MaxRetries
            RetryIntervalMinutes = [int]$configData.Settings.RetryIntervalMinutes
            
            # Logging configuration
            MaxLogSizeMB = if ($configData.Logging.MaxLogSizeMB) { [int]$configData.Logging.MaxLogSizeMB } else { 10 }
            MaxLogFiles = if ($configData.Logging.MaxLogFiles) { [int]$configData.Logging.MaxLogFiles } else { 5 }
            EnableLogRotation = if ($configData.Logging.EnableLogRotation) { [bool]($configData.Logging.EnableLogRotation -eq "true") } else { $true }
            
            # Computed paths for separate log files
            StartupLogPath = Join-Path $SCRIPT_DIR $configData.Logging.StartupLogFile
            ShutdownLogPath = Join-Path $SCRIPT_DIR $configData.Logging.ShutdownLogFile
            QueueLogPath = Join-Path $SCRIPT_DIR $configData.Logging.QueueLogFile
            WrapperLogPath = Join-Path $SCRIPT_DIR $configData.Logging.WrapperLogFile
            QueuePath = Join-Path $SCRIPT_DIR $configData.Paths.QueueFile
        }
        
        Write-Log "Configuration loaded successfully"
        return $true
    }
    catch {
        Write-Host "ERROR: Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# =============================================================================
# LOGGING FUNCTIONS WITH ROTATION SUPPORT
# =============================================================================

function Get-LogPath {
    switch ($Action) {
        "Startup" { return $config.StartupLogPath }
        "Shutdown" { return $config.ShutdownLogPath }
        "ProcessQueue" { return $config.QueueLogPath }
        default { return $config.StartupLogPath }
    }
}

function Rotate-LogFile {
    param([string]$LogPath)
    
    if (-not (Test-Path $LogPath) -or -not $config.EnableLogRotation) {
        return
    }
    
    try {
        $logFile = Get-Item $LogPath
        $logSizeMB = [math]::Round($logFile.Length / 1MB, 2)
        
        if ($logSizeMB -gt $config.MaxLogSizeMB) {
            Write-Host "Rotating log file: $LogPath (Size: $logSizeMB MB)"
            
            $logDir = Split-Path $LogPath -Parent
            $logName = [System.IO.Path]::GetFileNameWithoutExtension($LogPath)
            $logExt = [System.IO.Path]::GetExtension($LogPath)
            
            # Rotate existing backup files
            for ($i = $config.MaxLogFiles - 1; $i -ge 1; $i--) {
                $oldFile = Join-Path $logDir "$logName.$i$logExt"
                $newFile = Join-Path $logDir "$logName.$($i + 1)$logExt"
                
                if (Test-Path $oldFile) {
                    if (Test-Path $newFile) {
                        Remove-Item $newFile -Force
                    }
                    Move-Item $oldFile $newFile -Force
                }
            }
            
            # Move current log to .1
            $backupFile = Join-Path $logDir "$logName.1$logExt"
            if (Test-Path $backupFile) {
                Remove-Item $backupFile -Force
            }
            Move-Item $LogPath $backupFile -Force
            
            Write-Host "Log rotation completed. Backup saved as: $backupFile"
        }
    }
    catch {
        Write-Host "Warning: Log rotation failed: $($_.Exception.Message)"
    }
}

function Write-Log {
    param([string]$Message)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Action] $Message"
    
    # Always write to console for debugging
    Write-Host $logEntry
    
    # Write to appropriate log file if logging enabled and config loaded
    if ($config -and $config.LoggingEnabled) {
        try {
            $logPath = Get-LogPath
            
            # Rotate log if needed before writing
            Rotate-LogFile -LogPath $logPath
            
            Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silent fail for logging to prevent script termination
        }
    }
}

# =============================================================================
# NETWORK AND SERVER FUNCTIONS
# =============================================================================

function Test-NtfyServer {
    param([string]$ServerUrl, [int]$TimeoutSeconds = 5)
    
    try {
        Write-Log "Testing server connectivity: $ServerUrl"
        $response = Invoke-WebRequest -Uri $ServerUrl -Method GET -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        Write-Log "Server $ServerUrl is reachable"
        return $true
    }
    catch {
        Write-Log "Server $ServerUrl not reachable: $($_.Exception.Message)"
        return $false
    }
}

function Send-NtfyNotification {
    param(
        [string]$ServerUrl,
        [string]$Title,
        [string]$Message,
        [int]$Priority = 4,
        [string]$Tags = "windows",
        [int]$TimeoutSeconds = 15
    )
    
    try {
        $headers = @{
            'Title' = $Title
            'Priority' = $Priority.ToString()
            'Tags' = $Tags
        }
        
        # Add authentication if configured
        if ($config.Username -and $config.Password) {
            $authString = "$($config.Username):$($config.Password)"
            $encodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($authString))
            $headers['Authorization'] = "Basic $encodedAuth"
        }
        
        $fullUrl = "$ServerUrl/$($config.Topic)"
        Write-Log "Sending notification to: $fullUrl"
        
        $response = Invoke-RestMethod -Uri $fullUrl -Method Post -Body $Message -Headers $headers -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        Write-Log "Notification sent successfully to $ServerUrl"
        return $true
    }
    catch {
        Write-Log "Failed to send notification to $ServerUrl : $($_.Exception.Message)"
        return $false
    }
}

function Get-AvailableServer {
    Write-Log "Determining available ntfy server..."
    
    if (Test-NtfyServer -ServerUrl $config.LocalServer -TimeoutSeconds $config.NetworkTestTimeout) {
        Write-Log "Using local server: $($config.LocalServer)"
        return $config.LocalServer
    }
    elseif (Test-NtfyServer -ServerUrl $config.RemoteServer -TimeoutSeconds $config.NetworkTestTimeout) {
        Write-Log "Using remote server: $($config.RemoteServer)"
        return $config.RemoteServer
    }
    else {
        Write-Log "No servers available"
        return $null
    }
}

# =============================================================================
# QUEUE MANAGEMENT FUNCTIONS
# =============================================================================

function Save-NotificationToQueue {
    param(
        [string]$Title,
        [string]$Message,
        [int]$Priority = 4,
        [string]$Tags = "windows",
        [datetime]$OriginalTimestamp = (Get-Date),
        [string]$Type = "Unknown"
    )
    
    try {
        Write-Log "Saving notification to offline queue..."
        
        # Load existing queue
        $queue = @()
        if (Test-Path $config.QueuePath) {
            $queueContent = Get-Content $config.QueuePath -Raw -ErrorAction SilentlyContinue
            if ($queueContent) {
                $existingQueue = $queueContent | ConvertFrom-Json
                # Ensure array format
                if ($existingQueue -is [array]) {
                    $queue = @($existingQueue)
                } elseif ($existingQueue) {
                    $queue = @($existingQueue)
                }
            }
        }
        
        # Create notification object
        $notification = @{
            Title = $Title
            Message = $Message
            Priority = $Priority
            Tags = $Tags
            OriginalTimestamp = $OriginalTimestamp.ToString("yyyy-MM-dd HH:mm:ss")
            QueuedTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Type = $Type
        }
        
        # Add to queue
        $queue = [System.Collections.ArrayList]@($queue)
        $queue.Add($notification) | Out-Null
        
        # Save queue
        $queueArray = @($queue)
        $queueArray | ConvertTo-Json -Depth 10 | Set-Content $config.QueuePath -Encoding UTF8
        
        Write-Log "Notification queued successfully (Original time: $($OriginalTimestamp.ToString('yyyy-MM-dd HH:mm:ss')))"
        return $true
    }
    catch {
        Write-Log "Failed to queue notification: $($_.Exception.Message)"
        return $false
    }
}

function Process-QueuedNotifications {
    param([string]$ServerUrl)
    
    try {
        if (-not (Test-Path $config.QueuePath)) {
            Write-Log "No queue file found"
            return @{ ProcessedCount = 0; FailedCount = 0 }
        }
        
        $queueContent = Get-Content $config.QueuePath -Raw -ErrorAction SilentlyContinue
        if (-not $queueContent) {
            Write-Log "Queue file is empty"
            return @{ ProcessedCount = 0; FailedCount = 0 }
        }
        
        $queue = $queueContent | ConvertFrom-Json
        if (-not $queue -or $queue.Count -eq 0) {
            Write-Log "No notifications in queue"
            return @{ ProcessedCount = 0; FailedCount = 0 }
        }
        
        Write-Log "Processing $($queue.Count) queued notifications..."
        $processedNotifications = @()
        $failedNotifications = @()
        
        foreach ($notification in $queue) {
            # Create enhanced message with original timestamp
            $enhancedMessage = @"
[QUEUED NOTIFICATION - Original Time: $($notification.OriginalTimestamp)]

$($notification.Message)

Notification Details:
- Original Event: $($notification.OriginalTimestamp)
- Queued Time: $($notification.QueuedTimestamp)
- Delivered Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Event Type: $($notification.Type)

Note: This notification was queued due to connectivity issues and is now being delivered.

Notification sent via: $ServerUrl
"@
            
            $success = Send-NtfyNotification -ServerUrl $ServerUrl -Title $notification.Title -Message $enhancedMessage -Priority $notification.Priority -Tags "$($notification.Tags),queued" -TimeoutSeconds $config.QueueProcessorTimeout
            
            if ($success) {
                $processedNotifications += $notification
                Write-Log "Successfully delivered queued $($notification.Type) notification from $($notification.OriginalTimestamp)"
            } else {
                $failedNotifications += $notification
                Write-Log "Failed to deliver queued $($notification.Type) notification from $($notification.OriginalTimestamp)"
            }
            
            # Small delay between notifications
            Start-Sleep -Milliseconds 500
        }
        
        # Update queue with only failed notifications
        if ($failedNotifications.Count -eq 0) {
            # All sent successfully, remove queue file
            Remove-Item $config.QueuePath -Force -ErrorAction SilentlyContinue
            Write-Log "All queued notifications delivered successfully. Queue cleared."
            
            # Send summary if multiple items processed
            if ($processedNotifications.Count -gt 1) {
                $summaryMessage = "Successfully delivered $($processedNotifications.Count) queued notifications that were stored while the system was offline.`n`nNotification sent via: $ServerUrl"
                Send-NtfyNotification -ServerUrl $ServerUrl -Title "Queued Notifications Delivered" -Message $summaryMessage -Priority 4 -Tags "windows,queued,summary,loudspeaker" -TimeoutSeconds $config.QueueProcessorTimeout
            }
        } else {
            # Keep failed notifications for retry
            $failedNotifications | ConvertTo-Json -Depth 10 | Set-Content $config.QueuePath -Encoding UTF8
            Write-Log "$($failedNotifications.Count) notifications failed to send. Kept in queue for retry."
        }
        
        return @{
            ProcessedCount = $processedNotifications.Count
            FailedCount = $failedNotifications.Count
        }
    }
    catch {
        Write-Log "Error processing queued notifications: $($_.Exception.Message)"
        return @{ ProcessedCount = 0; FailedCount = -1 }
    }
}

# =============================================================================
# FAST STARTUP DETECTION AND STARTUP TYPE ANALYSIS
# =============================================================================

function Get-StartupType {
    try {
        Write-Log "Analyzing startup type and Fast Startup status..."
        
        # Check if Fast Startup is enabled
        $fastStartupEnabled = $false
        try {
            $hibernateEnabled = (powercfg /a) -match "Hibernate"
            $fastStartupReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
            if ($fastStartupReg -and $fastStartupReg.HiberbootEnabled -eq 1 -and $hibernateEnabled) {
                $fastStartupEnabled = $true
            }
        }
        catch {
            Write-Log "Could not determine Fast Startup status: $($_.Exception.Message)"
        }
        
        # Analyze startup type using multiple methods
        $startupType = "Unknown"
        $isRealStartup = $false
        $isFastStartup = $false
        
        # Method 1: Check system uptime vs last startup time
        try {
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $systemUptime = (Get-Date) - $osInfo.LastBootUpTime
            $uptimeSeconds = [math]::Round($systemUptime.TotalSeconds, 0)
            
            Write-Log "System uptime: $($systemUptime.ToString('hh\:mm\:ss')) ($uptimeSeconds seconds)"
            Write-Log "Last startup time: $($osInfo.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))"
            
            # If we're running very soon after "startup time", it might be a real startup
            if ($uptimeSeconds -lt 300) { # Less than 5 minutes uptime
                $isRealStartup = $true
                $startupType = "ColdStartup"
            } else {
                $startupType = "FastStartup"
                $isFastStartup = $true
            }
        }
        catch {
            Write-Log "Could not determine startup time: $($_.Exception.Message)"
        }
        
        # Method 2: Check for hibernation file activity
        try {
            $hiberfil = "C:\hiberfil.sys"
            if (Test-Path $hiberfil) {
                $hiberfilInfo = Get-Item $hiberfil -Force
                $hiberfileAge = (Get-Date) - $hiberfilInfo.LastWriteTime
                
                Write-Log "Hibernation file last modified: $($hiberfilInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
                Write-Log "Hibernation file age: $($hiberfileAge.TotalMinutes.ToString('0.0')) minutes"
                
                # If hibernation file was recently modified, likely Fast Startup
                if ($hiberfileAge.TotalMinutes -lt 10) {
                    $isFastStartup = $true
                    $startupType = "FastStartup"
                }
            }
        }
        catch {
            Write-Log "Could not check hibernation file: $($_.Exception.Message)"
        }
        
        # Method 3: Check Event Log for shutdown events
        try {
            $lastShutdownEvent = Get-WinEvent -FilterHashtable @{LogName='System'; ID=1074} -MaxEvents 1 -ErrorAction SilentlyContinue
            $lastStartupEvent = Get-WinEvent -FilterHashtable @{LogName='System'; ID=6005} -MaxEvents 1 -ErrorAction SilentlyContinue
            
            if ($lastShutdownEvent -and $lastStartupEvent) {
                $timeDiff = $lastStartupEvent.TimeCreated - $lastShutdownEvent.TimeCreated
                Write-Log "Time between last shutdown and startup: $($timeDiff.TotalMinutes.ToString('0.0')) minutes"
                
                # If startup happened very quickly after shutdown, likely Fast Startup
                if ($timeDiff.TotalMinutes -lt 2 -and $timeDiff.TotalMinutes -gt 0) {
                    $isFastStartup = $true
                    $startupType = "FastStartup"
                } else {
                    $isRealStartup = $true
                    $startupType = "ColdStartup"
                }
            }
        }
        catch {
            Write-Log "Could not analyze event logs: $($_.Exception.Message)"
        }
        
        Write-Log "Startup analysis complete:"
        Write-Log "  Fast Startup Enabled: $fastStartupEnabled"
        Write-Log "  Detected Startup Type: $startupType"
        Write-Log "  Is Real Startup: $isRealStartup"
        Write-Log "  Is Fast Startup: $isFastStartup"
        
        return @{
            FastStartupEnabled = $fastStartupEnabled
            StartupType = $startupType
            IsRealStartup = $isRealStartup
            IsFastStartup = $isFastStartup
        }
    }
    catch {
        Write-Log "Error in startup type analysis: $($_.Exception.Message)"
        return @{
            FastStartupEnabled = $false
            StartupType = "Unknown"
            IsRealStartup = $true
            IsFastStartup = $false
        }
    }
}

function Get-ShutdownType {
    try {
        Write-Log "Analyzing shutdown type..."
        
        # Check if this is a real shutdown or Fast Startup hibernation
        $shutdownType = "Unknown"
        $isRealShutdown = $true
        
        # Check if Fast Startup is enabled
        try {
            $fastStartupReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
            if ($fastStartupReg -and $fastStartupReg.HiberbootEnabled -eq 1) {
                $shutdownType = "FastStartupHibernation"
                $isRealShutdown = $false
                Write-Log "Fast Startup is enabled - this is hibernation, not true shutdown"
            } else {
                $shutdownType = "TrueShutdown"
                Write-Log "Fast Startup is disabled - this is a true shutdown"
            }
        }
        catch {
            Write-Log "Could not determine Fast Startup status, assuming true shutdown"
            $shutdownType = "TrueShutdown"
        }
        
        return @{
            ShutdownType = $shutdownType
            IsRealShutdown = $isRealShutdown
        }
    }
    catch {
        Write-Log "Error in shutdown type analysis: $($_.Exception.Message)"
        return @{
            ShutdownType = "Unknown"
            IsRealShutdown = $true
        }
    }
}

# =============================================================================
# SYSTEM INFORMATION GATHERING
# =============================================================================

function Get-SystemInformation {
    param([string]$EventType)
    
    try {
        Write-Log "Gathering system information for $EventType event..."
        
        $timestamp = Get-Date
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        
        # Get network adapters with IP addresses (only for startup events)
        $networkDetails = "Not applicable"
        if ($EventType -eq "Startup") {
            $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { 
                $_.IPEnabled -eq $true -and $_.IPAddress -ne $null 
            }
            
            $networkInfo = @()
            foreach ($adapter in $networkAdapters) {
                if ($adapter.Description) {
                    $adapterName = $adapter.Description -replace "Microsoft ", "" -replace " Adapter", ""
                    foreach ($ip in $adapter.IPAddress) {
                        if ($ip -match "^\d+\.\d+\.\d+\.\d+$") {  # IPv4 only
                            $networkInfo += "$adapterName : $ip"
                        }
                    }
                }
            }
            
            $networkDetails = if ($networkInfo.Count -gt 0) { 
                $networkInfo -join "`n" 
            } else { 
                "No active network adapters detected" 
            }
        }
        
        # Calculate uptime for shutdown events
        $uptime = $null
        if ($EventType -eq "Shutdown" -and $osInfo.LastBootUpTime) {
            $startupTime = $osInfo.LastBootUpTime
            $uptime = $timestamp - $startupTime
        }
        
        $systemInfo = @{
            Timestamp = $timestamp
            ComputerName = $computerName
            OSCaption = if ($osInfo.Caption) { $osInfo.Caption } else { "Windows" }
            OSVersion = if ($osInfo.Version) { $osInfo.Version } else { "Unknown" }
            NetworkDetails = $networkDetails
            StartupTime = if ($osInfo.LastBootUpTime) { $osInfo.LastBootUpTime } else { $timestamp }
            Uptime = $uptime
        }
        
        Write-Log "System information gathered successfully"
        return $systemInfo
    }
    catch {
        Write-Log "Error gathering system information: $($_.Exception.Message)"
        # Return minimal information
        return @{
            Timestamp = Get-Date
            ComputerName = $computerName
            OSCaption = "Windows"
            OSVersion = "Unknown"
            NetworkDetails = "Information unavailable"
            StartupTime = Get-Date
            Uptime = $null
        }
    }
}

# =============================================================================
# NOTIFICATION HANDLERS
# =============================================================================

function Send-StartupNotification {
    Write-Log "Processing startup notification..."
    
    # Analyze startup type first
    $startupAnalysis = Get-StartupType
    
    # Always send notification but include startup type information
    Write-Log "Startup type: $($startupAnalysis.StartupType)"
    
    # Wait for system to stabilize (shorter wait for Fast Startup)
    if ($startupAnalysis.IsFastStartup) {
        Write-Log "Fast Startup detected - shorter stabilization wait"
        Start-Sleep -Seconds 5
    } else {
        Write-Log "Real startup detected - longer stabilization wait"
        Start-Sleep -Seconds 10
    }
    
    $systemInfo = Get-SystemInformation -EventType "Startup"
    
    # Create startup notification message with startup type information
    $startupTypeText = if ($startupAnalysis.IsFastStartup) { 
        "Fast Startup (Resume from Hibernation)" 
    } elseif ($startupAnalysis.IsRealStartup) { 
        "Cold Startup (True Startup)" 
    } else { 
        "Startup (Type: $($startupAnalysis.StartupType))" 
    }
    
    $title = "$($systemInfo.ComputerName) Started"
    $message = @"
Computer: $($systemInfo.ComputerName)
OS: $($systemInfo.OSCaption) $($systemInfo.OSVersion)
Startup Time: $($systemInfo.StartupTime.ToString("yyyy-MM-dd HH:mm:ss"))
Startup Type: $startupTypeText
Fast Startup Enabled: $($startupAnalysis.FastStartupEnabled)
Network Adapters:
$($systemInfo.NetworkDetails)

System is now operational and ready for use.
"@
    
    # Try to send notification
    $server = Get-AvailableServer
    if ($server) {
        $enhancedMessage = $message + "`n`nNotification sent via: $server"
        $tags = if ($startupAnalysis.IsFastStartup) { "windows,startup,fastboot,rocket" } else { "windows,startup,coldboot,rocket" }
        $success = Send-NtfyNotification -ServerUrl $server -Title $title -Message $enhancedMessage -Priority 4 -Tags $tags -TimeoutSeconds $config.StartupTimeout
        
        if ($success) {
            Write-Log "Startup notification sent successfully"
        } else {
            Write-Log "Startup notification failed to send"
            $queueTags = if ($startupAnalysis.IsFastStartup) { "windows,startup,fastboot,loudspeaker" } else { "windows,startup,coldboot,loudspeaker" }
            Save-NotificationToQueue -Title $title -Message $message -Priority 4 -Tags $queueTags -OriginalTimestamp $systemInfo.Timestamp -Type "Startup-$($startupAnalysis.StartupType)"
        }
    } else {
        Write-Log "No servers available, queuing startup notification"
        $queueTags = if ($startupAnalysis.IsFastStartup) { "windows,startup,fastboot,loudspeaker" } else { "windows,startup,coldboot,loudspeaker" }
        Save-NotificationToQueue -Title $title -Message $message -Priority 4 -Tags $queueTags -OriginalTimestamp $systemInfo.Timestamp -Type "Startup-$($startupAnalysis.StartupType)"
    }
}

function Send-ShutdownNotification {
    Write-Log "Processing shutdown notification..."
    
    # Analyze shutdown type
    $shutdownAnalysis = Get-ShutdownType
    Write-Log "Shutdown type: $($shutdownAnalysis.ShutdownType)"
    
    $systemInfo = Get-SystemInformation -EventType "Shutdown"
    
    # Format uptime string
    $uptimeString = "Unknown"
    if ($systemInfo.Uptime) {
        $uptime = $systemInfo.Uptime
        if ($uptime.Days -gt 0) { 
            $uptimeString = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" 
        } else { 
            $uptimeString = "$($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" 
        }
    }
    
    # Get shutdown reason
    $shutdownReason = "System shutdown"
    try {
        $lastShutdownEvent = Get-WinEvent -FilterHashtable @{LogName='System'; ID=1074} -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($lastShutdownEvent -and $lastShutdownEvent.TimeCreated -gt (Get-Date).AddMinutes(-2)) {
            $eventMessage = $lastShutdownEvent.Message
            if ($eventMessage -match "Reason.*?:\s*(.*?)[\r\n]") {
                $shutdownReason = $matches[1].Trim()
            }
        }
    }
    catch {
        Write-Log "Could not determine shutdown reason"
    }
    
    # Create shutdown notification message with shutdown type information
    $shutdownTypeText = if ($shutdownAnalysis.IsRealShutdown) { 
        "True Shutdown" 
    } else { 
        "Fast Startup (Hibernation)" 
    }
    
    $title = "$($systemInfo.ComputerName) Shutting Down"
    $message = @"
Computer: $($systemInfo.ComputerName)
OS: $($systemInfo.OSCaption) $($systemInfo.OSVersion)
Shutdown Time: $($systemInfo.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"))
Shutdown Type: $shutdownTypeText
Uptime: $uptimeString
Reason: $shutdownReason

System is powering down...
"@
    
    # Try to send notification (with shorter timeout for shutdown)
    $server = Get-AvailableServer
    if ($server) {
        $enhancedMessage = $message + "`n`nNotification sent via: $server"
        $tags = if ($shutdownAnalysis.IsRealShutdown) { "windows,shutdown,trueshutdown,wave" } else { "windows,shutdown,fastshutdown,wave" }
        $success = Send-NtfyNotification -ServerUrl $server -Title $title -Message $enhancedMessage -Priority 4 -Tags $tags -TimeoutSeconds $config.ShutdownTimeout
        
        if ($success) {
            Write-Log "Shutdown notification sent successfully"
        } else {
            Write-Log "Shutdown notification failed to send"
            $queueTags = if ($shutdownAnalysis.IsRealShutdown) { "windows,shutdown,trueshutdown,loudspeaker" } else { "windows,shutdown,fastshutdown,loudspeaker" }
            Save-NotificationToQueue -Title $title -Message $message -Priority 4 -Tags $queueTags -OriginalTimestamp $systemInfo.Timestamp -Type "Shutdown-$($shutdownAnalysis.ShutdownType)"
        }
    } else {
        Write-Log "No servers available, queuing shutdown notification"
        $queueTags = if ($shutdownAnalysis.IsRealShutdown) { "windows,shutdown,trueshutdown,loudspeaker" } else { "windows,shutdown,fastshutdown,loudspeaker" }
        Save-NotificationToQueue -Title $title -Message $message -Priority 4 -Tags $queueTags -OriginalTimestamp $systemInfo.Timestamp -Type "Shutdown-$($shutdownAnalysis.ShutdownType)"
    }
    
    # Give extra time for file operations during shutdown
    Start-Sleep -Seconds 2
}

function Process-Queue {
    Write-Log "Processing notification queue..."
    
    $server = Get-AvailableServer
    if (-not $server) {
        Write-Log "No servers available for queue processing"
        return
    }
    
    $result = Process-QueuedNotifications -ServerUrl $server
    
    if ($result.ProcessedCount -gt 0) {
        Write-Log "Queue processing completed. Processed: $($result.ProcessedCount), Failed: $($result.FailedCount)"
    } else {
        Write-Log "No notifications were processed this run"
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

function Main {
    Write-Log "Starting ntfy Windows Notifications - Action: $Action"
    Write-Log "Script directory: $SCRIPT_DIR"
    Write-Log "Computer: $computerName"
    
    # Initialize configuration
    if (-not (Initialize-Configuration)) {
        Write-Log "Failed to initialize configuration. Exiting."
        exit 1
    }
    
    # Execute requested action
    switch ($Action) {
        "Startup" {
            Send-StartupNotification
        }
        "Shutdown" {
            Send-ShutdownNotification
        }
        "ProcessQueue" {
            Process-Queue
        }
        default {
            Write-Log "Unknown action: $Action"
            exit 1
        }
    }
    
    Write-Log "ntfy Windows Notifications completed successfully"
}

# Run main function
Main
