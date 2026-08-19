$ErrorActionPreference = "Stop"

$Documents = [Environment]::GetFolderPath("MyDocuments")
if (-not $Documents) { $Documents = Join-Path $env:USERPROFILE "Documents" }
$InstallDir = Join-Path $Documents "ClaudeGravity"
$ReleaseBase = if ($env:CLAUDEGRAVITY_RELEASE_BASE) { $env:CLAUDEGRAVITY_RELEASE_BASE } else { "https://github.com/dantegolf/ClaudeGravity-/releases/latest/download" }
$BundleUrl = if ($env:CLAUDEGRAVITY_BUNDLE_URL) { $env:CLAUDEGRAVITY_BUNDLE_URL } else { "$ReleaseBase/ClaudeGravity-runtime.zip" }

function Say($Message) {
  Write-Host ""
  Write-Host "==> $Message"
}

Say "Установка ClaudeGravity bundled runtime"

$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $nodeCommand) {
  if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Say "Устанавливаю Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "Не удалось установить Node.js через winget." }
    $env:Path = "$env:ProgramFiles\nodejs;$env:Path"
    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
  }
}
if (-not $nodeCommand) {
  throw "Требуется Node.js 18+. Установите Node.js и повторите установку."
}
$major = [int]((& $nodeCommand.Source -p "process.versions.node.split('.')[0]").Trim())
if ($major -lt 18) { throw "Требуется Node.js 18 или новее." }

Say "Скачиваю проверенный ClaudeGravity runtime из нашего GitHub Release..."
$tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "ClaudeGravity-$([guid]::NewGuid()).zip"
try {
  Invoke-WebRequest -UseBasicParsing -Uri $BundleUrl -OutFile $tempZip
  if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  Expand-Archive -LiteralPath $tempZip -DestinationPath $InstallDir -Force
} finally {
  Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
}

foreach ($required in @("ClaudeGravity.cmd", "ClaudeGravity.ps1", "runtime", "scripts", "manifest.json")) {
  if (-not (Test-Path -LiteralPath (Join-Path $InstallDir $required))) {
    throw "Runtime archive повреждён или неполон: отсутствует $required"
  }
}

Say "Готово: $InstallDir"
if ($env:CLAUDEGRAVITY_SKIP_LAUNCH -eq "1") { exit 0 }
& (Join-Path $InstallDir "ClaudeGravity.cmd")
