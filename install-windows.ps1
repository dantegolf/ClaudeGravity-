$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:USERPROFILE "Documents\ClaudeGravity"
$ScriptsDir = Join-Path $InstallDir "scripts"
$NpmUserDir = Join-Path $env:APPDATA "npm"
$NodeDir = Join-Path $env:ProgramFiles "nodejs"
$ProxyPackage = "antigravity-claude-proxy@2.8.5"
$RelayPackage = "@jacobbd/relay-ai@0.9.0"

function Say($Message) {
  Write-Host ""
  Write-Host "==> $Message"
}

Say "Установка ClaudeGravity для Windows"

if (-not (Get-Command node.exe -ErrorAction SilentlyContinue) -or -not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Say "Устанавливаю Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
      throw "Не удалось установить Node.js через winget (код $LASTEXITCODE)."
    }
    $env:Path = "$NpmUserDir;$NodeDir;$env:Path"
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
$env:Path = "$NpmUserDir;$NodeDir;$env:Path"

Say "Установка компонентов прокси и реле..."
$npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npmCommand) {
  throw "npm.cmd не найден после установки Node.js. Перезапустите PowerShell и установщик."
}
& $npmCommand.Source install -g $ProxyPackage $RelayPackage
if ($LASTEXITCODE -ne 0) {
  throw "npm не смог установить компоненты ClaudeGravity (код $LASTEXITCODE)."
}

$env:Path = "$NpmUserDir;$NodeDir;$env:Path"
if (-not (Get-Command acc.cmd -ErrorAction SilentlyContinue) -or -not (Get-Command relay-ai.cmd -ErrorAction SilentlyContinue)) {
  throw "Компоненты установлены, но команды acc.cmd или relay-ai.cmd не найдены."
}

Say "Создаю ярлыки в $InstallDir..."
New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null

$claudePs1 = @(
  '$ErrorActionPreference = "Stop"',
  '$HealthUrl = "http://127.0.0.1:8080/health"',
  '$NpmUserDir = Join-Path $env:APPDATA "npm"',
  '$NodeDir = Join-Path $env:ProgramFiles "nodejs"',
  '$env:Path = "$NpmUserDir;$NodeDir;$env:Path"',
  '',
  '$env:RELAY_AI_HOME = Join-Path $env:USERPROFILE ".relay-ai"',
  '$env:ANTIGRAVITY_API_KEY = "antigravity"',
  '$env:RELAY_AI_KEY_CUSTOM_ANTIGRAVITY = "antigravity"',
  '',
  'function Write-Utf8NoBom($Path, $Content) {',
  '  $encoding = New-Object System.Text.UTF8Encoding($false)',
  '  [System.IO.File]::WriteAllText($Path, $Content, $encoding)',
  '}',
  '',
  'function Test-Proxy {',
  '  try {',
  '    Invoke-RestMethod $HealthUrl -TimeoutSec 2 | Out-Null',
  '    return $true',
  '  } catch {',
  '    return $false',
  '  }',
  '}',
  '',
  'function Ensure-RelayProvider {',
  '  $relayDir = $env:RELAY_AI_HOME',
  '  $providersJsonPath = Join-Path $relayDir "providers.json"',
  '  $secretsJsonPath = Join-Path $relayDir "secrets.json"',
  '',
  '  if (-not (Test-Path -LiteralPath $relayDir)) {',
  '    New-Item -ItemType Directory -Force -Path $relayDir | Out-Null',
  '  }',
  '',
  '  $needsSecrets = $true',
  '  if (Test-Path -LiteralPath $secretsJsonPath) {',
  '    try {',
  '      $secContent = Get-Content -LiteralPath $secretsJsonPath -Raw',
  '      $secContent | ConvertFrom-Json | Out-Null',
  '      if ($secContent -match "provider:custom-antigravity") {',
  '        $needsSecrets = $false',
  '      }',
  '    } catch {',
  '      $needsSecrets = $true',
  '    }',
  '  }',
  '',
  '  if ($needsSecrets) {',
  '    $secJson = ''{"version":1,"accounts":{"provider:custom-antigravity":"antigravity"}}''',
  '    Write-Utf8NoBom $secretsJsonPath $secJson',
  '  } else {',
  '    Write-Utf8NoBom $secretsJsonPath $secContent',
  '  }',
  '',
  '  $needsConfig = $true',
  '  if (Test-Path -LiteralPath $providersJsonPath) {',
  '    try {',
  '      $content = Get-Content -LiteralPath $providersJsonPath -Raw',
  '      $content | ConvertFrom-Json | Out-Null',
  '      if ($content -match "addedAt" -and $content -match "gemini-3.6-flash-high") {',
  '        $needsConfig = $false',
  '      }',
  '    } catch {',
  '      $needsConfig = $true',
  '    }',
  '  }',
  '',
  '  if ($needsConfig) {',
  '    $jsonContent = ''{"schemaVersion":1,"providers":[{"id":"custom-antigravity","templateId":"custom-anthropic","name":"Antigravity","enabled":true,"authRef":"keyring:provider:custom-antigravity","addedAt":"2026-08-11T00:00:00.000Z","refreshedAt":"2026-08-11T00:00:00.000Z","api":{"npm":"@ai-sdk/anthropic","url":"http://127.0.0.1:8080"},"modelsCache":{"fetchedAt":"2026-08-11T00:00:00.000Z","models":[{"id":"gemini-3.6-flash-high","name":"gemini-3.6-flash-high","upstreamModelId":"gemini-3.6-flash-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-sonnet-4-6","name":"claude-sonnet-4-6","upstreamModelId":"claude-sonnet-4-6","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-pro","name":"gemini-2.5-pro","upstreamModelId":"gemini-2.5-pro","family":"gemini","brand":"Gemini","contextWindow":2000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-opus-4-6-thinking","name":"claude-opus-4-6-thinking","upstreamModelId":"claude-opus-4-6-thinking","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash","name":"gemini-2.5-flash","upstreamModelId":"gemini-2.5-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-lite","name":"gemini-2.5-flash-lite","upstreamModelId":"gemini-2.5-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-thinking","name":"gemini-2.5-flash-thinking","upstreamModelId":"gemini-2.5-flash-thinking","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash","name":"gemini-3-flash","upstreamModelId":"gemini-3-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash-agent","name":"gemini-3-flash-agent","upstreamModelId":"gemini-3-flash-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-image","name":"gemini-3.1-flash-image","upstreamModelId":"gemini-3.1-flash-image","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-lite","name":"gemini-3.1-flash-lite","upstreamModelId":"gemini-3.1-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-high","name":"gemini-3.1-pro-high","upstreamModelId":"gemini-3.1-pro-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-low","name":"gemini-3.1-pro-low","upstreamModelId":"gemini-3.1-pro-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-extra-low","name":"gemini-3.5-flash-extra-low","upstreamModelId":"gemini-3.5-flash-extra-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-low","name":"gemini-3.5-flash-low","upstreamModelId":"gemini-3.5-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-low","name":"gemini-3.6-flash-low","upstreamModelId":"gemini-3.6-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-medium","name":"gemini-3.6-flash-medium","upstreamModelId":"gemini-3.6-flash-medium","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-tiered","name":"gemini-3.6-flash-tiered","upstreamModelId":"gemini-3.6-flash-tiered","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-pro-agent","name":"gemini-pro-agent","upstreamModelId":"gemini-pro-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"}]}}]}''',
  '    Write-Utf8NoBom $providersJsonPath $jsonContent',
  '  } else {',
  '    Write-Utf8NoBom $providersJsonPath $content',
  '  }',
  '}',
  '',
  'function Pause-End {',
  '  Write-Host ""',
  '  Write-Host "Нажмите любую клавишу для закрытия..."',
  '  [Console]::ReadKey($true) | Out-Null',
  '}',
  '',
  'function Start-ClaudeGravity {',
  '  Clear-Host',
  '  Write-Host "========================================="',
  '  Write-Host "         ClaudeGravity Launcher          "',
  '  Write-Host "========================================="',
  '  Write-Host ""',
  '',
  '  $relayCommand = Get-Command relay-ai.cmd -ErrorAction SilentlyContinue',
  '  $accCommand = Get-Command acc.cmd -ErrorAction SilentlyContinue',
  '  if (-not $relayCommand -or -not $accCommand) {',
  '    throw "Компоненты ClaudeGravity не найдены. Запустите установщик заново."',
  '  }',
  '',
  '  # 1. Проверяем регистрацию провайдера Antigravity в relay-ai',
  '  Ensure-RelayProvider',
  '  $providerList = & $relayCommand.Source providers list 2>&1',
  '  if ($LASTEXITCODE -ne 0 -or $providerList -notmatch "custom-antigravity") {',
  '    throw "Relay AI не смог прочитать конфигурацию Antigravity."',
  '  }',
  '',
  '  # 2. Проверяем привязанные аккаунты Google',
  '  $accList = & $accCommand.Source accounts list 2>$null',
  '  if ($LASTEXITCODE -ne 0) {',
  '    throw "Не удалось проверить аккаунты Google."',
  '  }',
  '  $hasAccount = $accList -match "([1-9][0-9]*) account\(s\)"',
  '',
  '  if (-not $hasAccount) {',
  '    Write-Host "[!] Не найдено привязанных аккаунтов Google (Google AI / Antigravity)."',
  '    $reply = Read-Host "Привязать аккаунт Google прямо сейчас? [Y/n]"',
  '    if ($reply -eq "" -or $reply -match "^[Yy]") {',
  '      Write-Host "Останавливаю прокси перед привязкой..."',
  '      & $accCommand.Source stop | Out-Null',
  '      & $accCommand.Source accounts add',
  '      if ($LASTEXITCODE -ne 0) {',
  '        throw "Не удалось привязать аккаунт Google."',
  '      }',
  '    } else {',
  '      throw "Для запуска необходимо привязать аккаунт Google."',
  '    }',
  '  }',
  '',
  '  # 3. Проверяем и запускаем прокси',
  '  if (-not (Test-Proxy)) {',
  '    Write-Host ""',
  '    Write-Host "Запускаю Antigravity proxy..."',
  '    & $accCommand.Source start',
  '    if ($LASTEXITCODE -ne 0) {',
  '      throw "Не удалось запустить Antigravity proxy."',
  '    }',
  '',
  '    $proxyReady = $false',
  '    for ($attempt = 0; $attempt -lt 10; $attempt++) {',
  '      if (Test-Proxy) {',
  '        $proxyReady = $true',
  '        break',
  '      }',
  '      Start-Sleep -Seconds 1',
  '    }',
  '    if (-not $proxyReady) {',
  '      throw "Прокси не ответил на $HealthUrl."',
  '    }',
  '  }',
  '',
  '  Write-Host "[✓] Прокси и конфигурация Antigravity готовы."',
  '',
  '  Write-Host ""',
  '  Write-Host "[✓] Запускаю выбор модели и Claude Desktop..."',
  '  Write-Host ""',
  '  Write-Host "Напоминание для Claude Desktop:"',
  '  Write-Host " 1. Меню Help -> Troubleshooting -> Enable Developer Mode"',
  '  Write-Host " 2. Переключите режим на: Code"',
  '  Write-Host ""',
  '',
  '  & $relayCommand.Source claude-app',
  '  if ($LASTEXITCODE -ne 0) {',
  '    throw "Relay AI завершился с ошибкой."',
  '  }',
  '}',
  '',
  'try {',
  '  Start-ClaudeGravity',
  '  Pause-End',
  '} catch {',
  '  Write-Host ""',
  '  Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red',
  '  Pause-End',
  '  exit 1',
  '}'
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

Say "Файлы установлены. Проверяю запуск..."

& (Join-Path $ScriptsDir "ClaudeGravity.ps1")
