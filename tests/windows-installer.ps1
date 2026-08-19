$ErrorActionPreference = "Stop"

function Parse-Script($Path) {
  $tokens = $null
  $errors = $null
  $resolvedPath = (Resolve-Path $Path).Path
  $content = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($resolvedPath)).TrimStart([char]0xFEFF)
  $ast = [System.Management.Automation.Language.Parser]::ParseInput(
    $content,
    $resolvedPath,
    [ref]$tokens,
    [ref]$errors
  )
  if ($errors.Count -gt 0) {
    throw "$Path contains PowerShell syntax errors: $($errors -join '; ')"
  }
  return $ast
}

$root = Split-Path $PSScriptRoot -Parent
$installerPath = Join-Path $root "install-windows.ps1"
$launcherPath = Join-Path $root "launchers\scripts\ClaudeGravity.ps1"
$installerBytes = [System.IO.File]::ReadAllBytes($installerPath)
if ($installerBytes.Count -ge 3 -and $installerBytes[0] -eq 0xEF -and $installerBytes[1] -eq 0xBB -and $installerBytes[2] -eq 0xBF) {
  throw 'install-windows.ps1 must not contain a UTF-8 BOM because irm | iex treats it as part of the first command in Windows PowerShell 5.1.'
}
$installerAst = Parse-Script $installerPath
$launcherAst = Parse-Script $launcherPath

$assignment = $installerAst.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left.Extent.Text -eq '$claudePs1'
}, $true) | Select-Object -First 1

if (-not $assignment) {
  throw 'install-windows.ps1 does not generate $claudePs1.'
}

$elements = $assignment.Right.Expression.SubExpression.Statements[0].PipelineElements[0].Expression.Elements
$generatedLines = New-Object string[] $elements.Count
for ($index = 0; $index -lt $elements.Count; $index++) {
  $generatedLines[$index] = $elements[$index].Value
}
$generated = ($generatedLines -join [Environment]::NewLine).TrimEnd()
$launcher = (Get-Content -LiteralPath $launcherPath -Raw).TrimEnd()
if ($generated -ne $launcher) {
  $generatedRows = $generated -split "`r?`n"
  $launcherRows = $launcher -split "`r?`n"
  for ($line = 0; $line -lt [Math]::Max($generatedRows.Count, $launcherRows.Count); $line++) {
    if ($generatedRows[$line] -ne $launcherRows[$line]) {
      throw "Generated launcher differs at line $($line + 1): '$($generatedRows[$line])' != '$($launcherRows[$line])'."
    }
  }
}

$writer = $launcherAst.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Write-Utf8NoBom'
}, $true) | Select-Object -First 1
Invoke-Expression $writer.Extent.Text
$tempJson = Join-Path ([System.IO.Path]::GetTempPath()) "claudegravity-$([guid]::NewGuid()).json"
try {
  Write-Utf8NoBom $tempJson '{"ok":true}'
  $bytes = [System.IO.File]::ReadAllBytes($tempJson)
  if ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    throw 'Write-Utf8NoBom wrote a BOM.'
  }
  Get-Content -LiteralPath $tempJson -Raw | ConvertFrom-Json | Out-Null
} finally {
  Remove-Item -LiteralPath $tempJson -Force -ErrorAction SilentlyContinue
}

$ensureProvider = $launcherAst.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Ensure-RelayProvider'
}, $true) | Select-Object -First 1
Invoke-Expression $ensureProvider.Extent.Text
$previousRelayHome = $env:RELAY_AI_HOME
$tempRelayHome = Join-Path ([System.IO.Path]::GetTempPath()) "claudegravity-$([guid]::NewGuid())"
try {
  New-Item -ItemType Directory -Path $tempRelayHome | Out-Null
  $env:RELAY_AI_HOME = $tempRelayHome
  $staleConfig = '{"schemaVersion":1,"providers":[{"id":"custom-antigravity","templateId":"custom-anthropic","name":"Antigravity","enabled":true,"addedAt":"2026-08-11T00:00:00.000Z","api":{"url":"http://127.0.0.1:8080"},"modelsCache":{"models":[{"id":"gemini-3.6-flash-high"}]}}]}'
  Write-Utf8NoBom (Join-Path $tempRelayHome "providers.json") $staleConfig
  Write-Utf8NoBom (Join-Path $tempRelayHome "config.json") '{"theme":"dark","claudeGravityFavoritesVersion":1,"favoriteModels":[{"providerId":"other","modelId":"existing"}]}'

  Ensure-RelayProvider

  $repairedConfig = Get-Content -LiteralPath (Join-Path $tempRelayHome "providers.json") -Raw | ConvertFrom-Json
  $repairedProvider = @($repairedConfig.providers | Where-Object { $_.id -eq "custom-antigravity" })[0]
  if (-not $repairedProvider -or
      $repairedProvider.authRef -ne "keyring:provider:custom-antigravity" -or
      $repairedProvider.api.npm -ne "@ai-sdk/anthropic") {
    throw 'Ensure-RelayProvider did not repair a stale Antigravity provider.'
  }
  $repairedModelIds = @($repairedProvider.modelsCache.models | ForEach-Object { $_.id })
  if ($repairedModelIds.Count -ne 22) {
    throw "Expected 22 Antigravity models, got $($repairedModelIds.Count)."
  }
  foreach ($modelId in @("gemini-3.7-flash-low", "gemini-3.7-flash-medium", "gemini-3.7-flash-high")) {
    if ($repairedModelIds -notcontains $modelId) {
      throw "Missing Antigravity model: $modelId"
    }
  }

  $preferencesPath = Join-Path $tempRelayHome "config.json"
  $preferences = Get-Content -LiteralPath $preferencesPath -Raw | ConvertFrom-Json
  $favoriteIds = @($preferences.favoriteModels | ForEach-Object { "$($_.providerId)/$($_.modelId)" })
  foreach ($expectedFavorite in @(
    "other/existing",
    "custom-antigravity/gemini-3.7-flash-high",
    "custom-antigravity/gemini-3.1-pro-high",
    "custom-antigravity/claude-sonnet-4-6",
    "custom-antigravity/claude-opus-4-6-thinking",
    "custom-antigravity/gemini-2.5-pro"
  )) {
    if ($favoriteIds -notcontains $expectedFavorite) {
      throw "Missing Relay AI favorite: $expectedFavorite"
    }
  }
  if ($preferences.theme -ne "dark" -or $preferences.claudeGravityFavoritesVersion -ne 2) {
    throw 'Ensure-RelayProvider did not preserve Relay preferences or mark the favorites preset.'
  }

  $preferences.favoriteModels = @($preferences.favoriteModels | Where-Object { $_.modelId -ne "gemini-2.5-pro" })
  Write-Utf8NoBom $preferencesPath ($preferences | ConvertTo-Json -Depth 20)
  Ensure-RelayProvider
  $preferences = Get-Content -LiteralPath $preferencesPath -Raw | ConvertFrom-Json
  if (@($preferences.favoriteModels | Where-Object { $_.modelId -eq "gemini-2.5-pro" }).Count -ne 0) {
    throw 'Ensure-RelayProvider restored a favorite that the user removed.'
  }
} finally {
  $env:RELAY_AI_HOME = $previousRelayHome
  Remove-Item -LiteralPath $tempRelayHome -Recurse -Force -ErrorAction SilentlyContinue
}

$installerContent = [System.Text.Encoding]::UTF8.GetString($installerBytes).TrimStart([char]0xFEFF)

foreach ($required in @(
  'Write-Utf8NoBom',
  'npm.cmd',
  'acc.cmd',
  'relay-ai.cmd',
  '$providerOutput = $providerList -join [Environment]::NewLine',
  'antigravity-claude-proxy@latest',
  '@jacobbd/relay-ai@latest',
  'patch-antigravity-proxy.mjs',
  'npmRoot',
  'Проверяю обновления компонентов'
)) {
  if ($installerContent -notmatch [regex]::Escape($required)) {
    throw "Missing Windows safeguard: $required"
  }
}

Write-Host "Windows installer checks passed."