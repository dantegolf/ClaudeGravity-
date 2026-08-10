$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $HOME "Documents\ClaudeGravity"
$NpmUserDir = Join-Path $env:APPDATA "npm"

function Say($Message) {
  Write-Host ""
  Write-Host "==> $Message"
}

Say "ClaudeGravity Windows installer"

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Say "Installing Node.js LTS with winget"
    winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    $env:Path = "$NpmUserDir;C:\Program Files\nodejs;$env:Path"
  } else {
    Write-Host "Node.js is required. Install Node.js LTS and run this installer again:"
    Write-Host "https://nodejs.org/"
    exit 1
  }
}

Say "Ensuring npm global path"
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentUserPath -notlike "*$NpmUserDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$NpmUserDir", "User")
}
$env:Path = "$NpmUserDir;$env:Path"

Say "Installing Antigravity Claude Proxy and Relay AI"
npm install -g antigravity-claude-proxy @jacobbd/relay-ai

Say "Creating launchers in $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

@'
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
'@ | Set-Content -Encoding UTF8 (Join-Path $InstallDir "ClaudeGravity.ps1")

@'
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0ClaudeGravity.ps1"
'@ | Set-Content -Encoding ASCII (Join-Path $InstallDir "ClaudeGravity.cmd")

@'
Clear-Host
Write-Host "ClaudeGravity limits"
Write-Host ""

try {
  Invoke-RestMethod http://127.0.0.1:8080/health | ConvertTo-Json -Depth 20
} catch {
  Write-Host "Antigravity proxy is not responding on http://127.0.0.1:8080/health"
  Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Press any key to close..."
[Console]::ReadKey($true) | Out-Null
'@ | Set-Content -Encoding UTF8 (Join-Path $InstallDir "ClaudeGravity-Limits.ps1")

@'
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0ClaudeGravity-Limits.ps1"
'@ | Set-Content -Encoding ASCII (Join-Path $InstallDir "ClaudeGravity-Limits.cmd")

Say "Done"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: acc accounts add"
Write-Host "  2. Open: $InstallDir\ClaudeGravity.cmd"
Write-Host "  3. In Claude Desktop: Settings -> Developer -> Developer Mode, then use Code mode."
