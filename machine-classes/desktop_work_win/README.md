# Windows Work Desktop Machine Class

Comprehensive Windows work desktop configuration with multiple package managers and development tools.

## System Overview

This machine class represents a Windows work desktop with:
- **Scoop**: Primary CLI tool and development package manager (47 packages)
- **Chocolatey**: System applications and Windows-specific tools (30+ packages)
- **Winget**: Microsoft Store and modern Windows applications 
- **MSYS2 Pacman**: Unix-like tools and development environment (100+ packages)

## Package Managers

### Scoop (`scoop/packages.txt`)
Core development and CLI tools:
- **Development**: emacs, neovim, python39, lua, perl, just, make, meson
- **CLI Tools**: bat, eza, fzf, ripgrep, fd, jq, tldr, zoxide, hyperfine
- **System**: 7zip, coreutils, unzip, dark, delta, glow
- **Fonts**: iosevka-nf variants for terminal and coding
- **GUI**: wezterm, keypirinha, windirstat, rapidee, fiddler

### Chocolatey (`choco/packages.txt`) 
Windows system integration and specialized tools:
- **System**: .NET frameworks, Windows SDKs, Visual C++ redistributables
- **Applications**: Everything (file search), Divvy (window management)
- **Development**: MSYS2 integration, OpenSSH, various KB updates
- **Tools**: Keypirinha, Switcheroo (window switcher)

### Winget (`winget/packages.json`)
Modern Windows applications and Microsoft ecosystem tools.

### MSYS2 Pacman (`pacman/packages.txt`)
Unix-like development environment:
- **Base**: autotools, base-devel, build essentials
- **Development**: git, tmux, vim, bash, zsh, make, bison
- **Libraries**: Various development libraries and tools
- **Utilities**: Core Unix utilities ported to Windows

## Configuration Files

### Stow Configuration (`stow/stow.txt`)
Dotfiles to symlink for this machine class:
- Common cross-platform configs (git, shell, tmux, editors)
- Work-specific git configuration
- Windows-specific configs (autohotkey, powershell, clink, WSL integration)

## Usage

```bash
# Install packages for this machine class
just install-machine-class desktop_work_win

# Stow configurations  
just stow-machine-class desktop_work_win
```

## Legacy Sources

Created from combination of:
- Live system exports (August 2025)
- Legacy exports: `deprecated/legacy-exports/scoop/min_for_work.scoop`
- Legacy exports: `deprecated/legacy-exports/pacman/windows_msys2/pacman.txt`

## Notes

This represents a mature Windows development workstation with:
- Heavy CLI tooling via Scoop and MSYS2
- Windows system integration via Chocolatey 
- Modern application management via Winget
- Full dotfiles management for cross-platform workflows
- WSL integration for Linux development workflows