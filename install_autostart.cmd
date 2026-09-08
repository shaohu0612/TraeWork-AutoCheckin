@echo off
setlocal

echo ====================================================
echo   TraeWork Auto Check-in Installer
echo ====================================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $s = [Environment]::GetFolderPath('Startup'); $p = Join-Path $s 'TraeWorkAutoCheckin.lnk'; $lnk = $ws.CreateShortcut($p); $lnk.TargetPath = $args[0]; $lnk.Arguments = '--silent'; $lnk.WorkingDirectory = $args[1]; $lnk.WindowStyle = 7; $lnk.Save(); Write-Host '[OK] Auto check-in task installed successfully!' -ForegroundColor Green; Write-Host 'Check-in will run silently on Windows logon, and a notification will pop up in bottom-right tray.' -ForegroundColor Cyan;" "%~dp0run_checkin.cmd" "%~dp0."

echo.
pause
endlocal
