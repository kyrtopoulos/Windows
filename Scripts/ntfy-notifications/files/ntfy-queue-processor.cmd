@echo off
REM ntfy Queue Processor
REM Processes offline notifications when connectivity is restored
REM Can be called by Task Scheduler every 10 minutes

REM Set working directory to script location
cd /d "%~dp0"

REM Log queue processor execution
echo [%date% %time%] Queue processor started >> ntfy-wrapper.log

REM Call PowerShell script with ProcessQueue action
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "ntfy-core-functions.ps1" -Action "ProcessQueue"

REM Log completion
echo [%date% %time%] Queue processor completed (Exit Code: %ERRORLEVEL%) >> ntfy-wrapper.log

REM Exit with PowerShell script's exit code
exit /b %ERRORLEVEL%
