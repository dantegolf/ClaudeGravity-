$ErrorActionPreference = "Stop"
$Documents = [Environment]::GetFolderPath("MyDocuments")
if (-not $Documents) { $Documents = Join-Path $env:USERPROFILE "Documents" }
$InstallDir = Join-Path $Documents "ClaudeGravity"
$ScriptsDir = Join-Path $InstallDir "scripts"
$RawBase = if ($env:CLAUDEGRAVITY_RAW_BASE) { $env:CLAUDEGRAVITY_RAW_BASE } else { "https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main" }

if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) { throw "Node.js не найден. Сначала установите ClaudeGravity." }
if (-not (Test-Path -LiteralPath (Join-Path $ScriptsDir "supervisor.mjs"))) { throw "Основной ClaudeGravity runtime не найден в $InstallDir. Сначала установите ClaudeGravity." }

New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null
Invoke-WebRequest -UseBasicParsing "$RawBase/launchers/scripts/cg-agent.mjs" -OutFile (Join-Path $ScriptsDir "cg-agent.mjs")
Invoke-WebRequest -UseBasicParsing "$RawBase/launchers/scripts/cg-delegate.mjs" -OutFile (Join-Path $ScriptsDir "cg-delegate.mjs")
Invoke-WebRequest -UseBasicParsing "$RawBase/launchers/scripts/install-codex-integration.mjs" -OutFile (Join-Path $ScriptsDir "install-codex-integration.mjs")
Invoke-WebRequest -UseBasicParsing "$RawBase/launchers/CG-Agent.cmd" -OutFile (Join-Path $InstallDir "CG-Agent.cmd")
Invoke-WebRequest -UseBasicParsing "$RawBase/launchers/CG-Delegate.cmd" -OutFile (Join-Path $InstallDir "CG-Delegate.cmd")
Invoke-WebRequest -UseBasicParsing "$RawBase/launchers/CD-Delegate.cmd" -OutFile (Join-Path $InstallDir "CD-Delegate.cmd")

foreach ($Script in @("cg-agent.mjs", "cg-delegate.mjs", "install-codex-integration.mjs")) {
  & node.exe --check (Join-Path $ScriptsDir $Script)
  if ($LASTEXITCODE -ne 0) { throw "$Script содержит синтаксическую ошибку." }
}

& node.exe (Join-Path $ScriptsDir "install-codex-integration.mjs") `
  --raw-base $RawBase `
  --delegate-launcher (Join-Path $InstallDir "CG-Delegate.cmd")
if ($LASTEXITCODE -ne 0) { throw "Не удалось установить глобальную Codex integration." }

Write-Host ""
Write-Host "CG-Agent установлен: $InstallDir\CG-Agent.cmd" -ForegroundColor Green
Write-Host "Codex delegate установлен: $InstallDir\CG-Delegate.cmd" -ForegroundColor Green
Write-Host "Алиас: $InstallDir\CD-Delegate.cmd"
Write-Host "Перед использованием запустите ClaudeGravity и дождитесь READY в WebUI."
Write-Host "Пример worker-вызова:"
Write-Host '  CG-Agent.cmd --repo C:\Projects\app --task "Проверь проект и реализуй задачу"'
Write-Host "Пример supervisor-вызова:"
Write-Host '  %USERPROFILE%\.claudegravity\bin\cg-delegate.cmd --repo C:\Projects\app --task "Реализуй задачу"'
