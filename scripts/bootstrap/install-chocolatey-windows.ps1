#!/usr/bin/env powershell
# Install Chocolatey package manager for Windows
# Based on official installation instructions: https://chocolatey.org/install

$ErrorActionPreference = "Stop"

Write-Host "Installing Chocolatey package manager..." -ForegroundColor Green

# Check if Chocolatey is already installed
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed" -ForegroundColor Yellow
    choco --version
    exit 0
}

# Set execution policy for current user (required for Chocolatey installation)
Write-Host "Setting PowerShell execution policy..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Download and install Chocolatey
Write-Host "Downloading and installing Chocolatey..." -ForegroundColor Cyan
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} catch {
    Write-Error "Failed to install Chocolatey: $_"
    exit 1
}

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify installation
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "✓ Chocolatey installed successfully!" -ForegroundColor Green
    choco --version
} else {
    Write-Error "Chocolatey installation failed"
    exit 1
}

Write-Host "Chocolatey installation complete!" -ForegroundColor Green
Write-Host "Note: Use machine-class import to install packages" -ForegroundColor Cyan