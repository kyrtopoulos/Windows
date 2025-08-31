# Windows PowerShell & Automation Scripts

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-brightgreen.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Maintenance](https://img.shields.io/badge/Maintained-yes-green.svg)](https://github.com/kyrtopoulos/Windows)

Professional collection of Windows automation scripts, system administration tools, and productivity utilities for system administrators and power users.

*Created by [Dimitris Kyrtopoulos](https://kyrtopoulos.com) | [LinkedIn](https://www.linkedin.com/in/kyrtopoulos)*

---

## Repository Contents

### 📂 [Scripts/ntfy-notifications](./Scripts/ntfy-notifications/)
**Enterprise-grade Windows Startup/Shutdown Notification System**
- Real-time notifications via ntfy servers
- Offline queue management with timestamp preservation
- Encrypted credential storage with AES-256
- Dual server failover and centralized configuration
- Support for Task Scheduler and Group Policy deployment

### 📁 Scripts/
Collection of PowerShell scripts for various system administration tasks:
- System monitoring and reporting utilities
- Network configuration and testing tools
- File management and organization scripts
- Security and compliance automation
- Performance optimization utilities

### 🔧 Batch Files
Legacy batch files for compatibility and specific use cases:
- System maintenance routines
- Quick configuration scripts
- Backup and restore utilities
- Network diagnostics

### 📋 CMD Scripts
Command-line utilities and system tools:
- Registry modifications
- Service management
- System information gathering
- Automated installation helpers

### 📖 Guides & Tips
Documentation and best practices:
- Windows administration guides
- PowerShell scripting tips
- System optimization recommendations
- Security configuration guides

---

## Quick Start

### Prerequisites
- Windows 10/11
- PowerShell 5.1 or newer
- Administrator privileges (for system-level scripts)

### Installation
1. Clone this repository:
   ```powershell
   git clone https://github.com/kyrtopoulos/Windows.git
   ```

2. Set execution policy (if needed):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. Navigate to specific script directories for detailed instructions

---

## Featured Projects

### ntfy Windows Notifications Project
Enterprise-grade notification system for Windows startup/shutdown events with comprehensive monitoring:

- **Dual-Server Failover**: Automatic failover between local and remote ntfy servers
- **Offline Queue Management**: Stores notifications when servers unavailable, delivers when connectivity restored
- **Advanced Logging**: Separate log files with automatic rotation for different components
- **Startup Type Detection**: Distinguishes between Fast Startup (hibernation) and cold startup
- **Multiple Deployment Options**: Group Policy (recommended) and Task Scheduler methods
- **Enterprise Security**: SYSTEM-level execution with restricted file permissions
- **Centralized Configuration**: Single INI file for all system settings

[📖 Complete Documentation](./Scripts/ntfy-notifications/ntfy-Windows-Notifications-Project.md)

---

## Script Categories

### System Administration
- **System Information**: Hardware and software inventory scripts
- **Service Management**: Start/stop/configure Windows services
- **Registry Tools**: Safe registry modification utilities
- **User Management**: Account creation and permission scripts

### Network & Security
- **Network Diagnostics**: Connection testing and troubleshooting
- **Security Auditing**: System security assessment tools
- **Firewall Management**: Windows Firewall configuration scripts
- **Certificate Management**: SSL/TLS certificate utilities

### Automation & Monitoring
- **Scheduled Tasks**: PowerShell-based task automation
- **Log Analysis**: Windows Event Log parsing and analysis
- **Performance Monitoring**: Resource usage tracking scripts
- **Backup Solutions**: Automated backup and restore tools

### Productivity Tools
- **File Organization**: Bulk file management utilities
- **System Cleanup**: Temporary file and registry cleanup
- **Software Installation**: Automated software deployment
- **Configuration Management**: System setting standardization

---

## Usage Guidelines

### Before Running Scripts
1. **Read Documentation**: Each script includes detailed comments and usage instructions
2. **Test First**: Always test scripts in a non-production environment
3. **Check Prerequisites**: Verify PowerShell version and required modules
4. **Backup Important Data**: Create system restore points when appropriate

### Security Considerations
- Scripts are designed with security best practices
- Credential handling uses encryption where applicable
- All scripts include input validation and error handling
- Administrative privileges are requested only when necessary

### Compatibility
- **Windows 10**: Full compatibility
- **Windows 11**: Full compatibility  
- **Windows Server**: Most scripts compatible (check individual documentation)
- **PowerShell Core**: Selected scripts support cross-platform execution

---

## Repository Structure

```
Windows/
├── README.md                                         # This file
├── LICENSE                                           # Apache 2.0 License
├── SECURITY.md                                       # Security policy and vulnerability reporting
├── Scripts/
│   ├── ntfy-notifications/                           # Complete notification system
│   ├── SystemAdmin/                                  # System administration scripts
│   ├── NetworkTools/                                 # Network utilities
│   ├── SecurityAudit/                                # Security assessment tools
│   └── Productivity/                                 # Productivity utilities
├── Batch/                                            # Legacy batch files
├── CMD/                                              # Command-line utilities
└── Guides/                                           # Documentation and guides
```

---

## Contributing

### Guidelines
- Follow PowerShell best practices and coding standards
- Include comprehensive documentation and examples
- Test scripts across different Windows versions
- Use appropriate error handling and logging
- Submit well-documented pull requests

### Development Standards
- **Comments**: Clear, concise code documentation
- **Parameters**: Use proper parameter validation
- **Error Handling**: Implement try-catch blocks and meaningful error messages
- **Logging**: Include verbose output for troubleshooting
- **Security**: Follow secure coding practices

---

## Support & Resources

### Documentation
- Each script directory contains specific README files
- Inline documentation within all script files
- Usage examples and troubleshooting guides

### Community
- **Issues**: [GitHub Issues](https://github.com/kyrtopoulos/Windows/issues) for bug reports and feature requests
- **Discussions**: Use GitHub Discussions for questions and community support
- **Contributions**: Pull requests welcome following contribution guidelines

### Professional Services
For enterprise deployments, custom automation, or consulting services:
- **Website**: [kyrtopoulos.com](https://kyrtopoulos.com)
- **LinkedIn**: [linkedin.com/in/kyrtopoulos](https://www.linkedin.com/in/kyrtopoulos)

---

## License & Legal

### Apache License 2.0
This repository is licensed under the Apache License 2.0.
See [LICENSE](./LICENSE) file for complete terms.

### Disclaimer
These tools are provided "as-is" for educational and professional use without warranty.
Always test in non-production environments before deployment.
The author is not responsible for any system issues resulting from script usage.

---

*Professional Windows automation solutions by [Dimitris Kyrtopoulos](https://kyrtopoulos.com)*
