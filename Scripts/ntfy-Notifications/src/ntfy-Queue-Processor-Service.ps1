# Standalone Queue Processor Service for ntfy Windows Notifications
# Runs periodically to check and send queued ntfy Windows Notifications when network is restored
# Can be run as a scheduled task every 5-10 minutes

param(
    [int]$MaxRetries = 3,
    [int]$RetryIntervalMinutes = 5
)

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
    
    # Use config values or override with parameters
    if ($MaxRetries -eq 3 -and $config.MaxRetries) { 
        $MaxRetries = $config.MaxRetries 
    }
    if ($RetryIntervalMinutes -eq 5 -and $config.RetryIntervalMinutes) { 
        $RetryIntervalMinutes = $config.RetryIntervalMinutes 
    }
}
catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}
# =============================================================================

# Centralized file paths - all derived from $SCRIPT_BASE_PATH
$queuePath = Join-Path $SCRIPT_BASE_PATH "ntfy-Windows-Notification-Queue.json"
$logPath = Join-Path $SCRIPT_BASE_PATH "ntfy-Queue-Processor-Service.log"
$SecurePasswordPath = Join-Path $SCRIPT_BASE_PATH "ntfy-Password.enc"
$SecureUserPath = Join-Path $SCRIPT_BASE_PATH "ntfy-User.enc"
$KeyPath = Join-Path $SCRIPT_BASE_PATH "ntfy.key"

# Function to decrypt credentials
function Get-DecryptedCredentials {
    try {
        if ((Test-Path $KeyPath) -and (Test-Path $SecurePasswordPath) -and (Test-Path $SecureUserPath)) {
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
            Write-Log "Encrypted credential files not found."
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

# Function to test ntfy server connectivity
function Test-NtfyServer {
    param([string]$ServerUrl)
    
    try {
        $testResponse = Invoke-WebRequest -Uri "$ServerUrl" -Method GET -TimeoutSec $config.NetworkTimeoutSeconds.ServerTest -UseBasicParsing -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to send ntfy Windows Notification
function Send-NtfyNotification {
    param(
        [string]$ServerUrl,
        [string]$Title,
        [string]$Message,
        [hashtable]$Credentials,
        [int]$Priority = 4,
        [string]$Tags = "windows"
    )
    
    try {
        $headers = @{
            'Title' = $Title
            'Priority' = $Priority.ToString()
            'Tags' = $Tags
        }
        
        # Add authentication header
        $authString = "$($Credentials.Username):$($Credentials.Password)"
        $encodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($authString))
        $headers['Authorization'] = "Basic $encodedAuth"
        
        $response = Invoke-RestMethod -Uri "$ServerUrl/$ntfyTopic" -Method Post -Body $Message -Headers $headers -TimeoutSec $config.NetworkTimeoutSeconds.QueueProcessor -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "Failed to send ntfy Windows Notification to $ServerUrl`: $($_.Exception.Message)"
        return $false
    }
}

# Function to process queued ntfy Windows Notifications
function Process-QueuedNotifications {
    param([string]$ServerUrl, [hashtable]$Credentials)
    
    try {
        if (-not (Test-Path $queuePath)) {
            Write-Log "No queue file found. Nothing to process."
            return @{ ProcessedCount = 0; FailedCount = 0 }
        }
        
        $queueContent = Get-Content $queuePath -Raw -ErrorAction SilentlyContinue
        if (-not $queueContent) {
            Write-Log "Queue file is empty."
            return @{ ProcessedCount = 0; FailedCount = 0 }
        }
        
        $queue = $queueContent | ConvertFrom-Json
        if (-not $queue -or $queue.Count -eq 0) {
            Write-Log "No ntfy Windows Notifications in queue."
            return @{ ProcessedCount = 0; FailedCount = 0 }
        }
        
        Write-Log "Processing $($queue.Count) queued ntfy Windows Notifications..."
        $processedNotifications = @()
        $failedNotifications = @()
        
        foreach ($notification in $queue) {
            # Create message with original timestamp information
            $modifiedMessage = @"
[QUEUED NOTIFICATION - Original Time: $($notification.OriginalTimestamp)]

$($notification.Message)

ntfy Windows Notification Details:
- Original Event: $($notification.OriginalTimestamp)
- Queued Time: $($notification.QueuedTimestamp)  
- Delivered Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Event Type: $($notification.Type)

Note: This ntfy Windows Notification was queued due to network connectivity issues and is now being delivered with the original timestamp preserved.
"@
            
            $success = Send-NtfyNotification -ServerUrl $ServerUrl -Title $notification.Title -Message $modifiedMessage -Credentials $Credentials -Priority $notification.Priority -Tags "$($notification.Tags),queued"
            
            if ($success) {
                $processedNotifications += $notification
                Write-Log "Successfully delivered ntfy queued $($notification.Type) Windows Notification from $($notification.OriginalTimestamp)"
            } else {
                $failedNotifications += $notification
                Write-Log "Failed to deliver ntfy queued $($notification.Type) Windows Notification from $($notification.OriginalTimestamp)"
            }
            
            # Small delay between ntfy Windows Notifications to avoid overwhelming the server
            Start-Sleep -Milliseconds 500
        }
        
        # Update queue with only failed ntfy Windows Notifications
        if ($failedNotifications.Count -eq 0) {
            # All ntfy Windows Notifications sent successfully, remove queue file
            Remove-Item $queuePath -Force -ErrorAction SilentlyContinue
            Write-Log "All ntfy queued Windows Notifications delivered successfully. Queue cleared."
            
            # Send summary ntfy Windows Notification if we processed multiple ntfy Windows Notifications
            if ($processedNotifications.Count -gt 1) {
                $summaryMessage = @"
ntfy Windows Notification Queue Summary

Successfully delivered $($processedNotifications.Count) ntfy Windows queued Notifications that were stored while the system was offline.

Queue Statistics:
- Total Processed: $($processedNotifications.Count)
- Failed Deliveries: 0
- Queue Clear Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

All offline ntfy Windows Notifications have been successfully delivered with their original timestamps preserved.
"@
                Send-NtfyNotification -ServerUrl $ServerUrl -Title "Offline ntfy Windows Notifications Delivered" -Message $summaryMessage -Credentials $Credentials -Priority 4 -Tags "windows,queued,summary,success,loudspeaker"
            }
        } else {
            # Keep failed ntfy Windows Notifications in queue for next retry
            $failedNotifications | ConvertTo-Json -Depth 10 | Set-Content $queuePath -Encoding UTF8
            Write-Log "$($failedNotifications.Count) ntfy Windows Notifications failed to send. Kept in queue for retry."
        }
        
        return @{ 
            ProcessedCount = $processedNotifications.Count
            FailedCount = $failedNotifications.Count 
        }
    }
    catch {
        Write-Log "Error processing ntfy queued Windows Notifications: $($_.Exception.Message)"
        return @{ ProcessedCount = 0; FailedCount = -1 }
    }
}

# Main execution
Write-Log "Starting queue processor..."
Write-Log "Using configuration file: $configPath"
Write-Log "Using script base path: $SCRIPT_BASE_PATH"

# Check if queue file exists
if (-not (Test-Path $queuePath)) {
    Write-Log "No queue file found. Exiting."
    exit 0
}

# Get credentials
$credentials = Get-DecryptedCredentials
if (-not $credentials) {
    Write-Log "Cannot proceed without credentials. Exiting."
    exit 1
}

# Determine which server is available
$selectedServer = $null
if (Test-NtfyServer -ServerUrl $localNtfyServer) {
    $selectedServer = $localNtfyServer
    Write-Log "Using local ntfy server: $localNtfyServer"
} elseif (Test-NtfyServer -ServerUrl $remoteNtfyServer) {
    $selectedServer = $remoteNtfyServer  
    Write-Log "Using remote ntfy server: $remoteNtfyServer"
} else {
    Write-Log "Both ntfy servers are unavailable. Will retry later."
    exit 1
}

# Process queued ntfy Windows Notifications
$result = Process-QueuedNotifications -ServerUrl $selectedServer -Credentials $credentials

# Log results
if ($result.ProcessedCount -gt 0) {
    Write-Log "Queue processing completed. Processed: $($result.ProcessedCount), Failed: $($result.FailedCount)"
} else {
    Write-Log "No ntfy Windows Notifications were processed this run."
}

# Clear credentials from memory
$credentials = $null

Write-Log "Queue processor finished."
