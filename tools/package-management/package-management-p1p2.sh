#!/usr/bin/env bash
# Package Management Tool - P1/P2 Priority System
# Runtime tool supporting category-based package management with priority levels

set -euo pipefail

# Source shared functions if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../shared/common.sh" ]; then
    source "$SCRIPT_DIR/../shared/common.sh"
fi

# Configuration
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev/my/dotfiles}"
PLATFORM="${DOTFILES_PLATFORM:-}"

# Package lists directory
PACKAGE_DATA_DIR="$SCRIPT_DIR/data"

# Logging function
log() {
    echo "[package-mgmt-p1p2] $*"
}

# Error function
error() {
    echo "[package-mgmt-p1p2] ERROR: $*" >&2
    exit 1
}

# Validate environment
validate_environment() {
    if [ -z "$PLATFORM" ]; then
        error "DOTFILES_PLATFORM not set. Run: just configure"
    fi
    
    if [ ! -d "$PACKAGE_DATA_DIR" ]; then
        error "Package data directory not found: $PACKAGE_DATA_DIR"
    fi
}

# Get packages from files matching pattern
get_packages_from_files() {
    local pattern="$1"
    local packages=()
    
    for file in "$PACKAGE_DATA_DIR"/$pattern; do
        if [ -f "$file" ]; then
            log "Reading packages from: $(basename "$file")"
            while IFS= read -r package; do
                # Skip empty lines and comments
                if [[ -n "$package" && ! "$package" =~ ^[[:space:]]*# ]]; then
                    packages+=("$package")
                fi
            done < "$file"
        fi
    done
    
    printf '%s\n' "${packages[@]}"
}

# Install packages using specific package manager
install_packages_with_manager() {
    local manager="$1"
    local packages=("${@:2}")
    
    if [ ${#packages[@]} -eq 0 ]; then
        log "No $manager packages to install"
        return
    fi
    
    log "Installing ${#packages[@]} $manager packages: ${packages[*]}"
    
    case "$manager" in
        "brew")
            if ! command -v brew >/dev/null 2>&1; then
                log "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            # Add taps if needed
            brew tap adoptopenjdk/openjdk 2>/dev/null || true
            brew tap d12frosted/emacs-plus 2>/dev/null || true
            brew tap homebrew/cask 2>/dev/null || true
            brew tap homebrew/cask-fonts 2>/dev/null || true
            
            for package in "${packages[@]}"; do
                brew install "$package" || log "Warning: Failed to install $package"
            done
            ;;
        "cask")
            if ! command -v brew >/dev/null 2>&1; then
                error "Homebrew required for cask packages"
            fi
            for package in "${packages[@]}"; do
                brew install --cask "$package" || log "Warning: Failed to install $package"
            done
            ;;
        "mas")
            if ! command -v mas >/dev/null 2>&1; then
                log "Warning: mas not available, skipping App Store installs"
                return
            fi
            for package in "${packages[@]}"; do
                mas install "$package" || log "Warning: Failed to install $package"
            done
            ;;
        "pacman")
            sudo pacman -Syu --noconfirm
            printf '%s\n' "${packages[@]}" | xargs sudo pacman -S --noconfirm
            ;;
        "aur")
            # Install yay if not present
            if ! command -v yay >/dev/null 2>&1; then
                log "Installing yay for AUR packages..."
                git clone https://aur.archlinux.org/yay.git /tmp/yay
                cd /tmp/yay
                makepkg -si --noconfirm
                cd -
                rm -rf /tmp/yay
            fi
            printf '%s\n' "${packages[@]}" | xargs yay -S --noconfirm
            ;;
        "apt")
            sudo apt update
            printf '%s\n' "${packages[@]}" | xargs sudo apt install -y
            ;;
        *)
            error "Unsupported package manager: $manager"
            ;;
    esac
}

# Install packages for a category and priority level
install_category_priority() {
    local category="$1"
    local priority="$2"  # "basic-core", "p1", "p2"
    
    log "Installing $category $priority packages for platform: $PLATFORM"
    
    # Group packages by package manager
    declare -A packages_by_manager
    
    # Find all files matching the pattern
    local pattern="${PLATFORM}-${priority}-${category}-*"
    for file in "$PACKAGE_DATA_DIR"/$pattern; do
        if [ -f "$file" ]; then
            # Extract package manager from filename
            local manager=$(basename "$file" | sed "s/${PLATFORM}-${priority}-${category}-//; s/\.txt//")
            
            log "Found $manager packages in: $(basename "$file")"
            
            # Read packages from file
            while IFS= read -r package; do
                # Skip empty lines and comments
                if [[ -n "$package" && ! "$package" =~ ^[[:space:]]*# ]]; then
                    packages_by_manager["$manager"]+="$package "
                fi
            done < "$file"
        fi
    done
    
    # Install packages grouped by manager
    for manager in "${!packages_by_manager[@]}"; do
        local package_list=(${packages_by_manager["$manager"]})
        install_packages_with_manager "$manager" "${package_list[@]}"
    done
}

# Main install function
package_install() {
    validate_environment
    
    log "Installing packages for platform: $PLATFORM"
    
    # Always install basic core packages
    install_category_priority "core" "basic"
    
    # Install P1 categories if enabled
    if [ "${DOTFILES_CLI_EDITORS:-false}" = "true" ]; then
        install_category_priority "cli-editors" "p1"
    fi
    
    if [ "${DOTFILES_DEV_ENV:-false}" = "true" ]; then
        install_category_priority "dev-env" "p1"
    fi
    
    if [ "${DOTFILES_CLI_UTILS:-false}" = "true" ]; then
        install_category_priority "cli-utils" "p1"
    fi
    
    if [ "${DOTFILES_GUI_APPS:-false}" = "true" ]; then
        install_category_priority "gui-apps" "p1"
    fi
    
    # Install P2 categories if explicitly enabled
    if [ "${DOTFILES_CLI_EDITORS_P2:-false}" = "true" ]; then
        install_category_priority "cli-editors" "p2"
    fi
    
    if [ "${DOTFILES_DEV_ENV_P2:-false}" = "true" ]; then
        install_category_priority "dev-env" "p2"
    fi
    
    if [ "${DOTFILES_CLI_UTILS_P2:-false}" = "true" ]; then
        install_category_priority "cli-utils" "p2"
    fi
    
    if [ "${DOTFILES_GUI_APPS_P2:-false}" = "true" ]; then
        install_category_priority "gui-apps" "p2"
    fi
    
    # Install global packages if development environment enabled
    if [ "${DOTFILES_DEV_ENV:-false}" = "true" ]; then
        install_global_packages
    fi
    
    log "Package installation complete for $PLATFORM"
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

# Show current configuration
package_show_config() {
    validate_environment
    
    echo "=== Dotfiles Package Configuration (P1/P2 System) ==="
    echo "Platform: $PLATFORM"
    echo ""
    
    echo "Core (always enabled):"
    echo "  ✓ basic-core"
    echo ""
    
    echo "P1 Categories:"
    [ "${DOTFILES_CLI_EDITORS:-false}" = "true" ] && echo "  ✓ CLI_EDITORS" || echo "  ✗ CLI_EDITORS"
    [ "${DOTFILES_DEV_ENV:-false}" = "true" ] && echo "  ✓ DEV_ENV" || echo "  ✗ DEV_ENV"
    [ "${DOTFILES_CLI_UTILS:-false}" = "true" ] && echo "  ✓ CLI_UTILS" || echo "  ✗ CLI_UTILS"
    [ "${DOTFILES_GUI_APPS:-false}" = "true" ] && echo "  ✓ GUI_APPS" || echo "  ✗ GUI_APPS"
    echo ""
    
    echo "P2 Categories:"
    [ "${DOTFILES_CLI_EDITORS_P2:-false}" = "true" ] && echo "  ✓ CLI_EDITORS_P2" || echo "  ✗ CLI_EDITORS_P2"
    [ "${DOTFILES_DEV_ENV_P2:-false}" = "true" ] && echo "  ✓ DEV_ENV_P2" || echo "  ✗ DEV_ENV_P2"
    [ "${DOTFILES_CLI_UTILS_P2:-false}" = "true" ] && echo "  ✓ CLI_UTILS_P2" || echo "  ✗ CLI_UTILS_P2"
    [ "${DOTFILES_GUI_APPS_P2:-false}" = "true" ] && echo "  ✓ GUI_APPS_P2" || echo "  ✗ GUI_APPS_P2"
}

# Update packages (same as before)
package_update() {
    validate_environment
    
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
    
    log "Package update complete for $PLATFORM"
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
            echo "Environment variables: DOTFILES_PLATFORM, DOTFILES_CLI_EDITORS, DOTFILES_DEV_ENV, etc."
            exit 1
            ;;
    esac
fi