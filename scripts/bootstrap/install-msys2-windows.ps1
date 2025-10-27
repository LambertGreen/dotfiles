#!/usr/bin/env powershell
# Install MSYS2 independently for Windows
# MSYS2 provides Unix-like tools and pacman package manager

$ErrorActionPreference = "Stop"

Write-Host "Installing MSYS2..." -ForegroundColor Green

# Function to detect MSYS2 root directory
function Get-MSYS2Root {
    $msys2Locations = @("C:\msys64\usr\bin\pacman.exe", "C:\tools\msys64\usr\bin\pacman.exe")

    foreach ($location in $msys2Locations) {
        if (Test-Path $location) {
            # Extract root directory (e.g., C:\msys64 from C:\msys64\usr\bin\pacman.exe)
            $root = (Get-Item $location).Directory.Parent.Parent.FullName
            return $root
        }
    }
    return $null
}

# Check if MSYS2 is already installed
$msys2Root = Get-MSYS2Root

if ($msys2Root) {
    Write-Host "MSYS2 is already installed at: $msys2Root" -ForegroundColor Yellow
    $pacmanPath = Join-Path $msys2Root "usr\bin\pacman.exe"
    & $pacmanPath --version
} else {
    # Direct download and install
    Write-Host "Installing MSYS2 via direct download..." -ForegroundColor Cyan
    $installerUrl = "https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe"
    $installerPath = "$env:TEMP\msys2-installer.exe"
    $defaultInstallPath = "C:\msys64"

    try {
        Write-Host "Downloading MSYS2 installer..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

        Write-Host "Running MSYS2 installer (silent install to $defaultInstallPath)..." -ForegroundColor Cyan
        Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait

        Remove-Item $installerPath -Force
    } catch {
        Write-Error "Failed to install MSYS2: $_"
        exit 1
    }

    # Verify installation
    $msys2Root = Get-MSYS2Root

    if ($msys2Root) {
        Write-Host "✅ MSYS2 installed successfully at: $msys2Root" -ForegroundColor Green
        $pacmanPath = Join-Path $msys2Root "usr\bin\pacman.exe"
        & $pacmanPath --version
    } else {
        Write-Error "MSYS2 installation failed"
        exit 1
    }
}

# Configure Windows environment variables for MSYS2 (always run, even if already installed)
Write-Host ""
Write-Host "Configuring MSYS2 environment variables..." -ForegroundColor Cyan

# Add MSYS2 to User PATH (if not already present)
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$msys2BinPath = Join-Path $msys2Root "usr\bin"

# Detect architecture and choose appropriate MinGW environment
$arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
if ($arch -eq "ARM64") {
    $mingwBinPath = Join-Path $msys2Root "clangarm64\bin"
    $mingwEnv = "CLANGARM64"
} else {
    # x86_64/AMD64 - use UCRT64 (recommended default since Oct 2022)
    $mingwBinPath = Join-Path $msys2Root "ucrt64\bin"
    $mingwEnv = "UCRT64"
}

Write-Host "Detected architecture: $arch -> Using $mingwEnv environment" -ForegroundColor Cyan

# Add MinGW environment bin (Windows-native compilers and tools)
# Must come BEFORE msys64\usr\bin to avoid calling wrong gcc
if ($currentPath -notlike "*$mingwBinPath*") {
    Write-Host "Adding $mingwBinPath to User PATH..." -ForegroundColor Cyan
    $newPath = "$currentPath;$mingwBinPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $currentPath = $newPath
    Write-Host "✅ $mingwEnv bin added to PATH" -ForegroundColor Green
} else {
    Write-Host "✅ $mingwEnv bin already in PATH" -ForegroundColor Green
}

# Add MSYS2 usr/bin (POSIX utilities)
if ($currentPath -notlike "*$msys2BinPath*") {
    Write-Host "Adding $msys2BinPath to User PATH..." -ForegroundColor Cyan
    $newPath = "$currentPath;$msys2BinPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "✅ MSYS2 usr/bin added to PATH" -ForegroundColor Green
} else {
    Write-Host "✅ MSYS2 usr/bin already in PATH" -ForegroundColor Green
}

# Set MSYS environment variable for native symlink support (required for GNU Stow)
$currentMSYS = [Environment]::GetEnvironmentVariable("MSYS", "User")
if ($currentMSYS -ne "winsymlinks:nativestrict") {
    Write-Host "Setting MSYS=winsymlinks:nativestrict (required for GNU Stow)..." -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable("MSYS", "winsymlinks:nativestrict", "User")
    Write-Host "✅ MSYS environment variable configured" -ForegroundColor Green
} else {
    Write-Host "✅ MSYS environment variable already configured" -ForegroundColor Green
}

# Set MSYS2_PATH_TYPE to inherit Windows PATH (allows running scoop/choco apps from MSYS2)
$currentPathType = [Environment]::GetEnvironmentVariable("MSYS2_PATH_TYPE", "User")
if ($currentPathType -ne "inherit") {
    Write-Host "Setting MSYS2_PATH_TYPE=inherit (allows Windows PATH in MSYS2)..." -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable("MSYS2_PATH_TYPE", "inherit", "User")
    Write-Host "✅ MSYS2_PATH_TYPE configured" -ForegroundColor Green
} else {
    Write-Host "✅ MSYS2_PATH_TYPE already configured" -ForegroundColor Green
}

# Store MSYS2 root in .dotfiles.env for other scripts to use
Write-Host ""
Write-Host "Storing MSYS2 root path..." -ForegroundColor Cyan

$dotfilesEnv = "$env:USERPROFILE\.dotfiles.env"
if (Test-Path $dotfilesEnv) {
    $envContent = Get-Content $dotfilesEnv
    $msys2RootLine = "export MSYS2_ROOT=`"$msys2Root`""

    # Remove existing MSYS2_ROOT line if present
    $envContent = $envContent | Where-Object { $_ -notmatch "^export MSYS2_ROOT=" }

    # Add new MSYS2_ROOT line
    $envContent += $msys2RootLine

    Set-Content -Path $dotfilesEnv -Value $envContent
    Write-Host "✅ MSYS2_ROOT=$msys2Root stored in ~/.dotfiles.env" -ForegroundColor Green
} else {
    Write-Host "⚠️  ~/.dotfiles.env not found, skipping MSYS2_ROOT storage" -ForegroundColor Yellow
}

# Configure MSYS2 home directory to use Windows home
Write-Host ""
Write-Host "Configuring MSYS2 home directory..." -ForegroundColor Cyan

$nsswitchConf = Join-Path $msys2Root "etc\nsswitch.conf"
if (Test-Path $nsswitchConf) {
    $content = Get-Content $nsswitchConf
    $currentDbHome = $content | Select-String "^db_home:"
    
    if ($currentDbHome -match "db_home:\s*windows\s*$") {
        Write-Host "✅ MSYS2 home directory already configured correctly" -ForegroundColor Green
    } else {
        Write-Host "Current setting: $currentDbHome" -ForegroundColor Yellow
        Write-Host "Updating nsswitch.conf to use Windows home directory..." -ForegroundColor Cyan
        
        # Update line by line
        $newContent = $content | ForEach-Object {
            if ($_ -match "^db_home:") {
                "db_home: windows"
            } else {
                $_
            }
        }
        
        Set-Content -Path $nsswitchConf -Value $newContent
        Write-Host "✅ MSYS2 home directory configured to use Windows USERPROFILE" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️  nsswitch.conf not found at $nsswitchConf" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ MSYS2 installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Restart your shell to pick up environment variable changes" -ForegroundColor Yellow
