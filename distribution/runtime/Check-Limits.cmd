@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-Limits.ps1"
exit /b %ERRORLEVEL%
