#!/usr/bin/env powershell
# Windows Bootstrap Script
# Installs package managers, then converges to POSIX tools via MSYS2

param(
    [switch]$Help
)

if ($Help) {
    Write-Host "Windows Dotfiles Bootstrap"
    Write-Host ""
    Write-Host "This script installs Windows package managers and essential tools,"
    Write-Host "then converges to POSIX tools (bash, just, stow) via MSYS2."
    Write-Host ""
    Write-Host "Usage: .\bootstrap.ps1"
    Write-Host ""
    Write-Host "After bootstrap:"
    Write-Host "  All tools (just, stow, etc.) run via MSYS2 bash environment"
    Write-Host "  Cross-platform configs work the same on all systems"
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host "???? Windows Dotfiles Bootstrap" -ForegroundColor Magenta
Write-Host ""

# Check if configured
if (!(Test-Path "$env:USERPROFILE\.dotfiles.env")) {
    Write-Host "??? Not configured yet. Run: .\configure.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "???? Phase 1: Installing Windows Package Managers" -ForegroundColor Yellow
Write-Host ""

$scriptDir = "scripts\bootstrap"

# Install package managers
try {
    & "$scriptDir\install-scoop-windows.ps1"
    & "$scriptDir\install-chocolatey-windows.ps1" 
    & "$scriptDir\install-msys2-windows.ps1"
} catch {
    Write-Error "Package manager installation failed: $_"
    exit 1
}

Write-Host ""
Write-Host "???? Phase 2: Installing Essential POSIX Tools" -ForegroundColor Yellow
Write-Host ""

# Install just and stow via scoop (for POSIX tool convergence)
try {
    & "$scriptDir\install-just-windows.ps1"
    & "$scriptDir\install-stow-windows.ps1"
} catch {
    Write-Error "POSIX tool installation failed: $_"
    exit 1
}

Write-Host ""
Write-Host "??? Windows Bootstrap Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "???? Convergence: All platforms now use the same tools:" -ForegroundColor Cyan
Write-Host "  ??? bash (via MSYS2)" -ForegroundColor White
Write-Host "  ??? just (cross-platform task runner)" -ForegroundColor White  
Write-Host "  ??? stow (dotfile symlink manager)" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  just stow           # Deploy configurations" -ForegroundColor White
Write-Host "  just check-health   # Verify setup" -ForegroundColor White
