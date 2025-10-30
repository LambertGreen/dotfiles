param(
    [string]$MachineClass,
    [string]$App,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] $Message"
    $line | Out-File -FilePath $Global:LogFile -Append -Encoding utf8
    Write-Host $Message
}

# Resolve Home and dotfiles dir
$UserHome = $HOME
if (-not $UserHome) { $UserHome = $env:USERPROFILE }
$DotfilesDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)  # scripts/windows -> repo root

# Prepare logs dir under ~/.dotfiles/logs
$LogsDir = Join-Path $UserHome ".dotfiles/logs"
$null = New-Item -ItemType Directory -Path $LogsDir -Force
$Global:LogFile = Join-Path $LogsDir ("import-regkeys-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".log")

Write-Log "=== Windows Registry Importer ==="
Write-Log "Repo: $DotfilesDir"
Write-Log "Log: $LogFile"

# Load environment from ~/.dotfiles.env if present to get machine class
$DotfilesEnvPath = Join-Path $UserHome ".dotfiles.env"
if (-not $MachineClass) {
    if (Test-Path $DotfilesEnvPath) {
        $envLines = Get-Content -LiteralPath $DotfilesEnvPath -ErrorAction SilentlyContinue
        foreach ($line in $envLines) {
            if ($line -match '^(DOTFILES_MACHINE_CLASS)=(.*)$') {
                $MachineClass = $Matches[2].Trim()
            }
        }
    }
}

if (-not $MachineClass) {
    Write-Log "❌ Machine class not provided and not found in ~/.dotfiles.env (DOTFILES_MACHINE_CLASS)."
    Write-Log "   Provide -MachineClass or run 'just configure' to populate ~/.dotfiles.env."
    exit 1
}

Write-Log "MachineClass: $MachineClass"
if ($App) { Write-Log "App filter: $App" }
if ($WhatIf) { Write-Log "Mode: DRY-RUN (WhatIf)" }

# Determine config root (top-level submodule)
$ConfigRoot = Join-Path $DotfilesDir "win_reg_configs"
Write-Log "ConfigRoot (submodule): $ConfigRoot"

# Resolve manifest path for the class
$ManifestPath = Join-Path $DotfilesDir ("machine-classes/" + $MachineClass + "/win-reg/manifest.txt")
if (-not (Test-Path $ManifestPath)) {
    Write-Log "❌ Manifest not found: $ManifestPath"
    exit 1
}

# Read manifest entries (ignore comments/blank lines)
$entries = Get-Content -LiteralPath $ManifestPath |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }

if ($entries.Count -eq 0) {
    Write-Log "⚠ No entries in manifest: $ManifestPath"
    exit 0
}

# If an App filter was provided, restrict to that app
if ($App) {
    $entries = $entries | Where-Object { $_ -ieq $App }
    if ($entries.Count -eq 0) {
        Write-Log "⚠ App '$App' not listed in manifest. Nothing to do."
        exit 0
    }
}

# Import loop
foreach ($appEntry in $entries) {
    $appDir = Join-Path $ConfigRoot $appEntry
    if (-not (Test-Path $appDir)) {
        Write-Log "❌ App config directory not found: $appDir"
        continue
    }

    # Find all .reg files in app directory (recursive allowed for future growth)
    $regFiles = Get-ChildItem -Path $appDir -Filter *.reg -Recurse -File | Sort-Object FullName
    if ($regFiles.Count -eq 0) {
        Write-Log "⚠ No .reg files found for app '$appEntry' in $appDir"
        continue
    }

    Write-Log "==> Importing app: $appEntry"
    foreach ($reg in $regFiles) {
        Write-Log "Importing: $($reg.FullName)"
        if ($WhatIf) {
            Write-Log "  (dry-run) reg import \"$($reg.FullName)\""
            continue
        }
        # Invoke reg.exe directly; PowerShell will pass the path as a single argument even with spaces
        $regOut = & reg.exe import $reg.FullName 2>&1
        $exit = $LASTEXITCODE
        if ($regOut) { Write-Log ($regOut | Out-String).TrimEnd() }
        if ($exit -ne 0) {
            Write-Log "❌ reg import failed (exit $exit) for: $($reg.FullName)"
        } else {
            Write-Log "✅ Imported: $($reg.Name)"
        }
    }
}

Write-Log "=== Done ==="
