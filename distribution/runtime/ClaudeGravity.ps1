$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RuntimeDir = Join-Path $Root "runtime"
$ScriptsDir = Join-Path $Root "scripts"
$ProxyRoot = Join-Path $RuntimeDir "node_modules\antigravity-claude-proxy"
$AccCli = Join-Path $ProxyRoot "bin\cli.js"
$RelayCli = Join-Path $RuntimeDir "node_modules\@jacobbd\relay-ai\dist\cli.js"
$HealthUrl = "http://127.0.0.1:8080/health"

$env:RELAY_AI_HOME = Join-Path $env:USERPROFILE ".relay-ai"
$env:ANTIGRAVITY_API_KEY = "antigravity"
$env:RELAY_AI_KEY_CUSTOM_ANTIGRAVITY = "antigravity"

$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $nodeCommand) {
  throw "Node.js 18+ не найден. Повторно запустите установщик ClaudeGravity."
}
$Node = $nodeCommand.Source
$nodeMajor = [int]((& $Node -p "process.versions.node.split('.')[0]").Trim())
if ($nodeMajor -lt 18) {
  throw "Требуется Node.js 18 или новее."
}
if (-not (Test-Path -LiteralPath $AccCli)) {
  throw "Bundled Antigravity engine не найден. Переустановите ClaudeGravity."
}
if (-not (Test-Path -LiteralPath $RelayCli)) {
  throw "Bundled Relay engine не найден. Переустановите ClaudeGravity."
}

function Test-Proxy {
  try {
    Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2 | Out-Null
    return $true
  } catch {
    return $false
  }
}

Clear-Host
Write-Host "╭─────────────────────────────────────────╮"
Write-Host "│          ClaudeGravity Launcher         │"
Write-Host "╰─────────────────────────────────────────╯"
Write-Host "Runtime: bundled · Smart DNS: selective"

& $Node (Join-Path $ScriptsDir "patch-antigravity-proxy.mjs") $ProxyRoot
if ($LASTEXITCODE -ne 0) {
  throw "Bundled Antigravity engine не прошёл compatibility check."
}

& $Node $AccCli stop 2>$null | Out-Null
& $Node (Join-Path $ScriptsDir "configure-relay.mjs") $env:RELAY_AI_HOME
if ($LASTEXITCODE -ne 0) {
  throw "Не удалось подготовить конфигурацию Relay AI."
}

$providerOutput = (& $Node $RelayCli providers list 2>&1 | Out-String)
if ($providerOutput -notmatch "custom-antigravity") {
  throw "Relay AI не увидел провайдер Antigravity. $providerOutput"
}

$accountOutput = (& $Node $AccCli accounts list 2>&1 | Out-String)
if ($accountOutput -notmatch '[1-9][0-9]* account\(s\)') {
  $reply = Read-Host "Аккаунт Google ещё не привязан. Привязать сейчас? [Y/n]"
  if ($reply -and $reply -notmatch '^[Yy]$') {
    throw "Для запуска необходимо привязать аккаунт Google."
  }
  & $Node $AccCli accounts add
  if ($LASTEXITCODE -ne 0) {
    throw "Не удалось привязать аккаунт Google."
  }
}

if (-not (Test-Proxy)) {
  Write-Host ""
  Write-Host "Запускаю Antigravity engine..."
  & $Node $AccCli start
  if ($LASTEXITCODE -ne 0) {
    throw "Не удалось запустить Antigravity engine."
  }

  $ready = $false
  for ($attempt = 0; $attempt -lt 12; $attempt++) {
    if (Test-Proxy) {
      $ready = $true
      break
    }
    Start-Sleep -Seconds 1
  }
  if (-not $ready) {
    throw "Прокси не ответил на $HealthUrl."
  }
}

Write-Host ""
Write-Host "✓ ClaudeGravity готов. Открываю Claude Desktop..."
Write-Host ""
& $Node $RelayCli claude-app
exit $LASTEXITCODE
