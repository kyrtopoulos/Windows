:: Remove files older than 30 days from User's folders (Downloads, Temp) and Windows Temp folder

REM Remove files older than 30 days
forfiles /p "%userprofile%\Downloads" /s /m *.* /c "cmd /c Del /q @path" /d -30
forfiles /p "%userprofile%\appdata\Local\Temp" /s /m *.* /c "cmd /c Del /q @path"
forfiles /p "C:\Windows\Temp" /s /m *.* /c "cmd /c Del /q @path"
