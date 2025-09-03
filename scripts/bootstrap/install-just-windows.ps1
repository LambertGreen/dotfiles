#!/usr/bin/env powershell
# Install Just task runner for Windows via Scoop

$ErrorActionPreference = "Stop"

Write-Host "Installing Just task runner..." -ForegroundColor Green

# Check if Just is already installed
if (Get-Command just -ErrorAction SilentlyContinue) {
    Write-Host "Just is already installed" -ForegroundColor Yellow
    just --version
    exit 0
}

# Check if Scoop is available
if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop is required to install Just. Run install-scoop-windows.ps1 first."
    exit 1
}

# Install Just via Scoop
Write-Host "Installing Just via Scoop..." -ForegroundColor Cyan
try {
    scoop install just
} catch {
    Write-Error "Failed to install Just via Scoop: $_"
    exit 1
}

# Verify installation
if (Get-Command just -ErrorAction SilentlyContinue) {
    Write-Host "✓ Just installed successfully!" -ForegroundColor Green
    just --version
} else {
    Write-Error "Just installation failed"
    exit 1
}

Write-Host "Just installation complete!" -ForegroundColor Green