@echo off
REM ntfy Windows Shutdown Notification Wrapper  
REM Called by Group Policy on system shutdown

REM Set working directory to script location
cd /d "%~dp0"

REM Log wrapper execution
echo [%date% %time%] Shutdown wrapper started >> ntfy-wrapper.log

REM Call PowerShell script with Shutdown action
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "ntfy-core-functions.ps1" -Action "Shutdown"

REM Log completion
echo [%date% %time%] Shutdown wrapper completed (Exit Code: %ERRORLEVEL%) >> ntfy-wrapper.log

REM Exit with PowerShell script's exit code
exit /b %ERRORLEVEL%
