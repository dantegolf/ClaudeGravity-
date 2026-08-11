$ErrorActionPreference = "Continue"
$HealthUrl = "http://127.0.0.1:8080/health"
$NpmUserDir = Join-Path $env:APPDATA "npm"
$env:Path = "$NpmUserDir;$env:Path"

function Ensure-RelayProvider {
  $relayDir = Join-Path $HOME ".relay-ai"
  $providersJsonPath = Join-Path $relayDir "providers.json"

  if (-not (Test-Path $relayDir)) {
    New-Item -ItemType Directory -Force -Path $relayDir | Out-Null
  }

  $needsConfig = $true
  if (Test-Path $providersJsonPath) {
    $content = Get-Content $providersJsonPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "custom-antigravity") {
      $needsConfig = $false
    }
  }

  if ($needsConfig) {
    $jsonContent = '{"schemaVersion":1,"providers":[{"id":"custom-antigravity","templateId":"custom-anthropic","name":"Antigravity","enabled":true,"authRef":"keyring:provider:custom-antigravity","api":{"npm":"@ai-sdk/anthropic","url":"http://127.0.0.1:8080"},"modelsCache":{"fetchedAt":"2026-08-11T00:00:00.000Z","models":[{"id":"gemini-3.6-flash-high","name":"gemini-3.6-flash-high","upstreamModelId":"gemini-3.6-flash-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-sonnet-4-6","name":"claude-sonnet-4-6","upstreamModelId":"claude-sonnet-4-6","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-pro","name":"gemini-2.5-pro","upstreamModelId":"gemini-2.5-pro","family":"gemini","brand":"Gemini","contextWindow":2000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"}]}}]}'
    Set-Content -Encoding UTF8 $providersJsonPath $jsonContent
  }
}

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

# 1. Проверяем регистрацию провайдера Antigravity в relay-ai
Ensure-RelayProvider

# 2. Проверяем привязанные аккаунты Google
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

# 3. Проверяем и запускаем прокси
try {
  $res = Invoke-RestMethod $HealthUrl -TimeoutSec 2
} catch {
  Write-Host ""
  Write-Host "Запускаю Antigravity proxy..."
  acc start
  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "[✓] Запускаю выбор модели и Claude Desktop..."
Write-Host ""
Write-Host "Напоминание для Claude Desktop:"
Write-Host " 1. Меню Help -> Troubleshooting -> Enable Developer Mode"
Write-Host " 2. Переключите режим на: Code"
Write-Host ""

relay-ai claude-app
Pause-End
