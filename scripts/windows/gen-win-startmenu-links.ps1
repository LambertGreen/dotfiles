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

$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu"
$wtLnk = Join-Path $startMenuDir "Windows Terminal.lnk"
Ensure-Shortcut -LinkPath $wtLnk -TargetPath "explorer.exe" -Arguments "shell:AppsFolder\Microsoft.WindowsTerminal_8wekyb3d8bbwe!App" -Description "Windows Terminal"
Write-Output "Created/updated: $wtLnk"
