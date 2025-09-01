# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a unified cross-platform package management system (think "better Topgrade") combined with dotfiles management. It provides a single interface to manage packages across multiple package managers while also handling system configuration through GNU Stow.

### Project Goals
**Primary Goal**: Interactive commands (based on `just`) to manage dotfiles and install/update packages
**Secondary Goal**: Partner effectively with AI for project development/maintenance

### Meta-Project Challenge
This project has existed for 387+ commits across multiple years. A core challenge is enabling effective AI assistant handoffs - allowing different AI instances to quickly understand the project state, execute core workflows, and provide consistent help without rebuilding context from scratch each time.

## 🚀 AI Assistant Quick Start

### Essential Context
- **This is a mature, stable project** - focus on *executing workflows* not *understanding architecture*
- **The system works** - troubleshoot and fix issues as needed, but validate through end-user interface
- **Use the `just` interface** - all operations should go through documented commands
- **Prove success with E2E testing** - final validation must be through actual user workflows

### Core Workflows

#### 1. Test the System (Docker-based validation)
```bash
just test-developer-ubuntu    # Full test of user + admin package installation
just test-essential-arch      # Minimal system test
```
**Expected outcome**: Build succeeds, packages install, health check passes
**Success indicators**: Look for "✅ SUCCESS" and non-zero package counts in test output

#### 2. Package Management (Real system)
```bash
just install-packages-user    # Install user-level packages (safe, no sudo)
just install-packages-admin   # Install admin packages (may prompt for password)
just upgrade-packages-user    # Update user packages
just check-packages           # Check for available updates
```
**Expected outcome**: Packages install/upgrade, brew bundle completes successfully
**Success indicators**: "SUCCESS" messages, package counts increase/update

#### 3. Configuration Deployment
```bash
just configure               # Interactive machine class selection
just stow                   # Deploy dotfiles via symlinks
just check-health           # Verify system health
```
**Expected outcome**: Dotfiles symlinked, no broken links, "HEALTHY" status

#### 4. Verification Commands
```bash
just show-package-stats     # Display installed package counts
just show-logs-last         # View most recent operation log
```

### AI Assistant Operating Principles
1. **Fix issues as needed** - troubleshoot problems, update configs, resolve dependencies
2. **But validate through user interface** - final proof of success must be via `just` commands
3. **Focus on E2E outcomes** - did the complete workflow succeed from user perspective?
4. **Use logs for evidence** - grep relevant log files for proof of success
5. **Simple command invocation** - prefer `just command-name` over complex implementations

### Critical Requirement
**All final validation must be through actual end-user workflows** - no shortcuts like `docker run` or manual package checks. If you fix something, prove it works by running the actual `just test-*` or `just install-*` commands that users would run.

## Key Architecture

### Core Architectural Principles

**CRITICAL: Docker is Testing Infrastructure ONLY**
- Docker containers are used exclusively for testing the dotfiles system
- Docker is NOT a target daily driver environment
- Real users run the system on actual Linux/macOS/Windows machines
- Bootstrap scripts in `bootstrap/` folder must work on real systems
- Docker base stages should mirror what bootstrap scripts produce on real systems
- If something is universally needed (like Python3), it belongs in platform bootstrap scripts, not just Docker

**Bootstrap Brings All Platforms to Parity**
- Bootstrap must ensure system "readiness" - all platforms should reach the same functional state
- No platform should be "lame" and require special handling in later stages
- Bootstrap failures should be visible and explicit about which platforms need extra help
- The bootstrap process is a communication interface showing system requirements

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
- Each config directory has its own `.stowrc` with `--dotfiles` and `--target=~` flags
- Configurations are organized by application/tool in separate directories
- Multiple Emacs configurations supported via Chemacs 2 (Doom, Spacemacs, custom)

### Unified Package Management
- **Single interface** for multiple package managers per platform:
  - **macOS**: brew/cask + mas (Mac App Store) + npm/pip/gem
  - **Arch Linux**: pacman + AUR (via yay) + npm/pip/gem
  - **Ubuntu**: apt + npm/pip/gem
  - **Windows**: scoop + chocolatey + MSYS2/pacman
- **Implemented**: zinit (Zsh plugin management)
- **Future**: elpaca (Emacs), lazy.nvim (Neovim), cargo (Rust), pipx (Python CLI tools)
- **Two-step updates**: `just update-check` → `just update-upgrade`

## Docker Testing Design

### Testing Philosophy
Docker tests validate **outcomes** not **implementation details**. The test interface remains stable (e.g., `just test-developer-ubuntu`) while the internal implementation can change. Tests ensure the system meets its goals regardless of how it achieves them.

### Docker Cache Strategy
Each Dockerfile stage only COPYs the files it needs, creating a cache hierarchy:

```dockerfile
# Stage 1: Configure - only needs configure script
COPY configure.sh machine-classes/
RUN ./configure.sh

# Stage 2: Bootstrap - only needs bootstrap scripts  
COPY bootstrap.sh scripts/bootstrap/
RUN ./bootstrap.sh

# Stage 3: Install - needs package scripts
COPY scripts/package-management/
RUN just install-packages
```

**Benefits:**
- Changing package scripts doesn't invalidate configure/bootstrap cache
- Fast iterative development on specific stages
- Realistic testing of both install and upgrade workflows

### Testing Workflows

#### Initial Install Test
Tests what new users experience:
```bash
just test-developer-ubuntu  # Full build, all stages
```

#### Maintenance Workflow Test  
Tests the update cycle with registry caching:
```bash
# First run the install test (builds cache)
just test-developer-ubuntu

# Touch a local file to break Docker cache at COPY layer
touch machine-classes/docker_developer_ubuntu/brew/packages.user

# Test maintenance stages rebuild, earlier stages stay cached
just test-developer-ubuntu-maintenance
```

**Key Insight:** The `touch` command is run LOCALLY (outside Docker) on a file that gets COPYd. This breaks Docker's cache for that COPY layer and all subsequent layers, forcing rebuild of maintenance stages while keeping earlier stages cached.

### Registry Update Separation
- **Only `check-*` commands update registries** (brew update, apt update)
- **`install-*` and `upgrade-*` NEVER update registries**
- Initial install gets fresh registries from bootstrap
- Maintenance workflow explicitly separates check (update registries) from upgrade (use cached state)

This design enables:
1. Check for updates on Friday
2. Review changes over weekend
3. Upgrade on Monday when ready to debug
4. No surprise changes between check and upgrade

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

### Docker Testing Commands (Tiered Approach)
```bash
# CURRENT (working but outdated terminology):
cd test && just test-update basic arch   # Test complete workflow
cd test && just test-run basic arch      # Interactive shell

# CURRENT (tiered testing reflecting real usage patterns):
cd test && just test-min-cli arch     # Minimal CLI tools only
cd test && just test-mid-cli ubuntu   # Extended CLI tools
cd test && just test-mid-dev arch     # Development environment (multi-PM testing begins)
cd test && just test-max-dev ubuntu   # Full development (comprehensive multi-PM validation)

# GUI tiers tested manually only (no Docker)
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

# Note: Each directory has .stowrc with --dotfiles and --target=~ flags
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

## Current Implementation Status (2025-07-29)

### Recently Completed Major Refactoring (July 2025)

**Phase 1: Core Architecture**
- ✅ Major dotfiles reorganization (common/, osx_only/, linux_only/, windows_only/)
- ✅ Environment-driven architecture with ~/.dotfiles.env configuration
- ✅ Fixed all 13 git submodules after reorganization
- ✅ Documentation positioned as "better Topgrade" unified package management

**Phase 2: Tiered Configuration System**
- ✅ Rename `_ADVANCED` → `_HEAVY` throughout system
- ✅ Implement `IS_PERSONAL_MACHINE` and `IS_WORK_MACHINE` context flags
- ✅ Create 4-tier configuration approach (min-cli → mid-cli → mid-dev → max-dev)
- ✅ Update all documentation (README.org, CLAUDE.md) with tiered approach

**Phase 3: Testing Infrastructure Overhaul**
- ✅ Create tiered test recipes (test-min-cli, test-mid-cli, test-mid-dev, test-max-dev)
- ✅ Update Dockerfiles to use proper configuration inputs for each tier
- ✅ Remove all broken test recipes and legacy shortcuts
- ✅ Clean test justfile - only working tiered tests remain
- ✅ Fix Docker path inconsistencies and configuration state management

**Phase 4: Bootstrap Transparency & Health Check Fixes**
- ✅ Create individual install scripts in bootstrap/ folder for transparency
- ✅ Remove hidden curl commands - all downloads now visible
- ✅ Fix Ubuntu bootstrap (sudo for just installer, tomli for Python 3.10)
- ✅ Fix health check symlink detection to work with any dotfiles directory location
- ✅ Update health check to use HEAVY variable names
- ✅ Verify accurate symlink reporting (49 system links, 10 top-level)

**Phase 5: Multi-Package Manager Testing**
- ✅ Test min-cli tier on Arch and Ubuntu (basic functionality)
- ✅ Test mid-cli tier on Arch and Ubuntu (extended CLI tools)
- ✅ Test mid-dev tier on Arch (validates AUR/yay multi-PM installation)
- ✅ Verify health check shows "HEALTHY" status after successful stow operations

## ARCHITECTURE IS NOW STABLE AND PRODUCTION-READY

The system has completed its major architectural transformation. All high-priority tasks are complete.

### Remaining Testing Tasks (Medium Priority)
These can be completed in future sessions as needed:

- 🔄 Test mid-dev tier on Ubuntu (validates APT + other package managers)
- 🔄 Test max-dev tier on Arch (validates full HEAVY package installation)
- 🔄 Test max-dev tier on Ubuntu (validates complete Ubuntu workflow)

### Future Vision (Low Priority)
- App-specific package managers: zinit ✅ implemented, elpaca and lazy.nvim planned
- Complete unified package management across all package managers
- True multi-package-manager coordination and conflict resolution

### Next Session Guidance
The architecture is stable. Future work should focus on:
1. **Completing remaining tier tests** if needed for validation
2. **Adding new package categories** using the established TOML structure
3. **Implementing app-specific package managers** following existing patterns
4. **Production usage** - the system is ready for daily use

The tiered testing system is fully operational and the health check accurately validates system state.

## Workflow Notes

When making changes:
1. Test configurations on relevant platforms using tiered approach
2. Update TOML package definitions when adding new tools
3. Consider both GUI and terminal environments
4. Maintain backward compatibility where possible
5. Use unified package commands rather than individual package managers
6. Test multi-package-manager scenarios in mid-dev and max-dev tiers
