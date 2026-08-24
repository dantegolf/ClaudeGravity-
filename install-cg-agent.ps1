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
Invoke-WebRequest -UseBasicParsing "$RawBase/launchers/CG-Agent.cmd" -OutFile (Join-Path $InstallDir "CG-Agent.cmd")

& node.exe --check (Join-Path $ScriptsDir "cg-agent.mjs")
if ($LASTEXITCODE -ne 0) { throw "cg-agent.mjs содержит синтаксическую ошибку." }

Write-Host ""
Write-Host "CG-Agent установлен: $InstallDir\CG-Agent.cmd" -ForegroundColor Green
Write-Host "Перед использованием запустите ClaudeGravity и дождитесь READY в WebUI."
Write-Host "Пример:"
Write-Host '  CG-Agent.cmd --repo C:\Projects\app --task "Проверь проект и реализуй задачу"'
