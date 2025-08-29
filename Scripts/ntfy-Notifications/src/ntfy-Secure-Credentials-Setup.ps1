# Enhanced Secure Credential Setup for ntfy Windows Notifications
# Encrypts both username and password for maximum security
# Run this once as Administrator to securely store ntfy credentials

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,
    [Parameter(Mandatory=$true)]
    [string]$Password
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
}
catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}
# =============================================================================

# Centralized file paths - all derived from $SCRIPT_BASE_PATH
$SecurePasswordPath = Join-Path $SCRIPT_BASE_PATH "ntfy-Password.enc"
$SecureUserPath = Join-Path $SCRIPT_BASE_PATH "ntfy-User.enc"
$KeyPath = Join-Path $SCRIPT_BASE_PATH "ntfy.key"

Write-Host "Enhanced ntfy Credential Setup" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Using configuration file: $configPath" -ForegroundColor Gray
Write-Host "Using base path: $SCRIPT_BASE_PATH" -ForegroundColor Gray
Write-Host ""

# Create directory if it doesn't exist
if (-not (Test-Path $SCRIPT_BASE_PATH)) {
    New-Item -ItemType Directory -Path $SCRIPT_BASE_PATH -Force | Out-Null
    Write-Host "Created directory: $SCRIPT_BASE_PATH" -ForegroundColor Green
}

try {
    Write-Host "[1/6] Generating secure encryption key..." -ForegroundColor Yellow
    
    # Generate a random key for encryption (256-bit)
    $Key = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)

    # Save the key to a file using binary write
    [System.IO.File]::WriteAllBytes($KeyPath, $Key)
    
    if (Test-Path $KeyPath) {
        Write-Host "Encryption key generated successfully" -ForegroundColor Green
        
        # Set file as hidden and secure
        $keyFile = Get-Item $KeyPath
        $keyFile.Attributes = $keyFile.Attributes -bor [System.IO.FileAttributes]::Hidden
        
        Write-Host "[2/6] Setting secure permissions on key file..." -ForegroundColor Yellow
        
        # Set restrictive permissions on the key file
        $acl = Get-Acl $KeyPath
        $acl.SetAccessRuleProtection($true,$false) # Disable inheritance
        
        # Remove all existing access rules
        $acl.Access | ForEach-Object { 
            try { $acl.RemoveAccessRule($_) } catch { }
        }
        
        # Add specific permissions
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM","FullControl","Allow")
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")
        
        $acl.SetAccessRule($systemRule)
        $acl.SetAccessRule($adminRule)
        Set-Acl -Path $KeyPath -AclObject $acl
        
        Write-Host "Key file permissions secured" -ForegroundColor Green
    } else {
        throw "Key file was not created successfully"
    }

    Write-Host "[3/6] Encrypting username..." -ForegroundColor Yellow
    
    # Convert username to secure string and encrypt it
    $SecureUsername = ConvertTo-SecureString $Username -AsPlainText -Force
    $EncryptedUsername = ConvertFrom-SecureString $SecureUsername -Key $Key

    # Save encrypted username
    $EncryptedUsername | Out-File $SecureUserPath -Encoding UTF8
    
    if (Test-Path $SecureUserPath) {
        Write-Host "Username encrypted and saved" -ForegroundColor Green
        
        $userFile = Get-Item $SecureUserPath  
        $userFile.Attributes = $userFile.Attributes -bor [System.IO.FileAttributes]::Hidden

        Write-Host "[4/6] Setting secure permissions on username file..." -ForegroundColor Yellow
        
        # Set restrictive permissions on the username file
        $acl = Get-Acl $SecureUserPath
        $acl.SetAccessRuleProtection($true,$false) # Disable inheritance  
        
        # Remove all existing access rules
        $acl.Access | ForEach-Object { 
            try { $acl.RemoveAccessRule($_) } catch { }
        }
        
        # Add specific permissions
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM","FullControl","Allow")
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")
        
        $acl.SetAccessRule($systemRule)
        $acl.SetAccessRule($adminRule)
        Set-Acl -Path $SecureUserPath -AclObject $acl
        
        Write-Host "Username file permissions secured" -ForegroundColor Green
    } else {
        throw "Username file was not created successfully"
    }

    Write-Host "[5/6] Encrypting password..." -ForegroundColor Yellow
    
    # Convert password to secure string and encrypt it
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $EncryptedPassword = ConvertFrom-SecureString $SecurePassword -Key $Key

    # Save encrypted password
    $EncryptedPassword | Out-File $SecurePasswordPath -Encoding UTF8
    
    if (Test-Path $SecurePasswordPath) {
        Write-Host "Password encrypted and saved" -ForegroundColor Green
        
        $passwordFile = Get-Item $SecurePasswordPath  
        $passwordFile.Attributes = $passwordFile.Attributes -bor [System.IO.FileAttributes]::Hidden

        Write-Host "[6/6] Setting secure permissions on password file..." -ForegroundColor Yellow
        
        # Set restrictive permissions on the password file
        $acl = Get-Acl $SecurePasswordPath
        $acl.SetAccessRuleProtection($true,$false) # Disable inheritance  
        
        # Remove all existing access rules
        $acl.Access | ForEach-Object { 
            try { $acl.RemoveAccessRule($_) } catch { }
        }
        
        # Add specific permissions
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM","FullControl","Allow")
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")
        
        $acl.SetAccessRule($systemRule)
        $acl.SetAccessRule($adminRule)
        Set-Acl -Path $SecurePasswordPath -AclObject $acl
        
        Write-Host "Password file permissions secured" -ForegroundColor Green
    } else {
        throw "Password file was not created successfully"
    }

    Write-Host ""
    Write-Host "Credentials encrypted and secured successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Files created:" -ForegroundColor Cyan
    Write-Host "  Config file: $configPath" -ForegroundColor Gray
    Write-Host "  Key file: $KeyPath" -ForegroundColor Gray
    Write-Host "  Username file: $SecureUserPath" -ForegroundColor Gray  
    Write-Host "  Password file: $SecurePasswordPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Security features:" -ForegroundColor Cyan
    Write-Host "  - Centralized configuration management" -ForegroundColor Gray
    Write-Host "  - 256-bit AES encryption" -ForegroundColor Gray
    Write-Host "  - Files hidden from normal view" -ForegroundColor Gray
    Write-Host "  - Access restricted to SYSTEM and Administrators only" -ForegroundColor Gray
    Write-Host "  - Credentials stored separately for enhanced security" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Copy the ntfy Windows Notifications scripts to the same directory" -ForegroundColor Gray
    Write-Host "  2. Set up Task Scheduler tasks to run the scripts" -ForegroundColor Gray
    Write-Host "  3. Test both boot and shutdown ntfy Windows Notifications" -ForegroundColor Gray
    
    # Test decryption to ensure it works
    Write-Host ""
    Write-Host "Testing credential decryption..." -ForegroundColor Yellow
    
    $TestKey = [System.IO.File]::ReadAllBytes($KeyPath)
    $TestEncryptedUser = Get-Content $SecureUserPath
    $TestEncryptedPassword = Get-Content $SecurePasswordPath
    
    $TestSecureUser = ConvertTo-SecureString $TestEncryptedUser -Key $TestKey
    $TestSecurePassword = ConvertTo-SecureString $TestEncryptedPassword -Key $TestKey
    
    $TestBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TestSecureUser)
    $TestPlainUser = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($TestBSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($TestBSTR)
    
    if ($TestPlainUser -eq $Username) {
        Write-Host "Credential decryption test passed" -ForegroundColor Green
    } else {
        Write-Host "Credential decryption test failed" -ForegroundColor Red
    }
    
    # Clear test variables from memory
    $TestKey = $null
    $TestSecureUser = $null
    $TestSecurePassword = $null
    $TestPlainUser = $null
    
    Write-Host ""
    Write-Host "All files are stored in: $SCRIPT_BASE_PATH" -ForegroundColor Cyan
    Write-Host "To change paths in future, update the configuration file: ntfy-Windows-Notifications-Config.json" -ForegroundColor Yellow
    
} catch {
    Write-Host ""
    Write-Host "Error during credential setup: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  - Make sure you are running as Administrator" -ForegroundColor Gray
    Write-Host "  - Check that the target directory is writable" -ForegroundColor Gray
    Write-Host "  - Verify PowerShell execution policy allows scripts" -ForegroundColor Gray
    Write-Host "  - Ensure the configuration file exists and is valid" -ForegroundColor Gray
    exit 1
}

# Clear sensitive variables from memory
$Username = $null
$Password = $null
$SecureUsername = $null
$SecurePassword = $null
$Key = $null
