@echo off
chcp 65001 >nul
title ClaudeGravity Launcher

set "PATH=%APPDATA%\npm;C:\Program Files\nodejs;%PATH%"
set "ANTIGRAVITY_API_KEY=antigravity"
set "RELAY_DIR=%USERPROFILE%\.relay-ai"
set "PROVIDERS_JSON=%RELAY_DIR%\providers.json"

cls
echo =========================================
echo          ClaudeGravity Launcher
echo =========================================
echo.

where relay-ai >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Ошибка: Relay AI не найден. Выполните установку заново.
    pause
    exit /b 1
)

:: 1. Создаем / проверяем %USERPROFILE%\.relay-ai\providers.json
if not exist "%RELAY_DIR%" mkdir "%RELAY_DIR%"

findstr /C:"env:ANTIGRAVITY_API_KEY" "%PROVIDERS_JSON%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo { "schemaVersion": 1, "providers": [ { "id": "custom-antigravity", "templateId": "custom-anthropic", "name": "Antigravity", "enabled": true, "authRef": "env:ANTIGRAVITY_API_KEY", "api": { "npm": "@ai-sdk/anthropic", "url": "http://127.0.0.1:8080" }, "modelsCache": { "fetchedAt": "2026-08-11T00:00:00.000Z", "models": [ { "id": "gemini-3.6-flash-high", "name": "gemini-3.6-flash-high", "upstreamModelId": "gemini-3.6-flash-high", "family": "gemini", "brand": "Gemini", "contextWindow": 1000000, "modelFormat": "anthropic", "npm": "@ai-sdk/anthropic", "apiUrl": "http://127.0.0.1:8080" }, { "id": "claude-sonnet-4-6", "name": "claude-sonnet-4-6", "upstreamModelId": "claude-sonnet-4-6", "family": "claude", "brand": "Claude", "contextWindow": 1000000, "modelFormat": "anthropic", "npm": "@ai-sdk/anthropic", "apiUrl": "http://127.0.0.1:8080" }, { "id": "gemini-2.5-pro", "name": "gemini-2.5-pro", "upstreamModelId": "gemini-2.5-pro", "family": "gemini", "brand": "Gemini", "contextWindow": 2000000, "modelFormat": "anthropic", "npm": "@ai-sdk/anthropic", "apiUrl": "http://127.0.0.1:8080" } ] } } ] } > "%PROVIDERS_JSON%"
)

:: 2. Проверяем привязанные аккаунты
call acc accounts list 2>nul | findstr /R "[1-9][0-9]* account(s)" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [!] Не найдено привязанных аккаунтов Google (Google AI / Antigravity^).
    set /p add_acc="Привязать аккаунт Google прямо сейчас? [Y/n]: "
    if /i "%add_acc%"=="" set add_acc=Y
    if /i "%add_acc%"=="Y" (
        echo Останавливаю прокси перед привязкой аккаунта...
        call acc stop >nul 2>&1
        call acc accounts add
    )
)

:: 3. Запускаем прокси
curl -fsS http://127.0.0.1:8080/health >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Запускаю Antigravity proxy...
    call acc start
    timeout /t 2 >nul
)

:: 4. Обновляем динамические модели
call relay-ai providers refresh-models custom-antigravity >nul 2>&1

echo.
echo [v] Запускаю выбор модели и Claude Desktop...
echo.
echo Напоминание для Claude Desktop:
echo  1. Меню Help -^> Troubleshooting -^> Enable Developer Mode
echo  2. Переключите режим на: Code
echo.

call relay-ai claude-app
pause
