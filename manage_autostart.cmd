@echo off
setlocal
title TraeWorkCheckin Management Console
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage_autostart.ps1" %*
set "EXIT_CODE=%errorlevel%"
if %EXIT_CODE% neq 0 (
    echo.
    echo [ERROR] Process exited with code %EXIT_CODE%
    pause
)
exit /b %EXIT_CODE%