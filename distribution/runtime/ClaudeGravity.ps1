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

& $Node $Supervisor
exit $LASTEXITCODE
