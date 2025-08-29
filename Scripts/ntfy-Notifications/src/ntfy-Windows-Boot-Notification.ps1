# ntfy Windows Boot Notification Script (Enhanced with Offline Queue & Encrypted Credentials)
# Runs on system startup, queues ntfy Windows Boot Notifications when offline, sends when online

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
    $networkTimeout = $config.NetworkTimeoutSeconds.Boot
}
catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}
# =============================================================================

# System variables
$computerName = $env:COMPUTERNAME

# Centralized file paths - all derived from $SCRIPT_BASE_PATH
$logPath = Join-Path $SCRIPT_BASE_PATH "ntfy-Windows-Boot-Notifications.log"
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

# Function to save nfty Windows Boot Notification to queue
function Save-NotificationToQueue {
    param(
        [string]$Title,
        [string]$Message,
        [int]$Priority = 4,
        [string]$Tags = "windows,startup,loudspeaker",
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
        
        # Create nfty Windows Boot Notification object with original timestamp
        $notification = @{
            Title = $Title
            Message = $Message
            Priority = $Priority
            Tags = $Tags
            OriginalTimestamp = $OriginalTimestamp.ToString("yyyy-MM-dd HH:mm:ss")
            QueuedTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Type = "Boot"
        }
        
        # Add to queue using array methods
        $queue = [System.Collections.ArrayList]@($queue)
        $queue.Add($notification) | Out-Null
        
        # Save queue back to file
        $queueArray = @($queue)
        $queueArray | ConvertTo-Json -Depth 10 | Set-Content $queuePath -Encoding UTF8
        Write-Log "ntfy Windows Boot Notification queued offline with original timestamp: $($OriginalTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))"
        return $true
    }
    catch {
        Write-Log "Failed to save ntfy Windows Boot Notification to queue: $($_.Exception.Message)"
        return $false
    }
}

# Function to test ntfy server connectivity
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

# Function to send nfty Windows Boot Notification
function Send-NtfyNotification {
    param(
        [string]$ServerUrl,
        [string]$Title,
        [string]$Message,
        [hashtable]$Credentials,
        [int]$Priority = 4,
        [string]$Tags = "windows,startup,rocket"
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
        
        $response = Invoke-RestMethod -Uri "$ServerUrl/$ntfyTopic" -Method Post -Body $Message -Headers $headers -TimeoutSec $networkTimeout -ErrorAction Stop
        Write-Log "ntfy Windows Boot Notification sent successfully to $ServerUrl"
        return $true
    }
    catch {
        Write-Log "Failed to send ntfy Windows Boot Notification to $ServerUrl : $($_.Exception.Message)"
        return $false
    }
}

# Function to process queued ntfy Windows Boot Notifications
function Process-QueuedNotifications {
    param(
        [string]$ServerUrl,
        [hashtable]$Credentials
    )
    
    try {
        if (-not (Test-Path $queuePath)) {
            return
        }
        
        $queueContent = Get-Content $queuePath -Raw -ErrorAction SilentlyContinue
        if (-not $queueContent) {
            return
        }
        
        $queue = $queueContent | ConvertFrom-Json
        if (-not $queue -or $queue.Count -eq 0) {
            return
        }
        
        Write-Log "Processing $($queue.Count) queued ntfy Windows Boot Notifications..."
        $successfulSends = 0
        $failedSends = 0
        
        foreach ($notification in $queue) {
            # Modify message to include original timestamp
            $modifiedMessage = @"
[QUEUED NOTIFICATION - Original Time: $($notification.OriginalTimestamp)]

$($notification.Message)

Note: This nfty Windows Boot Notification was originally generated at $($notification.OriginalTimestamp) but was queued due to network connectivity issues and is now being delivered.
"@
            
            $success = Send-NtfyNotification -ServerUrl $ServerUrl -Title $notification.Title -Message $modifiedMessage -Credentials $Credentials -Priority $notification.Priority -Tags "$($notification.Tags),queued"
            
            if ($success) {
                $successfulSends++
                Write-Log "Successfully sent ntfy queued $($notification.Type) notification from $($notification.OriginalTimestamp)"
            } else {
                $failedSends++
                Write-Log "Failed to send ntfy queued $($notification.Type) notification from $($notification.OriginalTimestamp)"
            }
        }
        
        if ($failedSends -eq 0) {
            # All ntfy Windows Boot Notifications sent successfully, clear the queue
            Remove-Item $queuePath -Force -ErrorAction SilentlyContinue
            Write-Log "All queued ntfy Windows Boot Notifications sent successfully. Queue cleared."
            
            # Send summary nfty Windows Boot Notification
            if ($successfulSends -gt 1) {
                $summaryMessage = "Successfully delivered $successfulSends queued ntfy Windows Boot Notifications from when the system was offline."
                Send-NtfyNotification -ServerUrl $ServerUrl -Title "Queued ntfy Windows Boot Notifications Delivered" -Message $summaryMessage -Credentials $Credentials -Priority 4 -Tags "windows,startup,queued,summary,loudspeaker"
            }
        } else {
            Write-Log "Some ntfy Windows Boot Notifications failed to send. Keeping failed ntfy Windows Boot Notifications in queue."
            # Could implement logic here to remove only successful ones from queue
        }
    }
    catch {
        Write-Log "Error processing queued ntfy Windows Boot Notifications: $($_.Exception.Message)"
    }
}

# Main execution starts here
Write-Log "Starting ntfy Windows Boot Notification process for $computerName"
Write-Log "Configuration file: $configPath"
Write-Log "Script base path: $SCRIPT_BASE_PATH"

# Get decrypted credentials
$credentials = Get-DecryptedCredentials
if (-not $credentials) {
    Write-Log "Cannot proceed without credentials. Exiting."
    exit 1
}

# Get system information first
$originalTimestamp = Get-Date
try {
    # Use multiple methods to get accurate boot time
    $bootTime = $null
    
    # Method 1: WMI Win32_OperatingSystem
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $bootTime = $osInfo.LastBootUpTime
    } catch {
        Write-Log "Method 1 failed: $($_.Exception.Message)"
    }
    
    # Method 2: System Event Log as backup
    if (-not $bootTime) {
        try {
            $bootEvent = Get-WinEvent -FilterHashtable @{LogName='System'; ID=6005} -MaxEvents 1 -ErrorAction Stop
            $bootTime = $bootEvent.TimeCreated
            Write-Log "Used event log method for boot time"
        } catch {
            Write-Log "Method 2 failed: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Fallback to system uptime calculation
    if (-not $bootTime) {
        try {
            $uptimeSeconds = (Get-Counter -Counter "\System\System Up Time" -ErrorAction Stop).CounterSamples[0].CookedValue
            $bootTime = $originalTimestamp.AddSeconds(-$uptimeSeconds)
            Write-Log "Used uptime calculation method for boot time"
        } catch {
            Write-Log "Method 3 failed: $($_.Exception.Message)"
            $bootTime = $originalTimestamp
        }
    }
    
    $uptime = $originalTimestamp - $bootTime
    $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    
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
    
    Write-Log "System information gathered successfully"
}
catch {
    Write-Log "Error gathering system information: $($_.Exception.Message)"
    $bootTime = Get-Date
    $osInfo = @{ Caption = "Windows 11"; Version = "Unknown" }
    $computerInfo = @{ TotalPhysicalMemory = 0 }
    $networkDetails = "Network information unavailable"
}

# Create nfty Windows Boot Notification message
$title = "$computerName Started"
$message = @"
Computer: $computerName
OS: $($osInfo.Caption) $($osInfo.Version)
Boot Time: $($bootTime.ToString("yyyy-MM-dd HH:mm:ss"))
Network Adapters:
$networkDetails
Total RAM: $([math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)) GB

System is now fully operational and ready for use.
"@

# Wait for system to fully initialize and network to be ready
Start-Sleep -Seconds 15

# Determine which ntfy server to use and send nfty Windows Boot Notification
$selectedServer = $null
$notificationSent = $false

if (Test-NtfyServer -ServerUrl $localNtfyServer) {
    $selectedServer = $localNtfyServer
    Write-Log "Local ntfy server available: $localNtfyServer"
} elseif (Test-NtfyServer -ServerUrl $remoteNtfyServer) {
    $selectedServer = $remoteNtfyServer  
    Write-Log "Local server unavailable, remote server available: $remoteNtfyServer"
}

if ($selectedServer) {
    # Try to process any queued ntfy Windows Boot Notifications first
    Process-QueuedNotifications -ServerUrl $selectedServer -Credentials $credentials
    
    # Send current nfty Windows Boot Notification
    $enhancedMessage = $message + "`n`nntfy Windows Boot Notification sent via ntfy server $selectedServer"
    $success = Send-NtfyNotification -ServerUrl $selectedServer -Title $title -Message $enhancedMessage -Credentials $credentials -Priority 4 -Tags "windows,startup,rocket"
    
    if ($success) {
        $notificationSent = $true
        Write-Log "ntfy Windows Boot Notification sent successfully"
        
        # Create event log entry
        try {
            if (-not ([System.Diagnostics.EventLog]::SourceExists("Windows Boot Notifier"))) {
                [System.Diagnostics.EventLog]::CreateEventSource("Windows Boot Notifier", "Application")
            }
            Write-EventLog -LogName Application -Source "Windows Boot Notifier" -EntryType Information -EventId 1001 -Message "nfty Windows Boot Notification sent to ntfy server successfully"
        }
        catch {
            Write-Log "Could not write to event log: $($_.Exception.Message)"
        }
    }
}

if (-not $notificationSent) {
    # Both servers unavailable, queue the nfty Windows Boot Notification
    Write-Log "Both ntfy servers unavailable. Queuing ntfy Windows Boot Notification for later delivery."
    Save-NotificationToQueue -Title $title -Message $message -Priority 4 -Tags "windows,startup,loudspeaker" -OriginalTimestamp $originalTimestamp
}

# Clear credentials from memory
$credentials = $null

Write-Log "ntfy Windows Boot Notification process completed"
