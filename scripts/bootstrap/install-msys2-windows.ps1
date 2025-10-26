#!/usr/bin/env powershell
# Install MSYS2 independently for Windows
# MSYS2 provides Unix-like tools and pacman package manager

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
} else {
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
        Write-Host "✅ MSYS2 installed successfully at: $verifyPath" -ForegroundColor Green
        & $verifyPath --version
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
$msys2BinPath = "C:\msys64\usr\bin"

# Detect architecture and choose appropriate MinGW environment
$arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
if ($arch -eq "ARM64") {
    $mingwBinPath = "C:\msys64\clangarm64\bin"
    $mingwEnv = "CLANGARM64"
} else {
    # x86_64/AMD64 - use UCRT64 (recommended default since Oct 2022)
    $mingwBinPath = "C:\msys64\ucrt64\bin"
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

# Configure MSYS2 home directory to use Windows home
Write-Host ""
Write-Host "Configuring MSYS2 home directory..." -ForegroundColor Cyan

$nsswitchConf = "C:\msys64\etc\nsswitch.conf"
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
