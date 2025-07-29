# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository containing configuration files and setup scripts for cross-platform development environments (macOS, Windows, Linux). The repository uses GNU Stow for dotfile management and Just for system maintenance tasks.

## Key Architecture

### Directory Structure
- **Reorganized config structure** (as of 2024-07):
  - `configs/common/` - Cross-platform configurations
  - `configs/osx_only/` - macOS-specific configurations
  - `configs/windows_only/` - Windows-specific configurations
  - `configs/linux_only/` - Linux-specific configurations
- **Setup scripts**: `setup_*` directories contain platform-specific installation and configuration scripts
- **System maintenance**: `sys_maintenance_*` directories contain Just files for automated system upkeep
- **Tools**: `tools/` directory contains utilities like health check and package management

### Configuration Management
- Uses **GNU Stow** for symlinking dotfiles to home directory
- Each config directory has its own `.stowrc` with `--dotfiles` and `--no-folding` flags
- Configurations are organized by application/tool in separate directories
- Multiple Emacs configurations supported via Chemacs 2 (Doom, Spacemacs, custom)

### Package Management Strategy
- **macOS**: Homebrew (preferred) + Mac App Store (via `mas`)
- **Windows**: Scoop (preferred) + Chocolatey + MSYS2/Pacman for Unix tools
- **Linux**: System package managers + Homebrew Linux + Nix/Home Manager

## Common Commands

### System Maintenance (using Just)
```bash
# From project root (new environment-driven approach):
just stow                  # Stow configurations based on .dotfiles.env
just check-health          # Run health check on system
just cleanup-broken-links  # Find broken symlinks (dry run)
just cleanup-broken-links-remove  # Remove broken symlinks

# Navigate to system maintenance directory for updates:
just goto-sys-maintenance

# In sys_maintenance directory:
just system-check          # Preview all available updates
just system-upgrade        # Weekly fast update (brew, mas, completions)
just system-maintain       # Monthly deep maintenance
just brew-upgrade          # Update Homebrew packages
just mas-upgrade          # Update Mac App Store apps (macOS)
```

### Docker Testing Commands
```bash
# AUTOMATED tests (can be run in CI/scripts):
cd test && just test-stow basic arch      # Test through stow stage
cd test && just test-install basic arch   # Test through install stage
cd test && just test-update basic arch    # Test complete workflow

# INTERACTIVE tests (require human interaction - DO NOT USE IN SCRIPTS):
cd test && just test-run basic arch       # Drops into interactive shell for manual testing
```

### Dotfile Management
```bash
# New approach - from project root:
just stow                  # Automatically stows based on .dotfiles.env settings

# Manual stowing (from within config directories):
cd configs/common
stow git git_my shell tmux vim wezterm spelling

# Platform-specific configs (macOS example):
cd ../osx_only
stow git_osx shell_osx alacritty_osx hammerspoon

# Remove symlinks
stow -D <package_name>

# Note: Each directory has .stowrc with --dotfiles and --no-folding flags
```

### Package Manager Operations
```bash
# Homebrew (macOS/Linux)
brew bundle dump                    # Export current packages to Brewfile
brew bundle --file=./Brewfile      # Install from Brewfile

# Scoop (Windows)
scoop export > packages.json       # Export package list
scoop install packages.json        # Install from export
```

### Git Submodules
```bash
# Initialize after cloning
git submodule update --init --recursive
```

## Development Environment Setup

### Primary Editor: Emacs
- Multiple configurations via Chemacs 2: Doom Emacs (primary), Spacemacs, custom
- Doom Emacs health check: `doom doctor`
- Configuration locations:
  - Doom: `~/.emacs.doom/`
  - Custom: `~/.emacs.default/`
  - Chemacs profiles: `~/.emacs-profiles.el`

### Terminal Setup
- Primary terminal: WezTerm (cross-platform)
- Shell: Zsh with custom configurations
- Multiplexer: tmux with custom themes and plugin management
- Color support: 24-bit true color configured via terminfo

### Language Support
- Python: pyenv + pip for global packages
- Node.js: npm for global packages
- Ruby: rbenv + gem

## Important Files

### Configuration Files
- `README.org`: Comprehensive setup instructions for all platforms
- `TODO.org`: Current tasks and ongoing work
- `.dotfiles.env`: Environment variables for configuration (e.g., DOTFILES_CLI_EDITORS=true)
- Shell configs: `configs/common/shell/dot-zshrc`, `configs/common/shell/dot-shell_common`
- Git configs: `configs/common/git/dot-common.gitconfig`, `configs/*/git_*/dot-gitconfig` (platform-specific)
- Tmux: `configs/common/tmux/dot-tmux.conf` with theme system
- Editor configs: `configs/common/emacs/dot-doom.d/`, `configs/common/nvim/dot-config/nvim-*/`

### System Maintenance
- Main justfile: `justfile` (project root)
- Platform-specific: `sys_maintenance_*/dot-sys_maintenance/justfile`
- Package management: `tools/package-management/` with TOML definitions
- Health check: `tools/dotfiles-health/dotfiles-health.sh`

## Special Considerations

### Cross-Platform Compatibility
- Path handling varies between platforms (Windows vs Unix)
- Package names may differ between package managers
- Some tools require platform-specific configurations (e.g., Karabiner on macOS, AutoHotkey on Windows)

### Security
- Email configurations use system keychain for password storage
- GPG configurations are platform-specific
- SSH configurations follow platform conventions

### Performance
- ZSH completions require proper permissions (use `compaudit` to check)
- Emacs uses native compilation where available
- Terminal color support configured for performance

## Workflow Notes

When making changes:
1. Test configurations on relevant platforms
2. Update package export files when adding new tools
3. Consider both GUI and terminal environments
4. Maintain backward compatibility where possible
5. Use Just for system maintenance rather than manual commands
