$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$installerPath = Join-Path $root "install-cg-agent.ps1"
$delegatePath = Join-Path $root "launchers\scripts\cg-delegate.mjs"
$integrationPath = Join-Path $root "launchers\scripts\install-codex-integration.mjs"
$staticTestPath = Join-Path $root "tests\codex-delegation.mjs"

$tokens = $null
$errors = $null
$content = Get-Content -LiteralPath $installerPath -Raw
[System.Management.Automation.Language.Parser]::ParseInput($content, $installerPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
  throw "install-cg-agent.ps1 contains PowerShell syntax errors: $($errors -join '; ')"
}

foreach ($required in @(
  'cg-delegate.mjs',
  'install-codex-integration.mjs',
  'CG-Delegate.cmd',
  'CD-Delegate.cmd',
  '--delegate-launcher'
)) {
  if ($content -notmatch [regex]::Escape($required)) {
    throw "Missing Codex delegation installer wiring: $required"
  }
}

foreach ($script in @($delegatePath, $integrationPath, $staticTestPath)) {
  & node.exe --check $script
  if ($LASTEXITCODE -ne 0) { throw "Node syntax check failed: $script" }
}

& node.exe $staticTestPath
if ($LASTEXITCODE -ne 0) { throw "Codex delegation static checks failed." }

Write-Host "Windows Codex delegation checks passed."
