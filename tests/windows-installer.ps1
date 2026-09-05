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
$cmdPath = Join-Path $root "distribution\runtime\ClaudeGravity.cmd"
$limitsPath = Join-Path $root "distribution\runtime\Check-Limits.ps1"
$supervisorPath = Join-Path $root "launchers\scripts\supervisor.mjs"
$desktopConfigPath = Join-Path $root "launchers\scripts\configure-claude-desktop.mjs"
$configureRelayPath = Join-Path $root "launchers\scripts\configure-relay.mjs"
$patchPath = Join-Path $root "launchers\scripts\patch-antigravity-proxy.mjs"

$installerBytes = [System.IO.File]::ReadAllBytes($installerPath)
if ($installerBytes.Count -ge 3 -and $installerBytes[0] -eq 0xEF -and $installerBytes[1] -eq 0xBB -and $installerBytes[2] -eq 0xBF) {
  throw 'install-windows.ps1 must not contain a UTF-8 BOM because irm | iex treats it as part of the first command in Windows PowerShell 5.1.'
}

$installer = Parse-Script $installerPath
$launcher = Parse-Script $launcherPath
$cmd = Get-Content -LiteralPath $cmdPath -Raw
$limits = Parse-Script $limitsPath
$supervisor = Get-Content -LiteralPath $supervisorPath -Raw
$desktopConfig = Get-Content -LiteralPath $desktopConfigPath -Raw
$configureRelay = Get-Content -LiteralPath $configureRelayPath -Raw
$patch = Get-Content -LiteralPath $patchPath -Raw

foreach ($required in @(
  'dantegolf/ClaudeGravity-/releases/latest/download',
  'ClaudeGravity-runtime.zip',
  'curl.exe',
  'Invoke-WebRequest',
  'tar.exe',
  'Expand-Archive',
  'node.exe',
  'CLAUDEGRAVITY_BUNDLE_URL',
  'CLAUDEGRAVITY_DESKTOP_DIR',
  'WScript.Shell',
  'ClaudeGravity.lnk',
  'Check-Limits.lnk',
  '-WindowStyle Hidden',
  '$shortcut.Arguments'
)) {
  if ($installer -notmatch [regex]::Escape($required)) {
    throw "Missing bundled installer safeguard: $required"
  }
}

$curlIndex = $installer.IndexOf('curl.exe')
$webRequestIndex = $installer.IndexOf('Invoke-WebRequest')
if ($curlIndex -lt 0 -or $webRequestIndex -le $curlIndex) {
  throw 'Windows installer must prefer curl.exe and keep Invoke-WebRequest only as a fallback.'
}

$tarIndex = $installer.IndexOf('tar.exe')
$fallbackIndex = $installer.IndexOf('Expand-Archive')
if ($tarIndex -lt 0 -or $fallbackIndex -le $tarIndex) {
  throw 'Windows installer must prefer tar.exe and keep Expand-Archive only as a fallback.'
}

foreach ($forbidden in @('olegsuper338-lgtm', 'npm.cmd', '@latest', 'npm install -g')) {
  if ($installer -match [regex]::Escape($forbidden)) {
    throw "Legacy Windows installer dependency remains: $forbidden"
  }
}

foreach ($required in @('supervisor.mjs', 'RELAY_AI_HOME', 'ANTIGRAVITY_API_KEY', 'Start-Process', '-WindowStyle Hidden', 'CLAUDEGRAVITY_FOREGROUND')) {
  if ($launcher -notmatch [regex]::Escape($required)) {
    throw "Missing silent unified launcher safeguard: $required"
  }
}
if ($cmd -notmatch [regex]::Escape('-WindowStyle Hidden')) {
  throw 'ClaudeGravity.cmd must hide the bootstrap PowerShell window.'
}
foreach ($forbidden in @('claude-app', 'http://127.0.0.1:8080', 'npm install', 'acc.cmd', 'relay-ai.cmd')) {
  if ($launcher -match [regex]::Escape($forbidden)) {
    throw "Legacy launcher path remains: $forbidden"
  }
}

foreach ($required in @(
  '18080',
  '17645',
  '17646',
  'HOST: ''127.0.0.1''',
  '''server''',
  '''--quick''',
  '''custom-antigravity''',
  '''--mask-gateway-ids''',
  'applyClaudeDesktopConfig',
  'restoreClaudeDesktopConfig',
  '''/logs/stream''',
  '''/action/open-claude''',
  '''/action/restart''',
  '''/action/stop''',
  'claudegravity.log',
  "stdio: ['ignore', 'pipe', 'pipe']"
)) {
  if ($supervisor -notmatch [regex]::Escape($required)) {
    throw "Missing supervisor WebUI safeguard: $required"
  }
}
if ($supervisor -match [regex]::Escape("stdio: 'inherit'")) {
  throw 'Supervisor must not dump engine logs into the terminal.'
}
if ($supervisor -match [regex]::Escape("'claude-app'")) {
  throw 'Unified supervisor must not launch Relay claude-app because it creates a second public proxy.'
}

foreach ($required in @('ClaudeGravity WebUI v1', 'ClaudeGravity', 'LOCAL AI GATEWAY', 'CLAUDEGRAVITY_CONTROL_URL', 'Open Claude')) {
  if ($patch -notmatch [regex]::Escape($required)) {
    throw "Missing WebUI branding safeguard: $required"
  }
}

if ($configureRelay -notmatch [regex]::Escape('http://127.0.0.1:18080')) {
  throw 'Relay provider must default to the internal Antigravity port.'
}
if ($desktopConfig -notmatch [regex]::Escape('http://127.0.0.1:${port}/anthropic')) {
  throw 'Claude Desktop config must target the Relay gateway endpoint.'
}
foreach ($required in @('http://127.0.0.1:17645/health', 'http://127.0.0.1:18080/account-limits')) {
  if ($limits -notmatch [regex]::Escape($required)) {
    throw "Limits helper is not wired to the unified gateway: $required"
  }
}

foreach ($script in @($supervisorPath, $desktopConfigPath, $configureRelayPath, $patchPath)) {
  & node.exe --check $script
  if ($LASTEXITCODE -ne 0) { throw "Node syntax check failed: $script" }
}

foreach ($test in @('proxy-compat.mjs', 'smart-dns.mjs', 'model-catalog.mjs')) {
  & node.exe (Join-Path $PSScriptRoot $test)
  if ($LASTEXITCODE -ne 0) { throw "Network compatibility check failed: $test" }
}

Write-Host "Windows silent WebUI distribution checks passed."
