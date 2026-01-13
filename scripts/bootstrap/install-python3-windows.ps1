# Install Python 3 on Windows

$ErrorActionPreference = "Stop"

Write-Host "Installing Python 3 on Windows..." -ForegroundColor Yellow

# Check if Python 3 is already available via py launcher
try {
    $pyOutput = py -3 --version 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Python 3 is already registered with py launcher: $pyOutput" -ForegroundColor Green
        exit 0
    }
} catch {
    # py -3 failed, continue with installation
}

Write-Host "Python 3 not found or not registered with Windows Python Launcher (py.exe)" -ForegroundColor Yellow
Write-Host ""

# Strategy: Try winget first (modern), fall back to scoop
Write-Host "Attempting to install Python 3..." -ForegroundColor Cyan

# Check if winget is available
$wingetAvailable = $false
try {
    $null = Get-Command winget -ErrorAction Stop
    $wingetAvailable = $true
    Write-Host "winget is available" -ForegroundColor Green
} catch {
    Write-Host "winget not found" -ForegroundColor Yellow
}

if ($wingetAvailable) {
    Write-Host "Installing Python 3 via winget..." -ForegroundColor Cyan
    Write-Host "   This will register Python with the Windows Python Launcher (py.exe)" -ForegroundColor Gray

    try {
        # Install Python 3.13 (or latest stable)
        winget install --id Python.Python.3.13 --silent --accept-package-agreements --accept-source-agreements

        Write-Host "Python 3 installed via winget" -ForegroundColor Green
        Write-Host "   Verifying registration with py launcher..." -ForegroundColor Gray

        # Verify py launcher can find it (may need PATH refresh)
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        try {
            $pyOutput = py -3 --version 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Python 3 registered successfully: $pyOutput" -ForegroundColor Green
                exit 0
            }
        } catch {
            Write-Host "Python installed but not yet registered. You may need to:" -ForegroundColor Yellow
            Write-Host "   1. Close and reopen your terminal" -ForegroundColor White
            Write-Host "   2. Or logout/login to refresh PATH" -ForegroundColor White
            Write-Host "   Then verify with: py -3 --version" -ForegroundColor White
            exit 0
        }
    } catch {
        Write-Host "Failed to install via winget: $_" -ForegroundColor Red
        Write-Host "   Trying fallback method..." -ForegroundColor Yellow
    }
}

# Fallback: Try scoop
Write-Host "Checking for Scoop..." -ForegroundColor Cyan
$scoopAvailable = $false
try {
    $null = Get-Command scoop -ErrorAction Stop
    $scoopAvailable = $true
} catch {
    Write-Host "Scoop not found either" -ForegroundColor Yellow
}

if ($scoopAvailable) {
    Write-Host "Installing Python 3 via Scoop..." -ForegroundColor Cyan
    Write-Host "   Note: Scoop-installed Python may not register with py.exe" -ForegroundColor Yellow
    Write-Host "   Consider installing via winget instead for better integration" -ForegroundColor Yellow

    try {
        scoop install python

        # Check if python3 is now available
        $null = Get-Command python3 -ErrorAction Stop
        $pythonVersion = python3 --version
        Write-Host "Python 3 installed via Scoop: $pythonVersion" -ForegroundColor Green

        # Check if py launcher can find it
        try {
            $pyOutput = py -3 --version 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                Write-Host ""
                Write-Host "Python installed but NOT registered with Windows Python Launcher" -ForegroundColor Yellow
                Write-Host "   This may cause issues with some scripts that use 'py -3'" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "   Recommended: Install via winget for proper integration:" -ForegroundColor Cyan
                Write-Host "   1. scoop uninstall python" -ForegroundColor White
                Write-Host "   2. winget install Python.Python.3.13" -ForegroundColor White
            }
        } catch {
            # py command not working, that's ok
        }

        exit 0
    } catch {
        Write-Host "Failed to install via Scoop: $_" -ForegroundColor Red
    }
}

# No installation method available
Write-Host ""
Write-Host "Could not install Python 3 automatically" -ForegroundColor Red
Write-Host ""
Write-Host "Please install Python 3 manually:" -ForegroundColor Cyan
Write-Host "  Option 1 (Recommended): Install via winget" -ForegroundColor White
Write-Host "    winget install Python.Python.3.13" -ForegroundColor Gray
Write-Host ""
Write-Host "  Option 2: Download from python.org" -ForegroundColor White
Write-Host "    https://www.python.org/downloads/" -ForegroundColor Gray
Write-Host ""
Write-Host "  Option 3: Install winget first, then use Option 1" -ForegroundColor White
Write-Host "    - Windows 11: winget is pre-installed" -ForegroundColor Gray
Write-Host "    - Windows 10: Install 'App Installer' from Microsoft Store" -ForegroundColor Gray
Write-Host ""

exit 1
