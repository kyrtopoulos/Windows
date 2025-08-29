:: Reset Taskbar System Tray Notification Icons


@echo off

set regPath=HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify
set regKey1=IconStreams
set regKey2=PastIconsStream


echo.
echo Temporarily the explorer process will terminate before removing the cache of your taskbar corner overflow notification icons. 
echo.
echo Ensure that you save all open work before proceeding further.
echo.
pause

REG DELETE "HKCU\Control Panel\NotifyIconSettings" /F

echo.
taskkill /IM explorer.exe /F
echo.
FOR /F "tokens=*" %%a in ('Reg Query "%regpath%" /v %regkey1% ^| find /i "%regkey1%"') do goto IconStreams
echo Registry key "IconStreams" already deleted.
echo.

:verify-PastIconsStream
FOR /F "tokens=*" %%a in ('Reg Query "%regpath%" /v %regkey2% ^| find /i "%regkey2%"') do goto PastIconsStream
echo Registry key "PastIconsStream" already deleted.
echo.
goto restart

:IconStreams
reg delete "%regpath%" /f /v "%regkey1%"
goto verify-PastIconsStream

:PastIconsStream
reg delete "%regpath%" /f /v "%regkey2%"


:restart
echo.
echo.
echo To complete the reset of your taskbar corner overflow notification icons, please restart your PC.
echo.
CHOICE /C:YN /M "Would you like to initiate a restart of the PC at this moment?"
IF ERRORLEVEL 2 goto no
IF ERRORLEVEL 1 goto yes


:no
echo.
echo.
echo Restarting explorer.... 
echo.
echo Kindly ensure to restart your PC at a later time to complete the process of resetting your taskbar corner overflow notification icons.
echo.
start explorer.exe
pause
exit /B

:yes
shutdown /r /f /t 00
