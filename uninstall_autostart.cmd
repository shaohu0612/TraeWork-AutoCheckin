@echo off
setlocal

echo ====================================================
echo   TraeWork Auto Check-in Uninstaller
echo ====================================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$dir = [Environment]::GetFolderPath('Startup'); Get-ChildItem $dir -Filter '*Trae*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force; Unregister-ScheduledTask -TaskName 'TraeWorkAutoCheckin' -Confirm:$false -ErrorAction SilentlyContinue; Write-Host '[OK] Auto check-in task completely removed.' -ForegroundColor Green;"

echo.
pause
endlocal
