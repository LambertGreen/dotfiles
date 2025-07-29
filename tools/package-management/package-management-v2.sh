#!/usr/bin/env bash
# Package Management Tool v2
# Runtime tool supporting both legacy levels and feature flags

set -euo pipefail

# Source shared functions and feature flags
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../shared/common.sh" ]; then
    source "$SCRIPT_DIR/../shared/common.sh"
fi
source "$SCRIPT_DIR/feature-flags.sh"

# Configuration
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev/my/dotfiles}"
PLATFORM="${DOTFILES_PLATFORM:-}"
LEVEL="${DOTFILES_LEVEL:-}"
CONFIG="${DOTFILES_CONFIG:-}"

# Package lists directory
PACKAGE_DATA_DIR="$SCRIPT_DIR/data"

# Logging function
log() {
    echo "[package-mgmt-v2] $*"
}

# Error function
error() {
    echo "[package-mgmt-v2] ERROR: $*" >&2
    exit 1
}

# Validate environment
validate_environment() {
    if [ -z "$PLATFORM" ]; then
        error "DOTFILES_PLATFORM not set. Run: just configure"
    fi
    
    # Check if using feature flags or legacy levels
    if [ -n "$CONFIG" ] || [ -n "$(get_enabled_features 2>/dev/null || true)" ]; then
        log "Using feature flag configuration"
    elif [ -n "$LEVEL" ]; then
        log "Using legacy level configuration: $LEVEL"
    else
        error "No configuration found. Set DOTFILES_LEVEL or DOTFILES_CONFIG"
    fi
    
    if [ ! -d "$PACKAGE_DATA_DIR" ]; then
        error "Package data directory not found: $PACKAGE_DATA_DIR"
    fi
}

# Get packages to install based on configuration mode
get_packages_to_install() {
    local platform="$1"
    
    # Feature flag mode
    if [ -n "$CONFIG" ] || [ -n "$(get_enabled_features 2>/dev/null || true)" ]; then
        log "Getting packages from feature flags"
        get_packages_for_features "$platform"
        return
    fi
    
    # Legacy level mode
    if [ -n "$LEVEL" ]; then
        log "Getting packages from legacy level: $LEVEL"
        get_legacy_packages "$platform" "$LEVEL"
        return
    fi
    
    error "No valid configuration mode found"
}

# Get packages for legacy level system
get_legacy_packages() {
    local platform="$1"
    local level="$2"
    
    local packages=()
    
    # Basic packages for all levels
    if [[ "$level" =~ ^(basic|typical|max)$ ]]; then
        if [ -f "$PACKAGE_DATA_DIR/${platform}-basic-"* ]; then
            for file in "$PACKAGE_DATA_DIR/${platform}-basic-"*; do
                [ -f "$file" ] && cat "$file"
            done
        fi
    fi
    
    # Typical packages
    if [[ "$level" =~ ^(typical|max)$ ]]; then
        if [ -f "$PACKAGE_DATA_DIR/${platform}-typical-"* ]; then
            for file in "$PACKAGE_DATA_DIR/${platform}-typical-"*; do
                [ -f "$file" ] && cat "$file"
            done
        fi
    fi
    
    # Max packages
    if [[ "$level" == "max" ]]; then
        if [ -f "$PACKAGE_DATA_DIR/${platform}-max-"* ]; then
            for file in "$PACKAGE_DATA_DIR/${platform}-max-"*; do
                [ -f "$file" ] && cat "$file"
            done
        fi
    fi
}

# Install packages for macOS
install_packages_osx() {
    log "Installing macOS packages"
    
    # Install Homebrew if not present
    if ! command -v brew >/dev/null 2>&1; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Get packages to install
    local packages
    readarray -t packages < <(get_packages_to_install "osx")
    
    if [ ${#packages[@]} -eq 0 ]; then
        log "No packages to install"
        return
    fi
    
    # Install packages
    log "Installing ${#packages[@]} packages..."
    for package in "${packages[@]}"; do
        [ -n "$package" ] && brew install "$package" || log "Warning: Failed to install $package"
    done
    
    # Install global packages if not in minimal mode
    if [ "$CONFIG" != "minimal" ] && [ "$LEVEL" != "basic" ]; then
        install_global_packages
    fi
}

# Install packages for Arch Linux  
install_packages_arch() {
    log "Installing Arch packages"
    
    # Update system first
    sudo pacman -Syu --noconfirm
    
    # Get packages to install
    local packages
    readarray -t packages < <(get_packages_to_install "arch")
    
    if [ ${#packages[@]} -eq 0 ]; then
        log "No packages to install"
        return
    fi
    
    # Install packages
    log "Installing ${#packages[@]} packages..."
    printf '%s\n' "${packages[@]}" | xargs sudo pacman -S --noconfirm
    
    # Install global packages if not in minimal mode
    if [ "$CONFIG" != "minimal" ] && [ "$LEVEL" != "basic" ]; then
        install_global_packages
    fi
}

# Install packages for Ubuntu
install_packages_ubuntu() {
    log "Installing Ubuntu packages"
    
    # Update package list
    sudo apt update && sudo apt upgrade -y
    
    # Get packages to install
    local packages
    readarray -t packages < <(get_packages_to_install "ubuntu")
    
    if [ ${#packages[@]} -eq 0 ]; then
        log "No packages to install"
        return
    fi
    
    # Install packages
    log "Installing ${#packages[@]} packages..."
    printf '%s\n' "${packages[@]}" | xargs sudo apt install -y
    
    # Install global packages if not in minimal mode
    if [ "$CONFIG" != "minimal" ] && [ "$LEVEL" != "basic" ]; then
        install_global_packages
    fi
}

# Install global packages (Python, Node, Ruby)
install_global_packages() {
    log "Installing global packages..."
    
    # Python packages - handle externally-managed-environment
    if command -v python3 >/dev/null 2>&1; then
        log "Installing Python packages..."
        if python3 -m pip install --upgrade pip 2>/dev/null; then
            # Regular pip install works
            python3 -m pip install black pyflakes isort pytest nose pipenv pynvim || log "Warning: Some Python packages failed to install"
        else
            # Use --break-system-packages for externally-managed environments like Arch
            log "Using --break-system-packages for externally-managed Python environment"
            python3 -m pip install --upgrade pip --break-system-packages || log "Warning: pip upgrade failed"
            python3 -m pip install black pyflakes isort pytest nose pipenv pynvim --break-system-packages || log "Warning: Some Python packages failed to install"
        fi
    fi
    
    # Node.js packages
    if command -v npm >/dev/null 2>&1; then
        log "Installing Node.js packages..."
        npm install -g typescript typescript-language-server stylelint js-beautify js-tidy prettier neovim || log "Warning: Some Node.js packages failed to install"
    fi
    
    # Ruby packages
    if command -v gem >/dev/null 2>&1; then
        log "Installing Ruby packages..."
        gem install solargraph || log "Warning: Ruby packages failed to install"
    fi
}

# Update packages (same logic for both modes)
update_packages() {
    log "Updating packages for platform: $PLATFORM"
    
    case "$PLATFORM" in
        osx)
            if command -v brew >/dev/null 2>&1; then
                brew update && brew upgrade && brew cleanup
            fi
            if command -v mas >/dev/null 2>&1; then
                mas upgrade
            fi
            ;;
        arch)
            if command -v yay >/dev/null 2>&1; then
                yay -Syu --noconfirm
            else
                sudo pacman -Syu --noconfirm
            fi
            ;;
        ubuntu)
            sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
            if command -v brew >/dev/null 2>&1; then
                brew update && brew upgrade
            fi
            ;;
        *)
            error "Unsupported platform: $PLATFORM"
            ;;
    esac
    
    # Update global packages if not minimal
    if [ "$CONFIG" != "minimal" ] && [ "$LEVEL" != "basic" ]; then
        log "Updating global packages..."
        
        # Python packages
        if command -v python3 >/dev/null 2>&1; then
            if python3 -m pip install --upgrade pip 2>/dev/null; then
                python3 -m pip install --upgrade pip black pyflakes isort pytest nose pipenv pynvim || log "Warning: Some Python package updates failed"
            else
                python3 -m pip install --upgrade pip black pyflakes isort pytest nose pipenv pynvim --break-system-packages || log "Warning: Some Python package updates failed"
            fi
        fi
        
        # Node.js packages
        if command -v npm >/dev/null 2>&1; then
            npm update -g || log "Warning: Node.js package updates failed"
        fi
        
        # Ruby packages
        if command -v gem >/dev/null 2>&1; then
            gem update || log "Warning: Ruby package updates failed"
        fi
    fi
}

# Main install function
package_install() {
    validate_environment
    
    log "Installing packages for platform: $PLATFORM"
    
    case "$PLATFORM" in
        osx)
            install_packages_osx
            ;;
        arch)
            install_packages_arch
            ;;
        ubuntu)
            install_packages_ubuntu
            ;;
        msys2)
            error "MSYS2 package installation not yet implemented"
            ;;
        *)
            error "Unsupported platform: $PLATFORM"
            ;;
    esac
    
    log "Package installation complete for $PLATFORM"
}

# Main update function
package_update() {
    validate_environment
    update_packages
    log "Package update complete for $PLATFORM"
}

# Show configuration
package_show_config() {
    validate_environment
    
    if [ -n "$CONFIG" ] || [ -n "$(get_enabled_features 2>/dev/null || true)" ]; then
        show_config
    else
        echo "=== Dotfiles Package Configuration (Legacy) ==="
        echo "Platform: $PLATFORM"
        echo "Level: $LEVEL"
        echo ""
        echo "Packages to install:"
        get_legacy_packages "$PLATFORM" "$LEVEL"
    fi
}

# Export functions for use as library
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script called directly
    case "${1:-}" in
        install)
            package_install
            ;;
        update)
            package_update
            ;;
        show-config)
            package_show_config
            ;;
        *)
            echo "Usage: $0 {install|update|show-config}"
            echo "Environment variables required: DOTFILES_PLATFORM, DOTFILES_LEVEL or DOTFILES_CONFIG"
            exit 1
            ;;
    esac
fi