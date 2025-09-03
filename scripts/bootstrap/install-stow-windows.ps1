#!/usr/bin/env powershell
# Install GNU Stow for Windows via Scoop

$ErrorActionPreference = "Stop"

Write-Host "Installing GNU Stow..." -ForegroundColor Green

# Check if Stow is already installed
if (Get-Command stow -ErrorAction SilentlyContinue) {
    Write-Host "Stow is already installed" -ForegroundColor Yellow
    stow --version
    exit 0
}

# Check if Scoop is available
if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop is required to install Stow. Run install-scoop-windows.ps1 first."
    exit 1
}

# Install Stow via Scoop
Write-Host "Installing Stow via Scoop..." -ForegroundColor Cyan
try {
    scoop install stow
} catch {
    Write-Error "Failed to install Stow via Scoop: $_"
    exit 1
}

# Verify installation
if (Get-Command stow -ErrorAction SilentlyContinue) {
    Write-Host "✓ Stow installed successfully!" -ForegroundColor Green
    stow --version
} else {
    Write-Error "Stow installation failed"
    exit 1
}

Write-Host "Stow installation complete!" -ForegroundColor Green