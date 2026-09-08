@echo off
setlocal

:: ====================================================
:: TraeWork Auto Check-in - Autostart Manager
:: ====================================================

if /i "%~1"=="--install" goto :INSTALL_SILENT
if /i "%~1"=="-i" goto :INSTALL_SILENT
if /i "%~1"=="--uninstall" goto :UNINSTALL_SILENT
if /i "%~1"=="-u" goto :UNINSTALL_SILENT

:MENU
cls
echo ====================================================
echo      TraeWork Auto Check-in - Autostart Manager
echo ====================================================
echo.
echo   [1] Install autostart task (Run on Windows logon)
echo   [2] Uninstall autostart task (Remove completely)
echo   [3] Run check-in now (Test execution)
echo   [0] Exit
echo.
echo ====================================================
set "CHOICE="
set /p "CHOICE=Enter choice [1/2/3/0]: "

if "%CHOICE%"=="1" goto :INSTALL
if "%CHOICE%"=="2" goto :UNINSTALL
if "%CHOICE%"=="3" goto :RUN_NOW
if "%CHOICE%"=="0" goto :EXIT
if /i "%CHOICE%"=="q" goto :EXIT

echo.
echo [ERROR] Invalid choice. Please enter 1, 2, 3, or 0.
timeout /t 2 >nul 2>nul
goto :MENU

:INSTALL
echo.
echo [*] Installing autostart task...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $p = [Environment]::GetFolderPath('Startup') + '\TraeWorkAutoCheckin.lnk'; $lnk = $ws.CreateShortcut($p); $lnk.TargetPath = '%~dp0run_checkin.cmd'; $lnk.Arguments = '--silent'; $lnk.WorkingDirectory = '%~dp0'; $lnk.WindowStyle = 7; $lnk.Save(); if (Test-Path $p) { Write-Host '[OK] Auto check-in task installed successfully!' -ForegroundColor Green; Write-Host 'Check-in will run silently on Windows logon, with notification in bottom-right tray.' -ForegroundColor Cyan; } else { Write-Host '[ERROR] Failed to create shortcut.' -ForegroundColor Red; }"
echo.
pause
goto :MENU

:INSTALL_SILENT
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $p = [Environment]::GetFolderPath('Startup') + '\TraeWorkAutoCheckin.lnk'; $lnk = $ws.CreateShortcut($p); $lnk.TargetPath = '%~dp0run_checkin.cmd'; $lnk.Arguments = '--silent'; $lnk.WorkingDirectory = '%~dp0'; $lnk.WindowStyle = 7; $lnk.Save(); if (Test-Path $p) { Write-Host '[OK] Auto check-in task installed successfully!' -ForegroundColor Green; } else { Write-Host '[ERROR] Failed to create shortcut.' -ForegroundColor Red; }"
goto :EXIT

:UNINSTALL
echo.
echo [*] Removing autostart task...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$dir = [Environment]::GetFolderPath('Startup'); $p = Join-Path $dir 'TraeWorkAutoCheckin.lnk'; if (Test-Path $p) { Remove-Item $p -Force; Write-Host '[OK] Startup shortcut removed successfully.' -ForegroundColor Green; } else { Write-Host '[INFO] Startup shortcut not found.' -ForegroundColor Yellow; }; Unregister-ScheduledTask -TaskName 'TraeWorkAutoCheckin' -Confirm:$false -ErrorAction SilentlyContinue; Write-Host '[OK] Auto check-in cleanup completed.' -ForegroundColor Green;"
echo.
pause
goto :MENU

:UNINSTALL_SILENT
powershell -NoProfile -ExecutionPolicy Bypass -Command "$dir = [Environment]::GetFolderPath('Startup'); $p = Join-Path $dir 'TraeWorkAutoCheckin.lnk'; if (Test-Path $p) { Remove-Item $p -Force; Write-Host '[OK] Startup shortcut removed successfully.' -ForegroundColor Green; } else { Write-Host '[INFO] Startup shortcut not found.' -ForegroundColor Yellow; }; Unregister-ScheduledTask -TaskName 'TraeWorkAutoCheckin' -Confirm:$false -ErrorAction SilentlyContinue; Write-Host '[OK] Auto check-in cleanup completed.' -ForegroundColor Green;"
goto :EXIT

:RUN_NOW
echo.
echo [*] Running check-in...
call "%~dp0run_checkin.cmd"
echo.
pause
goto :MENU

:EXIT
endlocal