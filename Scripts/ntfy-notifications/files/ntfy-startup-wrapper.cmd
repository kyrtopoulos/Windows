@echo off
REM ntfy Windows Startup Notification Wrapper
REM Called by Group Policy on system startup

REM Set working directory to script location
cd /d "%~dp0"

REM Log wrapper execution
echo [%date% %time%] Startup wrapper started >> ntfy-wrapper.log

REM Call PowerShell script with Startup action
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "ntfy-core-functions.ps1" -Action "Startup"

REM Log completion
echo [%date% %time%] Startup wrapper completed (Exit Code: %ERRORLEVEL%) >> ntfy-wrapper.log

REM Exit with PowerShell script's exit code
exit /b %ERRORLEVEL%
