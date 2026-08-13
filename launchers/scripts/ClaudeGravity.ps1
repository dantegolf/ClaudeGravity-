$ErrorActionPreference = "Stop"
$HealthUrl = "http://127.0.0.1:8080/health"
$NpmUserDir = Join-Path $env:APPDATA "npm"
$NodeDir = Join-Path $env:ProgramFiles "nodejs"
$env:Path = "$NpmUserDir;$NodeDir;$env:Path"

$env:RELAY_AI_HOME = Join-Path $env:USERPROFILE ".relay-ai"
$env:ANTIGRAVITY_API_KEY = "antigravity"
$env:RELAY_AI_KEY_CUSTOM_ANTIGRAVITY = "antigravity"

function Write-Utf8NoBom($Path, $Content) {
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Test-Proxy {
  try {
    Invoke-RestMethod $HealthUrl -TimeoutSec 2 | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Ensure-RelayProvider {
  $relayDir = $env:RELAY_AI_HOME
  $providersJsonPath = Join-Path $relayDir "providers.json"
  $secretsJsonPath = Join-Path $relayDir "secrets.json"

  if (-not (Test-Path -LiteralPath $relayDir)) {
    New-Item -ItemType Directory -Force -Path $relayDir | Out-Null
  }

  $needsSecrets = $true
  if (Test-Path -LiteralPath $secretsJsonPath) {
    try {
      $secContent = Get-Content -LiteralPath $secretsJsonPath -Raw
      $secContent | ConvertFrom-Json | Out-Null
      if ($secContent -match "provider:custom-antigravity") {
        $needsSecrets = $false
      }
    } catch {
      $needsSecrets = $true
    }
  }

  if ($needsSecrets) {
    $secJson = '{"version":1,"accounts":{"provider:custom-antigravity":"antigravity"}}'
    Write-Utf8NoBom $secretsJsonPath $secJson
  } else {
    Write-Utf8NoBom $secretsJsonPath $secContent
  }

  $needsConfig = $true
  if (Test-Path -LiteralPath $providersJsonPath) {
    try {
      $content = Get-Content -LiteralPath $providersJsonPath -Raw
      $config = $content | ConvertFrom-Json
      $provider = @($config.providers | Where-Object { $_.id -eq "custom-antigravity" })[0]
      $modelIds = @($provider.modelsCache.models | ForEach-Object { $_.id })
      if ($provider -and
          $provider.templateId -eq "custom-anthropic" -and
          $provider.name -eq "Antigravity" -and
          $provider.enabled -eq $true -and
          $provider.authRef -eq "keyring:provider:custom-antigravity" -and
          $provider.addedAt -and
          $provider.api.url -eq "http://127.0.0.1:8080" -and
          $modelIds.Count -eq 22 -and
          $modelIds -contains "gemini-3.7-flash-low" -and
          $modelIds -contains "gemini-3.7-flash-medium" -and
          $modelIds -contains "gemini-3.7-flash-high") {
        $needsConfig = $false
      }
    } catch {
      $needsConfig = $true
    }
  }

  if ($needsConfig) {
    $jsonContent = '{"schemaVersion":1,"providers":[{"id":"custom-antigravity","templateId":"custom-anthropic","name":"Antigravity","enabled":true,"authRef":"keyring:provider:custom-antigravity","addedAt":"2026-08-11T00:00:00.000Z","refreshedAt":"2026-08-11T00:00:00.000Z","api":{"npm":"@ai-sdk/anthropic","url":"http://127.0.0.1:8080"},"modelsCache":{"fetchedAt":"2026-08-11T00:00:00.000Z","models":[{"id":"gemini-3.6-flash-high","name":"gemini-3.6-flash-high","upstreamModelId":"gemini-3.6-flash-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-sonnet-4-6","name":"claude-sonnet-4-6","upstreamModelId":"claude-sonnet-4-6","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-pro","name":"gemini-2.5-pro","upstreamModelId":"gemini-2.5-pro","family":"gemini","brand":"Gemini","contextWindow":2000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"claude-opus-4-6-thinking","name":"claude-opus-4-6-thinking","upstreamModelId":"claude-opus-4-6-thinking","family":"claude","brand":"Claude","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash","name":"gemini-2.5-flash","upstreamModelId":"gemini-2.5-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-lite","name":"gemini-2.5-flash-lite","upstreamModelId":"gemini-2.5-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-2.5-flash-thinking","name":"gemini-2.5-flash-thinking","upstreamModelId":"gemini-2.5-flash-thinking","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash","name":"gemini-3-flash","upstreamModelId":"gemini-3-flash","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3-flash-agent","name":"gemini-3-flash-agent","upstreamModelId":"gemini-3-flash-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-image","name":"gemini-3.1-flash-image","upstreamModelId":"gemini-3.1-flash-image","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-flash-lite","name":"gemini-3.1-flash-lite","upstreamModelId":"gemini-3.1-flash-lite","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-high","name":"gemini-3.1-pro-high","upstreamModelId":"gemini-3.1-pro-high","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.1-pro-low","name":"gemini-3.1-pro-low","upstreamModelId":"gemini-3.1-pro-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-extra-low","name":"gemini-3.5-flash-extra-low","upstreamModelId":"gemini-3.5-flash-extra-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.5-flash-low","name":"gemini-3.5-flash-low","upstreamModelId":"gemini-3.5-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-low","name":"gemini-3.6-flash-low","upstreamModelId":"gemini-3.6-flash-low","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-medium","name":"gemini-3.6-flash-medium","upstreamModelId":"gemini-3.6-flash-medium","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-3.6-flash-tiered","name":"gemini-3.6-flash-tiered","upstreamModelId":"gemini-3.6-flash-tiered","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"},{"id":"gemini-pro-agent","name":"gemini-pro-agent","upstreamModelId":"gemini-pro-agent","family":"gemini","brand":"Gemini","contextWindow":1000000,"modelFormat":"anthropic","npm":"@ai-sdk/anthropic","apiUrl":"http://127.0.0.1:8080"}]}}]}'
    $jsonConfig = $jsonContent | ConvertFrom-Json
    foreach ($modelId in @("gemini-3.7-flash-low", "gemini-3.7-flash-medium", "gemini-3.7-flash-high")) {
      $jsonConfig.providers[0].modelsCache.models += [pscustomobject]@{
        id = $modelId
        name = $modelId
        upstreamModelId = $modelId
        family = "gemini"
        brand = "Gemini"
        contextWindow = 1000000
        modelFormat = "anthropic"
        npm = "@ai-sdk/anthropic"
        apiUrl = "http://127.0.0.1:8080"
      }
    }
    Write-Utf8NoBom $providersJsonPath ($jsonConfig | ConvertTo-Json -Depth 20)
  } else {
    Write-Utf8NoBom $providersJsonPath $content
  }

  $configJsonPath = Join-Path $relayDir "config.json"
  try {
    if (Test-Path -LiteralPath $configJsonPath) {
      $preferences = Get-Content -LiteralPath $configJsonPath -Raw | ConvertFrom-Json
    } else {
      $preferences = New-Object PSObject
    }
  } catch {
    $preferences = New-Object PSObject
  }

  if ($preferences.claudeGravityFavoritesVersion -ne 2) {
    $favorites = @($preferences.favoriteModels | Where-Object { $_.providerId -and $_.modelId })
    $defaultModels = @(
      "gemini-3.7-flash-high",
      "gemini-3.1-pro-high",
      "claude-sonnet-4-6",
      "claude-opus-4-6-thinking",
      "gemini-2.5-pro"
    )
    foreach ($modelId in $defaultModels) {
      $exists = @($favorites | Where-Object {
        $_.providerId -eq "custom-antigravity" -and $_.modelId -eq $modelId
      }).Count -gt 0
      if (-not $exists -and $favorites.Count -lt 20) {
        $favorites += [pscustomobject]@{
          providerId = "custom-antigravity"
          modelId = $modelId
        }
      }
    }
    $preferences | Add-Member -NotePropertyName "favoriteModels" -NotePropertyValue @($favorites) -Force
    $preferences | Add-Member -NotePropertyName "claudeGravityFavoritesVersion" -NotePropertyValue 2 -Force
    Write-Utf8NoBom $configJsonPath ($preferences | ConvertTo-Json -Depth 20)
  }
}

function Pause-End {
  Write-Host ""
  Write-Host "Нажмите любую клавишу для закрытия..."
  [Console]::ReadKey($true) | Out-Null
}

function Start-ClaudeGravity {
  Clear-Host
  Write-Host "========================================="
  Write-Host "         ClaudeGravity Launcher          "
  Write-Host "========================================="
  Write-Host ""

  $npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($npmCommand) {
    Write-Host "Проверяю обновления компонентов..."
    & $npmCommand.Source install -g antigravity-claude-proxy@latest @jacobbd/relay-ai@latest --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) {
      Write-Host "[!] Обновление не удалось; использую установленные версии." -ForegroundColor Yellow
    }
    $npmRoot = (& $npmCommand.Source root -g | Select-Object -Last 1).Trim()
    $proxyRoot = Join-Path $npmRoot "antigravity-claude-proxy"
    & node.exe (Join-Path $PSScriptRoot "patch-antigravity-proxy.mjs") $proxyRoot
    if ($LASTEXITCODE -ne 0) {
      throw "Установленный Antigravity proxy несовместим с протоколом 2.8. Переустановите ClaudeGravity или обновите compatibility patch."
    }
    Write-Host ""
  }

  $relayCommand = Get-Command relay-ai.cmd -ErrorAction SilentlyContinue
  $accCommand = Get-Command acc.cmd -ErrorAction SilentlyContinue
  if (-not $relayCommand -or -not $accCommand) {
    throw "Компоненты ClaudeGravity не найдены. Запустите установщик заново."
  }

  # Запущенный Node-процесс продолжает использовать модули до обновления.
  & $accCommand.Source stop | Out-Null

  # 1. Проверяем регистрацию провайдера Antigravity в relay-ai
  Ensure-RelayProvider
  $providerList = & $relayCommand.Source providers list 2>&1
  $providerOutput = $providerList -join [Environment]::NewLine
  if ($providerOutput -notmatch "custom-antigravity") {
    $details = $providerOutput.Trim()
    if (-not $details) {
      $details = "relay-ai завершился с кодом $LASTEXITCODE."
    }
    throw "Relay AI не смог прочитать конфигурацию Antigravity.`n$details"
  }

  # 2. Проверяем привязанные аккаунты Google
  $accList = & $accCommand.Source accounts list 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Не удалось проверить аккаунты Google."
  }
  $hasAccount = $accList -match "([1-9][0-9]*) account\(s\)"

  if (-not $hasAccount) {
    Write-Host "[!] Не найдено привязанных аккаунтов Google (Google AI / Antigravity)."
    $reply = Read-Host "Привязать аккаунт Google прямо сейчас? [Y/n]"
    if ($reply -eq "" -or $reply -match "^[Yy]") {
      Write-Host "Останавливаю прокси перед привязкой..."
      & $accCommand.Source stop | Out-Null
      & $accCommand.Source accounts add
      if ($LASTEXITCODE -ne 0) {
        throw "Не удалось привязать аккаунт Google."
      }
    } else {
      throw "Для запуска необходимо привязать аккаунт Google."
    }
  }

  # 3. Проверяем и запускаем прокси
  if (-not (Test-Proxy)) {
    Write-Host ""
    Write-Host "Запускаю Antigravity proxy..."
    & $accCommand.Source start
    if ($LASTEXITCODE -ne 0) {
      throw "Не удалось запустить Antigravity proxy."
    }

    $proxyReady = $false
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
      if (Test-Proxy) {
        $proxyReady = $true
        break
      }
      Start-Sleep -Seconds 1
    }
    if (-not $proxyReady) {
      throw "Прокси не ответил на $HealthUrl."
    }
  }

  Write-Host "[✓] Прокси и конфигурация Antigravity готовы."

  Write-Host ""
  Write-Host "[✓] Запускаю выбор модели и Claude Desktop..."
  Write-Host ""
  Write-Host "Напоминание для Claude Desktop:"
  Write-Host " 1. Меню Help -> Troubleshooting -> Enable Developer Mode"
  Write-Host " 2. Переключите режим на: Code"
  Write-Host ""

  & $relayCommand.Source claude-app
  if ($LASTEXITCODE -ne 0) {
    throw "Relay AI завершился с ошибкой."
  }
}

try {
  Start-ClaudeGravity
  Pause-End
} catch {
  Write-Host ""
  Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
  Pause-End
  exit 1
}
