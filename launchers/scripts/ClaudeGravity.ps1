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
