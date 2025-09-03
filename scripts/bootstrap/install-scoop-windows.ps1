#!/usr/bin/env powershell
# Install Scoop package manager for Windows
# Based on official installation instructions: https://scoop.sh/

$ErrorActionPreference = "Stop"

Write-Host "Installing Scoop package manager..." -ForegroundColor Green

# Check if Scoop is already installed
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "Scoop is already installed" -ForegroundColor Yellow
    scoop --version
    exit 0
}

# Set execution policy for current user (required for Scoop installation)
Write-Host "Setting PowerShell execution policy..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Download and install Scoop
Write-Host "Downloading and installing Scoop..." -ForegroundColor Cyan
try {
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} catch {
    Write-Error "Failed to install Scoop: $_"
    exit 1
}

# Verify installation
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "✓ Scoop installed successfully!" -ForegroundColor Green
    scoop --version
} else {
    Write-Error "Scoop installation failed"
    exit 1
}

Write-Host "Scoop installation complete!" -ForegroundColor Green
Write-Host "Note: Use machine-class import to configure buckets and install packages" -ForegroundColor Cyan