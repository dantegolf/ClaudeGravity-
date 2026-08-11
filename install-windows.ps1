$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $HOME "Documents\ClaudeGravity"
$ScriptsDir = Join-Path $InstallDir "scripts"
$NpmUserDir = Join-Path $env:APPDATA "npm"

function Say($Message) {
  Write-Host ""
  Write-Host "==> $Message"
}

Say "Установка ClaudeGravity для Windows"

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Say "Устанавливаю Node.js LTS..."
    winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    $env:Path = "$NpmUserDir;C:\Program Files\nodejs;$env:Path"
  } else {
    Write-Host "Требуется Node.js. Установите Node.js LTS и запустите снова:"
    Write-Host "https://nodejs.org/"
    exit 1
  }
}

Say "Настройка пути npm..."
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentUserPath -notlike "*$NpmUserDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$NpmUserDir", "User")
}
$env:Path = "$NpmUserDir;$env:Path"

Say "Установка компонентов прокси и реле..."
npm install -g antigravity-claude-proxy @jacobbd/relay-ai

Say "Создаю ярлыки в $InstallDir..."
New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null

@'
$ErrorActionPreference = "Continue"
$HealthUrl = "http://127.0.0.1:8080/health"
$NpmUserDir = Join-Path $env:APPDATA "npm"
$env:Path = "$NpmUserDir;$env:Path"

function Pause-End {
  Write-Host ""
  Write-Host "Нажмите любую клавишу для закрытия..."
  [Console]::ReadKey($true) | Out-Null
}

Clear-Host
Write-Host "========================================="
Write-Host "         ClaudeGravity Launcher          "
Write-Host "========================================="
Write-Host ""

if (-not (Get-Command relay-ai -ErrorAction SilentlyContinue)) {
  Write-Host "Ошибка: Relay AI не найден. Запустите установщик заново."
  Pause-End
  exit 1
}

# 1. Проверка и запуск прокси
try {
  $res = Invoke-RestMethod $HealthUrl -TimeoutSec 2
} catch {
  Write-Host "Запускаю Antigravity proxy..."
  acc start
  Start-Sleep -Seconds 2
}

# 2. Проверка привязанных аккаунтов
try {
  $health = Invoke-RestMethod $HealthUrl -TimeoutSec 3
  if (-not $health.accounts -or $health.accounts.Count -eq 0) {
    Write-Host ""
    Write-Host "[!] Не найдено привязанных аккаунтов Google/Antigravity."
    $reply = Read-Host "Привязать аккаунт прямо сейчас? [Y/n]"
    if ($reply -eq "" -or $reply -match "^[Yy]") {
      cmd.exe /c "acc accounts add"
    }
  }
} catch {}

Write-Host ""
Write-Host "[✓] Запускаю Claude Desktop..."
Write-Host ""
Write-Host "Напоминание для Claude Desktop:"
Write-Host " 1. Меню Help -> Troubleshooting -> Enable Developer Mode"
Write-Host " 2. Переключите режим на: Code"
Write-Host " 3. Выберите модель: gemini-3.6-flash-high (Antigravity) 1M"
Write-Host ""

relay-ai claude-app
Pause-End
'@ | Set-Content -Encoding UTF8 (Join-Path $ScriptsDir "ClaudeGravity.ps1")

@'
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\ClaudeGravity.ps1"
'@ | Set-Content -Encoding ASCII (Join-Path $InstallDir "ClaudeGravity.cmd")

@'
$ErrorActionPreference = "Continue"
Clear-Host
Write-Host "=== Лимиты ClaudeGravity ==="
Write-Host ""

try {
  Invoke-RestMethod http://127.0.0.1:8080/health | ConvertTo-Json -Depth 20
} catch {
  Write-Host "Прокси не ответил на http://127.0.0.1:8080/health"
  Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Нажмите любую клавишу для закрытия..."
[Console]::ReadKey($true) | Out-Null
'@ | Set-Content -Encoding UTF8 (Join-Path $ScriptsDir "Check-Limits.ps1")

@'
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Check-Limits.ps1"
'@ | Set-Content -Encoding ASCII (Join-Path $InstallDir "Check-Limits.cmd")

Say "Установка завершена!"

& (Join-Path $ScriptsDir "ClaudeGravity.ps1")
