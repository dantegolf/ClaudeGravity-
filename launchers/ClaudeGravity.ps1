$ErrorActionPreference = "Stop"
$HealthUrl = "http://127.0.0.1:8080/health"

function Pause-End {
  Write-Host ""
  Write-Host "Press any key to close..."
  [Console]::ReadKey($true) | Out-Null
}

Clear-Host
Write-Host "ClaudeGravity"
Write-Host ""

if (-not (Get-Command relay-ai -ErrorAction SilentlyContinue)) {
  Write-Host "Relay AI not found: npm install -g @jacobbd/relay-ai"
  Pause-End
  exit 1
}

try {
  Invoke-RestMethod $HealthUrl -TimeoutSec 2 | Out-Null
} catch {
  Write-Host "Starting Antigravity proxy..."
  acc start
}

Write-Host "Opening Claude Desktop through Relay AI..."
Write-Host ""
relay-ai claude-app

Pause-End
