@echo off
setlocal
chcp 65001 >nul
title TraeWorkCheckin 自动签到管理控制台
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage_autostart.ps1" %*
exit /b %errorlevel%