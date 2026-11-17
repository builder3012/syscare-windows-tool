@echo off
setlocal EnableExtensions DisableDelayedExpansion
title SYSCARE WINDOWS TOOL - BO CHAY QUYEN ADMINISTRATOR
color 0B

fltmc >nul 2>&1
if errorlevel 1 (
    echo ================================================================
    echo  DANG YEU CAU QUYEN ADMINISTRATOR (UAC ELEVATION)...
    echo ================================================================
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:launcher_menu
cls
echo ===========================================================================================
echo   SYSCARE / JoIT WINDOWS TOOL - CHON PHUONG THUC KHOI CHAY
echo ===========================================================================================
echo.
echo   [1] Khoi chay Giao dien Modern PowerShell TUI (Khuyen nghi - Tieng Viet UTF-8, Sieu toc)
echo   [2] Khoi chay Giao dien Menu CMD BAT Co dien (Legacy Compatibility)
echo   [0] Thoat
echo.
echo ===========================================================================================
choice /C 120 /N /M "Chon che do khoi chay [1/2/0]: "
if errorlevel 3 exit /b 0
if errorlevel 2 goto run_bat
if errorlevel 1 goto run_ps_tui

:run_ps_tui
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Syscare.Console.ps1"
goto launcher_menu

:run_bat
call "%~dp0Tool_Windows.bat"
goto launcher_menu
