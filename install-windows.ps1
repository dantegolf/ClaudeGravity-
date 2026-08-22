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

function New-DesktopShortcut($ShortcutPath, $TargetPath, $Description, $Arguments = $null, $WorkingDirectory = $null) {
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($ShortcutPath)
  $shortcut.TargetPath = $TargetPath
  $shortcut.WorkingDirectory = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path $TargetPath -Parent }
  $shortcut.Description = $Description
  if ($Arguments) { $shortcut.Arguments = $Arguments }
  $shortcut.WindowStyle = 7
  $shortcut.Save()
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
  $downloaded = $false
  $curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curlCommand) {
    & $curlCommand.Source --fail --location --silent --show-error --retry 3 --retry-delay 2 --connect-timeout 15 --output $tempZip $BundleUrl
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $tempZip) -and (Get-Item -LiteralPath $tempZip).Length -gt 0) {
      $downloaded = $true
    } else {
      Say "curl.exe не смог скачать runtime, использую PowerShell fallback..."
      Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
    }
  }
  if (-not $downloaded) {
    Invoke-WebRequest -UseBasicParsing -Uri $BundleUrl -OutFile $tempZip
  }

  if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

  Say "Распаковываю runtime..."
  $extracted = $false
  $tarCommand = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($tarCommand) {
    & $tarCommand.Source -xf $tempZip -C $InstallDir
    if ($LASTEXITCODE -eq 0) {
      $extracted = $true
    } else {
      Say "tar.exe не смог распаковать ZIP, использую совместимый fallback..."
      Remove-Item -LiteralPath $InstallDir -Recurse -Force
      New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }
  }
  if (-not $extracted) {
    Expand-Archive -LiteralPath $tempZip -DestinationPath $InstallDir -Force
  }
} finally {
  Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
}

foreach ($required in @("ClaudeGravity.cmd", "ClaudeGravity.ps1", "Check-Limits.cmd", "runtime", "scripts", "manifest.json")) {
  if (-not (Test-Path -LiteralPath (Join-Path $InstallDir $required))) {
    throw "Runtime archive повреждён или неполон: отсутствует $required"
  }
}

Say "Создаю ярлыки на рабочем столе..."
$DesktopDir = if ($env:CLAUDEGRAVITY_DESKTOP_DIR) { $env:CLAUDEGRAVITY_DESKTOP_DIR } else { [Environment]::GetFolderPath("Desktop") }
if (-not $DesktopDir) { $DesktopDir = Join-Path $env:USERPROFILE "Desktop" }
New-Item -ItemType Directory -Force -Path $DesktopDir | Out-Null
$PowerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$LauncherScript = Join-Path $InstallDir "ClaudeGravity.ps1"
$LauncherArgs = '-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $LauncherScript + '"'
New-DesktopShortcut -ShortcutPath (Join-Path $DesktopDir "ClaudeGravity.lnk") -TargetPath $PowerShellExe -Arguments $LauncherArgs -WorkingDirectory $InstallDir -Description "Открыть ClaudeGravity"
New-DesktopShortcut -ShortcutPath (Join-Path $DesktopDir "Check-Limits.lnk") -TargetPath (Join-Path $InstallDir "Check-Limits.cmd") -Description "Проверить состояние ClaudeGravity"
Say "Ярлыки созданы: $DesktopDir"

Say "Готово: $InstallDir"
if ($env:CLAUDEGRAVITY_SKIP_LAUNCH -eq "1") { exit 0 }
& (Join-Path $InstallDir "ClaudeGravity.ps1")
