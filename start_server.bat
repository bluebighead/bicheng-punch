@echo off
title BiCheng Server

echo ========================================
echo       BiCheng - Local Server
echo ========================================
echo.

:: Try to find Python in various locations
set "PYTHON_CMD="
where python >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=python"
    goto :found_python
)

where python3 >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=python3"
    goto :found_python
)

where py >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=py"
    goto :found_python
)

:: Python not found
echo [ERROR] Python is not found.
echo Please install Python 3.x from: https://www.python.org/downloads/
echo.
echo Make sure to check "Add Python to PATH" during installation.
echo.
pause
exit /b 1

:found_python
echo [OK] Found: %PYTHON_CMD%
echo [INFO] Starting server...
echo.

:: Change to server directory
cd /d "%~dp0server"

:: Start the Python server
%PYTHON_CMD% server.py

:: If server exits
echo.
echo [INFO] Server has stopped.
pause
