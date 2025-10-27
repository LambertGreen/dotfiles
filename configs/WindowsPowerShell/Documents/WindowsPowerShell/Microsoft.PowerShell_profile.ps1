# ============================================================================
# Auto-Setup for PowerShell Modules (like zinit pattern in zsh)
# ============================================================================
function Initialize-PowerShellModules {
    $RequiredModules = @(
        @{Name='PSFzf'; Description='Fuzzy finder for files and command history (Ctrl+T, Ctrl+R)'},
        @{Name='posh-git'; Description='Git integration and prompt enhancements'},
        @{Name='z'; Description='Fast directory navigation based on frecency'},
        @{Name='Get-ChildItemColor'; Description='Colorized ls/dir output'}
    )

    # Check for missing modules
    $MissingModules = @()
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $Module.Name)) {
            $MissingModules += $Module
        }
    }

    # Check for oh-my-posh separately (it's a command, not a module)
    $OhMyPoshMissing = -not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)

    if ($MissingModules.Count -eq 0 -and -not $OhMyPoshMissing) {
        return  # All modules installed, nothing to do
    }

    # Display what's missing
    Write-Host ""
    Write-Host "PowerShell enhancement modules are not fully installed." -ForegroundColor Yellow
    Write-Host ""

    if ($MissingModules.Count -gt 0) {
        Write-Host "Missing PowerShell modules:" -ForegroundColor Cyan
        foreach ($Module in $MissingModules) {
            Write-Host "  - $($Module.Name): $($Module.Description)" -ForegroundColor White
        }
        Write-Host ""
    }

    if ($OhMyPoshMissing) {
        Write-Host "Missing tools:" -ForegroundColor Cyan
        Write-Host "  - oh-my-posh: Modern prompt theme engine" -ForegroundColor White
        Write-Host ""
    }

    # Prompt with timeout (like zinit)
    Write-Host "Do you want to install them now? [Y/n] (auto-installs in 10s)" -ForegroundColor Green

    $TimeoutSeconds = 10
    $StartTime = Get-Date
    $Response = $null

    while (((Get-Date) - $StartTime).TotalSeconds -lt $TimeoutSeconds) {
        if ([Console]::KeyAvailable) {
            $Key = [Console]::ReadKey($true)
            $Response = $Key.KeyChar
            break
        }
        Start-Sleep -Milliseconds 100
    }

    if ($Response -eq 'n' -or $Response -eq 'N') {
        Write-Host "Skipping installation. Modules will not be loaded." -ForegroundColor Yellow
        return
    }

    if ($null -eq $Response) {
        Write-Host "Y (timeout)" -ForegroundColor Green
    } else {
        Write-Host ""
    }

    # Install missing modules
    if ($MissingModules.Count -gt 0) {
        Write-Host ""
        Write-Host "Installing PowerShell modules..." -ForegroundColor Cyan

        foreach ($Module in $MissingModules) {
            Write-Host "  Installing $($Module.Name)..." -ForegroundColor White
            try {
                Install-Module -Name $Module.Name -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
                Write-Host "  ✓ $($Module.Name) installed successfully" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Failed to install $($Module.Name): $_" -ForegroundColor Red
            }
        }
    }

    # Install oh-my-posh via scoop if missing
    if ($OhMyPoshMissing) {
        Write-Host ""
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            Write-Host "  Installing oh-my-posh via scoop..." -ForegroundColor White
            try {
                scoop install oh-my-posh
                Write-Host "  ✓ oh-my-posh installed successfully" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Failed to install oh-my-posh: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  ⚠ Scoop not found. Install oh-my-posh manually with: scoop install oh-my-posh" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Installation complete. Restart your shell to load the modules." -ForegroundColor Green
    Write-Host "  (Close this window and open a new one, or run: & `$PROFILE)" -ForegroundColor Gray
    Write-Host ""
}

function Initialize-OhMyPoshThemes {
    $ThemesPath = "$HOME/dev/pub/oh-my-posh"

    # Check if themes directory exists
    if (Test-Path $ThemesPath) {
        return  # Already exists
    }

    # Check if oh-my-posh is installed
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        return  # oh-my-posh not installed, skip
    }

    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "⚠ Git not found. Cannot clone oh-my-posh themes." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Oh-My-Posh themes repository not found at: $ThemesPath" -ForegroundColor Yellow
    Write-Host "Do you want to clone it now? [Y/n] (auto-clones in 10s)" -ForegroundColor Green

    $TimeoutSeconds = 10
    $StartTime = Get-Date
    $Response = $null

    while (((Get-Date) - $StartTime).TotalSeconds -lt $TimeoutSeconds) {
        if ([Console]::KeyAvailable) {
            $Key = [Console]::ReadKey($true)
            $Response = $Key.KeyChar
            break
        }
        Start-Sleep -Milliseconds 100
    }

    if ($Response -eq 'n' -or $Response -eq 'N') {
        Write-Host "Skipping. Oh-My-Posh will show CONFIG ERROR until themes are installed." -ForegroundColor Yellow
        return
    }

    if ($null -eq $Response) {
        Write-Host "Y (timeout)" -ForegroundColor Green
    } else {
        Write-Host ""
    }

    Write-Host ""
    Write-Host "Cloning oh-my-posh themes..." -ForegroundColor Cyan

    try {
        New-Item -ItemType Directory -Path "$HOME/dev/pub" -Force | Out-Null

        $CloneResult = git clone --depth 1 https://github.com/JanDeDobbeleer/oh-my-posh.git $ThemesPath 2>&1

        if (Test-Path "$ThemesPath/themes") {
            Write-Host "✓ Oh-My-Posh themes cloned successfully" -ForegroundColor Green
            Write-Host "  Location: $ThemesPath/themes" -ForegroundColor Gray
        } else {
            Write-Host "✗ Clone appeared to succeed but themes directory not found" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Failed to clone oh-my-posh themes: $_" -ForegroundColor Red
    }

    Write-Host ""
}

# Run auto-setup checks
Initialize-PowerShellModules
Initialize-OhMyPoshThemes

# ============================================================================
# Readline settings
# ============================================================================
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# ============================================================================
# Module Imports (with error handling)
# ============================================================================

# Enable Fzf for fast search for: files, and command history
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# Enable git completions
if (Get-Module -ListAvailable -Name posh-git) {
    Import-Module posh-git
}

# Enable fast directory navigation using z command
if (Get-Module -ListAvailable -Name z) {
    Import-Module z
}

# Enable ls colors
if (Get-Module -ListAvailable -Name Get-ChildItemColor) {
    Import-Module Get-ChildItemColor
    Set-Alias ll Get-ChildItemColor -option AllScope
    Set-Alias ls Get-ChildItemColorFormatWide -option AllScope
}

# Bat wrapper because less pager does not correctly show colors,
# so set no paging
function lgreen-run-bat { bat.exe $args --paging=never}
Set-Alias bat lgreen-run-bat -option AllScope

# Show files when running tree command
function lgreen-run-tree { tree.com /F }
Set-Alias tree lgreen-run-tree

Set-Alias which get-command
Set-Alias g git

# ============================================================================
# Prompt - Oh-My-Posh
# ============================================================================
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh | Invoke-Expression
}

# Set code codepage so that unicode is correctly displayed in Vim
chcp 65001 > $null

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Enable Windows dark mode
function lgreen-enable-dark-mode {
  Set-ItemProperty `
    -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize `
    -Name AppsUseLightTheme `
    -Value 0
}

# Disable Windows dark mode
function lgreen-disable-dark-mode {
  Set-ItemProperty `
    -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize `
    -Name AppsUseLightTheme `
    -Value 1
}
Set-Alias okta-aws C:\okta-aws.bat
