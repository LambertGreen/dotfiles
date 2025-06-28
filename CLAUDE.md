# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository containing configuration files and setup scripts for cross-platform development environments (macOS, Windows, Linux). The repository uses GNU Stow for dotfile management and Just for system maintenance tasks.

## Key Architecture

### Directory Structure
- **Platform-specific configs**: Directories ending with `_osx`, `_win`, `_linux`, `_msys2` contain platform-specific configurations
- **Cross-platform configs**: Base directories (e.g., `emacs`, `git`, `shell`) contain universal configurations
- **Setup scripts**: `setup_*` directories contain platform-specific installation and configuration scripts
- **System maintenance**: `sys_maintenance_*` directories contain Just files for automated system upkeep

### Configuration Management
- Uses **GNU Stow** for symlinking dotfiles to home directory
- Configurations are organized by application/tool in separate directories
- Multiple Emacs configurations supported via Chemacs 2 (Doom, Spacemacs, custom)

### Package Management Strategy
- **macOS**: Homebrew (preferred) + Mac App Store (via `mas`)
- **Windows**: Scoop (preferred) + Chocolatey + MSYS2/Pacman for Unix tools
- **Linux**: System package managers + Homebrew Linux + Nix/Home Manager

## Common Commands

### System Maintenance (using Just)
```bash
# Navigate to system maintenance directory
just goto-sys-maintenance

# In sys_maintenance directory:
just system-check          # Preview all available updates
just system-upgrade         # Weekly fast update (brew, mas, completions)
just system-maintain        # Monthly deep maintenance
just brew-upgrade           # Update Homebrew packages
just mas-upgrade           # Update Mac App Store apps (macOS)
```

### Dotfile Management
```bash
# Navigate to configs directory first
cd configs

# Symlink common configs
stow git git_my shell tmux vim wezterm spelling

# Symlink platform-specific configs (macOS example)  
stow git_osx shell_osx alacritty_osx

# Symlink from root for submodule-containing packages (until reorganized)
cd ..
stow emacs hammerspoon nvim alfred-settings autohotkey nvim_win

# Remove symlinks
stow -D <package_name>
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
- Shell configs: `shell/dot-zshrc`, `shell/dot-shell_common`
- Git configs: `git/dot-common.gitconfig`, `git_*/dot-gitconfig` (platform-specific)
- Tmux: `tmux/dot-tmux.conf` with theme system
- Editor configs: `emacs/dot-doom.d/`, `nvim/dot-config/nvim-*/`

### System Maintenance
- Main justfile: `just/dot-justfile`
- Platform-specific: `sys_maintenance_*/dot-sys_maintenance/justfile`
- Common tasks: `sys_maintenance/dot-sys_maintenance/justfile_common`

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