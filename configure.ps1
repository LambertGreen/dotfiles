#!/usr/bin/env powershell
# Configure Script for Dotfiles Environment - Windows Version
# Sets up platform and basic environment, then configures machine class for package management

param(
    [switch]$NoAutodetect,
    [switch]$Help
)

if ($Help) {
    Write-Host "Dotfiles Configuration - Windows"
    Write-Host ""
    Write-Host "Sets up your dotfiles environment configuration."
    Write-Host ""
    Write-Host "Usage: .\configure.ps1 [-NoAutodetect]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -NoAutodetect   Disable automatic platform detection"
    Write-Host ""
    exit 0
}

$ErrorActionPreference = "Stop"

# Set up logging
$DOTFILES_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$USER_LOG_ROOT = Join-Path $env:USERPROFILE ".dotfiles"
$LOG_DIR = Join-Path $USER_LOG_ROOT "logs"
$LOG_FILE = Join-Path $LOG_DIR ("configure-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

# Create log directory if it doesn't exist
if (!(Test-Path $USER_LOG_ROOT)) {
    New-Item -ItemType Directory -Force -Path $USER_LOG_ROOT | Out-Null
}
if (!(Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
}

# Initialize log file with header
@"
Dotfiles Configuration Log
==========================
Date: $(Get-Date)
Machine: $env:COMPUTERNAME
User: $env:USERNAME
Script: configure.ps1 $($args -join ' ')
==========================

"@ | Out-File -FilePath $LOG_FILE

# Function to log both to console and file
function Log-Output {
    param($Message)
    Write-Host $Message
    Add-Content -Path $LOG_FILE -Value $Message
}

# Function to log only to file (for verbose details)
function Log-Verbose {
    param($Message)
    Add-Content -Path $LOG_FILE -Value $Message
}

# Function to handle prompts with timeout
function Prompt-WithTimeout {
    param(
        [string]$Prompt,
        [string]$Default,
        [int]$TimeoutSeconds = 15
    )
    
    Write-Host -NoNewline $Prompt
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = ""
    
    while ($stopwatch.ElapsedMilliseconds -lt ($TimeoutSeconds * 1000)) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq "Enter") {
                Write-Host ""
                break
            }
            $result += $key.KeyChar
            Write-Host -NoNewline $key.KeyChar
        }
        Start-Sleep -Milliseconds 100
    }
    
    if ($result -eq "") {
        $result = $Default
        Write-Host " (timeout - using default: $Default)"
        Log-Verbose "Timeout after ${TimeoutSeconds}s, using default: $Default"
    }
    
    return $result
}

Log-Output "???? Dotfiles Configuration - Windows"
Log-Output ""

# Check if already configured
$envFile = "$env:USERPROFILE\.dotfiles.env"
if (Test-Path $envFile) {
    Write-Host "???? Current configuration found:"
    Get-Content $envFile
    Write-Host ""
    
    $reconfigure = Prompt-WithTimeout -Prompt "Reconfigure? (y/N): " -Default "N"
    if ($reconfigure -notmatch "^[Yy]$") {
        Write-Host "??? Using existing configuration"
        exit 0
    }
    Write-Host ""
}

# Auto-detect platform
$DETECTED_PLATFORM = "unknown"
if (!$NoAutodetect) {
    Write-Host "???? Auto-detecting platform..."
    
    # Check for Windows-specific indicators
    if ($env:OS -eq "Windows_NT") {
        # Check for WSL
        if (Test-Path env:WSL_DISTRO_NAME) {
            $DETECTED_PLATFORM = "wsl"
            Write-Host "??? Detected: Windows Subsystem for Linux"
        }
        # Check for MSYS2
        elseif ((Test-Path "C:\msys64") -or (Test-Path "C:\tools\msys64")) {
            $DETECTED_PLATFORM = "msys2"
            Write-Host "??? Detected: Windows with MSYS2"
        }
        # Native Windows
        else {
            $DETECTED_PLATFORM = "windows"
            Write-Host "??? Detected: Windows (native)"
        }
    }
    
    Write-Host ""
}

# Platform selection
$PLATFORM = ""
if (!$NoAutodetect -and $DETECTED_PLATFORM -ne "unknown") {
    $use_detected = Prompt-WithTimeout -Prompt "Use detected platform ($DETECTED_PLATFORM)? (Y/n): " -Default "Y"
    if ($use_detected -match "^[Nn]$") {
        $PLATFORM = ""
    } else {
        $PLATFORM = $DETECTED_PLATFORM
    }
}

if ($PLATFORM -eq "") {
    Write-Host "Available platforms:"
    Write-Host "  1) windows - Native Windows"
    Write-Host "  2) msys2   - Windows with MSYS2"
    Write-Host "  3) wsl     - Windows Subsystem for Linux"
    Write-Host ""
    
    $platform_choice = Prompt-WithTimeout -Prompt "Select platform (1-3): " -Default "2"
    
    switch ($platform_choice) {
        "1" { $PLATFORM = "windows" }
        "2" { $PLATFORM = "msys2" }
        "3" { $PLATFORM = "wsl" }
        default { 
            Write-Host "??? Invalid choice" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""

# Check if machine class already exists
$EXISTING_MACHINE_CLASS = ""
if (Test-Path $envFile) {
    $content = Get-Content $envFile -Raw
    if ($content -match 'export DOTFILES_MACHINE_CLASS="([^"]+)"') {
        $EXISTING_MACHINE_CLASS = $matches[1]
    }
}

# Configure machine class
$MACHINE_CLASS = ""
$MACHINES_DIR = Join-Path $DOTFILES_ROOT "machine-classes"

if ($EXISTING_MACHINE_CLASS) {
    Write-Host "???? Current machine class: $EXISTING_MACHINE_CLASS"
    $change_class = Prompt-WithTimeout -Prompt "Change machine class? (y/N): " -Default "N"
    if ($change_class -match "^[Yy]$") {
        $MACHINE_CLASS = ""
    } else {
        $MACHINE_CLASS = $EXISTING_MACHINE_CLASS
    }
}

# Check if machine class is pre-set (for automation)
if ($env:DOTFILES_MACHINE_CLASS) {
    $MACHINE_CLASS = $env:DOTFILES_MACHINE_CLASS
    Write-Host "???? Using pre-set machine class: $MACHINE_CLASS"
}

if ($MACHINE_CLASS -eq "") {
    Write-Host ""
    Write-Host "??????  Machine Class Configuration"
    Write-Host ""
    
    # Display available machine classes for Windows
    Write-Host "???? Available machine classes:"
    Write-Host ""
    
    # Get Windows-relevant machine classes
    $machines = @()
    $machineFiles = Get-ChildItem -Path $MACHINES_DIR -Directory | Where-Object {
        $_.Name -match 'win|wsl|desktop|laptop|vm'
    }
    
    $i = 1
    foreach ($machine in $machineFiles) {
        $machineName = $machine.Name
        $machines += $machineName
        
        # Try to determine a description
        $description = ""
        if ($machineName -match "desktop_work_win") {
            $description = "Windows Desktop (Work)"
        } elseif ($machineName -match "desktop_gaming_win") {
            $description = "Windows Desktop (Gaming)"
        } elseif ($machineName -match "laptop_work_win") {
            $description = "Windows Laptop (Work)"
        } elseif ($machineName -match "wsl_work") {
            $description = "WSL Environment (Work)"
        } elseif ($machineName -match "vm.*win") {
            $description = "Windows Virtual Machine"
        } else {
            $description = $machineName
        }
        
        Write-Host "  $i) $machineName - $description"
        $i++
    }
    
    Write-Host ""
    $machine_choice = Prompt-WithTimeout -Prompt "Select machine class (1-$($machines.Count)): " -Default "1"
    
    try {
        $index = [int]$machine_choice - 1
        if ($index -ge 0 -and $index -lt $machines.Count) {
            $MACHINE_CLASS = $machines[$index]
        } else {
            Write-Host "??? Invalid choice" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "??? Invalid input" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Check if my/work configuration needed
$CONTEXT = ""
if (Test-Path $envFile) {
    $content = Get-Content $envFile -Raw
    if ($content -match 'export DOTFILES_CONTEXT="([^"]+)"') {
        $CONTEXT = $matches[1]
    }
}

if ($CONTEXT -eq "") {
    Write-Host "???? Context Configuration"
    Write-Host ""
    Write-Host "Select context for personal customizations:"
    Write-Host "  1) my   - Personal configuration"
    Write-Host "  2) work - Work configuration"
    Write-Host ""
    
    $context_choice = Prompt-WithTimeout -Prompt "Select context (1-2): " -Default "1"
    
    switch ($context_choice) {
        "1" { $CONTEXT = "my" }
        "2" { $CONTEXT = "work" }
        default { 
            Write-Host "??? Invalid choice" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""

# Create environment file
Write-Host "???? Creating configuration file..."
Log-Verbose "Writing to $envFile"

$envContent = @"
# Dotfiles Environment Configuration
# Generated by configure.ps1 on $(Get-Date)
export DOTFILES_PLATFORM="$PLATFORM"
export DOTFILES_MACHINE_CLASS="$MACHINE_CLASS"
export DOTFILES_CONTEXT="$CONTEXT"
export DOTFILES_ROOT="$($DOTFILES_ROOT -replace '\\', '/')"
"@

$envContent | Out-File -FilePath $envFile -Encoding ASCII

Write-Host ""
Write-Host "??? Configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "???? Summary:" -ForegroundColor Cyan
Write-Host "  Platform:      $PLATFORM" -ForegroundColor White
Write-Host "  Machine Class: $MACHINE_CLASS" -ForegroundColor White
Write-Host "  Context:       $CONTEXT" -ForegroundColor White
Write-Host "  Config File:   $envFile" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  .\bootstrap.ps1     # Install package managers and tools" -ForegroundColor White
Write-Host "  just stow           # Deploy configurations" -ForegroundColor White
Write-Host "  just check-health   # Verify setup" -ForegroundColor White
Write-Host ""
Write-Host "???? Tip: Configuration saved to $envFile"
Write-Host "   You can edit this file directly if needed."
