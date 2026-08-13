@echo off
chcp 65001 >nul
title Лимиты ClaudeGravity

set "PATH=%APPDATA%\npm;C:\Program Files\nodejs;%PATH%"

cls
echo === Лимиты ClaudeGravity ===
echo.

powershell -Command "try { Invoke-RestMethod http://127.0.0.1:8080/health | ConvertTo-Json -Depth 20 } catch { Write-Host 'Прокси не ответил на http://127.0.0.1:8080/health' }"

echo.
pause
