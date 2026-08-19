$ErrorActionPreference = "Stop"

function Parse-Script($Path) {
  $tokens = $null
  $errors = $null
  $resolvedPath = (Resolve-Path $Path).Path
  $content = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($resolvedPath)).TrimStart([char]0xFEFF)
  [System.Management.Automation.Language.Parser]::ParseInput($content, $resolvedPath, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    throw "$Path contains PowerShell syntax errors: $($errors -join '; ')"
  }
  return $content
}

$root = Split-Path $PSScriptRoot -Parent
$installerPath = Join-Path $root "install-windows.ps1"
$launcherPath = Join-Path $root "distribution\runtime\ClaudeGravity.ps1"
$limitsPath = Join-Path $root "distribution\runtime\Check-Limits.ps1"

$installerBytes = [System.IO.File]::ReadAllBytes($installerPath)
if ($installerBytes.Count -ge 3 -and $installerBytes[0] -eq 0xEF -and $installerBytes[1] -eq 0xBB -and $installerBytes[2] -eq 0xBF) {
  throw 'install-windows.ps1 must not contain a UTF-8 BOM because irm | iex treats it as part of the first command in Windows PowerShell 5.1.'
}

$installer = Parse-Script $installerPath
$launcher = Parse-Script $launcherPath
Parse-Script $limitsPath | Out-Null

foreach ($required in @(
  'dantegolf/ClaudeGravity-/releases/latest/download',
  'ClaudeGravity-runtime.zip',
  'Expand-Archive',
  'node.exe',
  'CLAUDEGRAVITY_BUNDLE_URL'
)) {
  if ($installer -notmatch [regex]::Escape($required)) {
    throw "Missing bundled installer safeguard: $required"
  }
}

foreach ($forbidden in @('olegsuper338-lgtm', 'npm.cmd', '@latest', 'npm install -g')) {
  if ($installer -match [regex]::Escape($forbidden)) {
    throw "Legacy Windows installer dependency remains: $forbidden"
  }
}

foreach ($required in @(
  'node_modules\antigravity-claude-proxy',
  'node_modules\@jacobbd\relay-ai',
  'patch-antigravity-proxy.mjs',
  'configure-relay.mjs',
  'ClaudeGravity готов'
)) {
  if ($launcher -notmatch [regex]::Escape($required)) {
    throw "Missing bundled launcher safeguard: $required"
  }
}

foreach ($forbidden in @('npm install', 'acc.cmd', 'relay-ai.cmd')) {
  if ($launcher -match [regex]::Escape($forbidden)) {
    throw "Bundled launcher still depends on a global command: $forbidden"
  }
}

Write-Host "Windows bundled distribution checks passed."
