@echo off
setlocal

echo ====================================================
echo   TraeWork Auto Check-in Installer
echo ====================================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $p = [Environment]::GetFolderPath('Startup') + '\TraeWorkAutoCheckin.lnk'; $lnk = $ws.CreateShortcut($p); $lnk.TargetPath = '%~dp0run_checkin.cmd'; $lnk.Arguments = '--silent'; $lnk.WorkingDirectory = '%~dp0'; $lnk.WindowStyle = 7; $lnk.Save(); Write-Host '[OK] Auto check-in task installed successfully!' -ForegroundColor Green; Write-Host 'Check-in will run silently on Windows logon, and a notification will pop up in bottom-right tray.' -ForegroundColor Cyan;"

echo.
pause
endlocal
