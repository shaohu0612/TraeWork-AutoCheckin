@echo off
setlocal

echo ====================================================
echo   TraeWork Auto Check-in Uninstaller
echo ====================================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$dir = [Environment]::GetFolderPath('Startup'); $target = Join-Path $dir 'TraeWorkAutoCheckin.lnk'; if (Test-Path $target) { Remove-Item $target -Force; Write-Host '[OK] Startup shortcut removed successfully.' -ForegroundColor Green; } else { Write-Host '[INFO] Startup shortcut not found.' -ForegroundColor Yellow; }; Unregister-ScheduledTask -TaskName 'TraeWorkAutoCheckin' -Confirm:$false -ErrorAction SilentlyContinue; Write-Host '[OK] Auto check-in cleanup completed.' -ForegroundColor Green;"

echo.
pause
endlocal
