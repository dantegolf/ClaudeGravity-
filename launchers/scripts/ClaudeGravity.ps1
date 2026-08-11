$ErrorActionPreference = "Continue"
$HealthUrl = "http://127.0.0.1:8080/health"
$NpmUserDir = Join-Path $env:APPDATA "npm"
$env:Path = "$NpmUserDir;$env:Path"

$env:RELAY_AI_HOME = Join-Path $env:USERPROFILE ".relay-ai"
$env:ANTIGRAVITY_API_KEY = "antigravity"
$env:RELAY_AI_KEY_CUSTOM_ANTIGRAVITY = "antigravity"

function Ensure-RelayProvider {
  $relayDir = $env:RELAY_AI_HOME
  $providersJsonPath = Join-Path $relayDir "providers.json"
  $secretsJsonPath = Join-Path $relayDir "secrets.json"

  if (-not (Test-Path -LiteralPath $relayDir)) {
    New-Item -ItemType Directory -Force -Path $relayDir | Out-Null
  }

  $needsSecrets = $true
  if (Test-Path -LiteralPath $secretsJsonPath) {
    $secContent = Get-Content -LiteralPath $secretsJsonPath -Raw -ErrorAction SilentlyContinue
    if ($secContent -match "provider:custom-antigravity") {
      $needsSecrets = $false
    }
  }

  if ($needsSecrets) {
    $secJson = '{"version":1,"accounts":{"provider:custom-antigravity":"antigravity"}}'
    Set-Content -LiteralPath $secretsJsonPath -Value $secJson -Encoding UTF8
  }

  $needsConfig = $true
  if (Test-Path -LiteralPath $providersJsonPath) {
    $content = Get-Content -LiteralPath $providersJsonPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "addedAt" -and $content -match "gemini-3.6-flash-high") {
      $needsConfig = $false
    }
  }

  if ($needsConfig) {
    $jsonContent = '{"schemaVersion":1,"providers":[{"id":"custom-antigravity","templateId":"custom-anthropic","name":"Antigravity","enabled":true,"authRef":"keyring:provider:custom-antigravity","addedAt":"2026-08-11T00:00:00.000Z","refreshedAt":"2026-08-11T00:00:00.000Z","api":{"npm":"@ai-sdk/anthropic","url":"http://127.0.0.1:8080"},"modelsCache":{"fetchedAt":"2026-08-11T00:00:00.000Z","models":[{"id":"gemini-3.6-flash-high","name":"gemini-3.6-flash-high","upstreamModelId":"gemini-3.6-flash-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-sonnet-4-6","name":"claude-sonnet-4-6","upstreamModelId":"claude-sonnet-4-6","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-pro","name":"gemini-2.5-pro","upstreamModelId":"gemini-2.5-pro","family":"gemini","brand":"Gemini","contextWindow":2000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-opus-4-6-thinking","name":"claude-opus-4-6-thinking","upstreamModelId":"claude-opus-4-6-thinking","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash","name":"gemini-2.5-flash","upstreamModelId":"gemini-2.5-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-lite","name":"gemini-2.5-flash-lite","upstreamModelId":"gemini-2.5-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-thinking","name":"gemini-2.5-flash-thinking","upstreamModelId":"gemini-2.5-flash-thinking","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash","name":"gemini-3-flash","upstreamModelId":"gemini-3-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash-agent","name":"gemini-3-flash-agent","upstreamModelId":"gemini-3-flash-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-image","name":"gemini-3.1-flash-image","upstreamModelId":"gemini-3.1-flash-image","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-lite","name":"gemini-3.1-flash-lite","upstreamModelId":"gemini-3.1-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-high","name":"gemini-3.1-pro-high","upstreamModelId":"gemini-3.1-pro-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-low","name":"gemini-3.1-pro-low","upstreamModelId":"gemini-3.1-pro-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-extra-low","name":"gemini-3.5-flash-extra-low","upstreamModelId":"gemini-3.5-flash-extra-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-low","name":"gemini-3.5-flash-low","upstreamModelId":"gemini-3.5-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-low","name":"gemini-3.6-flash-low","upstreamModelId":"gemini-3.6-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-medium","name":"gemini-3.6-flash-medium","upstreamModelId":"gemini-3.6-flash-medium","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-tiered","name":"gemini-3.6-flash-tiered","upstreamModelId":"gemini-3.6-flash-tiered","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-pro-agent","name":"gemini-pro-agent","upstreamModelId":"gemini-pro-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"}]}}]}'
    Set-Content -LiteralPath $providersJsonPath -Value $jsonContent -Encoding UTF8
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
