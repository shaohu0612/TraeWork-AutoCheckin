@echo off
setlocal
chcp 65001 >nul
title TraeWork ???? - ??????
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage_autostart.ps1" %*
exit /b %errorlevel%