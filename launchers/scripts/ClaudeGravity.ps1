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

# 1. Проверяем привязанные аккаунты Google
$accList = cmd.exe /c "acc accounts list" 2>$null
$hasAccount = $false
if ($accList -match "([1-9][0-9]*) account\(s\)") {
  $hasAccount = $true
}

if (-not $hasAccount) {
  Write-Host "[!] Не найдено привязанных аккаунтов Google (Google AI / Antigravity)."
  $reply = Read-Host "Привязать аккаунт Google прямо сейчас? [Y/n]"
  if ($reply -eq "" -or $reply -match "^[Yy]") {
    Write-Host "Останавливаю прокси перед привязкой..."
    acc stop | Out-Null
    cmd.exe /c "acc accounts add"
  }
}

# 2. Проверяем и запускаем прокси
try {
  $res = Invoke-RestMethod $HealthUrl -TimeoutSec 2
} catch {
  Write-Host ""
  Write-Host "Запускаю Antigravity proxy..."
  acc start
  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "[✓] Запускаю Claude Desktop..."
Write-Host ""
Write-Host "Напоминание для Claude Desktop:"
Write-Host " 1. Меню Help -> Troubleshooting -> Enable Developer Mode"
Write-Host " 2. Переключите режим на: Code"
Write-Host " 3. Выберите любую доступную модель Google внизу окна"
Write-Host ""

relay-ai claude-app
Pause-End
