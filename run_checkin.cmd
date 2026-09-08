@echo off
setlocal enabledelayedexpansion

:: ============================================
:: TraeWork Daily Auto Check-in Runner
:: ============================================

set "SCRIPT_PATH=%~dp0checkin.js"

:: 1. Check if Node.js is installed in system
where node >nul 2>nul
if %errorlevel% equ 0 (
  node "%SCRIPT_PATH%"
  goto :END
)

:: 2. Auto-detect any installed *trae*.exe
set "FOUND_EXE="

:: Check LocalAppData
for /d %%D in ("%LOCALAPPDATA%\Programs\*trae*") do (
  for %%F in ("%%D\*trae*.exe") do (
    if not defined FOUND_EXE if exist "%%F" set "FOUND_EXE=%%F"
  )
)

:: Check Program Files
for /d %%D in ("%ProgramFiles%\*trae*") do (
  for %%F in ("%%D\*trae*.exe") do (
    if not defined FOUND_EXE if exist "%%F" set "FOUND_EXE=%%F"
  )
)

:: Check user-specific directories across common drives if custom installed
if not defined FOUND_EXE (
  for %%D in (C D E F) do (
    if not defined FOUND_EXE if exist "%%D:\Users\%USERNAME%\AppData\Local\Programs\TRAE SOLO CN\TRAE SOLO CN.exe" (
      set "FOUND_EXE=%%D:\Users\%USERNAME%\AppData\Local\Programs\TRAE SOLO CN\TRAE SOLO CN.exe"
    )
    if not defined FOUND_EXE if exist "%%D:\Users\%USERNAME%\AppData\Local\Programs\Trae CN\Trae CN.exe" (
      set "FOUND_EXE=%%D:\Users\%USERNAME%\AppData\Local\Programs\Trae CN\Trae CN.exe"
    )
  )
)

if defined FOUND_EXE (
  set ELECTRON_RUN_AS_NODE=1
  set VSCODE_DEV=
  "!FOUND_EXE!" "%SCRIPT_PATH%"
  goto :END
)

echo [ERROR] No suitable runtime (Node.js or Trae) found on this machine!
echo Please install Node.js 18+ or ensure Trae is properly installed.
echo.

:END
:: If launched with --silent or -s, exit immediately (for scheduled tasks)
if /i "%~1"=="--silent" goto :EXIT
if /i "%~1"=="-s" goto :EXIT

echo.
pause

:EXIT
endlocal
