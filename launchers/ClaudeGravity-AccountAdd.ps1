$ErrorActionPreference = "Continue"

$NpmUserDir = Join-Path $env:APPDATA "npm"
$env:Path = "$NpmUserDir;$env:Path"

function Pause-End {
  Write-Host ""
  Write-Host "Press any key to close..."
  [Console]::ReadKey($true) | Out-Null
}

Clear-Host
Write-Host "ClaudeGravity - Account Binding"
Write-Host ""

if (-not (Get-Command acc -ErrorAction SilentlyContinue)) {
  Write-Host "Antigravity proxy (acc) not found in PATH."
  Write-Host "Install it via: npm install -g antigravity-claude-proxy"
  Pause-End
  exit 1
}

Write-Host "Launching Google/Antigravity account binding..."
Write-Host ""

cmd.exe /c "acc accounts add"

Write-Host ""
Write-Host "--- Launch ClaudeGravity ---"
$reply = Read-Host "Would you like to launch ClaudeGravity now? [Y/n]"
if ($reply -eq "" -or $reply -match "^[Yy]") {
  Write-Host ""
  Write-Host "Reminders for Claude Desktop:"
  Write-Host " 1. Menu Help -> Troubleshooting -> Enable Developer Mode"
  Write-Host " 2. Switch mode from 'Cowork' to 'Code'"
  Write-Host " 3. Select model: gemini-3.6-flash-high (Antigravity) 1M"
  Write-Host ""
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
  & (Join-Path $scriptDir "ClaudeGravity.ps1")
}
