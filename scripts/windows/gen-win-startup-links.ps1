param([switch]$WhatIf)
$ErrorActionPreference = "Stop"

function Ensure-Dir { param([string]$Path) if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }
function Ensure-Shortcut {
  param(
    [Parameter(Mandatory)] [string]$LinkPath,
    [Parameter(Mandatory)] [string]$TargetPath,
    [string]$Arguments = "",
    [string]$WorkingDirectory = "",
    [string]$IconLocation = "",
    [string]$Description = ""
  )
  if ($WhatIf) { Write-Output "[WhatIf] $LinkPath -> $TargetPath $Arguments"; return }
  Ensure-Dir (Split-Path $LinkPath)
  $wsh = New-Object -ComObject WScript.Shell
  $sc = $wsh.CreateShortcut($LinkPath)
  $sc.TargetPath = $TargetPath
  $sc.Arguments = $Arguments
  if ($WorkingDirectory) { $sc.WorkingDirectory = $WorkingDirectory }
  if ($IconLocation) { $sc.IconLocation = $IconLocation }
  if ($Description) { $sc.Description = $Description }
  $sc.Save()
}

function Resolve-AhkExe {
  $candidates = @(
    "$env:USERPROFILE\scoop\apps\autohotkey\current\AutoHotkey64.exe",
    "C:\\Program Files\\AutoHotkey\\v1\\AutoHotkey.exe",
    "C:\\Program Files\\AutoHotkey\\AutoHotkey.exe"
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  $cmd = Get-Command Autohotkey* -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { return $cmd.Source }
  Write-Output "AutoHotkey executable not found. Checked:"
  $candidates | ForEach-Object { Write-Output "  - $_ (exists=$([bool](Test-Path $_)))" }
  if ($cmd) { Write-Output "  - Get-Command found: $($cmd.Source)" }
  throw "AutoHotkey executable not found"
}

function Resolve-AhkInit {
  $candidates = @(
    "$env:USERPROFILE\.autohotkey\init.ahk",
    "$env:USERPROFILE\Documents\AutoHotkey\init.ahk",
    "$env:USERPROFILE\AppData\Roaming\AutoHotkey\init.ahk",
    "$env:USERPROFILE\dev\my\dotfiles\configs\autohotkey\dot-autohotkey\init.ahk"
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  Write-Output "AutoHotkey init.ahk not found. Checked:"
  $candidates | ForEach-Object { Write-Output "  - $_ (exists=$([bool](Test-Path $_)))" }
  throw "AutoHotkey init.ahk not found"
}

$startupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$ahkLnk = Join-Path $startupDir "AutoHotkey.lnk"
try {
  $ahkExe = Resolve-AhkExe
  $ahkInit = Resolve-AhkInit
  Write-Output "Resolved AHK exe: $ahkExe"
  Write-Output "Resolved init.ahk: $ahkInit"
  Ensure-Shortcut -LinkPath $ahkLnk -TargetPath $ahkExe -Arguments "`"$ahkInit`"" -Description "AutoHotkey init"
  Write-Output "Created/updated shortcut: $ahkLnk"
} catch {
  Write-Warning $_
  Write-Output "Hint: Ensure the autohotkey package is stowed and submodule is present."
  Write-Output "      Try: git submodule update --init --recursive"
  Write-Output "      Then: just stow"
}
