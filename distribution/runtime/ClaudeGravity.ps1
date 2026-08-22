param(
  [switch]$Foreground
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptsDir = Join-Path $Root "scripts"
$Supervisor = Join-Path $ScriptsDir "supervisor.mjs"

$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $nodeCommand) {
  throw "Node.js 18+ не найден. Повторно запустите установщик ClaudeGravity."
}
$Node = $nodeCommand.Source
$nodeMajor = [int]((& $Node -p "process.versions.node.split('.')[0]").Trim())
if ($nodeMajor -lt 18) {
  throw "Требуется Node.js 18 или новее."
}
if (-not (Test-Path -LiteralPath $Supervisor)) {
  throw "ClaudeGravity supervisor не найден. Переустановите ClaudeGravity."
}

if (-not $env:RELAY_AI_HOME) { $env:RELAY_AI_HOME = Join-Path $env:USERPROFILE ".relay-ai" }
if (-not $env:ANTIGRAVITY_API_KEY) { $env:ANTIGRAVITY_API_KEY = "antigravity" }
if (-not $env:RELAY_AI_KEY_CUSTOM_ANTIGRAVITY) { $env:RELAY_AI_KEY_CUSTOM_ANTIGRAVITY = "antigravity" }
if (-not $env:CLAUDEGRAVITY_STATE_DIR) { $env:CLAUDEGRAVITY_STATE_DIR = Join-Path $env:USERPROFILE ".claudegravity" }

if ($Foreground -or $env:CLAUDEGRAVITY_FOREGROUND -eq "1") {
  $env:CLAUDEGRAVITY_FOREGROUND_LOGS = "1"
  & $Node $Supervisor
  exit $LASTEXITCODE
}

New-Item -ItemType Directory -Force -Path $env:CLAUDEGRAVITY_STATE_DIR | Out-Null
$argument = '"' + $Supervisor + '"'
Start-Process -FilePath $Node -ArgumentList $argument -WindowStyle Hidden
exit 0
