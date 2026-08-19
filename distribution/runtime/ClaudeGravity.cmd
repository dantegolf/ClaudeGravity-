@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ClaudeGravity.ps1"
exit /b %ERRORLEVEL%
