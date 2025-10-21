# Package Management Architecture Design

## Vision: Super Package Manager with Transparent Registration

The goal is to create a **super package manager** that abstracts over multiple platform-specific package managers while providing transparent, granular control over what gets installed.

### Core Principles

1. **Transparent Registration** - `.dotfiles.env` clearly shows what categories are enabled
2. **Package Manager Flexibility** - Same app can come from different sources (brew vs apt vs AUR vs winget vs build-from-source)
3. **Codified Choices** - Explicit decisions about which package manager to use for each app on each platform
4. **Easy Setup & Updates** - Simple commands that work consistently across platforms
5. **Adaptability** - Can change package sources over time without breaking the interface

### Package Manager Abstraction Examples

**Emacs Installation Strategy:**
- **macOS**: `d12frosted/emacs-plus/emacs-plus@31` (Homebrew tap for latest)
- **Arch**: `emacs-plus` (AUR for latest features)  
- **Ubuntu**: `emacs` (system apt) or build from source for latest
- **Windows**: winget vs scoop choice based on overhead preferences

**Development Tools Strategy:**
- **System package managers first** (pacman, apt, homebrew)
- **Specialized managers when needed** (npm for JS tools, pip for Python)
- **Build from source** when packages are outdated
- **Private taps/repos** for custom builds with dependency management

## Category-Based Configuration

Replace opaque `basic/typical/max` levels with explicit, meaningful categories:

### Proposed Categories

```bash
# Always enabled
DOTFILES_CORE_SHELL=true           # git, stow, tmux, zsh, curl, wget

# Main feature categories  
DOTFILES_EDITORS=true              # emacs, neovim, vscode
DOTFILES_DEV_ENV=true              # python, node, ruby, rust, gcc, cmake, docker
DOTFILES_CLI_UTILS=true            # ripgrep, fd, bat, eza, jq, htop, tree
DOTFILES_GUI_APPS=false            # desktop applications, browsers
DOTFILES_FONTS=true                # nerd fonts, typography
DOTFILES_EMAIL=false               # isync, mu, msmtp

# Platform-specific
DOTFILES_MAC_STORE_APPS=false      # Mac App Store apps (macOS only)
```

### Category Consolidation

**DOTFILES_DEV_ENV** combines:
- Programming languages (python, node, ruby, rust, java)
- Build tools (gcc, cmake, ninja, make, clang)
- Containers (docker, docker-compose)
- Environment managers (pyenv, rbenv, jenv, direnv)
- Language servers and dev utilities

This consolidation makes sense because:
- These tools are typically needed together
- Reduces configuration complexity
- Represents a coherent "development environment" concept
- Can still be granularly controlled if needed later

## Architecture Components

### 1. Category Definitions (`categories.sh`)
```bash
# Core categories with package mappings
declare -A CATEGORY_PACKAGES
CATEGORY_PACKAGES[CORE_SHELL]="git stow tmux zsh curl wget"
CATEGORY_PACKAGES[DEV_ENV]="python node ruby rust gcc cmake docker"
CATEGORY_PACKAGES[EDITORS]="emacs neovim"
# ...
```

### 2. Platform-Specific Package Resolution (`resolvers/`)
```
resolvers/
├── osx.sh       # Homebrew, cask, mas strategies  
├── arch.sh      # pacman, AUR strategies
├── ubuntu.sh    # apt, snap, homebrew strategies
└── msys2.sh     # scoop, winget, pacman strategies
```

Each resolver maps abstract package names to concrete installation commands:
```bash
# osx.sh
resolve_package() {
    case $1 in
        "emacs") echo "d12frosted/emacs-plus/emacs-plus@31" ;;
        "python") echo "python pyenv pyenv-virtualenv" ;;
        # ...
    esac
}
```

### 3. Installation Engine (`package-manager.sh`)
```bash
install_category() {
    local category=$1
    local packages=$(get_packages_for_category $category)
    local platform_resolver="resolvers/${DOTFILES_PLATFORM}.sh"
    
    for package in $packages; do
        local resolved=$(resolve_package $package)
        install_resolved_package $resolved
    done
}
```

### 4. Configuration Interface (`configure.sh`)
Interactive setup that generates transparent `.dotfiles.env`:
```bash
# Dotfiles Configuration  
# Generated: 2024-01-15
export DOTFILES_PLATFORM=osx
export DOTFILES_CORE_SHELL=true
export DOTFILES_EDITORS=true  
export DOTFILES_DEV_ENV=true
export DOTFILES_CLI_UTILS=true
export DOTFILES_GUI_APPS=false
export DOTFILES_FONTS=true
export DOTFILES_EMAIL=false
```

## Configuration Profiles

Pre-defined combinations for common setups:

```bash
# Developer workstation
DEVELOPER_PROFILE="CORE_SHELL EDITORS DEV_ENV CLI_UTILS FONTS"

# Work machine (no personal tools)  
WORK_PROFILE="CORE_SHELL EDITORS DEV_ENV CLI_UTILS"

# Headless server
SERVER_PROFILE="CORE_SHELL DEV_ENV"

# Personal desktop
PERSONAL_PROFILE="CORE_SHELL EDITORS DEV_ENV CLI_UTILS GUI_APPS FONTS EMAIL"
```

## Implementation Strategy

### Phase 1: Category-based System
1. Design category definitions and package mappings
2. Create platform-specific resolvers  
3. Build installation engine with category support
4. Update configure script for category selection
5. Maintain backward compatibility with legacy levels

### Phase 2: Package Manager Flexibility
1. Implement sophisticated package resolution strategies
2. Add support for multiple package sources per platform
3. Create override mechanisms for custom package choices
4. Add build-from-source capabilities

### Phase 3: Advanced Features  
1. Dependency management across package managers
2. Private tap/repository support
3. Version pinning and update policies
4. Rollback and package removal capabilities

## Example Workflows

### Initial Setup
```bash
./configure.sh
# Interactive selection: developer profile + GUI apps
# Generates .dotfiles.env with transparent categories

./bootstrap.sh     # Install just, basic tools
just stow          # Deploy configurations  
just install       # Install packages per categories
```

### Adding a Category
```bash
# Edit .dotfiles.env
export DOTFILES_EMAIL=true

just install       # Install email tools (isync, mu, msmtp)
```

### Platform Migration  
```bash
# Same .dotfiles.env works on new platform
# Package resolver handles platform-specific choices
git clone dotfiles && cd dotfiles
source .dotfiles.env  # Load existing config
./configure.sh        # Auto-detect new platform, keep categories
just bootstrap && just stow && just install
```

## Benefits

1. **Transparency** - Clear visibility into what's configured
2. **Flexibility** - Can change package sources without breaking interface  
3. **Consistency** - Same categories work across all platforms
4. **Maintainability** - Package choices centralized in resolvers
5. **Extensibility** - Easy to add new categories or platforms
6. **Migration-friendly** - Configuration travels between machines

## Discussion Points

1. **Category granularity** - Are the proposed categories the right level of detail?
2. **Package resolution strategy** - How sophisticated should the resolver logic be?
3. **Override mechanisms** - How should users customize package choices?
4. **Backward compatibility** - Should we maintain legacy level support?
5. **Testing strategy** - How do we validate this across platforms?

## Next Steps

1. Review and refine category definitions
2. Design package resolver interface
3. Plan migration from current level-based system
4. Define testing approach for multi-platform validation