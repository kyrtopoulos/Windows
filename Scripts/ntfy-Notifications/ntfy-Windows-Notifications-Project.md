# ntfy Windows Notifications System

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-brightgreen.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![ntfy](https://img.shields.io/badge/ntfy-compatible-orange.svg)](https://ntfy.sh)

**Professional Windows Boot/Shutdown Notification System with Offline Queue Management**

*Created by [Dimitris Kyrtopoulos](https://kyrtopoulos.com) | [LinkedIn](https://www.linkedin.com/in/kyrtopoulos)*

---

## Overview

The ntfy Windows Notifications System is a comprehensive PowerShell-based solution that provides real-time Windows boot and shutdown notifications through ntfy servers. The system features enterprise-grade reliability with offline queue management, encrypted credential storage, automatic server failover, and centralized configuration management.

### Key Features

- **Dual Server Support**: Automatic failover between local and remote ntfy servers
- **Offline Queue Management**: Notifications are queued when servers are unavailable and delivered with original timestamps when connectivity is restored
- **Encrypted Credential Storage**: Military-grade AES-256 encryption for authentication credentials
- **Centralized Configuration**: Single JSON configuration file controls all system settings
- **Organized File Structure**: Professional directory hierarchy for easy maintenance
- **Comprehensive Logging**: Detailed logging with timestamp preservation

### System Architecture

```
ntfy Windows Notifications System
├── Boot/Shutdown Detection
├── Network Connectivity Testing
├── Dual Server Failover Logic
├── Offline Queue Management
├── Encrypted Authentication
└── Centralized Configuration
```

---

## System Requirements

- **Operating System**: Windows 10/11
- **PowerShell**: Version 5.1 or newer
- **Privileges**: Administrator access for initial setup
- **Network**: Access to ntfy servers (local/remote)
- **Services**: Task Scheduler service enabled
- **Storage**: Minimum 50MB free disk space

---

## Quick Start Guide

### Step 1: Download Initial Files

Download the following files from the GitHub repository:
- `ntfy-Windows-Notifications-Initialization.ps1`
- `ntfy-Windows-Notifications-Config.json`

**GitHub Repository**: https://github.com/kyrtopoulos/Windows/tree/main/Scripts/ntfy-Notifications

### Step 2: Configure Settings

Edit `ntfy-Windows-Notifications-Config.json` with your specific values:

```json
{
    "BasePath": "C:\\ntfy-Windows-Notifications",
    "LocalServer": "http://192.168.1.100:8080",
    "RemoteServer": "https://ntfy.sh",
    "Topic": "MyWindowsNotifications",
    "MaxRetries": 3,
    "RetryIntervalMinutes": 5,
    "NetworkTimeoutSeconds": {
        "ServerTest": 5,
        "Boot": 15,
        "Shutdown": 8,
        "QueueProcessor": 15
    },
    "LoggingEnabled": true,
    "QueueProcessorInterval": 10
}
```

### Step 3: Run Initialization

Execute as Administrator:
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\ntfy-Windows-Notifications-Initialization.ps1"
```

The initialization script will:
- Create the organized directory structure
- Download all required scripts from GitHub
- Verify file integrity
- Prepare the system for configuration

---

## Directory Structure

The system creates an organized directory hierarchy:

```
[BasePath]\
├── ntfy-Windows-Boot-Notification.ps1
├── ntfy-Windows-Shutdown-Notification.ps1
│
├── logs\
│   ├── ntfy-Windows-Boot-Notifications.log
│   ├── ntfy-Windows-Shutdown-Notifications.log
│   └── ntfy-Queue-Processor-Service.log
│
├── config\
│   └── ntfy-Windows-Notifications-Config.json
│
├── setup\
│   ├── ntfy-Queue-Processor-Service-Setup-Service.ps1
│   ├── ntfy-Secure-Credentials-Setup.ps1
│   ├── ntfy-Windows-Notifications-Initialization.ps1
│   └── ntfy-Windows-Notifications-Setup-Services.ps1
│
├── credentials\
│   ├── ntfy.key (created during credential setup)
│   ├── ntfy-Password.enc (created during credential setup)
│   └── ntfy-User.enc (created during credential setup)
│
└── queue\
    ├── ntfy-Queue-Processor-Service.ps1
    └── ntfy-Windows-Notification-Queue.json (created when needed)
```

---

## Credential Setup

### Secure Credential Configuration

Navigate to the setup directory and run the credential setup script:

```powershell
cd "[BasePath]\setup"
.\ntfy-Secure-Credentials-Setup.ps1 -Username "your_ntfy_username" -Password "your_ntfy_password"
```

**Security Features**:
- **AES-256 Encryption**: Military-grade encryption for credential protection
- **Restricted Access**: Files accessible only by SYSTEM and Administrators
- **Hidden Files**: Credential files are hidden from normal directory listings
- **Secure Key Management**: Encryption keys stored separately with restricted permissions

---

## Deployment: Task Scheduler (Automated Setup)

**Recommended for**: Standard users, automated deployment, consistent scheduling

### Automatic Setup Process

Navigate to the setup directory and run:

```powershell
cd "[BasePath]\setup"
.\ntfy-Windows-Notifications-Setup-Services.ps1
```

This creates three scheduled tasks:
- **ntfy Windows Boot Notification**: Triggers on system startup
- **ntfy Windows Shutdown Notification**: Triggers on Event ID 1074 (shutdown events)
- **ntfy Queue Processor Service**: Runs every 10 minutes to process offline notifications

### Task Configuration Details

**All tasks are configured with**:
- **Security Context**: NT AUTHORITY\SYSTEM with highest privileges
- **Power Management**: Runs on battery power
- **Execution**: Hidden window, bypass execution policy
- **Reliability**: 3 retry attempts with 1-minute intervals
- **Timeout**: 1-hour execution limit
- **Availability**: Can run on-demand and after missed schedules

---

## Configuration Management

### Centralized Configuration File

All system settings are managed through a single JSON configuration file located at:
```
[BasePath]\config\ntfy-Windows-Notifications-Config.json
```

### Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `BasePath` | Root directory for all system files | `"C:\\ntfy-Windows-Notifications"` |
| `LocalServer` | Primary ntfy server URL | `"http://192.168.1.100:8080"` |
| `RemoteServer` | Backup ntfy server URL | `"https://ntfy.sh"` |
| `Topic` | ntfy topic name for notifications | `"MyWindowsNotifications"` |
| `MaxRetries` | Maximum retry attempts for failed operations | `3` |
| `RetryIntervalMinutes` | Minutes between retry attempts | `5` |
| `NetworkTimeoutSeconds.ServerTest` | Server connectivity test timeout | `5` |
| `NetworkTimeoutSeconds.Boot` | Boot notification timeout | `15` |
| `NetworkTimeoutSeconds.Shutdown` | Shutdown notification timeout | `8` |
| `NetworkTimeoutSeconds.QueueProcessor` | Queue processing timeout | `15` |
| `LoggingEnabled` | Enable/disable detailed logging | `true` |
| `QueueProcessorInterval` | Queue processing interval in minutes | `10` |

### Configuration Updates

To modify system behavior:
1. **Edit the configuration file only** - never modify PowerShell scripts
2. **Use proper JSON syntax** with escaped backslashes for Windows paths
3. **Restart services** if changing paths or major settings
4. **Test changes** in non-production environment first

---

## System Operation

### Boot Notification Process

1. **System Startup**: Windows triggers the boot notification script
2. **Configuration Loading**: Script reads centralized configuration
3. **Credential Decryption**: Secure credentials are decrypted in memory
4. **System Information Gathering**: Collects boot time, network adapters, system specs
5. **Server Connectivity Testing**: Tests local server, then remote server if needed
6. **Queue Processing**: Processes any previously queued notifications
7. **Notification Sending**: Sends current boot notification
8. **Offline Handling**: Queues notification if servers are unavailable
9. **Logging**: Records all activities with timestamps

### Shutdown Notification Process

1. **Shutdown Detection**: Windows Event ID 1074 triggers the script
2. **Rapid Information Gathering**: Quick system information collection for timely shutdown
3. **Server Testing**: Fast connectivity tests with shortened timeouts
4. **Notification Sending**: Immediate notification dispatch
5. **Offline Queueing**: Queues notification if servers unavailable
6. **Graceful Completion**: Ensures script completes before system shutdown

### Queue Processing System

The queue processor runs every 10 minutes (configurable) and:
1. **Checks for Queued Notifications**: Examines the queue file for pending notifications
2. **Server Availability Testing**: Tests both local and remote servers
3. **Batch Processing**: Processes all queued notifications with original timestamps
4. **Queue Management**: Removes successfully sent notifications, retains failed ones
5. **Summary Reporting**: Sends summary notification when multiple items are processed

---

## Notification Format

### Boot Notification Example
```
Subject: ComputerName Started

Computer: DESKTOP-ABC123
OS: Windows 11 Pro 23H2
Boot Time: 2025-01-15 08:30:15
Network Adapters:
Intel Ethernet Connection: 192.168.1.150
Wi-Fi Adapter: 192.168.1.151
Total RAM: 16.00 GB

System is now fully operational and ready for use.

ntfy Windows Boot Notification sent via ntfy server http://192.168.1.100:8080
```

### Shutdown Notification Example
```
Subject: ComputerName Shutting Down

Computer: DESKTOP-ABC123
OS: Windows 11 Pro 23H2
Shutdown Time: 2025-01-15 17:45:30
Uptime: 9h 15m
Network Adapters:
Intel Ethernet Connection: 192.168.1.150
Wi-Fi Adapter: 192.168.1.151
Reason: User requested shutdown

System is powering down...

ntfy Windows Notification sent via ntfy server http://192.168.1.100:8080
```

### Queued Notification Format
```
Subject: ComputerName Started

[QUEUED NOTIFICATION - Original Time: 2025-01-15 08:30:15]

[Original notification content]

ntfy Windows Notification Details:
- Original Event: 2025-01-15 08:30:15
- Queued Time: 2025-01-15 08:30:16
- Delivered Time: 2025-01-15 09:15:22
- Event Type: Boot

Note: This ntfy Windows Notification was queued due to network connectivity issues and is now being delivered with the original timestamp preserved.

ntfy Windows Notification sent via ntfy server https://ntfy.sh
```

---

## Monitoring and Troubleshooting

### Log Files

The system maintains comprehensive logs in the `logs` directory:

- **`ntfy-Windows-Boot-Notifications.log`**: Boot notification activities
- **`ntfy-Windows-Shutdown-Notifications.log`**: Shutdown notification activities  
- **`ntfy-Queue-Processor-Service.log`**: Queue processing activities

### Log Entry Format
```
[2025-01-15 08:30:15] Starting ntfy Windows Boot Notification process for DESKTOP-ABC123
[2025-01-15 08:30:15] Configuration file: C:\ntfy-Windows-Notifications\config\ntfy-Windows-Notifications-Config.json
[2025-01-15 08:30:15] Script base path: C:\ntfy-Windows-Notifications
[2025-01-15 08:30:16] Local ntfy server available: http://192.168.1.100:8080
[2025-01-15 08:30:17] ntfy Windows Boot Notification sent successfully
```

### Common Issues and Solutions

#### Configuration File Not Found
**Symptoms**: Scripts fail with "Configuration file not found" error
**Solution**:
- Verify `ntfy-Windows-Notifications-Config.json` exists in the `config` directory
- Check file permissions and accessibility
- Validate JSON syntax using an online JSON validator

#### Server Connectivity Issues
**Symptoms**: Notifications are queued but not sent
**Solution**:
- Test server URLs manually in web browser
- Verify network connectivity and firewall settings
- Check server authentication credentials
- Review server logs for authentication failures

#### Permission Denied Errors
**Symptoms**: Scripts cannot read credential files or write logs
**Solution**:
- Run initial setup as Administrator
- Verify Task Scheduler tasks run as SYSTEM account
- Check file and folder permissions on the base directory
- Ensure antivirus software is not blocking script execution

#### Queue Not Processing
**Symptoms**: Offline notifications remain in queue indefinitely
**Solution**:
- Verify Queue Processor Service task is created and enabled
- Check if task is running every 10 minutes as scheduled
- Review queue processor logs for error details
- Test manual execution of the queue processor script

### Testing Procedures

#### System Testing Checklist

1. **Configuration Validation**:
   ```powershell
   # Test configuration loading
   cd "[BasePath]"
   .\ntfy-Windows-Boot-Notification.ps1
   ```

2. **Credential Testing**:
   - Verify encrypted files exist in `credentials` directory
   - Test credential decryption by running any script manually

3. **Server Connectivity Testing**:
   ```powershell
   # Test server reachability
   Invoke-WebRequest -Uri "http://your-local-server:port" -Method GET -UseBasicParsing
   Invoke-WebRequest -Uri "https://your-remote-server" -Method GET -UseBasicParsing
   ```

4. **Task Scheduler Verification**:
   - Open Task Scheduler (`taskschd.msc`)
   - Verify all three ntfy tasks are created and enabled
   - Run tasks manually to test execution

5. **Queue System Testing**:
   - Disconnect network connection
   - Run boot notification script manually
   - Reconnect network
   - Wait for queue processor or run manually
   - Verify queued notification is delivered

---

## Security Considerations

### Credential Security
- **Encryption**: AES-256 encryption with randomly generated keys
- **Access Control**: Files accessible only by SYSTEM and Administrators
- **Memory Management**: Credentials are cleared from memory after use
- **Separation**: Credentials stored separately from configuration

### File System Security
- **Hidden Files**: Sensitive files are marked as hidden
- **Restricted Permissions**: NTFS permissions limit access to authorized accounts
- **Directory Structure**: Organized structure prevents accidental exposure

### Network Security
- **HTTPS Support**: Compatible with SSL/TLS encrypted ntfy servers
- **Authentication**: Basic authentication with encrypted credential storage
- **Timeout Management**: Network timeouts prevent hanging connections

### Execution Security
- **Signed Execution**: Scripts can be digitally signed for additional security
- **Execution Policy**: Compatible with restricted execution policies
- **Privilege Management**: Runs with appropriate system privileges only

---

## Advanced Configuration

### Multiple Environment Support

Create environment-specific configuration files:
```
config\ntfy-Windows-Notifications-Config-Production.json
config\ntfy-Windows-Notifications-Config-Testing.json
config\ntfy-Windows-Notifications-Config-Development.json
```

Modify script configuration loading to specify environment:
```powershell
$configPath = Join-Path $PSScriptRoot "..\config\ntfy-Windows-Notifications-Config-Production.json"
```

### Custom Notification Templates

Modify notification messages by editing the message generation sections in:
- `ntfy-Windows-Boot-Notification.ps1` (lines 280-290)
- `ntfy-Windows-Shutdown-Notification.ps1` (lines 260-275)

### Extended Logging

Enable verbose logging by modifying the `Write-Log` function in each script to include additional debug information.

### Network Adapter Filtering

Customize network adapter information by modifying the network detection logic in both boot and shutdown scripts.

---

## Migration and Upgrades

### Upgrading from Previous Versions

1. **Backup Current Configuration**:
   ```powershell
   Copy-Item "[OldBasePath]\*.json" "[BackupLocation]\" -Force
   ```

2. **Run New Initialization Script**:
   - Download latest initialization script and configuration template
   - Update configuration with your existing settings
   - Run initialization to upgrade directory structure

3. **Migrate Credentials**:
   - Existing credential files are compatible with new versions
   - No re-encryption required for upgrades

4. **Update Task Scheduler**:
   ```powershell
   # Remove old tasks
   .\ntfy-Windows-Notifications-Setup-Services.ps1 -RemoveExisting
   # Create new tasks with updated paths
   .\ntfy-Windows-Notifications-Setup-Services.ps1
   ```

### Path Migration

To change the base path:
1. Update `BasePath` in configuration file
2. Move all files to new location
3. Update Task Scheduler script paths
4. Test all components after migration

---

## Performance Optimization

### System Resource Usage

The ntfy Windows Notifications System is designed for minimal resource consumption:
- **Memory Usage**: < 50MB during execution
- **CPU Usage**: Minimal impact on system performance
- **Disk Usage**: < 100MB including logs and queue files
- **Network Usage**: Small HTTP requests (typically < 1KB per notification)

### Optimization Recommendations

1. **Queue Processing Interval**: Adjust based on notification volume
2. **Log Rotation**: Implement log rotation for long-running systems
3. **Network Timeouts**: Tune timeouts based on network conditions
4. **Retry Settings**: Adjust retry counts and intervals for your environment

---

## Integration Examples

### Integration with Other Systems

#### SIEM Integration
Export logs to your SIEM system for centralized monitoring:
```powershell
# Example: Export logs to Windows Event Log
Write-EventLog -LogName Application -Source "ntfy Windows Notifier" -EntryType Information -EventId 1001
```

#### Monitoring Systems
Integrate with monitoring systems by parsing log files or using custom metrics.

#### Automation Platforms
Trigger additional actions based on boot/shutdown events by extending the notification scripts.

---

## Troubleshooting Guide

### Diagnostic Commands

#### System Information
```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Check execution policy
Get-ExecutionPolicy

# Check Task Scheduler tasks
Get-ScheduledTask -TaskName "*ntfy*"

# Check log files
Get-ChildItem "[BasePath]\logs\*.log" | Select-Object Name, Length, LastWriteTime
```

#### Network Testing
```powershell
# Test local server
Test-NetConnection -ComputerName "192.168.1.100" -Port 8080

# Test remote server
Test-NetConnection -ComputerName "ntfy.sh" -Port 443
```

#### Configuration Validation
```powershell
# Validate JSON configuration
try {
    $config = Get-Content "[BasePath]\config\ntfy-Windows-Notifications-Config.json" | ConvertFrom-Json
    Write-Host "Configuration is valid"
} catch {
    Write-Host "Configuration error: $($_.Exception.Message)"
}
```

---

## Support and Maintenance

### Regular Maintenance Tasks

1. **Monthly**:
   - Review log files for errors
   - Test notification delivery
   - Verify credential file integrity

2. **Quarterly**:
   - Update server URLs if changed
   - Review and adjust timeout settings
   - Test offline queue functionality

3. **Annually**:
   - Rotate encryption keys for enhanced security
   - Update PowerShell scripts if new versions available
   - Review and update configuration settings

### Getting Support

For issues, questions, or contributions:
- **GitHub Repository**: https://github.com/kyrtopoulos/Windows/tree/main/Scripts/ntfy-Notifications
- **Issues**: Submit issues via GitHub Issues
- **Documentation**: Refer to this comprehensive guide

---

## License and Attribution

**Created by**: Dimitris Kyrtopoulos  
**Repository**: https://github.com/kyrtopoulos/Windows  
**License**: Apache License 2.0 (refer to repository for full license terms)

### Third-Party Dependencies
- **PowerShell**: Microsoft PowerShell runtime
- **Windows Task Scheduler**: Microsoft Windows Task Scheduler service
- **ntfy**: Compatible with ntfy.sh and self-hosted ntfy servers

---

## Conclusion

The ntfy Windows Notifications System provides a robust, enterprise-ready solution for Windows boot and shutdown notifications. With its comprehensive feature set including offline queue management, encrypted credential storage, dual server support, and centralized configuration, the system ensures reliable notification delivery in any network environment.

The flexible deployment options (Task Scheduler vs Group Policy) accommodate both individual users and enterprise environments, while the organized file structure and comprehensive logging facilitate easy maintenance and troubleshooting.

For optimal results, follow the deployment recommendations for your environment, regularly monitor the system logs, and keep the configuration file updated with current server information.

---

*This documentation covers all aspects of the ntfy Windows Notifications System. For the latest updates and additional resources, visit the GitHub repository.*
