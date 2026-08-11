$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:USERPROFILE "Documents\ClaudeGravity"
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

$claudePs1 = @(
  '$ErrorActionPreference = "Continue"',
  '$HealthUrl = "http://127.0.0.1:8080/health"',
  '$NpmUserDir = Join-Path $env:APPDATA "npm"',
  '$env:Path = "$NpmUserDir;$env:Path"',
  '$env:RELAY_AI_HOME = Join-Path $env:USERPROFILE ".relay-ai"',
  '$env:ANTIGRAVITY_API_KEY = "antigravity"',
  '',
  'function Ensure-RelayProvider {',
  '  $relayDir = $env:RELAY_AI_HOME',
  '  $providersJsonPath = Join-Path $relayDir "providers.json"',
  '',
  '  if (-not (Test-Path -LiteralPath $relayDir)) {',
  '    New-Item -ItemType Directory -Force -Path $relayDir | Out-Null',
  '  }',
  '',
  '  $needsConfig = $true',
  '  if (Test-Path -LiteralPath $providersJsonPath) {',
  '    $content = Get-Content -LiteralPath $providersJsonPath -Raw -ErrorAction SilentlyContinue',
  '    if ($content -match "env:ANTIGRAVITY_API_KEY" -and $content -match "addedAt" -and $content -match "gemini-3.6-flash-high") {',
  '      $needsConfig = $false',
  '    }',
  '  }',
  '',
  '  if ($needsConfig) {',
  '    $jsonContent = ''{"schemaVersion":1,"providers":[{"id":"custom-antigravity","templateId":"custom-anthropic","name":"Antigravity","enabled":true,"authRef":"env:ANTIGRAVITY_API_KEY","addedAt":"2026-08-11T00:00:00.000Z","refreshedAt":"2026-08-11T00:00:00.000Z","api":{"npm":"@ai-sdk/anthropic","url":"http://127.0.0.1:8080"},"modelsCache":{"fetchedAt":"2026-08-11T00:00:00.000Z","models":[{"id":"gemini-3.6-flash-high","name":"gemini-3.6-flash-high","upstreamModelId":"gemini-3.6-flash-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-sonnet-4-6","name":"claude-sonnet-4-6","upstreamModelId":"claude-sonnet-4-6","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-pro","name":"gemini-2.5-pro","upstreamModelId":"gemini-2.5-pro","family":"gemini","brand":"Gemini","contextWindow":2000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-opus-4-6-thinking","name":"claude-opus-4-6-thinking","upstreamModelId":"claude-opus-4-6-thinking","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash","name":"gemini-2.5-flash","upstreamModelId":"gemini-2.5-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-lite","name":"gemini-2.5-flash-lite","upstreamModelId":"gemini-2.5-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-thinking","name":"gemini-2.5-flash-thinking","upstreamModelId":"gemini-2.5-flash-thinking","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash","name":"gemini-3-flash","upstreamModelId":"gemini-3-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash-agent","name":"gemini-3-flash-agent","upstreamModelId":"gemini-3-flash-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-image","name":"gemini-3.1-flash-image","upstreamModelId":"gemini-3.1-flash-image","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-lite","name":"gemini-3.1-flash-lite","upstreamModelId":"gemini-3.1-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-high","name":"gemini-3.1-pro-high","upstreamModelId":"gemini-3.1-pro-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-low","name":"gemini-3.1-pro-low","upstreamModelId":"gemini-3.1-pro-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-extra-low","name":"gemini-3.5-flash-extra-low","upstreamModelId":"gemini-3.5-flash-extra-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-low","name":"gemini-3.5-flash-low","upstreamModelId":"gemini-3.5-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-low","name":"gemini-3.6-flash-low","upstreamModelId":"gemini-3.6-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-medium","name":"gemini-3.6-flash-medium","upstreamModelId":"gemini-3.6-flash-medium","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-tiered","name":"gemini-3.6-flash-tiered","upstreamModelId":"gemini-3.6-flash-tiered","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-pro-agent","name":"gemini-pro-agent","upstreamModelId":"gemini-pro-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"}]}}]}''',
  '    Set-Content -LiteralPath $providersJsonPath -Value $jsonContent -Encoding UTF8',
  '  }',
  '}',
  '',
  'function Pause-End {',
  '  Write-Host ""',
  '  Write-Host "Нажмите любую клавишу для закрытия..."',
  '  [Console]::ReadKey($true) | Out-Null',
  '}',
  '',
  'Clear-Host',
  'Write-Host "========================================="',
  'Write-Host "         ClaudeGravity Launcher          "',
  'Write-Host "========================================="',
  'Write-Host ""',
  '',
  'if (-not (Get-Command relay-ai -ErrorAction SilentlyContinue)) {',
  '  Write-Host "Ошибка: Relay AI не найден. Запустите установщик заново."',
  '  Pause-End',
  '  exit 1',
  '}',
  '',
  '# 1. Проверяем регистрацию провайдера Antigravity в relay-ai',
  'Ensure-RelayProvider',
  '',
  '# 2. Проверяем привязанные аккаунты Google',
  '$accList = cmd.exe /c "acc accounts list" 2>$null',
  '$hasAccount = $false',
  'if ($accList -match "([1-9][0-9]*) account\(s\)") {',
  '  $hasAccount = $true',
  '}',
  '',
  'if (-not $hasAccount) {',
  '  Write-Host "[!] Не найдено привязанных аккаунтов Google (Google AI / Antigravity)."',
  '  $reply = Read-Host "Привязать аккаунт Google прямо сейчас? [Y/n]"',
  '  if ($reply -eq "" -or $reply -match "^[Yy]") {',
  '    Write-Host "Останавливаю прокси перед привязкой..."',
  '    acc stop | Out-Null',
  '    cmd.exe /c "acc accounts add"',
  '  }',
  '}',
  '',
  '# 3. Проверяем и запускаем прокси',
  'try {',
  '  $res = Invoke-RestMethod $HealthUrl -TimeoutSec 2',
  '} catch {',
  '  Write-Host ""',
  '  Write-Host "Запускаю Antigravity proxy..."',
  '  acc start',
  '  Start-Sleep -Seconds 2',
  '}',
  '',
  'Write-Host ""',
  'Write-Host "[✓] Запускаю выбор модели и Claude Desktop..."',
  'Write-Host ""',
  'Write-Host "Напоминание для Claude Desktop:"',
  'Write-Host " 1. Меню Help -> Troubleshooting -> Enable Developer Mode"',
  'Write-Host " 2. Переключите режим на: Code"',
  'Write-Host ""',
  '',
  'relay-ai claude-app',
  'Pause-End'
)
$claudePs1 | Set-Content -Encoding UTF8 (Join-Path $ScriptsDir "ClaudeGravity.ps1")

$claudeCmd = @(
  '@echo off',
  'powershell -ExecutionPolicy Bypass -File "%~dp0scripts\ClaudeGravity.ps1"'
)
$claudeCmd | Set-Content -Encoding ASCII (Join-Path $InstallDir "ClaudeGravity.cmd")

$limitsPs1 = @(
  '$ErrorActionPreference = "Continue"',
  'Clear-Host',
  'Write-Host "=== Лимиты ClaudeGravity ==="',
  'Write-Host ""',
  '',
  'try {',
  '  Invoke-RestMethod http://127.0.0.1:8080/health | ConvertTo-Json -Depth 20',
  '} catch {',
  '  Write-Host "Прокси не ответил на http://127.0.0.1:8080/health"',
  '  Write-Host $_.Exception.Message',
  '}',
  '',
  'Write-Host ""',
  'Write-Host "Нажмите любую клавишу для закрытия..."',
  '[Console]::ReadKey($true) | Out-Null'
)
$limitsPs1 | Set-Content -Encoding UTF8 (Join-Path $ScriptsDir "Check-Limits.ps1")

$limitsCmd = @(
  '@echo off',
  'powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Check-Limits.ps1"'
)
$limitsCmd | Set-Content -Encoding ASCII (Join-Path $InstallDir "Check-Limits.cmd")

Say "Установка завершена!"

& (Join-Path $ScriptsDir "ClaudeGravity.ps1")
