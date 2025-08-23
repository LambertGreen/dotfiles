#!/usr/bin/env powershell
# Install MSYS2 independently for Windows
# MSYS2 provides Unix-like tools and pacman package manager
# Note: MSYS2 updates are handled manually to allow review of changes

$ErrorActionPreference = "Stop"

Write-Host "Installing MSYS2..." -ForegroundColor Green

# Check if MSYS2 is already installed (check common locations)
$msys2Locations = @("C:\msys64\usr\bin\pacman.exe", "C:\tools\msys64\usr\bin\pacman.exe")
$msys2Path = $null

foreach ($location in $msys2Locations) {
    if (Test-Path $location) {
        $msys2Path = $location
        break
    }
}

if ($msys2Path) {
    Write-Host "MSYS2 is already installed at: $msys2Path" -ForegroundColor Yellow
    & $msys2Path --version
    exit 0
}

# Direct download and install
Write-Host "Installing MSYS2 via direct download..." -ForegroundColor Cyan
$installerUrl = "https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe"
$installerPath = "$env:TEMP\msys2-installer.exe"

try {
    Write-Host "Downloading MSYS2 installer..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    
    Write-Host "Running MSYS2 installer (silent install to C:\msys64)..." -ForegroundColor Cyan
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    
    Remove-Item $installerPath -Force
} catch {
    Write-Error "Failed to install MSYS2: $_"
    exit 1
}

# Verify installation (check both locations again)
$verifyPath = $null
foreach ($location in $msys2Locations) {
    if (Test-Path $location) {
        $verifyPath = $location
        break
    }
}

if ($verifyPath) {
    Write-Host "✓ MSYS2 installed successfully at: $verifyPath" -ForegroundColor Green
    & $verifyPath --version
} else {
    Write-Error "MSYS2 installation failed"
    exit 1
}

Write-Host "MSYS2 installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Important notes:" -ForegroundColor Yellow
Write-Host "- MSYS2 updates are handled manually (not via scoop/choco)" -ForegroundColor Cyan
Write-Host "- Update MSYS2 with: pacman -Syu (review changes before applying)" -ForegroundColor Cyan
Write-Host "- Use machine-class import to install pacman packages" -ForegroundColor Cyan