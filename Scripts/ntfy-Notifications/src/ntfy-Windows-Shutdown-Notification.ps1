# ntfy Windows Shutdown Notification Script (Enhanced with Offline Queue & Encrypted Credentials)
# Runs on system shutdown event, queues ntfy Windows Shutdown Notifications when offline

# =============================================================================
# CENTRALIZED CONFIGURATION - UPDATE CONFIG FILE TO CHANGE ALL SETTINGS
# =============================================================================
try {
    $configPath = Join-Path $PSScriptRoot "ntfy-Windows-Notifications-Config.json"
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }
    $config = Get-Content $configPath | ConvertFrom-Json
    
    # Load configuration values
    $SCRIPT_BASE_PATH = $config.BasePath
    $localNtfyServer = $config.LocalServer
    $remoteNtfyServer = $config.RemoteServer
    $ntfyTopic = $config.Topic
    $networkTimeout = $config.NetworkTimeoutSeconds.Shutdown
}
catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}
# =============================================================================

# System variables
$computerName = $env:COMPUTERNAME

# Centralized file paths - all derived from $SCRIPT_BASE_PATH
$logPath = Join-Path $SCRIPT_BASE_PATH "ntfy-Windows-Shutdown-Notifications.log"
$queuePath = Join-Path $SCRIPT_BASE_PATH "ntfy-Windows-Notification-Queue.json"
$SecurePasswordPath = Join-Path $SCRIPT_BASE_PATH "ntfy-Password.enc"
$SecureUserPath = Join-Path $SCRIPT_BASE_PATH "ntfy-User.enc"
$KeyPath = Join-Path $SCRIPT_BASE_PATH "ntfy.key"

# Function to decrypt credentials
function Get-DecryptedCredentials {
    try {
        if ((Test-Path $KeyPath) -and (Test-Path $SecurePasswordPath) -and (Test-Path $SecureUserPath)) {
            # Read the encryption key
            $Key = [System.IO.File]::ReadAllBytes($KeyPath)
            
            # Decrypt username
            $EncryptedUser = Get-Content $SecureUserPath
            $SecureUser = ConvertTo-SecureString $EncryptedUser -Key $Key
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureUser)
            $PlainUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            
            # Decrypt password
            $EncryptedPassword = Get-Content $SecurePasswordPath
            $SecurePassword = ConvertTo-SecureString $EncryptedPassword -Key $Key
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            
            return @{
                Username = $PlainUser
                Password = $PlainPassword
            }
        } else {
            Write-Log "Encrypted credential files not found. Please run credential setup script first."
            return $null
        }
    }
    catch {
        Write-Log "Failed to decrypt credentials: $($_.Exception.Message)"
        return $null
    }
}

# Function to write log entries
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Ensure directory exists
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path $logPath -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

# Function to save ntfy Windows Shutdown Notification to queue
function Save-NotificationToQueue {
    param(
        [string]$Title,
        [string]$Message,
        [int]$Priority = 4,
        [string]$Tags = "windows,shutdown,loudspeaker",
        [datetime]$OriginalTimestamp = (Get-Date)
    )
    
    try {
        $queueDir = Split-Path $queuePath -Parent
        if (-not (Test-Path $queueDir)) {
            New-Item -ItemType Directory -Path $queueDir -Force | Out-Null
        }
        
        # Load existing queue or create new
        $queue = @()
        if (Test-Path $queuePath) {
            $queueContent = Get-Content $queuePath -Raw -ErrorAction SilentlyContinue
            if ($queueContent) {
                $existingQueue = $queueContent | ConvertFrom-Json
                # Ensure we have an array, not a single object
                if ($existingQueue -is [array]) {
                    $queue = @($existingQueue)
                } elseif ($existingQueue) {
                    $queue = @($existingQueue)
                } else {
                    $queue = @()
                }
            }
        }
        
        # Create ntfy Windows Shutdown Notification object with original timestamp
        $notification = @{
            Title = $Title
            Message = $Message
            Priority = $Priority
            Tags = $Tags
            OriginalTimestamp = $OriginalTimestamp.ToString("yyyy-MM-dd HH:mm:ss")
            QueuedTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Type = "Shutdown"
        }
        
        # Add to queue using array methods
        $queue = [System.Collections.ArrayList]@($queue)
        $queue.Add($notification) | Out-Null
        
        # Save queue back to file
        $queueArray = @($queue)
        $queueArray | ConvertTo-Json -Depth 10 | Set-Content $queuePath -Encoding UTF8
        
        Write-Log "ntfy Windows Shutdown Notification queued offline with original timestamp: $($OriginalTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))"
        return $true
    }
    catch {
        Write-Log "Failed to save ntfy Windows Shutdown Notification to queue: $($_.Exception.Message)"
        return $false
    }
}

# Function to test ntfy server connectivity (faster for shutdown)
function Test-NtfyServer {
    param([string]$ServerUrl)
    
    try {
        $testResponse = Invoke-WebRequest -Uri "$ServerUrl" -Method GET -TimeoutSec $config.NetworkTimeoutSeconds.ServerTest -UseBasicParsing -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "Server $ServerUrl not reachable: $($_.Exception.Message)"
        return $false
    }
}

# Function to send ntfy Windows Shutdown Notification
function Send-NtfyNotification {
    param(
        [string]$ServerUrl,
        [string]$Title,
        [string]$Message,
        [hashtable]$Credentials,
        [int]$Priority = 4,
        [string]$Tags = "windows,shutdown,wave"
    )
    
    try {
        $headers = @{
            'Title' = $Title
            'Priority' = $Priority.ToString()
            'Tags' = $Tags
        }
        
        # Add authentication header with encrypted username and password
        $authString = "$($Credentials.Username):$($Credentials.Password)"
        $encodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($authString))
        $headers['Authorization'] = "Basic $encodedAuth"
        
        # Shorter timeout for shutdown scenario
        $response = Invoke-RestMethod -Uri "$ServerUrl/$ntfyTopic" -Method Post -Body $Message -Headers $headers -TimeoutSec $networkTimeout -ErrorAction Stop
        Write-Log "ntfy Windows Shutdown Notification sent successfully to $ServerUrl"
        return $true
    }
    catch {
        Write-Log "Failed to send ntfy Windows Shutdown Notification to $ServerUrl`: $($_.Exception.Message)"
        return $false
    }
}

# Main execution starts here
Write-Log "Starting ntfy Windows Shutdown Notification process for $computerName"
Write-Log "Using configuration file: $configPath"
Write-Log "Using script base path: $SCRIPT_BASE_PATH"

# Get decrypted credentials
$credentials = Get-DecryptedCredentials
if (-not $credentials) {
    Write-Log "Cannot proceed without credentials. Exiting."
    exit 1
}

# Get system information quickly (important for shutdown timing)
$originalTimestamp = Get-Date
try {
    $shutdownTime = $originalTimestamp
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $bootTime = $osInfo.LastBootUpTime
    $uptime = $shutdownTime - $bootTime
    
    # Get all network adapters with their IP addresses
    $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { 
        $_.IPEnabled -eq $true -and $_.IPAddress -ne $null 
    }
    
    $networkInfo = @()
    foreach ($adapter in $networkAdapters) {
        $adapterName = $adapter.Description -replace "Microsoft ", "" -replace " Adapter", ""
        foreach ($ip in $adapter.IPAddress) {
            if ($ip -match "^\d+\.\d+\.\d+\.\d+$") {  # IPv4 only
                $networkInfo += "$adapterName : $ip"
            }
        }
    }
    
    $networkDetails = if ($networkInfo.Count -gt 0) { 
        $networkInfo -join "`n" 
    } else { 
        "No active network adapters" 
    }
    
    # Get shutdown reason from the most recent shutdown event
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
        Write-Log "Could not determine shutdown reason: $($_.Exception.Message)"
    }
    
    Write-Log "System information gathered successfully"
}
catch {
    Write-Log "Error gathering system information: $($_.Exception.Message)"
    $shutdownTime = Get-Date
    $uptime = New-TimeSpan -Hours 0 -Minutes 0
    $osInfo = @{ Caption = "Windows 11"; Version = "Unknown" }
    $shutdownReason = "System shutdown"
    $networkDetails = "Network information unavailable"
}

# Create ntfy Windows Shutdown Notification message
$title = "$computerName Shutting Down"
$uptimeString = if ($uptime.Days -gt 0) { 
    "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" 
} else { 
    "$($uptime.Hours)h $($uptime.Minutes)m" 
}

$message = @"
Computer: $computerName
OS: $($osInfo.Caption) $($osInfo.Version)
Shutdown Time: $($shutdownTime.ToString("yyyy-MM-dd HH:mm:ss"))
Uptime: $uptimeString
Network Adapters:
$networkDetails
Reason: $shutdownReason

System is powering down...
"@

# Determine which ntfy server to use and send ntfy Windows Shutdown Notification (quick check for shutdown)
$selectedServer = $null
$notificationSent = $false

if (Test-NtfyServer -ServerUrl $localNtfyServer) {
    $selectedServer = $localNtfyServer
    Write-Log "Using local ntfy server: $localNtfyServer"
} elseif (Test-NtfyServer -ServerUrl $remoteNtfyServer) {
    $selectedServer = $remoteNtfyServer
    Write-Log "Local server unavailable, using remote server: $remoteNtfyServer"
}

if ($selectedServer) {
    # Send current ntfy Windows Shutdown Notification
    $enhancedMessage = $message + "`n`nntfy Windows Notification sent via ntfy server $selectedServer"
    $success = Send-NtfyNotification -ServerUrl $selectedServer -Title $title -Message $enhancedMessage -Credentials $credentials -Priority 4 -Tags "windows,shutdown,wave"
    
    if ($success) {
        $notificationSent = $true
        Write-Log "ntfy Windows Shutdown Notification sent successfully"
        
        # Create event log entry
        try {
            if (-not ([System.Diagnostics.EventLog]::SourceExists("Windows Shutdown Notifier"))) {
                [System.Diagnostics.EventLog]::CreateEventSource("Windows Shutdown Notifier", "Application")
            }
            Write-EventLog -LogName Application -Source "Windows Shutdown Notifier" -EntryType Information -EventId 2001 -Message "ntfy Windows Shutdown Notification sent to ntfy server successfully"
        }
        catch {
            Write-Log "Could not write to event log: $($_.Exception.Message)"
        }
    }
}

if (-not $notificationSent) {
    # Both servers unavailable, queue the ntfy Windows Shutdown Notification
    Write-Log "Both ntfy servers unavailable. Queuing ntfy Windows Shutdown Notification for later delivery."
    Write-Log "Original timestamp for queue: $($originalTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))"
    
    $queueSuccess = Save-NotificationToQueue -Title $title -Message $message -Priority 4 -Tags "windows,shutdown,loudspeaker" -OriginalTimestamp $originalTimestamp
    
    if ($queueSuccess) {
        Write-Log "ntfy Windows Shutdown Notification successfully queued"
        # Give extra time for file operations to complete during shutdown
        Start-Sleep -Seconds 2
    } else {
        Write-Log "ERROR: Failed to queue ntfy Windows Shutdown Notification"
    }
}

# Clear credentials from memory
$credentials = $null

Write-Log "ntfy Windows Shutdown Notification process completed"
