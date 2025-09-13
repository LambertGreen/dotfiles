#!/usr/bin/env powershell
# Install GNU Stow for Windows via MSYS2

$ErrorActionPreference = "Stop"

Write-Host "Installing GNU Stow..." -ForegroundColor Green

# Check MSYS2 paths
$msys2Paths = @("C:\msys64", "C:\tools\msys64")
$msys2Path = $null

foreach ($path in $msys2Paths) {
    if (Test-Path $path) {
        $msys2Path = $path
        break
    }
}

if (!$msys2Path) {
    Write-Error "MSYS2 not found. Run install-msys2-windows.ps1 first."
    exit 1
}

$bashPath = Join-Path $msys2Path "usr\bin\bash.exe"

# Check if Stow is already installed in MSYS2
Write-Host "Checking for existing Stow installation in MSYS2..." -ForegroundColor Cyan
$stowCheck = & $bashPath -lc "which stow 2>/dev/null"
if ($stowCheck) {
    Write-Host "Stow is already installed in MSYS2" -ForegroundColor Yellow
    & $bashPath -lc "stow --version"
    exit 0
}

# Install Stow via MSYS2 pacman
Write-Host "Installing Stow via MSYS2 pacman..." -ForegroundColor Cyan
try {
    & $bashPath -lc "pacman -S --noconfirm stow"
} catch {
    Write-Error "Failed to install Stow via MSYS2: $_"
    exit 1
}

# Verify installation
$stowCheck = & $bashPath -lc "which stow 2>/dev/null"
if ($stowCheck) {
    Write-Host "??? Stow installed successfully in MSYS2!" -ForegroundColor Green
    & $bashPath -lc "stow --version"
    
    Write-Host ""
    Write-Host "Note: Stow is installed in MSYS2 environment" -ForegroundColor Yellow
    Write-Host "To use stow, run from MSYS2 bash or use:" -ForegroundColor Yellow
    Write-Host "  $bashPath -c 'stow <arguments>'" -ForegroundColor White
} else {
    Write-Error "Stow installation failed"
    exit 1
}

Write-Host "Stow installation complete!" -ForegroundColor Green
